#!/bin/bash

# Script to download and setup Go toolchain based on go.mod version
# Supports: Linux and macOS on amd64 and arm64

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

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
            print_error "Unsupported OS: $os"
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
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    print_info "Detected platform: ${OS}/${ARCH}"
}

# Extract Go version from go.mod
get_go_version() {
    if [ ! -f "go.mod" ]; then
        print_error "go.mod not found in current directory"
        exit 1
    fi
    
    # Extract version from go.mod (e.g., "go 1.21.13" -> "1.21.13")
    GO_VERSION=$(grep -E "^go [0-9]+\.[0-9]+(\.[0-9]+)?" go.mod | awk '{print $2}')
    
    if [ -z "$GO_VERSION" ]; then
        print_error "Could not extract Go version from go.mod"
        exit 1
    fi
    
    print_info "Go version from go.mod: ${GO_VERSION}"
}

# Check if Go is already downloaded
check_existing_go() {
    local go_dir=".goroot/go${GO_VERSION}.${OS}-${ARCH}"
    
    if [ -d "$go_dir" ] && [ -x "$go_dir/bin/go" ]; then
        local installed_version=$("$go_dir/bin/go" version | awk '{print $3}' | sed 's/go//')
        if [ "$installed_version" = "$GO_VERSION" ]; then
            print_info "Go ${GO_VERSION} already installed at $go_dir"
            echo "$go_dir"
            return 0
        else
            print_warning "Found Go at $go_dir but version mismatch. Will re-download."
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
    
    print_info "Downloading Go ${GO_VERSION} for ${OS}/${ARCH}..."
    print_info "URL: ${download_url}"
    
    mkdir -p .goroot
    
    # Download Go tarball
    if ! curl -L -f -o ".goroot/$tarball" "$download_url"; then
        print_error "Failed to download Go from $download_url"
        print_error "Please verify that Go ${GO_VERSION} is available for ${OS}/${ARCH}"
        exit 1
    fi
    
    print_info "Extracting Go..."
    mkdir -p "$go_dir"
    tar -C "$go_dir" --strip-components=1 -xzf ".goroot/$tarball"
    rm ".goroot/$tarball"
    
    # Verify installation
    if [ ! -x "$go_dir/bin/go" ]; then
        print_error "Go binary not found after extraction"
        exit 1
    fi
    
    local installed_version=$("$go_dir/bin/go" version | awk '{print $3}' | sed 's/go//')
    print_info "Successfully installed Go ${installed_version} at $go_dir"
    
    echo "$go_dir"
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

main
