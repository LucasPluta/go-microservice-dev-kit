#!/bin/bash

# Source utilities
source "$(dirname "$0")/../util.sh"

lp-echo "Generating protobuf code for all services..."

# Find all services with proto directories
SERVICES_DIR="services"
FAILED_SERVICES=()

if [ ! -d "$SERVICES_DIR" ]; then
    lp-error "Services directory not found"
    exit 1
fi

for service_dir in "$SERVICES_DIR"/*; do
    if [ ! -d "$service_dir" ]; then
        continue
    fi
    
    service=$(basename "$service_dir")
    proto_dir="$service_dir/proto"
    
    # Check if service has a proto directory with .proto files
    if [ -d "$proto_dir" ] && ls "$proto_dir"/*.proto &>/dev/null; then
        lp-echo "Generating proto for service: $service"
        
        # Call proto.sh for this service
        if ! "$(dirname "$0")/proto.sh" "$service"; then
            lp-error "Failed to generate proto for $service"
            FAILED_SERVICES+=("$service")
        fi
    fi
done

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    lp-error "Failed to generate proto for services: ${FAILED_SERVICES[*]}"
    exit 1
fi

lp-success "✓ Generated protobuf code for all services"
