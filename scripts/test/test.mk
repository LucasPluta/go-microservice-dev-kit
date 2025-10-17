# test.mk - Testing targets

.PHONY: test test-all test-web-client

# Test all
test:
	@$(TEST_SCRIPTS_DIR)/test.sh

# Test (all services)
test-services:
	@$(TEST_SCRIPTS_DIR)/test-services.sh

# Test web client setup
test-web-client:
	@$(TEST_SCRIPTS_DIR)/test-web-client.sh
