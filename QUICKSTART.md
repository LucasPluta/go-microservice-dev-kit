# Quick Start Guide

This guide will help you get started with the GoMicroserviceFramework in minutes.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Protocol Buffers Compiler (protoc)](https://grpc.io/docs/protoc-installation/)

**Note:** Go installation is NOT required - the framework downloads it automatically.

## Step 1: Setup Go Toolchain

The framework downloads the Go toolchain specified in `go.mod`:

```bash
# Download Go toolchain (supports macOS and Linux on amd64/arm64)
make setup-go
```

This downloads Go 1.21.13 to `.goroot/` directory.

## Step 2: Install Required Tools

Install the Go protobuf plugins:

```bash
make install-tools
```

## Step 3: Create Your First Service

Let's create a user service with PostgreSQL and Redis support:

```bash
./scripts/create-service.sh user-service --postgres --redis
```

This command creates a complete microservice with:
- gRPC server setup
- PostgreSQL integration
- Redis integration
- Docker configuration
- Example API definitions

## Step 4: Explore the Generated Service

Navigate to the service directory:

```bash
cd services/user-service
```

The service structure:

```
user-service/
├── cmd/main.go                 # Service entry point
├── internal/
│   ├── handler/handler.go     # gRPC request handlers
│   └── service/service.go     # Business logic
├── proto/user-service.proto   # API definitions
└── README.md                   # Service-specific docs
```

**Note:** The framework uses a **single `go.mod` at the repository root** (monorepo structure). Services import packages using the full module path: `github.com/LucasPluta/GoMicroserviceFramework/services/user-service/...`

## Step 5: Define Your API

Edit `proto/user-service.proto` to define your gRPC API:

```protobuf
syntax = "proto3";

package user-service;

option go_package = "github.com/LucasPluta/GoMicroserviceFramework/services/user-service/proto";

service UserServiceService {
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse) {}
  rpc GetUser(GetUserRequest) returns (GetUserResponse) {}
  rpc ListUsers(ListUsersRequest) returns (stream User) {}
}

message CreateUserRequest {
  string name = 1;
  string email = 2;
}

message CreateUserResponse {
  string user_id = 1;
  string message = 2;
}

message GetUserRequest {
  string user_id = 1;
}

message GetUserResponse {
  string user_id = 1;
  string name = 2;
  string email = 3;
}

message ListUsersRequest {
  int32 limit = 1;
}

message User {
  string user_id = 1;
  string name = 2;
  string email = 3;
}
```

## Step 6: Generate Protobuf Code

Generate Go code from your proto definitions (from the repository root):

```bash
make proto SERVICE=user-service
```

This creates `proto/user-service.pb.go` and `proto/user-service_grpc.pb.go`.

## Step 7: Implement Business Logic

### Update Service Layer

Edit `internal/service/service.go` to implement your business logic:

```go
package service

import (
    "context"
    "database/sql"
    "fmt"
    
    "github.com/go-redis/redis/v8"
    "github.com/google/uuid"
)

type Service struct {
    ctx   context.Context
    db    *sql.DB
    redis *redis.Client
}

func NewService(ctx context.Context, db *sql.DB, redis *redis.Client, nc *nats.Conn) *Service {
    return &Service{
        ctx:   ctx,
        db:    db,
        redis: redis,
    }
}

// CreateUser creates a new user in the database
func (s *Service) CreateUser(name, email string) (string, error) {
    userID := uuid.New().String()
    
    query := "INSERT INTO users (id, name, email) VALUES ($1, $2, $3)"
    _, err := s.db.ExecContext(s.ctx, query, userID, name, email)
    if err != nil {
        return "", fmt.Errorf("failed to create user: %w", err)
    }
    
    // Cache the user in Redis
    if s.redis != nil {
        cacheKey := fmt.Sprintf("user:%s", userID)
        s.redis.HSet(s.ctx, cacheKey, "name", name, "email", email)
    }
    
    return userID, nil
}

// GetUser retrieves a user by ID
func (s *Service) GetUser(userID string) (name, email string, err error) {
    // Try cache first
    if s.redis != nil {
        cacheKey := fmt.Sprintf("user:%s", userID)
        result, err := s.redis.HGetAll(s.ctx, cacheKey).Result()
        if err == nil && len(result) > 0 {
            return result["name"], result["email"], nil
        }
    }
    
    // Fetch from database
    query := "SELECT name, email FROM users WHERE id = $1"
    err = s.db.QueryRowContext(s.ctx, query, userID).Scan(&name, &email)
    return
}
```

### Update Handler Layer

Edit `internal/handler/handler.go` to implement gRPC handlers:

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
    if req.Name == "" || req.Email == "" {
        return nil, status.Error(codes.InvalidArgument, "name and email are required")
    }
    
    userID, err := h.svc.CreateUser(req.Name, req.Email)
    if err != nil {
        return nil, status.Errorf(codes.Internal, "failed to create user: %v", err)
    }
    
    return &pb.CreateUserResponse{
        UserId:  userID,
        Message: "User created successfully",
    }, nil
}

func (h *Handler) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.GetUserResponse, error) {
    if req.UserId == "" {
        return nil, status.Error(codes.InvalidArgument, "user_id is required")
    }
    
    name, email, err := h.svc.GetUser(req.UserId)
    if err != nil {
        return nil, status.Errorf(codes.NotFound, "user not found: %v", err)
    }
    
    return &pb.GetUserResponse{
        UserId: req.UserId,
        Name:   name,
        Email:  email,
    }, nil
}
```

## Step 8: Add Service to Docker Compose

Return to the root directory:

```bash
cd ../..
```

Add your service to `docker-compose.yml`:

```yaml
  user-service:
    build:
      context: ./services/user-service
      dockerfile: Dockerfile
    ports:
      - "50052:50051"
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
```

## Step 9: Start the Infrastructure

Start PostgreSQL, Redis, and NATS:

```bash
docker-compose up -d postgres redis nats
```

Wait a few seconds for services to be healthy.

## Step 10: Run Your Service

You can run the service either locally or in Docker.

### Option A: Run Locally

```bash
cd services/user-service
export USE_POSTGRES=true
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export POSTGRES_DB=microservices
export USE_REDIS=true
export REDIS_HOST=localhost
export REDIS_PORT=6379

go run cmd/main.go
```

### Option B: Run with Docker Compose

```bash
docker-compose up user-service
```

## Step 11: Test Your Service

Install grpcurl if you haven't already:

```bash
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
```

Test your service:

```bash
# List available services
grpcurl -plaintext localhost:50051 list

# Call GetStatus (from example implementation)
grpcurl -plaintext -d '{"service_id": "test"}' localhost:50051 user-service.UserServiceService/GetStatus

# Create a user (after implementing CreateUser)
grpcurl -plaintext -d '{"name": "John Doe", "email": "john@example.com"}' localhost:50051 user-service.UserServiceService/CreateUser

# Get a user (after implementing GetUser)
grpcurl -plaintext -d '{"user_id": "USER_ID_HERE"}' localhost:50051 user-service.UserServiceService/GetUser
```

## Next Steps

- **Add More Services**: Create additional microservices using the generator
- **Implement Authentication**: Add JWT or other auth mechanisms
- **Add Monitoring**: Integrate Prometheus and Grafana
- **Add Tracing**: Integrate OpenTelemetry or Jaeger
- **Write Tests**: Add unit and integration tests
- **API Gateway**: Add an API gateway for HTTP/REST support

## Common Commands

```bash
# Create a new service
./scripts/create-service.sh <name> [--postgres] [--redis] [--nats]

# Start all services
make up

# Stop all services
make down

# View logs
make logs                    # All services
make logs SERVICE=user-service  # Specific service

# Build a service for current platform
make build SERVICE=user-service

# Build for multiple architectures (linux/amd64, linux/arm64)
make build-multiarch SERVICE=user-service

# Build all services
make build-all-services

# Build Docker image (requires pre-built binary)
make docker-build SERVICE=user-service

# Build multi-arch Docker images
make docker-build-multiarch SERVICE=user-service REGISTRY=your-registry.io

# Run tests
make test

# Clean build artifacts
make clean
```

## Troubleshooting

### Can't connect to PostgreSQL
- Ensure PostgreSQL is running: `docker-compose ps postgres`
- Check logs: `docker-compose logs postgres`
- Verify connection string in environment variables

### protoc command not found
- Install Protocol Buffers compiler: https://grpc.io/docs/protoc-installation/
- Ensure it's in your PATH

### go module errors
- Run `go mod tidy` in the **root directory** (the framework uses a single go.mod for all services)
- Ensure `make setup-go` was run to download the Go toolchain
- Verify Go version: check root `go.mod` for required version

For more help, see the main [README.md](README.md).
