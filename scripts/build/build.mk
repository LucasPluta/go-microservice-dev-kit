# build.mk - Build and compilation targets

.PHONY: build build-service build-all-services build-multiarch docker-build docker-build-multiarch proto proto-all

# Build everything (all services for all architectures)
build:
	@make proto-all
	@make build-all-services

# Generate protobuf code for all services
proto-all:
	@$(BUILD_SCRIPTS_DIR)/proto-all.sh

# Generate protobuf code for a specific service
proto:
	@$(BUILD_SCRIPTS_DIR)/proto.sh $(SERVICE)

# Build a specific service binary for current platform
build-service:
	@$(BUILD_SCRIPTS_DIR)/build.sh $(SERVICE)

# Build service binaries for linux/amd64 and linux/arm64
build-multiarch:
	@$(BUILD_SCRIPTS_DIR)/build-multiarch.sh $(SERVICE)

# Build all service binaries
build-all-services:
	@$(BUILD_SCRIPTS_DIR)/build-all-services.sh

# Build Docker image for a service (uses pre-built binary)
docker-build:
	@$(BUILD_SCRIPTS_DIR)/docker-build.sh $(SERVICE)

# Build and push multi-arch Docker images
docker-build-multiarch:
	@$(BUILD_SCRIPTS_DIR)/docker-build-multiarch.sh $(SERVICE) $(REGISTRY)
