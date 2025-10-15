#!/usr/bin/env bash

# Source utilities (includes set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../util.sh"

lp-echo "Testing web client setup..."

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    lp-error "Node.js is not installed. Please install Node.js 18+ to build the web client."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    lp-error "Node.js version 18+ is required. Current version: $(node --version)"
    exit 1
fi

lp-success "Node.js $(node --version) is available"

# Check if npm is available
if ! command -v npm &> /dev/null; then
    lp-error "npm is not installed. Please install npm."
    exit 1
fi

lp-success "npm $(npm --version) is available"

# Check if buf is available
WEB_CLIENT_DIR="${FRAMEWORK_ROOT}/web-client"
cd "$WEB_CLIENT_DIR"

if [ ! -d "node_modules" ]; then
    lp-echo "Installing Node.js dependencies..."
    npm install
fi

# Test protobuf generation
lp-echo "Testing protobuf generation..."
if npm run proto; then
    lp-success "Protobuf generation successful"
else
    lp-error "Protobuf generation failed"
    exit 1
fi

# Check if generated files exist
if [ -f "src/gen/example-service_pb.ts" ] && [ -f "src/gen/example-service_connect.ts" ]; then
    lp-success "Generated TypeScript files are present"
else
    lp-error "Generated TypeScript files are missing"
    exit 1
fi

lp-success "Web client setup test completed successfully!"
lp-echo "You can now run:"
lp-echo "  make dev-web-client    # Start development server"
lp-echo "  make build-web-client  # Build for production"
lp-echo "  make up                # Start all services including web client"