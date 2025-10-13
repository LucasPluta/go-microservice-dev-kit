# example-service

This service was generated using the GoMicroserviceFramework.

## Features

- gRPC API (unary and streaming)
- PostgreSQL integration
- Redis integration
- NATS message bus integration

## Development

### Generate protobuf code

```bash
make proto
```

### Build

```bash
make build
```

### Run locally

```bash
make run
```

### Run with Docker Compose

Add the service to `docker-compose.yml`:

```yaml
  example-service:
    build:
      context: ./services/example-service
      dockerfile: Dockerfile
    ports:
      - "50051:50051"  # Adjust port as needed
    environment:
      - SERVICE_NAME=example-service
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
      - USE_NATS=true
      - NATS_URL=nats://nats:4222
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      nats:
        condition: service_healthy
```

Then run:

```bash
docker-compose up example-service
```

## Testing

Test the gRPC service using grpcurl:

```bash
grpcurl -plaintext localhost:50051 list
grpcurl -plaintext -d '{"service_id": "test"}' localhost:50051 example-service.ExampleServiceService/GetStatus
```
