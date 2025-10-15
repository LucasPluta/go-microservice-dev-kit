# AI Coding Agent Instructions - GoMicroserviceFramework

## Architecture Overview

This is a **self-contained Go microservices framework** with a unique architecture that downloads its own Go toolchain and protoc compiler. Services are generated from templates and follow strict layered patterns.

### Core Framework Structure
- **`pkg/`**: Shared infrastructure clients (PostgreSQL, Redis, NATS, gRPC server)
- **`services/`**: Individual microservices with identical structure
- **`scripts/`**: Modular build/develop/test scripts organized by function
- **Self-contained toolchain**: Uses `.goroot/` and `.gobincache/` for isolated Go/protoc installations

## Service Generation & Structure

### Creating New Services
```bash
./scripts/develop/create-service.sh <service-name> [--postgres] [--redis] [--nats] [--internal]
```

**Every generated service follows this exact structure:**
```
services/<service-name>/
├── cmd/main.go              # Bootstrap with environment-based config
├── internal/handler/        # gRPC request/response handling
├── internal/service/        # Business logic layer
└── proto/                   # Protocol buffer definitions
```

### Critical Service Patterns
- **Dependency injection in `main.go`**: Infrastructure clients are conditionally initialized based on environment variables like `USE_POSTGRES=true`
- **Service naming convention**: `user-service` → `UserService` (PascalCase) in code, `userservice` (no hyphens) in proto package
- **Handler layer responsibility**: Request validation, gRPC status codes, streaming management only
- **Service layer responsibility**: All business logic, database interactions, cross-service communication

## Development Workflows

### Essential Commands
```bash
make setup          # Downloads Go toolchain + protoc (required first step)
make build          # Builds all services for current platform
make up             # Starts infrastructure + all services via docker-compose
make logs SERVICE=<name>    # Follow logs for specific service
make clean          # Stops containers, removes images
```

### Build System
- **Modular Makefiles**: `scripts/{setup,build,test,develop}/*.mk` imported into main Makefile
- **Multi-architecture support**: Builds for linux/darwin + amd64/arm64 combinations
- **Pre-built binaries**: Docker images expect binaries in `bin/` directory, not source compilation

### Infrastructure Dependencies
- **PostgreSQL** (5432): Standard connection pooling in `pkg/database/postgres.go`
- **Redis** (6379): Standard client in `pkg/redis/redis.go` with context support
- **NATS** (4222/8222): Message bus with JetStream enabled for pub/sub patterns

## Code Patterns & Conventions

### Error Handling
- Use `google.golang.org/grpc/status` for gRPC error codes
- Infrastructure connection failures should be fatal in `main.go`
- Business logic errors return gRPC status errors in handlers

### Configuration
- **Environment-based**: All config via env vars with sensible defaults
- **Standard env pattern**: `getEnv("CONFIG_KEY", "default_value")` in main.go
- **Service detection**: `USE_POSTGRES`, `USE_REDIS`, `USE_NATS` flags enable optional dependencies

### Proto/gRPC Patterns
- **Package naming**: Service `user-service` uses proto package `userservice` (no hyphens)
- **Streaming support**: Framework includes both unary and server-streaming RPC examples
- **Reflection enabled**: All gRPC servers include reflection for debugging with grpcurl

### Logging & Utilities
- **Custom logging**: Scripts use `lp-echo`, `lp-error`, `lp-success` functions from `scripts/util.sh`
- **Strict error handling**: All scripts use `set -euo pipefail` with error traps
- **Quiet mode support**: Build scripts support `QUIET_MODE=true` for CI environments

## Testing Strategy

Framework supports 4 test layers:
1. **Unit tests**: `internal/service/*_test.go` for business logic
2. **Integration tests**: Test with real Postgres/Redis/NATS instances  
3. **gRPC handler tests**: Test endpoint behavior with mock services
4. **End-to-end tests**: Full workflow testing via docker-compose

### Test Execution
```bash
make test                    # Run all tests
make test SERVICE=<name>     # Test specific service
```

## Common Patterns

- **Service initialization**: Always follows dependency injection pattern in `cmd/main.go`
- **Context propagation**: All operations use `context.Context` from request or background
- **Graceful shutdown**: Services handle SIGINT/SIGTERM for clean container stops
- **Health checks**: Docker services include proper health check configurations
- **Connection pooling**: Database connections use framework-standard pool settings

## Development Tips

- **Use framework scripts**: Don't run `go build` directly; use `make build` for proper toolchain
- **Service ports**: gRPC services default to 50051, but configurable via `GRPC_PORT`
- **Local development**: `make up` starts all infrastructure; individual services can run locally
- **Proto changes**: Run `make proto SERVICE=<name>` to regenerate gRPC code after .proto edits