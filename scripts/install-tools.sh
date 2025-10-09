#!/usr/bin/env bash
set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/util.sh"

# Ensure setup-go has been run
"${SCRIPT_DIR}/setup-go.sh" >/dev/null 2>&1 || true

# Get Go binary
GO=$(get_go_binary)
if [ $? -ne 0 ]; then
    lp-error "Failed to get Go binary. Run 'make setup-go' first"
    exit 1
fi

lp-echo "Installing required tools to ${GOBIN_CACHE}..."
lp-echo "Using Go: ${GO}"

# Create directory
mkdir -p "$GOBIN_CACHE"

# Install protoc-gen-go
lp-echo "Installing protoc-gen-go..."
"$GO" install google.golang.org/protobuf/cmd/protoc-gen-go@latest
lp-success "Installed: protoc-gen-go"

# Install protoc-gen-go-grpc
lp-echo "Installing protoc-gen-go-grpc..."
"$GO" install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
lp-success "Installed: protoc-gen-go-grpc"

lp-success "Tools installed successfully to ${GOBIN_CACHE}"
