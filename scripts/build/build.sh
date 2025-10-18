#!/bin/bash
. "./scripts/util.sh"

ci-make proto-all
ci-make build-all-services-multiarch
ci-make build-web-client
ci-make docker-build-all
ci-make docker-build-web-client