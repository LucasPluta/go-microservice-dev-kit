#!/bin/bash
. "./scripts/util.sh"

# Script to create a new microservice from template

# Check if service name is provided
if [ -z "$1" ]; then
    lp-error "Service name is required"
    echo "Usage: ./scripts/create-service.sh <service-name> [options]"
    echo ""
    echo "Options:"
    echo "  --postgres    Enable PostgreSQL support"
    echo "  --redis       Enable Redis support"
    echo "  --nats        Enable NATS support"
    echo "  --internal    Make service internal (no public gRPC endpoint)"
    echo ""
    echo "Example:"
    echo "  ./scripts/create-service.sh user-service --postgres --redis --nats"
    exit 1
fi

SERVICE_NAME=$1
shift

# Convert service-name to PascalCase for use in code (e.g., user-service -> UserService)
SERVICE_NAME_PASCAL=$(echo "$SERVICE_NAME" | sed -r 's/(^|-)([a-z])/\U\2/g')
# Convert service-name to proto package name (e.g., user-service -> userservice, no hyphens)
PROTO_PACKAGE=$(echo "$SERVICE_NAME" | tr -d '-')

# Parse options
USE_POSTGRES=false
USE_REDIS=false
USE_NATS=false
IS_INTERNAL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --postgres)
            USE_POSTGRES=true
            shift
            ;;
        --redis)
            USE_REDIS=true
            shift
            ;;
        --nats)
            USE_NATS=true
            shift
            ;;
        --internal)
            IS_INTERNAL=true
            shift
            ;;
        *)
            lp-warn "Unknown option: $1"
            shift
            ;;
    esac
done

SERVICE_DIR="services/${SERVICE_NAME}"

# Check if service already exists
if [ -d "$SERVICE_DIR" ]; then
    lp-error "Service '${SERVICE_NAME}' already exists in ${SERVICE_DIR}"
    exit 1
fi

lp-echo "Creating new service: ${SERVICE_NAME}"
lp-echo "  PostgreSQL: ${USE_POSTGRES}"
lp-echo "  Redis: ${USE_REDIS}"
lp-echo "  NATS: ${USE_NATS}"
lp-echo "  Internal: ${IS_INTERNAL}"

# Create service directory structure
mkdir -p "${SERVICE_DIR}"/{cmd,internal/handler,internal/service,proto}

lp-echo "Created directory structure"

# Create main.go
cat > "${SERVICE_DIR}/cmd/main.go" <<EOF
package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/LucasPluta/GoMicroserviceFramework/pkg/grpc"
EOF

if [ "$USE_POSTGRES" = true ]; then
cat >> "${SERVICE_DIR}/cmd/main.go" <<EOF
	"database/sql"
	"github.com/LucasPluta/GoMicroserviceFramework/pkg/database"
EOF
fi

if [ "$USE_REDIS" = true ]; then
cat >> "${SERVICE_DIR}/cmd/main.go" <<EOF
	"github.com/LucasPluta/GoMicroserviceFramework/pkg/redis"
EOF
fi

if [ "$USE_NATS" = true ]; then
cat >> "${SERVICE_DIR}/cmd/main.go" <<EOF
	"github.com/LucasPluta/GoMicroserviceFramework/pkg/nats"
EOF
fi

cat >> "${SERVICE_DIR}/cmd/main.go" <<EOF
	"github.com/LucasPluta/GoMicroserviceFramework/services/${SERVICE_NAME}/internal/handler"
	"github.com/LucasPluta/GoMicroserviceFramework/services/${SERVICE_NAME}/internal/service"
	pb "github.com/LucasPluta/GoMicroserviceFramework/services/${SERVICE_NAME}/proto"
)

func main() {
	log.Println("Starting ${SERVICE_NAME}...")

	// Get configuration from environment
	serviceName := getEnv("SERVICE_NAME", "${SERVICE_NAME}")
	grpcPort := getEnv("GRPC_PORT", "50051")

	log.Printf("Service: %s", serviceName)
	log.Printf("gRPC Port: %s", grpcPort)

	ctx := context.Background()
EOF

if [ "$USE_POSTGRES" = true ]; then
cat >> "${SERVICE_DIR}/cmd/main.go" <<EOF

	// Initialize PostgreSQL connection if enabled
	var db *sql.DB
	if getEnv("USE_POSTGRES", "false") == "true" {
		dbConfig := database.Config{
			Host:     getEnv("POSTGRES_HOST", "localhost"),
			Port:     getEnv("POSTGRES_PORT", "5432"),
			User:     getEnv("POSTGRES_USER", "postgres"),
			Password: getEnv("POSTGRES_PASSWORD", "postgres"),
			DBName:   getEnv("POSTGRES_DB", "microservices"),
		}
		var err error
		db, err = database.NewPostgresConnection(dbConfig)
		if err != nil {
			log.Fatalf("Failed to connect to PostgreSQL: %v", err)
		}
		defer db.Close()
	}
EOF
fi

if [ "$USE_REDIS" = true ]; then
cat >> "${SERVICE_DIR}/cmd/main.go" <<EOF

	// Initialize Redis connection if enabled
	var redisClient *redis.Client
	if getEnv("USE_REDIS", "false") == "true" {
		redisConfig := redis.Config{
			Host: getEnv("REDIS_HOST", "localhost"),
			Port: getEnv("REDIS_PORT", "6379"),
		}
		var err error
		redisClient, err = redis.NewRedisClient(redisConfig)
		if err != nil {
			log.Fatalf("Failed to connect to Redis: %v", err)
		}
		defer redisClient.Close()
	}
EOF
fi

if [ "$USE_NATS" = true ]; then
cat >> "${SERVICE_DIR}/cmd/main.go" <<EOF

	// Initialize NATS connection if enabled
	var nc *nats.Conn
	if getEnv("USE_NATS", "false") == "true" {
		natsConfig := nats.Config{
			URL: getEnv("NATS_URL", "nats://localhost:4222"),
		}
		var err error
		nc, err = nats.NewNATSConnection(natsConfig)
		if err != nil {
			log.Fatalf("Failed to connect to NATS: %v", err)
		}
		defer nc.Close()
	}
EOF
fi

cat >> "${SERVICE_DIR}/cmd/main.go" <<EOF

	// Initialize service
	svc := service.NewService(ctx$([ "$USE_POSTGRES" = true ] && echo ", db")$([ "$USE_REDIS" = true ] && echo ", redisClient")$([ "$USE_NATS" = true ] && echo ", nc"))

	// Create gRPC server with Connect-RPC support
	grpcServer := grpc.NewConnectServer()
	pb.Register${SERVICE_NAME_PASCAL}ServiceServer(grpcServer, handler.NewHandler(svc))

	// Start server in a goroutine (supports both gRPC and Connect-RPC)
	go func() {
		if err := grpc.StartConnectServer(grpcServer, nil, grpcPort); err != nil {
			log.Fatalf("Failed to start gRPC server: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	grpcServer.GracefulStop()
	log.Println("Server stopped")
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
EOF

lp-echo "Created cmd/main.go"

# Create service layer
cat > "${SERVICE_DIR}/internal/service/service.go" <<EOF
package service

import (
	"context"
EOF

if [ "$USE_POSTGRES" = true ]; then
cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
	"database/sql"
EOF
fi

if [ "$USE_REDIS" = true ]; then
cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
	"github.com/go-redis/redis/v8"
EOF
fi

if [ "$USE_NATS" = true ]; then
cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
	"github.com/nats-io/nats.go"
EOF
fi

cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
)

type Service struct {
	ctx context.Context
EOF

if [ "$USE_POSTGRES" = true ]; then
cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
	db  *sql.DB
EOF
fi

if [ "$USE_REDIS" = true ]; then
cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
	redis *redis.Client
EOF
fi

if [ "$USE_NATS" = true ]; then
cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
	nats *nats.Conn
EOF
fi

cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
}

func NewService(ctx context.Context$([ "$USE_POSTGRES" = true ] && echo ", db *sql.DB")$([ "$USE_REDIS" = true ] && echo ", redis *redis.Client")$([ "$USE_NATS" = true ] && echo ", nc *nats.Conn")) *Service {
	return &Service{
		ctx: ctx,
EOF

if [ "$USE_POSTGRES" = true ]; then
cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
		db:  db,
EOF
fi

if [ "$USE_REDIS" = true ]; then
cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
		redis: redis,
EOF
fi

if [ "$USE_NATS" = true ]; then
cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
		nats: nc,
EOF
fi

cat >> "${SERVICE_DIR}/internal/service/service.go" <<EOF
	}
}

// Add your business logic methods here
EOF

lp-echo "Created internal/service/service.go"

# Create handler layer
cat > "${SERVICE_DIR}/internal/handler/handler.go" <<EOF
package handler

import (
	"github.com/LucasPluta/GoMicroserviceFramework/services/${SERVICE_NAME}/internal/service"
	pb "github.com/LucasPluta/GoMicroserviceFramework/services/${SERVICE_NAME}/proto"
)

type Handler struct {
	pb.Unimplemented${SERVICE_NAME_PASCAL}ServiceServer
	svc *service.Service
}

func NewHandler(svc *service.Service) *Handler {
	return &Handler{
		svc: svc,
	}
}

// Implement your gRPC methods here
EOF

lp-echo "Created internal/handler/handler.go"

# Create proto file
cat > "${SERVICE_DIR}/proto/${SERVICE_NAME}.proto" <<EOF
syntax = "proto3";

package ${PROTO_PACKAGE};

option go_package = "github.com/LucasPluta/GoMicroserviceFramework/services/${SERVICE_NAME}/proto";

// ${SERVICE_NAME_PASCAL}Service provides methods for the ${SERVICE_NAME}
service ${SERVICE_NAME_PASCAL}Service {
  // Example unary RPC
  rpc GetStatus(GetStatusRequest) returns (GetStatusResponse) {}
  
  // Example streaming RPC (server-side streaming)
  rpc StreamData(StreamDataRequest) returns (stream StreamDataResponse) {}
}

message GetStatusRequest {
  string service_id = 1;
}

message GetStatusResponse {
  string status = 1;
  string message = 2;
}

message StreamDataRequest {
  string filter = 1;
  int32 limit = 2;
}

message StreamDataResponse {
  string data = 1;
  int64 timestamp = 2;
}
EOF

lp-echo "Created proto/${SERVICE_NAME}.proto"

# Note: Using monorepo structure with single go.mod at root
# No per-service go.mod needed

# Create README
cat > "${SERVICE_DIR}/README.md" <<EOF
# ${SERVICE_NAME}

This service was generated using the GoMicroserviceFramework.

## Features

- gRPC API (unary and streaming)
EOF

if [ "$USE_POSTGRES" = true ]; then
cat >> "${SERVICE_DIR}/README.md" <<EOF
- PostgreSQL integration
EOF
fi

if [ "$USE_REDIS" = true ]; then
cat >> "${SERVICE_DIR}/README.md" <<EOF
- Redis integration
EOF
fi

if [ "$USE_NATS" = true ]; then
cat >> "${SERVICE_DIR}/README.md" <<EOF
- NATS message bus integration
EOF
fi

cat >> "${SERVICE_DIR}/README.md" <<EOF

## Development

### Generate protobuf code

From the repository root:

\`\`\`bash
make proto SERVICE=${SERVICE_NAME}
\`\`\`

### Build

Build the binary:

\`\`\`bash
make build SERVICE=${SERVICE_NAME}
\`\`\`

Build Docker image:

\`\`\`bash
make docker-build SERVICE=${SERVICE_NAME}
\`\`\`

Build multi-architecture Docker image:

\`\`\`bash
make docker-build-multiarch SERVICE=${SERVICE_NAME} REGISTRY=your-registry.io
\`\`\`

### Run locally

\`\`\`bash
cd services/${SERVICE_NAME}
go run ./cmd/main.go
\`\`\`

### Run with Docker Compose

Add the service to \`docker-compose.yml\`:

\`\`\`yaml
  ${SERVICE_NAME}:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        SERVICE_NAME: ${SERVICE_NAME}
    ports:
      - "50051:50051"  # Adjust port as needed
    environment:
      - SERVICE_NAME=${SERVICE_NAME}
      - GRPC_PORT=50051
EOF

if [ "$USE_POSTGRES" = true ]; then
cat >> "${SERVICE_DIR}/README.md" <<EOF
      - USE_POSTGRES=true
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=microservices
EOF
fi

if [ "$USE_REDIS" = true ]; then
cat >> "${SERVICE_DIR}/README.md" <<EOF
      - USE_REDIS=true
      - REDIS_HOST=redis
      - REDIS_PORT=6379
EOF
fi

if [ "$USE_NATS" = true ]; then
cat >> "${SERVICE_DIR}/README.md" <<EOF
      - USE_NATS=true
      - NATS_URL=nats://nats:4222
EOF
fi

cat >> "${SERVICE_DIR}/README.md" <<EOF
    depends_on:
EOF

if [ "$USE_POSTGRES" = true ]; then
cat >> "${SERVICE_DIR}/README.md" <<EOF
      postgres:
        condition: service_healthy
EOF
fi

if [ "$USE_REDIS" = true ]; then
cat >> "${SERVICE_DIR}/README.md" <<EOF
      redis:
        condition: service_healthy
EOF
fi

if [ "$USE_NATS" = true ]; then
cat >> "${SERVICE_DIR}/README.md" <<EOF
      nats:
        condition: service_healthy
EOF
fi

cat >> "${SERVICE_DIR}/README.md" <<EOF
\`\`\`

Then run:

\`\`\`bash
docker-compose up ${SERVICE_NAME}
\`\`\`

## Testing

Test the gRPC service using grpcurl:

\`\`\`bash
grpcurl -plaintext localhost:50051 list
grpcurl -plaintext -d '{"service_id": "test"}' localhost:50051 ${PROTO_PACKAGE}.${SERVICE_NAME_PASCAL}Service/GetStatus
\`\`\`
EOF

lp-echo "Created README.md"

lp-echo ""
lp-echo "✅ Service '${SERVICE_NAME}' created successfully!"
lp-echo ""
lp-echo "Next steps:"
lp-echo "1. cd ${SERVICE_DIR}"
lp-echo "2. Implement your business logic in internal/service/service.go"
lp-echo "3. Implement your gRPC handlers in internal/handler/handler.go"
lp-echo "4. Update proto/${SERVICE_NAME}.proto with your API definitions"
lp-echo "5. From repo root, run 'make proto SERVICE=${SERVICE_NAME}' to generate protobuf code"
lp-echo "6. Build: 'make build SERVICE=${SERVICE_NAME}' or 'make docker-build SERVICE=${SERVICE_NAME}'"
lp-echo "7. Add the service to docker-compose.yml (see ${SERVICE_DIR}/README.md)"
lp-echo "8. Run 'docker-compose up ${SERVICE_NAME}' to start your service"
