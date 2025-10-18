#!/bin/bash
. "./scripts/util.sh"

# Script to download and setup protoc toolchain
# Supports: Linux and macOS on amd64 and arm64
# Usage: setup-protoc.sh [--quiet]
#   --quiet: Skip output if protoc is already installed

ci-make setup-go
ci-make setup-protoc
ci-make install-tools
ci-make generate-certs