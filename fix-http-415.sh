#!/usr/bin/env bash

# Quick fix script for HTTP 415 error
# This rebuilds services with Connect-RPC support

set -euo pipefail

echo "🔧 Fixing HTTP 415 Error - Rebuilding services with Connect-RPC support"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Step 1: Build services with system Go (framework Go version was updated)
echo "📦 Step 1/4: Building example-service..."
go build -o bin/example-service ./services/example-service/cmd/

# Step 2: Stop running containers
echo "🛑 Step 2/4: Stopping Docker containers..."
docker-compose down

# Step 3: Rebuild Docker images
echo "🐳 Step 3/4: Rebuilding Docker images..."
docker-compose build example-service web-client

# Step 4: Start everything
echo "🚀 Step 4/4: Starting all services..."
docker-compose up -d

# Wait a moment for services to start
echo ""
echo "⏳ Waiting for services to start..."
sleep 5

# Check if services are running
echo ""
echo "✅ Checking service status:"
docker-compose ps

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Done! Services are ready."
echo ""
echo "🌐 Open your browser: http://localhost:8080"
echo ""
echo "📋 Check logs:"
echo "   docker logs example-service  # Should show 'Dual-protocol server listening'"
echo "   docker logs web-client       # nginx access logs"
echo ""
echo "🧪 Test with curl:"
echo "   curl -X POST http://localhost:8080/api/exampleservice.ExampleServiceService/GetStatus \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -H 'connect-protocol-version: 1' \\"
echo "     -d '{\"serviceId\": \"test-123\"}'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"