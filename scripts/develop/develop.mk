# develop.mk - Development and maintenance targets

DEVELOP_SCRIPTS := $(SCRIPTS_DIR)/develop

.PHONY: up down logs create-service clean clean-all

# Start all services with docker-compose
up:
	@$(DEVELOP_SCRIPTS)/up.sh

# Stop all services
down:
	@$(DEVELOP_SCRIPTS)/down.sh

# View logs from services
logs:
	@$(DEVELOP_SCRIPTS)/logs.sh $(SERVICE)

# Create a new service
create-service:
	@$(DEVELOP_SCRIPTS)/create-service.sh $(SERVICE) $(OPTS)

# Clean all build artifacts
clean:
	@$(DEVELOP_SCRIPTS)/clean.sh

# Clean all artifacts including Go toolchain
clean-all:
	@$(DEVELOP_SCRIPTS)/clean-all.sh
