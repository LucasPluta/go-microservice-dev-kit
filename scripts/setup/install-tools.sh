#!/bin/bash
. "./scripts/util.sh"

# Get Go binary (will error if not installed)
if ! GO=$(get_go_binary); then
    lp-error "Failed to get Go binary. Run 'make setup-go' first"
    exit 1
fi

lp-quiet-echo "Installing required tools to ${GOBIN_CACHE}..."

# Create directory
mkdir -p "$GOBIN_CACHE"

# Install protoc-gen-go
lp-quiet-echo "Installing protoc-gen-go..."
"$GO" install google.golang.org/protobuf/cmd/protoc-gen-go@latest 2>&1

# Install protoc-gen-go-grpc
lp-quiet-echo "Installing protoc-gen-go-grpc..."
"$GO" install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest 2>&1

# Get the relative path to GOBIN_CACHE, use basename
GOBIN_RELATIVE=$(basename "$GOBIN_CACHE")

lp-echo "All tools are installed in ${GOBIN_RELATIVE}"
