#!/usr/bin/env bash
set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/util.sh"

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

lp-echo "Building Docker image for ${SERVICE}..."

BIN_DIR="${FRAMEWORK_ROOT}/bin"
BINARY_PATH="${BIN_DIR}/${SERVICE}-linux-amd64"

# Check if binary exists, if not build it
if [ ! -f "$BINARY_PATH" ]; then
    lp-warn "Binary not found: ${BINARY_PATH}"
    lp-echo "Building for linux/amd64..."
    "${SCRIPT_DIR}/build-multiarch.sh" "$SERVICE"
fi

lp-echo "Building Docker image..."
cd "$FRAMEWORK_ROOT"
docker build \
    --build-arg SERVICE_NAME="$SERVICE" \
    --build-arg TARGETARCH=amd64 \
    --build-arg TARGETOS=linux \
    -t "${SERVICE}:latest" \
    -f Dockerfile .

lp-success "Docker image built: ${SERVICE}:latest"
