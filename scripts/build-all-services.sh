#!/usr/bin/env bash
set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/util.sh"

lp-echo "Building all services..."

SERVICES_DIR="${FRAMEWORK_ROOT}/services"
BUILD_SCRIPT="${SCRIPT_DIR}/build.sh"

# Find all services
service_count=0
for service_dir in "$SERVICES_DIR"/*; do
    if [ -d "$service_dir" ] && [ -f "$service_dir/go.mod" ]; then
        service_name=$(basename "$service_dir")
        lp-echo "Building service: ${service_name}"
        
        if ! "$BUILD_SCRIPT" "$service_name"; then
            lp-error "Failed to build ${service_name}"
            exit 1
        fi
        
        ((service_count++))
    fi
done

if [ $service_count -eq 0 ]; then
    lp-warn "No services found in ${SERVICES_DIR}"
else
    lp-success "All ${service_count} services built successfully"
fi
