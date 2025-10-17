#!/bin/bash
. "./scripts/util.sh"

# Run regular clean first
lp-echo "Running regular clean..."
ci-make clean

# Remove Go toolchain
if [ -d "${FRAMEWORK_ROOT}/.goroot" ]; then
    lp-echo "Cleaning Go toolchain from ${FRAMEWORK_ROOT}/.goroot..."
    rm -rf "${FRAMEWORK_ROOT}/.goroot"
    lp-echo "Go toolchain removed"
fi

lp-echo "Full clean complete"
