#!/usr/bin/env bash

# Script to download and setup Go toolchain based on go.mod version
# Supports: Linux and macOS on amd64 and arm64
# Usage: setup-go.sh [--quiet]
#   --quiet: Skip output if Go is already installed

# Source utilities (includes set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../util.sh"

# Parse arguments
QUIET_MODE=false
if [ "${1:-}" = "--quiet" ]; then
    QUIET_MODE=true
fi

# Detect host OS and architecture
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$os" in
        linux*)
            OS="linux"
            ;;
        darwin*)
            OS="darwin"
            ;;
        *)
            lp-error "Unsupported OS: $os"
            exit 1
            ;;
    esac
    
    case "$arch" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            lp-error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    if [ "$QUIET_MODE" = false ]; then
        lp-echo "Detected platform: ${OS}/${ARCH}"
    fi
}

# Extract Go version from go.mod
get_go_version() {
    if [ ! -f "go.mod" ]; then
        lp-error "go.mod not found in current directory"
        exit 1
    fi
    
    # Extract version from go.mod (e.g., "go 1.21.13" -> "1.21.13")
    GO_VERSION=$(grep -E "^go [0-9]+\.[0-9]+(\.[0-9]+)?" go.mod | awk '{print $2}')
    
    if [ -z "$GO_VERSION" ]; then
        lp-error "Could not extract Go version from go.mod"
        exit 1
    fi
    
    if [ "$QUIET_MODE" = false ]; then
        lp-echo "Go version from go.mod: ${GO_VERSION}"
    fi
}

# Check if Go is already downloaded
check_existing_go() {
    local go_dir=".goroot/go${GO_VERSION}.${OS}-${ARCH}"
    
    if [ -d "$go_dir" ] && [ -x "$go_dir/bin/go" ]; then
        local installed_version=$("$go_dir/bin/go" version | awk '{print $3}' | sed 's/go//')
        if [ "$installed_version" = "$GO_VERSION" ]; then
            if [ "$QUIET_MODE" = false ]; then
                lp-echo "Go ${GO_VERSION} already installed at $go_dir"
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

# Download and extract Go
download_go() {
    local go_dir=".goroot/go${GO_VERSION}.${OS}-${ARCH}"
    local download_url="https://go.dev/dl/go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
    local tarball="go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
    
    lp-echo "Downloading Go ${GO_VERSION} for ${OS}/${ARCH}..."
    lp-echo "URL: ${download_url}"
    
    mkdir -p .goroot
    
    # Download Go tarball (suppress curl progress bar)
    if ! curl -L -f -s -S -o ".goroot/$tarball" "$download_url"; then
        lp-error "Failed to download Go from $download_url"
        lp-error "Please verify that Go ${GO_VERSION} is available for ${OS}/${ARCH}"
        exit 1
    fi
    
    lp-echo "Extracting Go..."
    mkdir -p "$go_dir"
    tar -C "$go_dir" --strip-components=1 -xzf ".goroot/$tarball" 2>&1 | grep -v "^x " || true
    rm ".goroot/$tarball"
    
    # Verify installation
    if [ ! -x "$go_dir/bin/go" ]; then
        lp-error "Go binary not found after extraction"
        exit 1
    fi
    
    local installed_version=$("$go_dir/bin/go" version | awk '{print $3}' | sed 's/go//')
    lp-success "Successfully installed Go ${installed_version} at $go_dir"
}

# Main function
main() {
    detect_platform
    get_go_version
    
    if check_existing_go; then
        return 0
    fi
    
    download_go
}

# Only run if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main
fi
