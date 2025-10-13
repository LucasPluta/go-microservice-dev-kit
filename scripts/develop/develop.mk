# develop.mk - Development and maintenance targets

.PHONY: up down logs create-service clean clean-all

# Start all services with docker-compose
up:
	@$(DEVELOP_SCRIPTS_DIR)/up.sh

# Stop all services
down:
	@$(DEVELOP_SCRIPTS_DIR)/down.sh

# View logs from services
logs:
	@$(DEVELOP_SCRIPTS_DIR)/logs.sh $(SERVICE)

# Create a new service
create-service:
	@$(DEVELOP_SCRIPTS_DIR)/create-service.sh $(SERVICE) $(OPTS)

# Clean all build artifacts
clean:
	@$(DEVELOP_SCRIPTS_DIR)/clean.sh

# Clean all artifacts including Go toolchain
clean-all:
	@$(DEVELOP_SCRIPTS_DIR)/clean-all.sh
