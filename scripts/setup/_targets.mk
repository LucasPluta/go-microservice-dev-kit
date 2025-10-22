# setup.mk - Setup and installation targets

.PHONY: setup setup-go setup-protoc install-tools setup-tls generate-certs

SETUP_SCRIPTS_DIR=$(SCRIPTS_DIR)/setup

# Setup everything (Go toolchain, protoc, and development tools)
setup:
	@$(SETUP_SCRIPTS_DIR)/setup.sh

# Download and setup Go toolchain from go.mod
setup-go:
	@$(SETUP_SCRIPTS_DIR)/setup-go.sh

# Download and setup protoc compiler
setup-protoc:
	@$(SETUP_SCRIPTS_DIR)/setup-protoc.sh

# Install required development tools (protoc plugins)
install-tools:
	@$(SETUP_SCRIPTS_DIR)/install-tools.sh

# Generate TLS certificates for development
generate-certs:
	@$(SETUP_SCRIPTS_DIR)/generate-certs.sh