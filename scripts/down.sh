#!/usr/bin/env bash

# Source utilities (includes set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/util.sh"

lp-echo "Stopping all services with docker-compose..."
docker-compose down
lp-success "Services stopped successfully"
