#!/bin/bash
. "./scripts/util.sh"

# Get Go binary (will error if not installed)
if ! GO=$(get_go_binary); then
    lp-error "Failed to get Go binary. Run 'make setup-go' first"
    exit 1
fi

lp-echo "Running tests for all services..."

SERVICES_DIR="${FRAMEWORK_ROOT}/services"
test_count=0
failed_count=0

# Find all services and run tests
for service_dir in "$SERVICES_DIR"/*; do
    if [ -d "$service_dir" ]; then
        service_name=$(basename "$service_dir")
        
        # Check if service has any Go files
        if ! find "$service_dir" -name "*.go" -type f | grep -q .; then
            continue
        fi
        
        lp-echo "Testing ${service_name}..."
        
        # Run tests and capture output
        if test_output=$(cd "$service_dir" && "$GO" test -v ./... 2>&1); then
            # Tests passed - show only summary
            echo "$test_output"
            lp-success "Tests passed for ${service_name}"
            test_count=$((test_count + 1))
        else
            # Tests failed - show full output for debugging
            echo "$test_output"
            lp-error "Tests failed for ${service_name}"
            failed_count=$((failed_count + 1))
        fi
    fi
done

if [ $test_count -eq 0 ]; then
    lp-warn "No services with Go files found to test in ${SERVICES_DIR}"
elif [ $failed_count -eq 0 ]; then
    lp-success "All ${test_count} service(s) passed tests"
else
    lp-error "${failed_count} service(s) failed tests"
    exit 1
fi
