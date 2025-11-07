#!/bin/bash
. "./scripts/util.sh"

function check_docker_available() {
    if ! command -v docker &> /dev/null; then
        return 1
    fi

    # Test if Docker is running
    if ! docker info >/dev/null 2>&1; then
        lp-echo "Docker is not running."

        # If on macOS, try to start Docker Desktop
        if [[ "$OSTYPE" == "darwin"* ]]; then
            lp-echo "Attempting to start Docker Desktop..."
            open -a Docker

            # Wait until Docker daemon is up
            while ! docker info >/dev/null 2>&1; do
                lp-echo "Waiting for Docker to start..."
                sleep 3
            done
            lp-echo "Docker is now running."
        else
            lp-echo "Please start the Docker daemon manually."
            return 1
        fi
    fi

    return 0
}


SERVICE="${1:-}"

if [ -z "$SERVICE" ]; then
    lp-error "SERVICE name is required"
    lp-echo "Usage: $0 <service-name>"
    exit 1
fi

# Validate service exists
if ! validate_service "$SERVICE"; then
    exit 1
fi

# Check if docker is up, running, and available before proceeding
if ! check_docker_available; then
    lp-error "Docker is not available. Please ensure Docker is installed and running."
    exit 1
fi

lp-quiet-echo "Building Docker image for ${SERVICE}..."

BIN_DIR="${FRAMEWORK_ROOT}/bin"
BINARY_PATH="${BIN_DIR}/${SERVICE}-linux-amd64"

# Check if binary exists, if not build it
if [ ! -f "$BINARY_PATH" ]; then
    lp-warn "Binary not found: ${BINARY_PATH}"
    lp-echo "Building for linux/amd64..."
    "./scripts/build/build-multiarch.sh" "$SERVICE"
fi

cd "$FRAMEWORK_ROOT"
SHA=$(docker build -q \
    --build-arg SERVICE_NAME="$SERVICE" \
    --build-arg TARGETOS=linux \
    -t "${SERVICE}:latest" \
    -f Dockerfile .)

lp-echo "Built: ${SERVICE}:latest - SHA: $SHA"

# if kind is installed, load the images into kind
if command -v kind &> /dev/null; then
    # Check the list of clusters.  If only one exists, use that name, otherwise look for a cluster named "kind"
    if [ "$(kind get clusters | wc -l)" -eq 1 ]; then
        CLUSTER_NAME=$(kind get clusters)
        lp-echo "Loading image into kind cluster '${CLUSTER_NAME}'..."
        kind load docker-image "${SERVICE}:latest" --name "${CLUSTER_NAME}"
    elif kind get clusters | grep -q "^kind$"; then
        lp-echo "Loading image into kind cluster 'kind'..."
        kind load docker-image "${SERVICE}:latest" --name "kind"
    else 
        lp-echo "No suitable kind cluster found. Skipping loading image into kind."
    fi
fi
