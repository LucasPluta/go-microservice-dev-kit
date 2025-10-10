#!/usr/bin/env bash

# Source utilities (includes set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/util.sh"

# Get Go binary (will error if not installed)
if ! GO=$(get_go_binary); then
    lp-error "Failed to get Go binary. Run 'make setup-go' first"
    exit 1
fi

lp-echo "Installing required tools to ${GOBIN_CACHE}..."

# Create directory
mkdir -p "$GOBIN_CACHE"

# Install protoc-gen-go
lp-echo "Installing protoc-gen-go..."
"$GO" install google.golang.org/protobuf/cmd/protoc-gen-go@latest 2>&1

# Install protoc-gen-go-grpc
lp-echo "Installing protoc-gen-go-grpc..."
"$GO" install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest 2>&1

lp-success "Tools installed successfully to ${GOBIN_CACHE}"
