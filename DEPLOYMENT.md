# Deployment Guide

This guide covers various deployment strategies for services built with the GoMicroserviceFramework.

## Table of Contents

- [Docker Compose (Development)](#docker-compose-development)
- [Kubernetes (Production)](#kubernetes-production)
- [Cloud Platforms](#cloud-platforms)
- [CI/CD Pipeline](#cicd-pipeline)

## Docker Compose (Development)

### Basic Setup

1. Ensure services are added to `docker-compose.yml`
2. Start infrastructure and services:

```bash
docker-compose up -d
```

### Service Configuration

Each service in `docker-compose.yml` should follow this pattern:

```yaml
your-service:
  build:
    context: ./services/your-service
    dockerfile: Dockerfile
  ports:
    - "50052:50051"  # External:Internal
  environment:
    - SERVICE_NAME=your-service
    - GRPC_PORT=50051
    # Database config
    - USE_POSTGRES=true
    - POSTGRES_HOST=postgres
    - POSTGRES_PORT=5432
    - POSTGRES_USER=postgres
    - POSTGRES_PASSWORD=postgres
    - POSTGRES_DB=microservices
    # Redis config
    - USE_REDIS=true
    - REDIS_HOST=redis
    - REDIS_PORT=6379
    # NATS config
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

### Useful Commands

```bash
# Start all services
docker-compose up -d

# Start specific services
docker-compose up -d postgres redis nats your-service

# View logs
docker-compose logs -f your-service

# Restart a service
docker-compose restart your-service

# Rebuild and restart
docker-compose up -d --build your-service

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Scale a service
docker-compose up -d --scale your-service=3
```

## Kubernetes (Production)

### Prerequisites

- Kubernetes cluster (version 1.24+)
- kubectl configured
- Container registry (Docker Hub, GCR, ECR, etc.)

### Step 1: Build and Push Images

```bash
# Build service image
cd services/your-service
docker build -t your-registry/your-service:v1.0.0 .

# Push to registry
docker push your-registry/your-service:v1.0.0
```

### Step 2: Create Kubernetes Manifests

Create `k8s/` directory structure:

```
k8s/
├── namespace.yaml
├── postgres/
│   ├── statefulset.yaml
│   ├── service.yaml
│   └── pvc.yaml
├── redis/
│   ├── deployment.yaml
│   └── service.yaml
├── nats/
│   ├── deployment.yaml
│   └── service.yaml
└── services/
    └── your-service/
        ├── deployment.yaml
        ├── service.yaml
        └── configmap.yaml
```

### Namespace

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
```

### Service Deployment

```yaml
# k8s/services/your-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-service
  namespace: microservices
spec:
  replicas: 3
  selector:
    matchLabels:
      app: your-service
  template:
    metadata:
      labels:
        app: your-service
    spec:
      containers:
      - name: your-service
        image: your-registry/your-service:v1.0.0
        ports:
        - containerPort: 50051
          name: grpc
        env:
        - name: SERVICE_NAME
          value: "your-service"
        - name: GRPC_PORT
          value: "50051"
        - name: USE_POSTGRES
          value: "true"
        - name: POSTGRES_HOST
          value: "postgres"
        - name: POSTGRES_PORT
          value: "5432"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: POSTGRES_DB
          value: "microservices"
        - name: USE_REDIS
          value: "true"
        - name: REDIS_HOST
          value: "redis"
        - name: REDIS_PORT
          value: "6379"
        - name: USE_NATS
          value: "true"
        - name: NATS_URL
          value: "nats://nats:4222"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:50051"]
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:50051"]
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Service

```yaml
# k8s/services/your-service/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: your-service
  namespace: microservices
spec:
  selector:
    app: your-service
  ports:
  - name: grpc
    port: 50051
    targetPort: 50051
  type: ClusterIP
```

### ConfigMap

```yaml
# k8s/services/your-service/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: your-service-config
  namespace: microservices
data:
  SERVICE_NAME: "your-service"
  GRPC_PORT: "50051"
```

### Secrets

```bash
# Create secrets for database credentials
kubectl create secret generic postgres-secret \
  --from-literal=username=postgres \
  --from-literal=password=your-secure-password \
  -n microservices
```

### PostgreSQL StatefulSet

```yaml
# k8s/postgres/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: microservices
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: POSTGRES_DB
          value: "microservices"
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

### Deploy to Kubernetes

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create secrets
kubectl create secret generic postgres-secret \
  --from-literal=username=postgres \
  --from-literal=password=your-secure-password \
  -n microservices

# Deploy infrastructure
kubectl apply -f k8s/postgres/
kubectl apply -f k8s/redis/
kubectl apply -f k8s/nats/

# Wait for infrastructure to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n microservices --timeout=300s

# Deploy services
kubectl apply -f k8s/services/your-service/

# Check status
kubectl get pods -n microservices
kubectl get services -n microservices
```

## Cloud Platforms

### AWS ECS/Fargate

1. **Create ECR Repository**:
```bash
aws ecr create-repository --repository-name your-service
```

2. **Build and Push**:
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker build -t your-service .
docker tag your-service:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/your-service:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/your-service:latest
```

3. **Create Task Definition** and **Service** via AWS Console or CLI

### Google Cloud Run

```bash
# Build and deploy
gcloud builds submit --tag gcr.io/PROJECT-ID/your-service
gcloud run deploy your-service \
  --image gcr.io/PROJECT-ID/your-service \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

### Azure Container Instances

```bash
az container create \
  --resource-group myResourceGroup \
  --name your-service \
  --image your-registry.azurecr.io/your-service:latest \
  --dns-name-label your-service-unique \
  --ports 50051
```

## CI/CD Pipeline

### GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Build and Deploy

on:
  push:
    branches: [main]
    paths:
      - 'services/**'

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [user-service, order-service, notification-service]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Login to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: ./services/${{ matrix.service }}
          push: true
          tags: |
            ghcr.io/${{ github.repository }}/${{ matrix.service }}:latest
            ghcr.io/${{ github.repository }}/${{ matrix.service }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
  
  deploy:
    needs: build
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up kubectl
        uses: azure/setup-kubectl@v3
      
      - name: Configure kubectl
        run: |
          echo "${{ secrets.KUBE_CONFIG }}" | base64 -d > kubeconfig
          export KUBECONFIG=kubeconfig
      
      - name: Deploy to Kubernetes
        run: |
          kubectl apply -f k8s/
          kubectl rollout restart deployment -n microservices
```

### GitLab CI

Create `.gitlab-ci.yml`:

```yaml
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_REGISTRY: registry.gitlab.com
  DOCKER_IMAGE: $DOCKER_REGISTRY/$CI_PROJECT_PATH

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $DOCKER_REGISTRY
    - docker build -t $DOCKER_IMAGE/your-service:$CI_COMMIT_SHA services/your-service
    - docker push $DOCKER_IMAGE/your-service:$CI_COMMIT_SHA

test:
  stage: test
  image: golang:1.21
  script:
    - cd services/your-service
    - go test ./...

deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl config use-context $KUBE_CONTEXT
    - kubectl set image deployment/your-service your-service=$DOCKER_IMAGE/your-service:$CI_COMMIT_SHA -n microservices
  only:
    - main
```

## Monitoring and Logging

### Prometheus Monitoring

Add to service Dockerfile:

```dockerfile
# Add health check endpoint
HEALTHCHECK CMD grpc_health_probe -addr=:50051 || exit 1
```

### Centralized Logging

Use structured logging and aggregate with:
- **ELK Stack** (Elasticsearch, Logstash, Kibana)
- **Grafana Loki**
- **CloudWatch** (AWS)
- **Stackdriver** (GCP)

## Best Practices

1. **Use Multi-Stage Builds** to reduce image size
2. **Tag Images** with version and git SHA
3. **Set Resource Limits** in Kubernetes
4. **Use Health Checks** for readiness and liveness
5. **Store Secrets Securely** (never in code or config files)
6. **Enable TLS** for production gRPC endpoints
7. **Use Service Mesh** (Istio, Linkerd) for complex deployments
8. **Implement Circuit Breakers** and retry logic
9. **Monitor** all services with metrics and alerts
10. **Automate** deployments via CI/CD

## Rollback Strategy

### Kubernetes Rollback

```bash
# Check rollout history
kubectl rollout history deployment/your-service -n microservices

# Rollback to previous version
kubectl rollout undo deployment/your-service -n microservices

# Rollback to specific revision
kubectl rollout undo deployment/your-service --to-revision=2 -n microservices
```

### Docker Compose Rollback

```bash
# Stop current version
docker-compose down

# Checkout previous version
git checkout previous-tag

# Start previous version
docker-compose up -d --build
```

## Production Checklist

- [ ] TLS/SSL certificates configured
- [ ] Database credentials stored in secrets
- [ ] Resource limits set for all containers
- [ ] Health checks configured
- [ ] Monitoring and alerting set up
- [ ] Logging aggregation configured
- [ ] Backup strategy implemented
- [ ] Disaster recovery plan documented
- [ ] Load testing completed
- [ ] Security scanning performed
- [ ] Documentation updated
- [ ] Runbooks created for operations team

## Troubleshooting

### Container won't start

```bash
# Check logs
kubectl logs <pod-name> -n microservices

# Describe pod for events
kubectl describe pod <pod-name> -n microservices
```

### Service unreachable

```bash
# Check service endpoints
kubectl get endpoints -n microservices

# Test connectivity from another pod
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Inside pod:
apk add curl
curl http://your-service:50051
```

### Database connection issues

```bash
# Check if PostgreSQL is running
kubectl get pods -l app=postgres -n microservices

# Test database connection
kubectl exec -it postgres-0 -n microservices -- psql -U postgres -d microservices
```

## Additional Resources

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [gRPC Production Guide](https://grpc.io/docs/guides/performance/)
- [12-Factor App](https://12factor.net/)
