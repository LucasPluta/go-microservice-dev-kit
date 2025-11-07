#!/bin/bash

# kind-deploy.sh
# Deploy GoMicroserviceFramework to existing Kind cluster

. "./scripts/util.sh"

# Configuration
CLUSTER_NAME="gomicroservice-framework"
REGISTRY_PORT="5001"
HELM_RELEASE_NAME="gomicroservice"

lp-echo "Deploying GoMicroserviceFramework to Kind cluster"

# Check prerequisites and cluster
lp-echo "Checking prerequisites and cluster status..."

if ! command_exists helm; then
    lp-error "Helm is not installed. Please install Helm first: https://helm.sh/docs/intro/install/"
    exit 1
fi

if ! command_exists docker; then
    lp-error "Docker is not installed. Please install Docker first"
    exit 1
fi

# Check if Kind cluster exists and is running
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    lp-error "Kind cluster '${CLUSTER_NAME}' not found. Please run './scripts/kube/kind-setup.sh' first"
    exit 1
fi

# Check if kubectl can connect to the cluster
if ! kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null 2>&1; then
    lp-error "Cannot connect to Kind cluster. Please ensure cluster is running"
    exit 1
fi

lp-success "Prerequisites checked and cluster is accessible"

# Build and load container images
lp-echo "Building and loading container images..."

cd "${FRAMEWORK_ROOT}"

# Ensure binaries are built
if [[ ! -d "bin" ]]; then
    lp-echo "Building Go services..."
    make build
fi

# Build Docker images and push to local registry
lp-echo "Building Docker images..."

# Build service images
for service in example-service health-service user-service; do
    lp-echo "Building ${service}..."
    docker build --build-arg SERVICE_NAME="${service}" -t "localhost:${REGISTRY_PORT}/${service}:latest" .
    docker push "localhost:${REGISTRY_PORT}/${service}:latest"
done

# Build web client
lp-echo "Building web-client..."
docker build -f Dockerfile.web -t "localhost:${REGISTRY_PORT}/web-client:latest" .
docker push "localhost:${REGISTRY_PORT}/web-client:latest"

lp-success "All images built and pushed to local registry"

# Generate certificates if they don't exist
lp-echo "Checking TLS certificates..."

if [[ ! -d "${FRAMEWORK_ROOT}/certs" ]] || [[ ! -f "${FRAMEWORK_ROOT}/certs/ca-cert.pem" ]]; then
    lp-echo "Generating TLS certificates..."
    make setup
fi

# Populate Helm values with certificates
lp-echo "Populating Helm values with certificates..."
"${FRAMEWORK_ROOT}/scripts/setup/populate-helm-certs.sh"

# Deploy with Helm
lp-echo "Deploying with Helm..."

# Update values for local registry
helm upgrade --install "${HELM_RELEASE_NAME}" "${FRAMEWORK_ROOT}/helm-chart" \
    --set global.imageRegistry="localhost:${REGISTRY_PORT}" \
    --set global.imageTag="latest" \
    --set webClient.service.type="NodePort" \
    --set exampleService.service.type="NodePort" \
    --wait --timeout=5m

lp-success "Deployment completed successfully!"

# Display access information
lp-echo "Deployment Summary"
lp-echo ""
lp-echo "Cluster: ${CLUSTER_NAME}"
lp-echo "Registry: localhost:${REGISTRY_PORT}"
lp-echo ""
lp-echo "Access URLs:"
lp-echo "  Web Client (HTTP):  http://localhost:8080"
lp-echo "  Web Client (HTTPS): https://localhost:8443"
lp-echo "  Example Service:    localhost:50051 (gRPC)"
lp-echo ""
lp-echo "Useful commands:"
lp-echo "  kubectl get pods                    # Check pod status"
lp-echo "  kubectl logs -f deployment/example-service  # Follow service logs"
lp-echo "  helm list                          # List Helm releases"
lp-echo "  ./scripts/kube/kind-cleanup.sh     # Cleanup cluster"
lp-echo ""
lp-echo "To check deployment status:"
lp-echo "  kubectl get all"