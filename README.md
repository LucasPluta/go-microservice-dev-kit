# GoMicroserviceFramework

A comprehensive framework for quickly building, testing, and deploying Go microservices with gRPC, PostgreSQL, Redis, and NATS support.

## Features

- 🚀 **Quick Service Generation**: Create new microservices with a single command
- 🔌 **Optional Integrations**: Choose PostgreSQL, Redis, and/or NATS for each service
- 🌐 **gRPC Support**: Built-in support for both unary and streaming gRPC calls
- 🐳 **Docker Ready**: Templated docker-compose configuration for easy deployment
- 🔒 **Public/Internal Services**: Configure services as public-facing or internal
- 📦 **Modular Architecture**: Clean separation of concerns with handler, service, and proto layers

## Quick Start

### Prerequisites

- Go 1.21+
- Docker and Docker Compose
- Protocol Buffers compiler (`protoc`)
- gRPC Go plugins

Install protoc plugins:
```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

### Creating a New Service

Use the service generator script to create a new microservice:

```bash
./scripts/create-service.sh <service-name> [options]
```

**Options:**
- `--postgres`: Enable PostgreSQL support
- `--redis`: Enable Redis support
- `--nats`: Enable NATS message bus support
- `--internal`: Make service internal (no public gRPC endpoint)

**Examples:**

Create a user service with PostgreSQL and Redis:
```bash
./scripts/create-service.sh user-service --postgres --redis
```

Create a notification service with NATS:
```bash
./scripts/create-service.sh notification-service --nats
```

Create a full-featured service with all integrations:
```bash
./scripts/create-service.sh order-service --postgres --redis --nats
```

### Service Structure

Each generated service follows this structure:

```
services/<service-name>/
├── cmd/
│   └── main.go              # Application entry point
├── internal/
│   ├── handler/             # gRPC handlers
│   │   └── handler.go
│   └── service/             # Business logic
│       └── service.go
├── proto/
│   └── <service-name>.proto # Protocol buffer definitions
├── Dockerfile               # Docker configuration
├── Makefile                 # Build automation
├── go.mod                   # Go dependencies
└── README.md                # Service documentation
```

### Developing a Service

1. **Define your API** in `proto/<service-name>.proto`
2. **Generate protobuf code**:
   ```bash
   cd services/<service-name>
   make proto
   ```
3. **Implement business logic** in `internal/service/service.go`
4. **Implement gRPC handlers** in `internal/handler/handler.go`
5. **Build the service**:
   ```bash
   make build
   ```

### Running Services

#### Local Development

Run a single service locally:
```bash
cd services/<service-name>
make run
```

#### Docker Compose

1. Add your service to `docker-compose.yml` (see `docker-compose.template.yml` for reference)
2. Start infrastructure and your service:
   ```bash
   docker-compose up
   ```

Start specific services:
```bash
docker-compose up postgres redis nats
docker-compose up <service-name>
```

### Infrastructure Services

The framework includes the following infrastructure services:

- **PostgreSQL** (port 5432): Relational database
- **Redis** (port 6379): In-memory data store and cache
- **NATS** (ports 4222, 8222): Message bus with JetStream support

### Testing Services

Use `grpcurl` to test your gRPC services:

```bash
# List available services
grpcurl -plaintext localhost:50051 list

# Call a unary method
grpcurl -plaintext -d '{"service_id": "test"}' localhost:50051 <package>.<Service>/GetStatus

# Call a streaming method
grpcurl -plaintext -d '{"filter": "all", "limit": 10}' localhost:50051 <package>.<Service>/StreamData
```

## Framework Packages

### `pkg/grpc`
Utilities for creating and configuring gRPC servers with reflection support.

### `pkg/database`
PostgreSQL connection management with connection pooling.

### `pkg/redis`
Redis client initialization and connection management.

### `pkg/nats`
NATS connection management with JetStream support for advanced messaging patterns.

## Project Layout

```
.
├── docker-compose.yml           # Main docker-compose configuration
├── docker-compose.template.yml  # Template for adding new services
├── go.mod                       # Framework dependencies
├── pkg/                         # Shared packages
│   ├── database/               # PostgreSQL utilities
│   ├── grpc/                   # gRPC server utilities
│   ├── nats/                   # NATS utilities
│   └── redis/                  # Redis utilities
├── scripts/
│   └── create-service.sh       # Service generator script
├── services/                    # Microservices directory
│   └── example-service/        # Example service implementation
└── README.md                    # This file
```

## Best Practices

1. **Service Independence**: Each service should be independently deployable
2. **Configuration via Environment**: Use environment variables for configuration
3. **Health Checks**: Implement health check endpoints for monitoring
4. **Graceful Shutdown**: Handle SIGINT and SIGTERM signals properly
5. **Error Handling**: Return appropriate gRPC status codes
6. **Logging**: Use structured logging for better observability
7. **Testing**: Write unit tests for service logic and integration tests for handlers

## Configuration

Services are configured via environment variables:

### Common Variables
- `SERVICE_NAME`: Name of the service
- `GRPC_PORT`: Port for gRPC server (default: 50051)

### PostgreSQL
- `USE_POSTGRES`: Enable PostgreSQL (true/false)
- `POSTGRES_HOST`: Database host
- `POSTGRES_PORT`: Database port
- `POSTGRES_USER`: Database user
- `POSTGRES_PASSWORD`: Database password
- `POSTGRES_DB`: Database name

### Redis
- `USE_REDIS`: Enable Redis (true/false)
- `REDIS_HOST`: Redis host
- `REDIS_PORT`: Redis port

### NATS
- `USE_NATS`: Enable NATS (true/false)
- `NATS_URL`: NATS connection URL

## Example: Creating a Complete Service

Here's a complete workflow for creating a new service:

```bash
# 1. Create the service
./scripts/create-service.sh payment-service --postgres --redis --nats

# 2. Navigate to the service directory
cd services/payment-service

# 3. Update the proto file with your API
# Edit proto/payment-service.proto

# 4. Generate protobuf code
make proto

# 5. Implement your business logic
# Edit internal/service/service.go
# Edit internal/handler/handler.go

# 6. Build the service
make build

# 7. Test locally
make run

# 8. Add to docker-compose.yml and deploy
cd ../..
docker-compose up payment-service
```

## Troubleshooting

### Protobuf generation fails
Ensure you have installed the protoc plugins:
```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

### Service can't connect to database
- Ensure the database service is running and healthy
- Check the environment variables are set correctly
- Verify network connectivity in docker-compose

### Port already in use
Change the port mapping in docker-compose.yml or stop the conflicting service.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License
