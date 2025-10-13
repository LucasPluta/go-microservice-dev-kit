# Examples

This document provides practical examples of using the GoMicroserviceFramework.

## Example 1: Creating a Simple Health Check Service

Create a minimal internal service without any external dependencies:

```bash
./scripts/create-service.sh health-service --internal
```

This creates a service that:
- Has no database, cache, or message queue dependencies
- Provides basic health check endpoints
- Can be used for service mesh health monitoring

## Example 2: User Management Service

Create a user service with PostgreSQL and Redis:

```bash
./scripts/create-service.sh user-service --postgres --redis
```

### Implement User Storage

Edit `services/user-service/proto/user-service.proto`:

```protobuf
syntax = "proto3";

package userservice;

option go_package = "user-service/proto";

service UserServiceService {
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse) {}
  rpc GetUser(GetUserRequest) returns (GetUserResponse) {}
  rpc UpdateUser(UpdateUserRequest) returns (UpdateUserResponse) {}
  rpc DeleteUser(DeleteUserRequest) returns (DeleteUserResponse) {}
  rpc ListUsers(ListUsersRequest) returns (stream User) {}
}

message User {
  string id = 1;
  string username = 2;
  string email = 3;
  int64 created_at = 4;
  int64 updated_at = 5;
}

message CreateUserRequest {
  string username = 1;
  string email = 2;
}

message CreateUserResponse {
  User user = 1;
  string message = 2;
}

message GetUserRequest {
  string id = 1;
}

message GetUserResponse {
  User user = 1;
}

message UpdateUserRequest {
  string id = 1;
  string username = 2;
  string email = 3;
}

message UpdateUserResponse {
  User user = 1;
  string message = 2;
}

message DeleteUserRequest {
  string id = 1;
}

message DeleteUserResponse {
  string message = 1;
}

message ListUsersRequest {
  int32 limit = 1;
  int32 offset = 2;
}
```

Generate protobuf code (from repository root):

```bash
make proto SERVICE=user-service
```

Implement the service layer (`internal/service/service.go`):

```go
package service

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	redisclient "github.com/go-redis/redis/v8"
	"github.com/google/uuid"
)

type Service struct {
	ctx   context.Context
	db    *sql.DB
	redis *redisclient.Client
}

type User struct {
	ID        string
	Username  string
	Email     string
	CreatedAt time.Time
	UpdatedAt time.Time
}

func NewService(ctx context.Context, db *sql.DB, redis *redisclient.Client, nc *natslib.Conn) *Service {
	s := &Service{
		ctx:   ctx,
		db:    db,
		redis: redis,
	}
	s.initDB()
	return s
}

func (s *Service) initDB() {
	if s.db == nil {
		return
	}
	
	// Create users table
	query := `
		CREATE TABLE IF NOT EXISTS users (
			id VARCHAR(36) PRIMARY KEY,
			username VARCHAR(255) NOT NULL UNIQUE,
			email VARCHAR(255) NOT NULL UNIQUE,
			created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
		)
	`
	_, err := s.db.ExecContext(s.ctx, query)
	if err != nil {
		log.Printf("Failed to create users table: %v", err)
	}
}

func (s *Service) CreateUser(username, email string) (*User, error) {
	user := &User{
		ID:        uuid.New().String(),
		Username:  username,
		Email:     email,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	
	query := `
		INSERT INTO users (id, username, email, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := s.db.ExecContext(s.ctx, query,
		user.ID, user.Username, user.Email, user.CreatedAt, user.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}
	
	// Cache user in Redis
	if s.redis != nil {
		cacheKey := fmt.Sprintf("user:%s", user.ID)
		s.redis.HSet(s.ctx, cacheKey,
			"username", user.Username,
			"email", user.Email,
		)
		s.redis.Expire(s.ctx, cacheKey, 1*time.Hour)
	}
	
	return user, nil
}

func (s *Service) GetUser(userID string) (*User, error) {
	// Try cache first
	if s.redis != nil {
		cacheKey := fmt.Sprintf("user:%s", userID)
		result, err := s.redis.HGetAll(s.ctx, cacheKey).Result()
		if err == nil && len(result) > 0 {
			return &User{
				ID:       userID,
				Username: result["username"],
				Email:    result["email"],
			}, nil
		}
	}
	
	// Fetch from database
	user := &User{}
	query := `
		SELECT id, username, email, created_at, updated_at
		FROM users WHERE id = $1
	`
	err := s.db.QueryRowContext(s.ctx, query, userID).Scan(
		&user.ID, &user.Username, &user.Email, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	
	// Update cache
	if s.redis != nil {
		cacheKey := fmt.Sprintf("user:%s", userID)
		s.redis.HSet(s.ctx, cacheKey,
			"username", user.Username,
			"email", user.Email,
		)
		s.redis.Expire(s.ctx, cacheKey, 1*time.Hour)
	}
	
	return user, nil
}

func (s *Service) UpdateUser(userID, username, email string) (*User, error) {
	query := `
		UPDATE users
		SET username = $1, email = $2, updated_at = $3
		WHERE id = $4
		RETURNING id, username, email, created_at, updated_at
	`
	
	user := &User{}
	err := s.db.QueryRowContext(s.ctx, query, username, email, time.Now(), userID).Scan(
		&user.ID, &user.Username, &user.Email, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to update user: %w", err)
	}
	
	// Invalidate cache
	if s.redis != nil {
		cacheKey := fmt.Sprintf("user:%s", userID)
		s.redis.Del(s.ctx, cacheKey)
	}
	
	return user, nil
}

func (s *Service) DeleteUser(userID string) error {
	query := "DELETE FROM users WHERE id = $1"
	result, err := s.db.ExecContext(s.ctx, query, userID)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}
	
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("user not found")
	}
	
	// Invalidate cache
	if s.redis != nil {
		cacheKey := fmt.Sprintf("user:%s", userID)
		s.redis.Del(s.ctx, cacheKey)
	}
	
	return nil
}

func (s *Service) ListUsers(limit, offset int32) ([]*User, error) {
	query := `
		SELECT id, username, email, created_at, updated_at
		FROM users
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`
	
	rows, err := s.db.QueryContext(s.ctx, query, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to list users: %w", err)
	}
	defer rows.Close()
	
	users := []*User{}
	for rows.Next() {
		user := &User{}
		err := rows.Scan(&user.ID, &user.Username, &user.Email, &user.CreatedAt, &user.UpdatedAt)
		if err != nil {
			continue
		}
		users = append(users, user)
	}
	
	return users, nil
}
```

Implement handlers (`internal/handler/handler.go`):

```go
package handler

import (
	"context"
	
	"user-service/internal/service"
	pb "user-service/proto"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Handler struct {
	pb.UnimplementedUserServiceServiceServer
	svc *service.Service
}

func NewHandler(svc *service.Service) *Handler {
	return &Handler{
		svc: svc,
	}
}

func (h *Handler) CreateUser(ctx context.Context, req *pb.CreateUserRequest) (*pb.CreateUserResponse, error) {
	if req.Username == "" || req.Email == "" {
		return nil, status.Error(codes.InvalidArgument, "username and email are required")
	}
	
	user, err := h.svc.CreateUser(req.Username, req.Email)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to create user: %v", err)
	}
	
	return &pb.CreateUserResponse{
		User: &pb.User{
			Id:        user.ID,
			Username:  user.Username,
			Email:     user.Email,
			CreatedAt: user.CreatedAt.Unix(),
			UpdatedAt: user.UpdatedAt.Unix(),
		},
		Message: "User created successfully",
	}, nil
}

func (h *Handler) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.GetUserResponse, error) {
	if req.Id == "" {
		return nil, status.Error(codes.InvalidArgument, "user id is required")
	}
	
	user, err := h.svc.GetUser(req.Id)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "user not found: %v", err)
	}
	
	return &pb.GetUserResponse{
		User: &pb.User{
			Id:        user.ID,
			Username:  user.Username,
			Email:     user.Email,
			CreatedAt: user.CreatedAt.Unix(),
			UpdatedAt: user.UpdatedAt.Unix(),
		},
	}, nil
}

// Implement other handlers similarly...
```

## Example 3: Notification Service with NATS

Create a notification service that publishes and subscribes to events:

```bash
./scripts/create-service.sh notification-service --nats
```

Implement event publishing in `internal/service/service.go`:

```go
func (s *Service) PublishNotification(userID, message string) error {
	if s.nats == nil {
		return fmt.Errorf("NATS not configured")
	}
	
	notification := map[string]interface{}{
		"user_id":   userID,
		"message":   message,
		"timestamp": time.Now().Unix(),
	}
	
	data, err := json.Marshal(notification)
	if err != nil {
		return fmt.Errorf("failed to marshal notification: %w", err)
	}
	
	subject := "notifications.user." + userID
	err = s.nats.Publish(subject, data)
	if err != nil {
		return fmt.Errorf("failed to publish notification: %w", err)
	}
	
	log.Printf("Published notification to %s", subject)
	return nil
}

func (s *Service) SubscribeToNotifications(userID string, handler func(string)) error {
	if s.nats == nil {
		return fmt.Errorf("NATS not configured")
	}
	
	subject := "notifications.user." + userID
	
	_, err := s.nats.Subscribe(subject, func(msg *nats.Msg) {
		var notification map[string]interface{}
		if err := json.Unmarshal(msg.Data, &notification); err != nil {
			log.Printf("Failed to unmarshal notification: %v", err)
			return
		}
		
		if message, ok := notification["message"].(string); ok {
			handler(message)
		}
	})
	
	return err
}
```

## Example 4: Inter-Service Communication

Services can communicate with each other via gRPC:

```go
// In order-service, call user-service
import (
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	userpb "user-service/proto"
)

func (s *Service) CreateOrder(userID string, items []string) error {
	// Connect to user service
	conn, err := grpc.Dial("user-service:50051", 
		grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return fmt.Errorf("failed to connect to user service: %w", err)
	}
	defer conn.Close()
	
	client := userpb.NewUserServiceServiceClient(conn)
	
	// Verify user exists
	resp, err := client.GetUser(context.Background(), &userpb.GetUserRequest{
		Id: userID,
	})
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}
	
	log.Printf("Creating order for user: %s", resp.User.Username)
	
	// Create order...
	return nil
}
```

## Example 5: Complete Docker Compose Setup

Add all services to `docker-compose.yml`:

```yaml
version: '3.8'

services:
  # Infrastructure
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: microservices
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  nats:
    image: nats:2-alpine
    ports:
      - "4222:4222"
      - "8222:8222"
    command: ["-js", "-m", "8222"]
    healthcheck:
      test: ["CMD", "wget", "-q", "-O-", "http://localhost:8222/healthz"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Services
  user-service:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        SERVICE_NAME: user-service
    ports:
      - "50051:50051"
    environment:
      - SERVICE_NAME=user-service
      - GRPC_PORT=50051
      - USE_POSTGRES=true
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=microservices
      - USE_REDIS=true
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  notification-service:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        SERVICE_NAME: notification-service
    ports:
      - "50052:50051"
    environment:
      - SERVICE_NAME=notification-service
      - GRPC_PORT=50051
      - USE_NATS=true
      - NATS_URL=nats://nats:4222
    depends_on:
      nats:
        condition: service_healthy

  health-service:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        SERVICE_NAME: health-service
    ports:
      - "50053:50051"
    environment:
      - SERVICE_NAME=health-service
      - GRPC_PORT=50051

volumes:
  postgres_data:
```

Start all services:

```bash
docker-compose up -d
```

## Example 6: Testing with grpcurl

```bash
# User Service - Create user
grpcurl -plaintext -d '{"username": "john_doe", "email": "john@example.com"}' \
  localhost:50051 userservice.UserServiceService/CreateUser

# User Service - Get user
grpcurl -plaintext -d '{"id": "USER_ID"}' \
  localhost:50051 userservice.UserServiceService/GetUser

# User Service - List users (streaming)
grpcurl -plaintext -d '{"limit": 10, "offset": 0}' \
  localhost:50051 userservice.UserServiceService/ListUsers

# Notification Service
grpcurl -plaintext -d '{"user_id": "USER_ID", "message": "Hello"}' \
  localhost:50052 notificationservice.NotificationServiceService/SendNotification

# Health Service
grpcurl -plaintext -d '{"service_id": "user-service"}' \
  localhost:50053 healthservice.HealthServiceService/GetStatus
```

## Tips

1. **Start Simple**: Begin with one service and gradually add more
2. **Use Environment Variables**: Never hardcode configuration
3. **Test Locally First**: Use `make run` before Docker
4. **Monitor Logs**: Use `docker-compose logs -f service-name`
5. **Iterate Quickly**: The framework supports rapid development cycles
6. **Follow Conventions**: Keep the generated structure for consistency
7. **Document Your APIs**: Keep proto files well-documented
8. **Version Your Services**: Tag Docker images appropriately

## Next Steps

- Add authentication/authorization
- Implement API gateway
- Add monitoring with Prometheus
- Set up distributed tracing
- Implement circuit breakers
- Add rate limiting
- Create admin dashboard
