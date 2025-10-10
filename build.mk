# build.mk - Build and compilation targets

.PHONY: build build-service build-all-services build-multiarch docker-build docker-build-multiarch proto

# Build everything (all services for all architectures)
build: proto build-all-services
	@echo "✓ Build complete! All services compiled."

# Generate protobuf code for a service
proto:
	@$(SCRIPTS_DIR)/proto.sh $(SERVICE)

# Build a specific service binary for current platform
build-service:
	@$(SCRIPTS_DIR)/build.sh $(SERVICE)

# Build service binaries for linux/amd64 and linux/arm64
build-multiarch:
	@$(SCRIPTS_DIR)/build-multiarch.sh $(SERVICE)

# Build all service binaries
build-all-services:
	@$(SCRIPTS_DIR)/build-all-services.sh

# Build Docker image for a service (uses pre-built binary)
docker-build:
	@$(SCRIPTS_DIR)/docker-build.sh $(SERVICE)

# Build and push multi-arch Docker images
docker-build-multiarch:
	@$(SCRIPTS_DIR)/docker-build-multiarch.sh $(SERVICE) $(REGISTRY)
