#!/bin/bash

# Script to create a new microservice from template

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if service name is provided
if [ -z "$1" ]; then
    print_error "Service name is required"
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
            print_warning "Unknown option: $1"
            shift
            ;;
    esac
done

SERVICE_DIR="services/${SERVICE_NAME}"

# Check if service already exists
if [ -d "$SERVICE_DIR" ]; then
    print_error "Service '${SERVICE_NAME}' already exists in ${SERVICE_DIR}"
    exit 1
fi

print_info "Creating new service: ${SERVICE_NAME}"
print_info "  PostgreSQL: ${USE_POSTGRES}"
print_info "  Redis: ${USE_REDIS}"
print_info "  NATS: ${USE_NATS}"
print_info "  Internal: ${IS_INTERNAL}"

# Create service directory structure
mkdir -p "${SERVICE_DIR}"/{cmd,internal/handler,internal/service,proto}

print_info "Created directory structure"

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
	"${SERVICE_NAME}/internal/handler"
	"${SERVICE_NAME}/internal/service"
	pb "${SERVICE_NAME}/proto"
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

	// Create gRPC server
	grpcServer := grpc.NewServer()
	pb.Register${SERVICE_NAME_PASCAL}ServiceServer(grpcServer, handler.NewHandler(svc))

	// Start server in a goroutine
	go func() {
		if err := grpc.StartServer(grpcServer, grpcPort); err != nil {
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

print_info "Created cmd/main.go"

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

print_info "Created internal/service/service.go"

# Create handler layer
cat > "${SERVICE_DIR}/internal/handler/handler.go" <<EOF
package handler

import (
	"${SERVICE_NAME}/internal/service"
	pb "${SERVICE_NAME}/proto"
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

print_info "Created internal/handler/handler.go"

# Create proto file
cat > "${SERVICE_DIR}/proto/${SERVICE_NAME}.proto" <<EOF
syntax = "proto3";

package ${PROTO_PACKAGE};

option go_package = "${SERVICE_NAME}/proto";

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

print_info "Created proto/${SERVICE_NAME}.proto"

# Create Dockerfile
cat > "${SERVICE_DIR}/Dockerfile" <<EOF
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/service ./cmd/main.go

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/service .

# Expose gRPC port
EXPOSE 50051

CMD ["./service"]
EOF

print_info "Created Dockerfile"

# Create go.mod
cat > "${SERVICE_DIR}/go.mod" <<EOF
module ${SERVICE_NAME}

go 1.21

require (
	github.com/LucasPluta/GoMicroserviceFramework v0.0.0
	google.golang.org/grpc v1.59.0
	google.golang.org/protobuf v1.31.0
EOF

if [ "$USE_POSTGRES" = true ]; then
cat >> "${SERVICE_DIR}/go.mod" <<EOF
	github.com/lib/pq v1.10.9
EOF
fi

if [ "$USE_REDIS" = true ]; then
cat >> "${SERVICE_DIR}/go.mod" <<EOF
	github.com/go-redis/redis/v8 v8.11.5
EOF
fi

if [ "$USE_NATS" = true ]; then
cat >> "${SERVICE_DIR}/go.mod" <<EOF
	github.com/nats-io/nats.go v1.31.0
EOF
fi

cat >> "${SERVICE_DIR}/go.mod" <<EOF
)

replace github.com/LucasPluta/GoMicroserviceFramework => ../../
EOF

print_info "Created go.mod"

# Create Makefile
cat > "${SERVICE_DIR}/Makefile" <<EOF
.PHONY: proto build run clean

proto:
	protoc --go_out=. --go_opt=paths=source_relative \\
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \\
		proto/${SERVICE_NAME}.proto

build:
	go build -o bin/${SERVICE_NAME} ./cmd/main.go

run:
	go run ./cmd/main.go

clean:
	rm -rf bin/
	rm -f proto/*.pb.go

test:
	go test -v ./...
EOF

print_info "Created Makefile"

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

\`\`\`bash
make proto
\`\`\`

### Build

\`\`\`bash
make build
\`\`\`

### Run locally

\`\`\`bash
make run
\`\`\`

### Run with Docker Compose

Add the service to \`docker-compose.yml\`:

\`\`\`yaml
  ${SERVICE_NAME}:
    build:
      context: ./services/${SERVICE_NAME}
      dockerfile: Dockerfile
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

print_info "Created README.md"

print_info ""
print_info "✅ Service '${SERVICE_NAME}' created successfully!"
print_info ""
print_info "Next steps:"
print_info "1. cd ${SERVICE_DIR}"
print_info "2. Implement your business logic in internal/service/service.go"
print_info "3. Implement your gRPC handlers in internal/handler/handler.go"
print_info "4. Update proto/${SERVICE_NAME}.proto with your API definitions"
print_info "5. Run 'make proto' to generate protobuf code"
print_info "6. Add the service to docker-compose.yml (see ${SERVICE_DIR}/README.md)"
print_info "7. Run 'docker-compose up ${SERVICE_NAME}' to start your service"
