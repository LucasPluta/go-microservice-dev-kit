# health-service

This service was generated using the GoMicroserviceFramework.

## Features

- gRPC API (unary and streaming)

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
  health-service:
    build:
      context: ./services/health-service
      dockerfile: Dockerfile
    ports:
      - "50051:50051"  # Adjust port as needed
    environment:
      - SERVICE_NAME=health-service
      - GRPC_PORT=50051
    depends_on:
```

Then run:

```bash
docker-compose up health-service
```

## Testing

Test the gRPC service using grpcurl:

```bash
grpcurl -plaintext localhost:50051 list
grpcurl -plaintext -d '{"service_id": "test"}' localhost:50051 healthservice.HealthServiceService/GetStatus
```
