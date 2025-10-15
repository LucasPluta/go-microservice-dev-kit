# Go Microservice Dev Kit

A comprehensive dev kit for quickly building, testing, and deploying Go microservices with gRPC, PostgreSQL, Redis, and NATS support.

## Features

- 🚀 **Quick Service Generation**: Create new microservices with a single command
- 🔌 **Optional Integrations**: Choose PostgreSQL, Redis, and/or NATS for each service
- 🌐 **gRPC Support**: Built-in support for both unary and streaming gRPC calls
- �️ **Web Client**: React-based gRPC-Web client with TypeScript support
- �🐳 **Docker Ready**: Templated docker-compose configuration for easy deployment
- 🔒 **Public/Internal Services**: Configure services as public-facing or internal
- 📦 **Modular Architecture**: Clean separation of concerns with handler, service, and proto layers
- 🛠️ **Self-Contained**: No external Go installation required - downloads toolchain automatically

## Quick Start

### Prerequisites

- Docker and Docker Compose (for running services)
- Make
- Node.js 18+ and npm (for web client development)
- **No Go/Protoc installation required** - framework downloads a repo-specific installation automatically

### Help

```bash
make help
```

### TL;DR - Just run everything

```bash
make all
```

### Setup

The framework is self-contained and downloads the Go toolchain automatically:

```bash
# Download Go toolchain (version from go.mod)
make setup-go

# Download the pinned version of protoc (stored in `.goroot/`)
make install-protoc

# Install protoc plugins (stored in `.gobincache/`)
make install-tools
```

**Supported Platforms:**
- macOS: amd64 (Intel), arm64 (Apple Silicon)
- Linux: amd64, arm64

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
├── go.mod                   # Go dependencies
└── README.md                # Service documentation
```

**Note:** Services use the root `Dockerfile` and `Makefile` for building.

### Web Client

The framework includes a React-based web client that communicates with gRPC services via gRPC-Web:

```bash
# Start everything (services + web client)
make up
# Access web interface at http://localhost:8080

# Development mode (backend via Docker, React dev server locally)
make dev-web-client
# Access at http://localhost:3000

# Build web client for production
make build-web-client
```

Features:
- **TypeScript integration** with auto-generated protobuf types
- **gRPC-Web communication** through nginx proxy
- **Real-time streaming** support for server-side streaming RPCs
- **CORS handling** and proper error management

See [WEB_CLIENT.md](WEB_CLIENT.md) for detailed setup and usage.

### Developing a Service

1. **Define your API** in `proto/<service-name>.proto`
2. **Generate protobuf code** (from repository root):
   ```bash
   make proto SERVICE=<service-name>
   ```
3. **Implement business logic** in `internal/service/service.go`
4. **Implement gRPC handlers** in `internal/handler/handler.go`
5. **Build the service**:
   ```bash
   # Build binary for current platform
   make build SERVICE=<service-name>
   
   # Build binaries for linux/amd64 and linux/arm64
   make build-multiarch SERVICE=<service-name>
   
   # Build Docker image (requires pre-built binary)
   make docker-build SERVICE=<service-name>
   
   # Build multi-arch Docker images
   make docker-build-multiarch SERVICE=<service-name> REGISTRY=your-registry.io
   ```

### Running Services

#### Local Development

Run a single service locally:
```bash
cd services/<service-name>
go run ./cmd/main.go
```

Or use the built binary:
```bash
./bin/<service-name>
```

#### Docker Compose

1. Add your service to `docker-compose.yml` (see `docker-compose.template.yml` for reference):
   ```yaml
   your-service:
     build:
       context: .
       dockerfile: Dockerfile
       args:
         SERVICE_NAME: your-service
     ports:
       - "50051:50051"
     environment:
       - SERVICE_NAME=your-service
       - GRPC_PORT=50051
       # Add other environment variables as needed
   ```

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

### CI/CD with GitHub Actions

The framework includes automated CI/CD:

- **Automated Testing**: Runs on every push to test all services
- **Multi-Architecture Builds**: Builds binaries for linux/amd64 and linux/arm64
- **Docker Image Creation**: Automatically builds Docker images on main branch
- **Artifact Storage**: Build artifacts stored for 7 days

Workflow runs on:
- Push to `main` branch
- Push to `copilot/**` branches
- Pull requests to `main`

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
├── go.mod                       # Single go.mod for entire monorepo
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
