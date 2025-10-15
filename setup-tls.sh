#!/bin/bash
set -euo pipefail

# Script to set up TLS and rebuild services with TLS enabled

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source utilities
source "$SCRIPT_DIR/scripts/util.sh"

cd "$PROJECT_ROOT"

lp-echo "Setting up TLS for GoMicroserviceFramework..."
echo ""

# Step 1: Generate certificates
if [ ! -d "certs" ] || [ ! -f "certs/server-cert.pem" ]; then
    lp-echo "Step 1: Generating TLS certificates..."
    ./scripts/setup/generate-certs.sh
else
    lp-echo "Step 1: Certificates already exist, skipping generation"
    echo "  (Delete 'certs' directory to regenerate)"
fi

echo ""

# Step 2: Build services
lp-echo "Step 2: Building services with TLS support..."
make build

echo ""

# Step 3: Build Docker images
lp-echo "Step 3: Building Docker images..."
docker-compose build

echo ""

# Step 4: Start services
lp-echo "Step 4: Starting services with TLS enabled..."
docker-compose down 2>/dev/null || true
docker-compose up -d

echo ""

# Step 5: Wait for services to start
lp-echo "Step 5: Waiting for services to start..."
sleep 5

echo ""

# Step 6: Verify TLS is working
lp-echo "Step 6: Verifying TLS connections..."

# Check if grpcurl is available
if ! command -v grpcurl &> /dev/null; then
    lp-error "grpcurl not found. Install it to test gRPC connections:"
    echo "  brew install grpcurl"
    echo ""
else
    echo "Testing gRPC service with TLS..."
    if grpcurl -cacert certs/ca-cert.pem \
        -d '{"service_id": "test"}' \
        localhost:50051 \
        exampleservice.ExampleServiceService/GetStatus 2>&1 | grep -q "status"; then
        lp-success "✓ gRPC service TLS working"
    else
        lp-error "✗ gRPC service TLS test failed"
    fi
fi

echo ""

# Check web client
echo "Testing web client HTTPS..."
if curl -k --silent --output /dev/null --head --fail https://localhost:8443; then
    lp-success "✓ Web client HTTPS working"
else
    lp-error "✗ Web client HTTPS test failed"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
lp-success "TLS setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Services are now running with TLS enabled:"
echo ""
echo "  🔐 gRPC Service:  grpc://localhost:50051 (TLS)"
echo "  🌐 Web Client:    https://localhost:8443"
echo "  📋 API Endpoint:  https://localhost:8443/api"
echo ""
echo "Next steps:"
echo ""
echo "  1. Trust the CA certificate on your system:"
echo ""
echo "     macOS:"
echo "       sudo security add-trusted-cert -d -r trustRoot \\"
echo "         -k /Library/Keychains/System.keychain $PROJECT_ROOT/certs/ca-cert.pem"
echo ""
echo "     Linux:"
echo "       sudo cp $PROJECT_ROOT/certs/ca-cert.pem \\"
echo "         /usr/local/share/ca-certificates/gomicroservices-ca.crt"
echo "       sudo update-ca-certificates"
echo ""
echo "  2. Import the CA certificate into your browser"
echo ""
echo "  3. Access the web client at https://localhost:8443"
echo ""
echo "  4. Test gRPC with grpcurl:"
echo "       grpcurl -cacert certs/ca-cert.pem \\"
echo "         -d '{\"service_id\": \"test\"}' \\"
echo "         localhost:50051 \\"
echo "         exampleservice.ExampleServiceService/GetStatus"
echo ""
echo "View logs with: make logs"
echo "Stop services with: make down"
echo ""
echo "⚠️  Note: Self-signed certificates are for DEVELOPMENT ONLY!"
echo "   Use trusted CA certificates in production."
echo ""
