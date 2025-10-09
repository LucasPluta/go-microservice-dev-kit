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

# Ensure setup-go has been run
"${SCRIPT_DIR}/setup-go.sh" >/dev/null 2>&1 || true

# Get Go binary
GO=$(get_go_binary)
if [ $? -ne 0 ]; then
    lp-error "Failed to get Go binary. Run 'make setup-go' first"
    exit 1
fi

lp-echo "Building ${SERVICE} for current platform..."
lp-echo "Using Go: ${GO}"

SERVICE_DIR="${FRAMEWORK_ROOT}/services/${SERVICE}"
BIN_DIR="${FRAMEWORK_ROOT}/bin"

# Create bin directory
mkdir -p "$BIN_DIR"

lp-echo "Compiling binary..."
cd "$SERVICE_DIR"
CGO_ENABLED=0 "$GO" build \
    -ldflags='-w -s' \
    -o "${BIN_DIR}/${SERVICE}" \
    ./cmd/main.go

lp-success "Built: ${BIN_DIR}/${SERVICE}"
