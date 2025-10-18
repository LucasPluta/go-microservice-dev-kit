# develop.mk - Development and maintenance targets

.PHONY: up down logs dev-web-client create-service clean clean-all

# Start all services with docker-compose
up:
	@$(DEVELOP_SCRIPTS_DIR)/up.sh

# Stop all services
down:
	@$(DEVELOP_SCRIPTS_DIR)/down.sh

# View logs from services
logs:
	@$(DEVELOP_SCRIPTS_DIR)/logs.sh $(SERVICE)

# Start web client development server
dev-web-client:
	@$(DEVELOP_SCRIPTS_DIR)/dev-web-client.sh

# Create a new service
create-service:
	@$(DEVELOP_SCRIPTS_DIR)/create-service.sh $(SERVICE) $(OPTS)

# Clean all build artifacts
clean:
	@$(DEVELOP_SCRIPTS_DIR)/clean.sh

# Clean all artifacts including Go toolchain, and docker images
clean-all:
	@$(DEVELOP_SCRIPTS_DIR)/clean-all.sh
	@make docker-clean

docker-clean:
	@docker system prune -a --volumes --force && docker network prune --force
