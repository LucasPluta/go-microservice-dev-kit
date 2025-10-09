.PHONY: help build build-service build-all-services docker-build docker-build-multiarch test proto clean up down logs create-service install-tools

# Default service name if not specified
SERVICE ?= example-service

# Default platforms for multi-arch builds
PLATFORMS ?= linux/amd64,linux/arm64

# Docker registry (override with your registry)
REGISTRY ?= localhost:5000

help:
	@echo "GoMicroserviceFramework - Available commands:"
	@echo ""
	@echo "  make up                      - Start all services with docker-compose"
	@echo "  make down                    - Stop all services"
	@echo "  make logs [SERVICE=name]     - View logs from services"
	@echo "  make clean                   - Clean all build artifacts"
	@echo "  make test                    - Run tests for all services"
	@echo ""
	@echo "Build commands:"
	@echo "  make build [SERVICE=name]         - Build a specific service binary"
	@echo "  make build-all-services           - Build all service binaries"
	@echo "  make docker-build SERVICE=name    - Build Docker image for a service"
	@echo "  make docker-build-multiarch SERVICE=name - Build multi-arch Docker image"
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

up:
	docker-compose up -d

down:
	docker-compose down

logs:
ifdef SERVICE
	docker-compose logs -f $(SERVICE)
else
	docker-compose logs -f
endif

clean:
	@echo "Cleaning build artifacts..."
	@find services -type f -name "*.pb.go" -delete
	@find services -type d -name "bin" -exec rm -rf {} + 2>/dev/null || true
	@rm -rf bin/
	@echo "Clean complete"

# Generate protobuf code for a specific service
proto:
ifndef SERVICE
	@echo "Error: SERVICE name is required"
	@echo "Usage: make proto SERVICE=service-name"
	@exit 1
endif
	@echo "Generating protobuf code for $(SERVICE)..."
	@if [ ! -d "services/$(SERVICE)" ]; then \
		echo "Error: Service '$(SERVICE)' not found"; \
		exit 1; \
	fi
	@cd services/$(SERVICE) && \
		protoc --go_out=. --go_opt=paths=source_relative \
			--go-grpc_out=. --go-grpc_opt=paths=source_relative \
			proto/$(SERVICE).proto
	@echo "Protobuf code generated successfully"

# Build a single service binary
build:
ifndef SERVICE
	@echo "Error: SERVICE name is required"
	@echo "Usage: make build SERVICE=service-name"
	@exit 1
endif
	@echo "Building $(SERVICE)..."
	@if [ ! -d "services/$(SERVICE)" ]; then \
		echo "Error: Service '$(SERVICE)' not found"; \
		exit 1; \
	fi
	@mkdir -p bin
	@cd services/$(SERVICE) && \
		go build -o ../../bin/$(SERVICE) ./cmd/main.go
	@echo "Built: bin/$(SERVICE)"

# Build all service binaries
build-all-services:
	@echo "Building all services..."
	@for dir in services/*; do \
		if [ -d "$$dir" ] && [ -f "$$dir/go.mod" ]; then \
			service=$$(basename $$dir); \
			echo "Building $$service..."; \
			$(MAKE) build SERVICE=$$service || exit 1; \
		fi \
	done
	@echo "All services built successfully"

# Build Docker image for a specific service
docker-build:
ifndef SERVICE
	@echo "Error: SERVICE name is required"
	@echo "Usage: make docker-build SERVICE=service-name"
	@exit 1
endif
	@echo "Building Docker image for $(SERVICE)..."
	@if [ ! -d "services/$(SERVICE)" ]; then \
		echo "Error: Service '$(SERVICE)' not found"; \
		exit 1; \
	fi
	docker build --build-arg SERVICE_NAME=$(SERVICE) \
		-t $(SERVICE):latest \
		-f Dockerfile .
	@echo "Docker image built: $(SERVICE):latest"

# Build multi-architecture Docker image for a specific service
docker-build-multiarch:
ifndef SERVICE
	@echo "Error: SERVICE name is required"
	@echo "Usage: make docker-build-multiarch SERVICE=service-name [REGISTRY=registry] [PLATFORMS=linux/amd64,linux/arm64]"
	@exit 1
endif
	@echo "Building multi-arch Docker image for $(SERVICE)..."
	@echo "Platforms: $(PLATFORMS)"
	@echo "Registry: $(REGISTRY)"
	@if [ ! -d "services/$(SERVICE)" ]; then \
		echo "Error: Service '$(SERVICE)' not found"; \
		exit 1; \
	fi
	docker buildx build --platform $(PLATFORMS) \
		--build-arg SERVICE_NAME=$(SERVICE) \
		-t $(REGISTRY)/$(SERVICE):latest \
		--push \
		-f Dockerfile .
	@echo "Multi-arch Docker image built and pushed: $(REGISTRY)/$(SERVICE):latest"

# Run tests for all services
test:
	@echo "Running tests for all services..."
	@for dir in services/*; do \
		if [ -d "$$dir" ] && [ -f "$$dir/go.mod" ]; then \
			echo "Testing $$(basename $$dir)..."; \
			(cd "$$dir" && go test -v ./... || exit 1); \
		fi \
	done
	@echo "Tests complete"

# Create a new service
create-service:
ifndef SERVICE
	@echo "Error: SERVICE name is required"
	@echo "Usage: make create-service SERVICE=service-name OPTS='--postgres --redis --nats'"
	@exit 1
endif
	./scripts/create-service.sh $(SERVICE) $(OPTS)

# Install development tools
install-tools:
	@echo "Installing required tools..."
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	@echo "Tools installed successfully"
