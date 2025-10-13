# setup.mk - Setup and installation targets

.PHONY: setup setup-go setup-protoc install-tools

# Setup everything (Go toolchain, protoc, and development tools)
setup:
	@make setup-go
	@make setup-protoc
	@make install-tools

# Download and setup Go toolchain from go.mod
setup-go:
	@$(SETUP_SCRIPTS_DIR)/setup-go.sh

# Download and setup protoc compiler
setup-protoc:
	@$(SETUP_SCRIPTS_DIR)/setup-protoc.sh

# Install required development tools (protoc plugins)
install-tools:
	@$(SETUP_SCRIPTS_DIR)/install-tools.sh
