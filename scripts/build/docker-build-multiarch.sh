#!/bin/bash
. "./scripts/util.sh"

SERVICE="${1:-}"
REGISTRY="${2:-localhost:5000}"

if [ -z "$SERVICE" ]; then
    lp-error "SERVICE name is required"
    lp-echo "Usage: $0 <service-name> [registry]"
    exit 1
fi

# Validate service exists
if ! validate_service "$SERVICE"; then
    exit 1
fi

lp-echo "Building multi-arch Docker images for ${SERVICE}..."
lp-echo "Registry: ${REGISTRY}"

# Build binaries for multiple architectures
lp-echo "Building binaries for multiple architectures..."
"${SCRIPT_DIR}/build-multiarch.sh" "$SERVICE"

cd "$FRAMEWORK_ROOT"

# Build for linux/amd64
lp-echo "Building Docker image for linux/amd64..."
docker build \
    --build-arg SERVICE_NAME="$SERVICE" \
    --build-arg TARGETARCH=amd64 \
    --build-arg TARGETOS=linux \
    --platform linux/amd64 \
    -t "${REGISTRY}/${SERVICE}:latest-amd64" \
    -f Dockerfile .
lp-success "Built: ${REGISTRY}/${SERVICE}:latest-amd64"

# Build for linux/arm64
lp-echo "Building Docker image for linux/arm64..."
docker build \
    --build-arg SERVICE_NAME="$SERVICE" \
    --build-arg TARGETARCH=arm64 \
    --build-arg TARGETOS=linux \
    --platform linux/arm64 \
    -t "${REGISTRY}/${SERVICE}:latest-arm64" \
    -f Dockerfile .
lp-success "Built: ${REGISTRY}/${SERVICE}:latest-arm64"

# Push images
lp-echo "Pushing images to registry..."
docker push "${REGISTRY}/${SERVICE}:latest-amd64"
docker push "${REGISTRY}/${SERVICE}:latest-arm64"
lp-success "Images pushed to registry"

# Create and push manifest
lp-echo "Creating and pushing multi-arch manifest..."
docker manifest create "${REGISTRY}/${SERVICE}:latest" \
    "${REGISTRY}/${SERVICE}:latest-amd64" \
    "${REGISTRY}/${SERVICE}:latest-arm64"
docker manifest push "${REGISTRY}/${SERVICE}:latest"

lp-success "Multi-arch Docker image built and pushed: ${REGISTRY}/${SERVICE}:latest"
