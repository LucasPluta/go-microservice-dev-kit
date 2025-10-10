# test.mk - Testing targets

.PHONY: test test-all

# Test everything (all services)
test: test-all
	@echo "✓ Tests complete!"

# Run tests for all services
test-all:
	@$(TEST_SCRIPTS_DIR)/test.sh
