# Score.dev Configuration for GoMicroserviceFramework

This directory contains the Score.dev configuration for deploying the GoMicroserviceFramework stack to Kubernetes or other container orchestration platforms.

## Overview

The `score.yaml` file defines the complete microservices stack including:

### Infrastructure Services
- **PostgreSQL** (postgres:15-alpine) - Primary database
- **Redis** (redis:7-alpine) - Caching and session storage  
- **NATS** (nats:2-alpine) - Message bus with JetStream enabled

### Application Services
- **example-service** - Example gRPC microservice (port 50051)
- **health-service** - Health check microservice (port 50052)
- **user-service** - User management microservice (port 50053)
- **web-client** - React + gRPC-Web frontend with Nginx (ports 80/443)

## Prerequisites

1. **Score CLI**: Install Score CLI from [score.dev](https://score.dev)
2. **Certificates**: Generate TLS certificates using the framework's setup
3. **Container Images**: Build and push container images to a registry

## Setup

### 1. Generate Certificates

```bash
make setup
```

This generates the required TLS certificates in the `./certs/` directory.

### 2. Populate Certificates in Score Configuration

```bash
./scripts/setup/populate-score-certs.sh
```

This script base64-encodes the certificates and populates them in the Score configuration.

### 3. Build and Push Container Images

```bash
# Set your registry
export IMAGE_REGISTRY=your-registry.com/your-namespace

# Build all services
make build

# Build Docker images
make docker-build

# Push to registry (you'll need to implement push commands)
# docker push $IMAGE_REGISTRY/example-service:latest
# docker push $IMAGE_REGISTRY/health-service:latest  
# docker push $IMAGE_REGISTRY/user-service:latest
# docker push $IMAGE_REGISTRY/web-client:latest
```

## Deployment

### Using score-compose (Docker Compose)

```bash
# Initialize score-compose
score-compose init --file score.yaml

# Generate docker-compose.yml
score-compose generate score.yaml

# Deploy
docker-compose up -d
```

### Using score-k8s (Kubernetes)

```bash
# Set environment variables
export IMAGE_REGISTRY=your-registry.com/your-namespace
export IMAGE_TAG=latest
export STORAGE_CLASS=standard

# Generate Kubernetes manifests
score-k8s --file score.yaml --output manifests/

# Apply to cluster
kubectl apply -f manifests/
```

### Using score-helm (Helm)

```bash
# Generate Helm chart
score-helm --file score.yaml --output helm-chart/

# Deploy with Helm
helm install gomicroservice-framework ./helm-chart/
```

## Configuration

### Environment Variables

The following environment variables can be set to customize deployment:

- `IMAGE_REGISTRY` - Container registry URL (default: localhost:5000)
- `IMAGE_TAG` - Container image tag (default: latest)  
- `STORAGE_CLASS` - Kubernetes storage class (default: standard)

### Resource Limits

Current resource allocations:

**Infrastructure Services:**
- PostgreSQL: 256Mi-512Mi memory, 100m-500m CPU
- Redis: 128Mi-256Mi memory, 50m-200m CPU
- NATS: 128Mi-256Mi memory, 50m-200m CPU

**Application Services:**
- Each microservice: 128Mi-256Mi memory, 100m-500m CPU
- Web client: 64Mi-128Mi memory, 50m-200m CPU

### Persistent Storage

- PostgreSQL data: 10Gi persistent volume
- TLS certificates: ConfigMap volume mounted to all services

## Service Architecture

### Network Topology

```
Internet -> web-client:443 (HTTPS)
                |
                +-> example-service:50051 (gRPC/TLS)
                +-> health-service:50052 (gRPC/TLS)  
                +-> user-service:50053 (gRPC/TLS)
                          |
                          +-> postgres:5432
                          +-> redis:6379
                          +-> nats:4222
```

### Health Checks

All services include comprehensive health checks:

- **Infrastructure services**: Native health check commands
- **gRPC services**: grpc_health_probe with TLS support
- **Web client**: HTTPS endpoint health checks

### Security

- **TLS encryption**: All gRPC communications use mutual TLS
- **Certificate management**: Centralized certificate distribution via ConfigMap
- **Network policies**: Services communicate only with required dependencies

## Development

### Local Development with Score

For local development, you can use score-compose to generate a docker-compose setup:

```bash
# Generate local development setup
export IMAGE_REGISTRY=localhost:5000
export IMAGE_TAG=dev
score-compose generate score.yaml

# Start local development environment
docker-compose up -d postgres redis nats
```

Then run individual services locally using the framework's development tools:

```bash
make up    # Start infrastructure
# Services can be run individually for development
```

### Adding New Services

To add a new service to the Score configuration:

1. Generate the service using the framework:
   ```bash
   ./scripts/develop/create-service.sh new-service --postgres --redis --nats
   ```

2. Add the service definition to `score.yaml`:
   ```yaml
   new-service:
     image: "${IMAGE_REGISTRY:-localhost:5000}/new-service:${IMAGE_TAG:-latest}"
     variables:
       SERVICE_NAME: new-service
       GRPC_PORT: "50054"  # Next available port
       # ... other standard configuration
   ```

3. Update the service ports section and rebuild

## Troubleshooting

### Common Issues

1. **Certificate errors**: Ensure certificates are generated and populated correctly
2. **Image pull errors**: Verify IMAGE_REGISTRY and ensure images are pushed
3. **Resource constraints**: Adjust resource limits based on your cluster capacity
4. **Storage issues**: Ensure storage class exists and has sufficient capacity

### Debugging

```bash
# Check Score configuration
score-compose validate score.yaml

# Check generated manifests
score-k8s --file score.yaml --output /tmp/debug-manifests/
kubectl apply --dry-run=client -f /tmp/debug-manifests/

# Monitor deployment
kubectl get pods -w
kubectl logs -f deployment/example-service
```

## Migration from Docker Compose

The Score configuration maintains feature parity with the existing `docker-compose.yml`:

- All environment variables preserved
- Health checks maintained  
- Volume mounts configured
- Service dependencies respected
- TLS configuration intact

The primary benefits of Score over direct Docker Compose:

1. **Platform agnostic**: Deploy to Docker, Kubernetes, or other platforms
2. **Environment parameterization**: Easy environment-specific configuration
3. **Resource management**: Proper CPU/memory limits and requests
4. **Cloud-native patterns**: Health checks, readiness probes, rolling updates