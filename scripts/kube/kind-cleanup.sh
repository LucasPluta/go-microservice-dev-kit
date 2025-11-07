#!/bin/bash

# kind-cleanup.sh
# Cleanup script for Kind cluster deployment

. "./scripts/util.sh"

# Configuration
CLUSTER_NAME="gomicroservice-framework"
REGISTRY_NAME="kind-registry"
HELM_RELEASE_NAME="gomicroservice"

lp-echo "Cleaning up Kind cluster deployment..."

# Remove Helm release
if helm list | grep -q "${HELM_RELEASE_NAME}"; then
    lp-echo "Removing Helm release '${HELM_RELEASE_NAME}'..."
    helm uninstall "${HELM_RELEASE_NAME}" || true
    lp-success "Helm release removed"
else
    lp-echo "Helm release '${HELM_RELEASE_NAME}' not found"
fi

# Delete Kind cluster
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    lp-echo "Deleting Kind cluster '${CLUSTER_NAME}'..."
    kind delete cluster --name "${CLUSTER_NAME}"
    lp-success "Kind cluster deleted"
else
    lp-echo "Kind cluster '${CLUSTER_NAME}' not found"
fi

# Remove local registry
if docker ps -a --format 'table {{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
    lp-echo "Removing local registry '${REGISTRY_NAME}'..."
    docker stop "${REGISTRY_NAME}" || true
    docker rm "${REGISTRY_NAME}" || true
    lp-success "Local registry removed"
else
    lp-echo "Local registry '${REGISTRY_NAME}' not found"
fi

# Clean up local images (optional)
read -p "Do you want to remove local Docker images? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    lp-echo "Removing local Docker images..."
    docker rmi localhost:5001/example-service:latest 2>/dev/null || true
    docker rmi localhost:5001/health-service:latest 2>/dev/null || true
    docker rmi localhost:5001/user-service:latest 2>/dev/null || true
    docker rmi localhost:5001/web-client:latest 2>/dev/null || true
    lp-success "Local images removed"
fi

lp-success "Cleanup completed!"