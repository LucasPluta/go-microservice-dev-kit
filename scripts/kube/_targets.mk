# kube.mk - Kubernetes deployment and management targets

.PHONY: simulate-blue-green

KUBE_SCRIPTS_DIR=$(SCRIPTS_DIR)/kube

simulate-blue-green:
	@$(KUBE_SCRIPTS_DIR)/simulate-blue-green.sh
