#!/bin/bash
. "./scripts/util.sh"

lp-quiet-echo "Building all services..."

SERVICES_DIR="${FRAMEWORK_ROOT}/services"

# Find all services
service_count=0
for service_dir in "$SERVICES_DIR"/*; do
    if [ -d "$service_dir" ]; then
        service_name=$(basename "$service_dir")
        lp-quiet-echo "Building docker image: ${service_name}"
        
        if ! ci-make docker-build SERVICE="$service_name"; then
            lp-error "Failed to build ${service_name}"
            exit 1
        fi

        service_count=$((service_count + 1))
    fi
done

if [ $service_count -eq 0 ]; then
    lp-warn "No services found in ${SERVICES_DIR}"
else
    lp-quiet-echo "All ${service_count} services built successfully"
fi
