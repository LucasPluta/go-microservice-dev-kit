#!/bin/bash
. "./scripts/util.sh"

lp-echo "Stopping all services with docker-compose..."
docker compose down
lp-success "Services stopped successfully"
