# test.mk - Testing targets

TEST_SCRIPTS := $(SCRIPTS_DIR)/test

.PHONY: test test-all

# Test everything (all services)
test: test-all
	@echo "✓ Tests complete!"

# Run tests for all services
test-all:
	@$(TEST_SCRIPTS)/test.sh
