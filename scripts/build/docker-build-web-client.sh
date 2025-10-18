#!/bin/bash
. "./scripts/util.sh"

cd "$FRAMEWORK_ROOT"
SHA=$(docker build -q \
    -f Dockerfile.web \
    --build-arg TARGETOS=linux \
    -t "web-client:latest" \
    -f Dockerfile.web .)

lp-echo "Built: web-client:latest - SHA: $SHA"