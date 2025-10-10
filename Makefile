.PHONY: help build build-service build-all-services build-multiarch docker-build docker-build-multiarch test proto clean clean-all up down logs create-service install-tools setup-go

# Default service name if not specified
SERVICE=example-service

# Docker registry (override with your registry)
REGISTRY=localhost:5000

# Scripts directory
SCRIPTS_DIR=$(PWD)/scripts

# Add .gobincache to the PATH
PATH:=$(PWD)/.gobincache:$(PWD)/.gobincache:$(PATH)

PROTOC_VERSION=31.1

help:
	@echo "GoMicroserviceFramework - Available commands:"
	@echo ""
	@echo "  make setup-go                - Download and setup Go toolchain from go.mod"
	@echo "  make up                      - Start all services with docker-compose"
	@echo "  make down                    - Stop all services"
	@echo "  make logs [SERVICE=name]     - View logs from services"
	@echo "  make clean                   - Clean all build artifacts"
	@echo "  make clean-all               - Clean all artifacts including Go toolchain"
	@echo "  make test                    - Run tests for all services"
	@echo ""
	@echo "Build commands:"
	@echo "  make build [SERVICE=name]         - Build a specific service binary"
	@echo "  make build-multiarch SERVICE=name - Build service for linux/amd64 and linux/arm64"
	@echo "  make build-all-services           - Build all service binaries"
	@echo "  make docker-build SERVICE=name    - Build Docker image for a service"
	@echo "  make docker-build-multiarch SERVICE=name - Build multi-arch Docker images"
	@echo "  make proto [SERVICE=name]         - Generate protobuf code for a service"
	@echo ""
	@echo "Service management:"
	@echo "  make create-service SERVICE=name OPTS='--postgres --redis --nats'"
	@echo "  make install-tools               - Install required development tools"
	@echo ""
	@echo "Examples:"
	@echo "  make build SERVICE=user-service"
	@echo "  make docker-build SERVICE=payment-service"
	@echo "  make docker-build-multiarch SERVICE=order-service REGISTRY=myregistry.io"
	@echo "  make proto SERVICE=notification-service"
	@echo "  make create-service SERVICE=auth-service OPTS='--postgres --redis'"

setup-go:
	@$(SCRIPTS_DIR)/setup-go.sh

setup-protoc:
	@$(SCRIPTS_DIR)/setup-protoc.sh

up:
	@$(SCRIPTS_DIR)/up.sh

down:
	@$(SCRIPTS_DIR)/down.sh

logs:
	@$(SCRIPTS_DIR)/logs.sh $(SERVICE)

clean:
	@$(SCRIPTS_DIR)/clean.sh

clean-all:
	@$(SCRIPTS_DIR)/clean-all.sh

proto:
	@$(SCRIPTS_DIR)/proto.sh $(SERVICE)

build:
	@$(SCRIPTS_DIR)/build.sh $(SERVICE)

build-multiarch:
	@$(SCRIPTS_DIR)/build-multiarch.sh $(SERVICE)

build-all-services:
	@$(SCRIPTS_DIR)/build-all-services.sh

docker-build:
	@$(SCRIPTS_DIR)/docker-build.sh $(SERVICE)

docker-build-multiarch:
	@$(SCRIPTS_DIR)/docker-build-multiarch.sh $(SERVICE) $(REGISTRY)

test:
	@$(SCRIPTS_DIR)/test.sh

create-service:
	@$(SCRIPTS_DIR)/create-service.sh $(SERVICE) $(OPTS)

install-tools:
	@$(SCRIPTS_DIR)/install-tools.sh

export

env:
	printenv