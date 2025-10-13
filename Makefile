# GoMicroserviceFramework - Master Makefile
# This file imports modular makefiles for better organization

.PHONY: help all env

SHELL := /bin/bash

# Set the default target to be "help" if no target is specified
.DEFAULT_GOAL := help

# Default service name if not specified
SERVICE=example-service

# Docker registry (override with your registry)
REGISTRY=localhost:5000

# Scripts directory
SCRIPTS_DIR=$(PWD)/scripts
SETUP_SCRIPTS_DIR=$(SCRIPTS_DIR)/setup
BUILD_SCRIPTS_DIR=$(SCRIPTS_DIR)/build
TEST_SCRIPTS_DIR=$(SCRIPTS_DIR)/test
DEVELOP_SCRIPTS_DIR=$(SCRIPTS_DIR)/develop

# Add .gobincache to the PATH
PATH:=$(PWD)/.gobincache:$(PWD)/.gobincache:$(PATH)

PROTOC_VERSION=31.1

QUIET_MODE=true

# Export all variables to sub-makefiles
export

# Import modular makefiles from organized subdirectories
include scripts/setup/setup.mk
include scripts/build/build.mk
include scripts/test/test.mk
include scripts/develop/develop.mk

# Default target
all: 
	@make setup
	@make build
	@make test

# Help menu
help:
	@echo "GoMicroserviceFramework - Available commands:"
	@echo ""
	@echo "High-level commands:"
	@echo "  make all                     - Setup, build, and test everything"
	@echo "  make setup                   - Setup Go toolchain, protoc, and tools"
	@echo "  make build                   - Build all services with proto generation"
	@echo "  make test                    - Run tests for all services"
	@echo ""
	@echo "Setup commands (setup.mk):"
	@echo "  make setup-go                - Download and setup Go toolchain from go.mod"
	@echo "  make setup-protoc            - Download and setup protoc compiler"
	@echo "  make install-tools           - Install required development tools"
	@echo ""
	@echo "Build commands (build.mk):"
	@echo "  make build-service SERVICE=name    - Build a specific service binary"
	@echo "  make build-multiarch SERVICE=name  - Build service for linux/amd64 and linux/arm64"
	@echo "  make build-all-services            - Build all service binaries"
	@echo "  make docker-build SERVICE=name     - Build Docker image for a service"
	@echo "  make docker-build-multiarch SERVICE=name - Build multi-arch Docker images"
	@echo "  make proto SERVICE=name            - Generate protobuf code for a service"
	@echo "  make proto-all                     - Generate protobuf code for all services"
	@echo ""
	@echo "Test commands (test.mk):"
	@echo "  make test-all                - Run all tests"
	@echo ""
	@echo "Development commands (develop.mk):"
	@echo "  make up                      - Start all services with docker-compose"
	@echo "  make down                    - Stop all services"
	@echo "  make logs [SERVICE=name]     - View logs from services"
	@echo "  make create-service SERVICE=name OPTS='--postgres --redis --nats'"
	@echo "  make clean                   - Clean all build artifacts"
	@echo "  make clean-all               - Clean all artifacts including Go toolchain"
	@echo ""
	@echo "Examples:"
	@echo "  make all                                                      # Setup and build everything"
	@echo "  make setup                                                    # Setup toolchain and tools"
	@echo "  make build-service SERVICE=user-service                       # Build specific service"
	@echo "  make docker-build SERVICE=payment-service                     # Build Docker image"
	@echo "  make docker-build-multiarch SERVICE=order-service REGISTRY=myregistry.io"
	@echo "  make proto SERVICE=notification-service                       # Generate protobuf"
	@echo "  make create-service SERVICE=auth-service OPTS='--postgres --redis'"

# Environment inspection
env:
	$(load_env) printenv