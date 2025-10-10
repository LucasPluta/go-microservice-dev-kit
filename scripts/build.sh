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

# Get Go binary (will error if not installed)
if ! GO=$(get_go_binary); then
    lp-error "Failed to get Go binary. Run 'make setup-go' first"
    exit 1
fi

lp-echo "Building ${SERVICE} for current platform..."

SERVICE_DIR="${FRAMEWORK_ROOT}/services/${SERVICE}"
BIN_DIR="${FRAMEWORK_ROOT}/bin"

# Create bin directory
mkdir -p "$BIN_DIR"

lp-echo "Compiling binary..."
cd "$SERVICE_DIR"
if ! CGO_ENABLED=0 "$GO" build \
    -ldflags='-w -s' \
    -o "${BIN_DIR}/${SERVICE}" \
    ./cmd/main.go ; then
    exit 1
fi

lp-success "Built: ${BIN_DIR}/${SERVICE}"
