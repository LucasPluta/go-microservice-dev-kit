# Testing Guide

This guide covers how to test services built with the GoMicroserviceFramework.

## Testing Philosophy

Services should have multiple layers of testing:

1. **Unit Tests**: Test individual functions and methods
2. **Integration Tests**: Test interactions with databases, caches, and message queues
3. **gRPC Handler Tests**: Test gRPC endpoint behavior
4. **End-to-End Tests**: Test complete workflows

## Unit Testing

### Testing Service Logic

Create tests for your service layer in `internal/service/service_test.go`:

```go
package service

import (
	"context"
	"testing"
)

func TestGetServiceStatus(t *testing.T) {
	ctx := context.Background()
	svc := NewService(ctx, nil, nil, nil)
	
	status := svc.GetServiceStatus("test-service")
	
	if status == "" {
		t.Error("Expected non-empty status")
	}
}
```

Run tests:

```bash
cd services/<service-name>
go test ./internal/service/...
```

## Integration Testing with Dependencies

### Testing with PostgreSQL

Use a test database or Docker container for PostgreSQL tests:

```go
package service

import (
	"context"
	"database/sql"
	"testing"
	
	"github.com/LucasPluta/GoMicroserviceFramework/pkg/database"
)

func setupTestDB(t *testing.T) *sql.DB {
	cfg := database.Config{
		Host:     "localhost",
		Port:     "5432",
		User:     "postgres",
		Password: "postgres",
		DBName:   "test_db",
	}
	
	db, err := database.NewPostgresConnection(cfg)
	if err != nil {
		t.Skipf("Skipping test: PostgreSQL not available: %v", err)
	}
	
	return db
}

func TestWithDatabase(t *testing.T) {
	db := setupTestDB(t)
	defer db.Close()
	
	ctx := context.Background()
	svc := NewService(ctx, db, nil, nil)
	
	// Your test logic here
}
```

### Testing with Redis

```go
package service

import (
	"context"
	"testing"
	
	"github.com/LucasPluta/GoMicroserviceFramework/pkg/redis"
)

func setupTestRedis(t *testing.T) *redis.Client {
	cfg := redis.Config{
		Host: "localhost",
		Port: "6379",
	}
	
	client, err := redis.NewRedisClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
	}
	
	return client
}
```

### Testing with NATS

```go
package service

import (
	"testing"
	
	"github.com/LucasPluta/GoMicroserviceFramework/pkg/nats"
)

func setupTestNATS(t *testing.T) *nats.Conn {
	cfg := nats.Config{
		URL: "nats://localhost:4222",
	}
	
	nc, err := nats.NewNATSConnection(cfg)
	if err != nil {
		t.Skipf("Skipping test: NATS not available: %v", err)
	}
	
	return nc
}
```

## Testing gRPC Handlers

Create tests for your handlers in `internal/handler/handler_test.go`:

```go
package handler

import (
	"context"
	"testing"
	
	"your-service/internal/service"
	pb "your-service/proto"
)

func TestGetStatus(t *testing.T) {
	// Create service
	ctx := context.Background()
	svc := service.NewService(ctx, nil, nil, nil)
	
	// Create handler
	h := NewHandler(svc)
	
	// Test request
	req := &pb.GetStatusRequest{
		ServiceId: "test",
	}
	
	resp, err := h.GetStatus(ctx, req)
	if err != nil {
		t.Fatalf("GetStatus failed: %v", err)
	}
	
	if resp.Status != "healthy" {
		t.Errorf("Expected status 'healthy', got '%s'", resp.Status)
	}
}

func TestGetStatusInvalidRequest(t *testing.T) {
	ctx := context.Background()
	svc := service.NewService(ctx, nil, nil, nil)
	h := NewHandler(svc)
	
	req := &pb.GetStatusRequest{
		ServiceId: "", // Empty service ID
	}
	
	_, err := h.GetStatus(ctx, req)
	if err == nil {
		t.Error("Expected error for empty service_id")
	}
}
```

## Testing Streaming RPCs

```go
package handler

import (
	"testing"
	
	pb "your-service/proto"
	"google.golang.org/grpc"
)

type mockStreamDataServer struct {
	grpc.ServerStream
	responses []*pb.StreamDataResponse
}

func (m *mockStreamDataServer) Send(resp *pb.StreamDataResponse) error {
	m.responses = append(m.responses, resp)
	return nil
}

func TestStreamData(t *testing.T) {
	ctx := context.Background()
	svc := service.NewService(ctx, nil, nil, nil)
	h := NewHandler(svc)
	
	req := &pb.StreamDataRequest{
		Filter: "test",
		Limit:  5,
	}
	
	stream := &mockStreamDataServer{}
	
	err := h.StreamData(req, stream)
	if err != nil {
		t.Fatalf("StreamData failed: %v", err)
	}
	
	if len(stream.responses) != 5 {
		t.Errorf("Expected 5 responses, got %d", len(stream.responses))
	}
}
```

## Running Tests

### Run all tests in a service

```bash
cd services/<service-name>
go test ./...
```

### Run tests with coverage

```bash
go test -cover ./...
```

### Generate coverage report

```bash
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

### Run specific tests

```bash
go test -run TestGetStatus ./internal/handler/...
```

### Run tests with verbose output

```bash
go test -v ./...
```

## Integration Testing with Docker Compose

For integration tests that need infrastructure, use Docker Compose:

```bash
# Start infrastructure
docker-compose up -d postgres redis nats

# Wait for services to be ready
sleep 5

# Run integration tests
cd services/<service-name>
go test -tags=integration ./...

# Cleanup
docker-compose down
```

### Tag integration tests

Mark integration tests with build tags:

```go
//go:build integration
// +build integration

package service

import "testing"

func TestWithRealDatabase(t *testing.T) {
	// This test only runs with: go test -tags=integration
}
```

## Manual Testing with grpcurl

### Install grpcurl

```bash
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
```

### List available services

```bash
grpcurl -plaintext localhost:50051 list
```

### List service methods

```bash
grpcurl -plaintext localhost:50051 list <package>.<Service>
```

### Describe a method

```bash
grpcurl -plaintext localhost:50051 describe <package>.<Service>.<Method>
```

### Call a unary method

```bash
grpcurl -plaintext -d '{"service_id": "test"}' \
  localhost:50051 <package>.<Service>/GetStatus
```

### Call a streaming method

```bash
grpcurl -plaintext -d '{"filter": "test", "limit": 10}' \
  localhost:50051 <package>.<Service>/StreamData
```

## Load Testing

### Using ghz for gRPC load testing

Install ghz:

```bash
go install github.com/bojand/ghz/cmd/ghz@latest
```

Run load test:

```bash
ghz --insecure \
  --proto proto/service.proto \
  --call package.Service/Method \
  -d '{"field": "value"}' \
  -c 10 \
  -n 1000 \
  localhost:50051
```

Parameters:
- `-c`: Number of concurrent connections
- `-n`: Number of requests
- `-d`: Request data

## Continuous Integration

### GitHub Actions Example

Create `.github/workflows/test.yml`:

```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
      
      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379
      
      nats:
        image: nats:2-alpine
        ports:
          - 4222:4222
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      
      - name: Install dependencies
        run: go mod download
      
      - name: Run tests
        run: go test -v -cover ./...
        env:
          POSTGRES_HOST: localhost
          REDIS_HOST: localhost
          NATS_URL: nats://localhost:4222
```

## Test Coverage Goals

Aim for:
- **Service Layer**: 80%+ coverage
- **Handler Layer**: 90%+ coverage
- **Critical Paths**: 100% coverage

## Best Practices

1. **Write tests first** (TDD approach)
2. **Mock external dependencies** for unit tests
3. **Use table-driven tests** for multiple scenarios
4. **Test error cases** as thoroughly as success cases
5. **Use meaningful test names** that describe what's being tested
6. **Keep tests fast** - slow tests discourage frequent testing
7. **Clean up after tests** - close connections, delete test data
8. **Use t.Parallel()** for tests that can run concurrently
9. **Test boundary conditions** - empty inputs, max values, etc.
10. **Document complex test setups**

## Example: Complete Test Suite

```go
package handler

import (
	"context"
	"testing"
	
	"your-service/internal/service"
	pb "your-service/proto"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestGetStatus(t *testing.T) {
	tests := []struct {
		name      string
		serviceID string
		wantErr   bool
		errCode   codes.Code
	}{
		{
			name:      "valid request",
			serviceID: "test-service",
			wantErr:   false,
		},
		{
			name:      "empty service id",
			serviceID: "",
			wantErr:   true,
			errCode:   codes.InvalidArgument,
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx := context.Background()
			svc := service.NewService(ctx, nil, nil, nil)
			h := NewHandler(svc)
			
			req := &pb.GetStatusRequest{
				ServiceId: tt.serviceID,
			}
			
			resp, err := h.GetStatus(ctx, req)
			
			if tt.wantErr {
				if err == nil {
					t.Fatal("expected error, got none")
				}
				st, ok := status.FromError(err)
				if !ok {
					t.Fatal("error is not a gRPC status")
				}
				if st.Code() != tt.errCode {
					t.Errorf("expected code %v, got %v", tt.errCode, st.Code())
				}
				return
			}
			
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			
			if resp.Status != "healthy" {
				t.Errorf("expected status 'healthy', got '%s'", resp.Status)
			}
		})
	}
}
```

## Debugging Tests

### Increase verbosity

```bash
go test -v ./...
```

### Print detailed test output

```bash
go test -v -run TestName ./... 2>&1 | tee test.log
```

### Run single test

```bash
go test -v -run ^TestGetStatus$ ./internal/handler/
```

### Enable race detection

```bash
go test -race ./...
```

## Resources

- [Go Testing Package](https://pkg.go.dev/testing)
- [Table Driven Tests](https://github.com/golang/go/wiki/TableDrivenTests)
- [gRPC Testing](https://grpc.io/docs/languages/go/basics/#testing)
- [Testify (testing toolkit)](https://github.com/stretchr/testify)
