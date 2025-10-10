# setup.mk - Setup and installation targets

.PHONY: setup setup-go setup-protoc install-tools

# Setup everything (Go toolchain, protoc, and development tools)
setup: setup-go setup-protoc install-tools
	@echo "✓ Setup complete! Framework is ready to use."

# Download and setup Go toolchain from go.mod
setup-go:
	@$(SCRIPTS_DIR)/setup-go.sh

# Download and setup protoc compiler
setup-protoc:
	@$(SCRIPTS_DIR)/setup-protoc.sh

# Install required development tools (protoc plugins)
install-tools:
	@$(SCRIPTS_DIR)/install-tools.sh
