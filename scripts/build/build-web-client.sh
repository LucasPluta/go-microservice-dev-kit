#!/bin/bash
. "./scripts/util.sh"

WEB_CLIENT_DIR="${FRAMEWORK_ROOT}/web-client"

lp-echo "Building React web client..."

# Check if web-client directory exists
if [ ! -d "$WEB_CLIENT_DIR" ]; then
    lp-error "Web client directory not found: $WEB_CLIENT_DIR"
    exit 1
fi

cd "$WEB_CLIENT_DIR"

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    lp-echo "Installing Node.js dependencies..."
    npm install
fi

# Generate protobuf types
lp-echo "Generating protobuf TypeScript types..."
npm run build --silent > /dev/null

# Build the React application
lp-echo "Building React application..."
npm run build --silent > /dev/null

lp-echo "Web client built successfully"