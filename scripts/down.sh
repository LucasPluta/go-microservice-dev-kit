#!/usr/bin/env bash
set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/util.sh"

lp-echo "Stopping all services with docker-compose..."
docker-compose down
lp-success "Services stopped successfully"
