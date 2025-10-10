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

SERVICE_DIR="${FRAMEWORK_ROOT}/services/${SERVICE}"
PROTO_FILE="${SERVICE_DIR}/proto/${SERVICE}.proto"

if [ ! -f "$PROTO_FILE" ]; then
    lp-warn "Proto file not found: ${PROTO_FILE}"
    lp-echo "Service may not have a proto definition"
    exit 0
fi

lp-echo "Generating protobuf code for ${SERVICE}..."
lp-echo "Proto file: ${PROTO_FILE}"

# Get protoc binary (will error if not installed)
if ! PROTOC=$(get_protoc_binary); then
    lp-error "Failed to get protoc binary. Run 'make setup-protoc' first"
    exit 1
fi

cd "$SERVICE_DIR"
$PROTOC --go_out=. --go_opt=paths=source_relative \
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \
    "proto/${SERVICE}.proto" 2>&1

lp-success "Protobuf code generated successfully for ${SERVICE}"
