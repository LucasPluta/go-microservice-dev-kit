# setup.mk - Setup and installation targets

SETUP_SCRIPTS := $(SCRIPTS_DIR)/setup

.PHONY: setup setup-go setup-protoc install-tools

# Setup everything (Go toolchain, protoc, and development tools)
setup: setup-go setup-protoc install-tools
	@echo "✓ Setup complete! Framework is ready to use."

# Download and setup Go toolchain from go.mod
setup-go:
	@$(SETUP_SCRIPTS)/setup-go.sh

# Download and setup protoc compiler
setup-protoc:
	@$(SETUP_SCRIPTS)/setup-protoc.sh

# Install required development tools (protoc plugins)
install-tools:
	@$(SETUP_SCRIPTS)/install-tools.sh
