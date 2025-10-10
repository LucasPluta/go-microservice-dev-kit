#!/usr/bin/env bash

# Script to download and setup protoc toolchain
# Supports: Linux and macOS on amd64 and arm64
# Usage: setup-protoc.sh [--quiet]
#   --quiet: Skip output if protoc is already installed

# Source utilities (includes set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../util.sh"

# Parse arguments
QUIET_MODE=false
if [ "${1:-}" = "--quiet" ]; then
    QUIET_MODE=true
fi

# Check if protoc is already downloaded
check_existing_protoc() {
    local protoc_dir=".goroot/protoc-${PROTOC_VERSION}.${OS}-${ARCH}"

    if [ -d "$protoc_dir" ] && [ -x "$protoc_dir/bin/protoc" ]; then
        local installed_version=$("$protoc_dir/bin/protoc" --version | awk '{print $2}')
        if [ "$installed_version" = "$PROTOC_VERSION" ]; then
            if [ "$QUIET_MODE" = false ]; then
                lp-echo "protoc ${PROTOC_VERSION} already installed at $protoc_dir"
            fi
            # Don't output path to stdout - it causes nested logging issues
            return 0
        else
            if [ "$QUIET_MODE" = false ]; then
                lp-warn "Found Go at $go_dir but version mismatch. Will re-download."
            fi
            rm -rf "$go_dir"
        fi
    fi
    
    return 1
}

# Download and extract protoc
download_protoc() {
    local protoc_dir=".goroot/protoc-${PROTOC_VERSION}.${OS}-${ARCH}"
    local download_url=""
    if [ "$ARCH" = "amd64" ] && [ "$OS" = "darwin" ]; then
        download_url="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-osx-x86_64.zip"
    elif [ "$ARCH" = "arm64" ] && [ "$OS" = "darwin" ]; then
        download_url="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-osx-aarch_64.zip"
    elif [ "$ARCH" = "amd64" ] && [ "$OS" = "linux" ]; then
        download_url="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-${OS}-x86_64.zip"
    elif [ "$ARCH" = "arm64" ] && [ "$OS" = "linux" ]; then
        download_url="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-${OS}-aarch_64.zip"
    else
        lp-error "No prebuilt protoc available for ${OS}/${ARCH}"
        exit 1
    fi

    local zipfile="protoc-${PROTOC_VERSION}.${OS}-${ARCH}.zip"
    
    lp-echo "Downloading protoc ${PROTOC_VERSION} for ${OS}/${ARCH}..."
    lp-echo "URL: ${download_url}"
    
    mkdir -p .goroot
    
    # Download protoc zip (suppress curl progress bar)
    if ! curl -L -f -s -S -o ".goroot/$zipfile" "$download_url"; then
        lp-error "Failed to download protoc from $download_url"
        lp-error "Please verify that protoc ${PROTOC_VERSION} is available for ${OS}/${ARCH}"
        exit 1
    fi
    
    lp-echo "Extracting protoc..."
    mkdir -p "$protoc_dir"
    unzip -q ".goroot/$zipfile" -d "$protoc_dir"
    rm ".goroot/$zipfile"
    
    # Verify installation
    if [ ! -x "$protoc_dir/bin/protoc" ]; then
        lp-error "protoc binary not found after extraction"
        exit 1
    fi
    
    local installed_version=$("$protoc_dir/bin/protoc" --version | awk '{print $2}')
    if [ "$installed_version" != "$PROTOC_VERSION" ]; then
        lp-error "Version mismatch after extraction: expected $PROTOC_VERSION, got $installed_version"
        exit 1
    fi
    
    lp-success "Successfully installed protoc ${installed_version} at $protoc_dir"
}

# Main function
main() {
    detect_platform
    
    if check_existing_protoc; then
        return 0
    fi
    
    download_protoc
}

# Only run if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main
fi
