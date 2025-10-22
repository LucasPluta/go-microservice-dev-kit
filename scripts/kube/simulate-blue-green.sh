#!/bin/bash
. "./scripts/util.sh"

# -----------------------------
# Functions
# -----------------------------
cleanup() {
  lp-echo "🧹 Cleaning up..."

  kubectl delete deployment myapp-blue || :
  kubectl delete deployment myapp-green || :
  kubectl delete service myapp-service || :
  # Kill any background port-forward processes
  pkill -f "kubectl port-forward service/myapp-service" 2>/dev/null  || :
  minikube stop  || :

  lp-echo "✅ Cleanup complete!"
}

# Trap SIGINT (Ctrl+C) and run cleanup
trap cleanup SIGINT SIGTERM EXIT

# -----------------------------
# Main Script
# -----------------------------
lp-echo "🚀 Starting minikube..."
minikube start

lp-echo "🟦 Deploying BLUE version (nginx)..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-blue
  labels:
    app: myapp
    version: blue
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: myapp
        image: nginx:1.21
        ports:
        - containerPort: 80
EOF

lp-echo "🌐 Creating Service..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
    version: blue
  ports:
    - port: 80
      targetPort: 80
  type: NodePort
EOF

sleep 3

lp-echo "🔹 Starting port-forward for BLUE..."
kubectl port-forward service/myapp-service 8080:80 &
PF_BLUE=$!

sleep 3

echo "curl http://localhost:8080 (BLUE)"
curl -s http://localhost:8080 | head -n 5
kill $PF_BLUE

lp-echo "🟩 Deploying GREEN version (httpd)..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
  labels:
    app: myapp
    version: green
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: myapp
        image: httpd:2.4
        ports:
        - containerPort: 80
EOF

lp-echo "🔹 Testing GREEN directly..."
# Wait for the pod to be ready
kubectl wait --for=condition=ready pod -l version=green --timeout=60s

sleep 3

GREEN_POD=$(kubectl get pods -l version=green -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $GREEN_POD 8081:80 &
PF_GREEN=$!

sleep 3

lp-echo "curl http://localhost:8081 (GREEN)"
curl -s http://localhost:8081 | head -n 5
kill $PF_GREEN

lp-echo "🔄 Switching Service traffic to GREEN..."
kubectl patch service myapp-service -p '{"spec":{"selector":{"app":"myapp","version":"green"}}}'

sleep 3

lp-echo "🔹 Testing GREEN via Service..."
kubectl port-forward service/myapp-service 8080:80 &
PF_GREEN_SVC=$!

sleep 3


curl -s http://localhost:8080 | head -n 5
kill $PF_GREEN_SVC

lp-echo "⏪ Rolling back to BLUE..."
kubectl patch service myapp-service -p '{"spec":{"selector":{"app":"myapp","version":"blue"}}}'

sleep 3

lp-echo "🔹 Testing BLUE via Service..."
kubectl port-forward service/myapp-service 8080:80 &
PF_BLUE_SVC=$!
sleep 2
curl -s http://localhost:8080 | head -n 5
kill $PF_BLUE_SVC