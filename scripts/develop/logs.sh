#!/usr/bin/env bash

# Source utilities (includes set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../util.sh"

SERVICE="${1:-}"

if [ -n "$SERVICE" ]; then
    lp-echo "Viewing logs for service: ${SERVICE}"
    docker-compose logs -f "$SERVICE"
else
    lp-echo "Viewing logs for all services"
    docker-compose logs -f
fi
