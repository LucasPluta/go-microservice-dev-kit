#!/bin/bash
. "./scripts/util.sh"

lp-echo "Starting all services with docker-compose..."
docker compose up -d
lp-success "Services started successfully"
