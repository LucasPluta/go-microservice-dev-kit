#!/bin/bash
. "./scripts/util.sh"

ci-make setup
ci-make build
ci-make test