#!/usr/bin/env bash

# Source utilities (includes set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$0")/../util.sh"

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

# Get Go binary (will error if not installed)
if ! GO=$(get_go_binary); then
    lp-error "Failed to get Go binary. Run 'make setup-go' first"
    exit 1
fi

lp-quiet-echo "Building ${SERVICE} for multiple architectures..."

SERVICE_DIR="${FRAMEWORK_ROOT}/services/${SERVICE}"
BIN_DIR="${FRAMEWORK_ROOT}/bin"

# Create bin directory
mkdir -p "$BIN_DIR"

# Build for linux/amd64
lp-quiet-echo "Building for linux/amd64..."
cd "$SERVICE_DIR"
if ! CGO_ENABLED=0 GOOS=linux GOARCH=amd64 "$GO" build \
    -ldflags='-w -s' \
    -o "${BIN_DIR}/${SERVICE}-linux-amd64" \
    ./cmd/main.go 2>&1; then
    exit 1
fi
lp-echo "Built: ${BIN_DIR}/${SERVICE}-linux-amd64"

# Build for linux/arm64
lp-quiet-echo "Building for linux/arm64..."
cd "$SERVICE_DIR"
if ! CGO_ENABLED=0 GOOS=linux GOARCH=arm64 "$GO" build \
    -ldflags='-w -s' \
    -o "${BIN_DIR}/${SERVICE}-linux-arm64" \
    ./cmd/main.go 2>&1; then
    exit 1
fi
lp-echo "Built: ${BIN_DIR}/${SERVICE}-linux-arm64"

lp-echo "Multi-arch build complete for ${SERVICE}"
