#!/usr/bin/env bash

# Source utilities (includes set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../util.sh"

# Run regular clean first
lp-echo "Running regular clean..."
"${SCRIPT_DIR}/clean.sh"

# Remove Go toolchain
if [ -d "${FRAMEWORK_ROOT}/.goroot" ]; then
    lp-echo "Cleaning Go toolchain from ${FRAMEWORK_ROOT}/.goroot..."
    rm -rf "${FRAMEWORK_ROOT}/.goroot"
    lp-success "Go toolchain removed"
fi

lp-success "Full clean complete"
