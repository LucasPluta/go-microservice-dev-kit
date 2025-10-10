# develop.mk - Development and maintenance targets

.PHONY: up down logs create-service clean clean-all

# Start all services with docker-compose
up:
	@$(SCRIPTS_DIR)/up.sh

# Stop all services
down:
	@$(SCRIPTS_DIR)/down.sh

# View logs from services
logs:
	@$(SCRIPTS_DIR)/logs.sh $(SERVICE)

# Create a new service
create-service:
	@$(SCRIPTS_DIR)/create-service.sh $(SERVICE) $(OPTS)

# Clean all build artifacts
clean:
	@$(SCRIPTS_DIR)/clean.sh

# Clean all artifacts including Go toolchain
clean-all:
	@$(SCRIPTS_DIR)/clean-all.sh
