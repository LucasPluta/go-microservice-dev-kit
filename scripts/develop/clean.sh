#!/usr/bin/env bash

# Source utilities (includes set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../util.sh"

lp-echo "Cleaning build artifacts..."

# Remove generated protobuf files
lp-echo "Removing generated protobuf files..."
find "${FRAMEWORK_ROOT}/services" -type f -name "*.pb.go" -delete

# Remove service bin directories
lp-echo "Removing service bin directories..."
find "${FRAMEWORK_ROOT}/services" -type d -name "bin" -exec rm -rf {} + 2>/dev/null || true

# Remove main bin directory
if [ -d "${FRAMEWORK_ROOT}/bin" ]; then
    lp-echo "Removing ${FRAMEWORK_ROOT}/bin..."
    rm -rf "${FRAMEWORK_ROOT}/bin"
fi

# Remove gobincache
if [ -d "${FRAMEWORK_ROOT}/.gobincache" ]; then
    lp-echo "Removing ${FRAMEWORK_ROOT}/.gobincache..."
    rm -rf "${FRAMEWORK_ROOT}/.gobincache"
fi

lp-success "Clean complete"
