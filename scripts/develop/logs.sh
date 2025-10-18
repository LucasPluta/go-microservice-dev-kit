#!/bin/bash
. "./scripts/util.sh"

SERVICE="${1:-}"

if [ -n "$SERVICE" ]; then
    lp-echo "Viewing logs for service: ${SERVICE}"
    docker-compose logs -f "$SERVICE"
else
    lp-echo "Viewing logs for all services"
    docker-compose logs -f
fi
