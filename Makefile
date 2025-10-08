.PHONY: help build test clean up down logs

help:
	@echo "GoMicroserviceFramework - Available commands:"
	@echo ""
	@echo "  make up              - Start all services with docker-compose"
	@echo "  make down            - Stop all services"
	@echo "  make logs            - View logs from all services"
	@echo "  make clean           - Clean all build artifacts"
	@echo "  make test            - Run tests for all services"
	@echo "  make build           - Build all services"
	@echo "  make create-service  - Create a new service (use SERVICE=name)"
	@echo ""
	@echo "Examples:"
	@echo "  make create-service SERVICE=user-service OPTS='--postgres --redis'"
	@echo "  make up"
	@echo "  make logs SERVICE=example-service"

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
	@echo "Clean complete"

build:
	@echo "Building all services..."
	@for dir in services/*; do \
		if [ -d "$$dir" ] && [ -f "$$dir/Makefile" ]; then \
			echo "Building $$(basename $$dir)..."; \
			(cd "$$dir" && make build) || exit 1; \
		fi \
	done
	@echo "Build complete"

test:
	@echo "Running tests for all services..."
	@for dir in services/*; do \
		if [ -d "$$dir" ] && [ -f "$$dir/go.mod" ]; then \
			echo "Testing $$(basename $$dir)..."; \
			(cd "$$dir" && go test -v ./... || exit 1); \
		fi \
	done
	@echo "Tests complete"

create-service:
ifndef SERVICE
	@echo "Error: SERVICE name is required"
	@echo "Usage: make create-service SERVICE=service-name OPTS='--postgres --redis --nats'"
	@exit 1
endif
	./scripts/create-service.sh $(SERVICE) $(OPTS)

install-tools:
	@echo "Installing required tools..."
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	@echo "Tools installed successfully"
