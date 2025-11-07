#!/bin/bash

# kind-setup.sh
# Setup Kind cluster with local registry for GoMicroserviceFramework

. "./scripts/util.sh"

# Configuration
CLUSTER_NAME="gomicroservice-framework"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"

lp-echo "Setting up Kind cluster for GoMicroserviceFramework"

# Check prerequisites
lp-echo "Checking prerequisites..."

if ! command_exists kind; then
    lp-error "Kind is not installed. Please install Kind first: https://kind.sigs.k8s.io/docs/user/quick-start/"
    exit 1
fi

if ! command_exists kubectl; then
    lp-error "kubectl is not installed. Please install kubectl first"
    exit 1
fi

if ! command_exists docker; then
    lp-error "Docker is not installed. Please install Docker first"
    exit 1
fi

lp-success "All prerequisites are installed"

# Create Kind cluster if it doesn't exist
lp-echo "Setting up Kind cluster..."

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    lp-echo "Kind cluster '${CLUSTER_NAME}' already exists"
else
    lp-echo "Creating Kind cluster '${CLUSTER_NAME}'..."
    
    # Create cluster config with port mappings for web client
    cat <<EOF > /tmp/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
    protocol: TCP
  - containerPort: 30443
    hostPort: 8443
    protocol: TCP
  - containerPort: 30051
    hostPort: 50051
    protocol: TCP
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:5000"]
EOF

    kind create cluster --name "${CLUSTER_NAME}" --config /tmp/kind-config.yaml
    rm /tmp/kind-config.yaml
    lp-success "Kind cluster created"
fi

# Setup local registry
lp-echo "Setting up local Docker registry..."

if docker ps --format 'table {{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
    lp-echo "Local registry '${REGISTRY_NAME}' already running"
else
    lp-echo "Creating local registry '${REGISTRY_NAME}'..."
    docker run -d --restart=always -p "127.0.0.1:${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" registry:2
    
    # Connect the registry to the cluster network if not already connected
    if ! docker network ls | grep -q "kind"; then
        docker network create kind || true
    fi
    docker network connect "kind" "${REGISTRY_NAME}" || true
    
    lp-success "Local registry created and connected"
fi

lp-success "Kind cluster setup completed!"
lp-echo ""
lp-echo "Cluster: ${CLUSTER_NAME}"
lp-echo "Registry: localhost:${REGISTRY_PORT}"
lp-echo ""
lp-echo "Next steps:"
lp-echo "  1. Run: ./scripts/kube/kind-deploy.sh"
lp-echo "  2. Or manually: helm install gomicroservice ./helm-chart/"