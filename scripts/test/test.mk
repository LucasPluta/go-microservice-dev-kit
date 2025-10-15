# test.mk - Testing targets

.PHONY: test test-all test-web-client

# Test everything (all services)
test:
	@make test-all

# Run tests for all services
test-all:
	@$(TEST_SCRIPTS_DIR)/test.sh

# Test web client setup
test-web-client:
	@$(TEST_SCRIPTS_DIR)/test-web-client.sh
