#!/bin/bash
. "./scripts/util.sh"

ci-make test-services
ci-make test-web-client