#!/usr/bin/env bash

# Source utilities (includes set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../util.sh"

lp-echo "Starting all services with docker-compose..."
docker-compose up -d
lp-success "Services started successfully"
