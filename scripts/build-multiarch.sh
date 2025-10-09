#!/usr/bin/env bash

# Source utilities (includes set -euo pipefail)
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

# Ensure setup-go has been run
"${SCRIPT_DIR}/setup-go.sh" >/dev/null 2>&1 || true

# Get Go binary
if ! GO=$(get_go_binary); then
    lp-error "Failed to get Go binary. Run 'make setup-go' first"
    exit 1
fi

lp-echo "Building ${SERVICE} for multiple architectures..."
lp-echo "Using Go: ${GO}"

SERVICE_DIR="${FRAMEWORK_ROOT}/services/${SERVICE}"
BIN_DIR="${FRAMEWORK_ROOT}/bin"

# Create bin directory
mkdir -p "$BIN_DIR"

# Build for linux/amd64
lp-echo "Building for linux/amd64..."
cd "$SERVICE_DIR"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 "$GO" build \
    -ldflags='-w -s' \
    -o "${BIN_DIR}/${SERVICE}-linux-amd64" \
    ./cmd/main.go
lp-success "Built: ${BIN_DIR}/${SERVICE}-linux-amd64"

# Build for linux/arm64
lp-echo "Building for linux/arm64..."
cd "$SERVICE_DIR"
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 "$GO" build \
    -ldflags='-w -s' \
    -o "${BIN_DIR}/${SERVICE}-linux-arm64" \
    ./cmd/main.go
lp-success "Built: ${BIN_DIR}/${SERVICE}-linux-arm64"

lp-success "Multi-arch build complete for ${SERVICE}"
