#!/bin/bash

# Deploy DevOps API to Minikube
echo "🚀 Deploying DevOps API to Minikube..."
echo "======================================"

# Check if Minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube is not installed!"
    echo "Please install Minikube: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed!"
    exit 1
fi

# Start Minikube if not running
echo "🔧 Checking Minikube status..."
if ! minikube status | grep -q "Running"; then
    echo "Starting Minikube..."
    minikube start --driver=docker --cpus=2 --memory=4096
else
    echo "✅ Minikube is already running"
fi

# Use Minikube's Docker daemon
echo "🐳 Setting up Docker with Minikube..."
eval $(minikube docker-env)

# Build Docker image
echo "📦 Building Docker image..."
docker build -t devops-api:latest .

# Apply Kubernetes manifests
echo "⚙️  Applying Kubernetes manifests..."

# Create namespace
kubectl apply -f k8s/namespace.yaml

# Apply ConfigMap
kubectl apply -f k8s/configmap.yaml

# Apply Deployment
kubectl apply -f k8s/deployment.yaml

# Apply Service
kubectl apply -f k8s/service.yaml

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/devops-api -n devops-api --timeout=120s

# Show deployment info
echo ""
echo "📊 DEPLOYMENT STATUS"
echo "==================="

echo "🔍 Namespace:"
kubectl get namespace devops-api

echo ""
echo "📦 Pods:"
kubectl get pods -n devops-api -o wide

echo ""
echo "🔄 Deployment:"
kubectl get deployment -n devops-api

echo ""
echo "🌐 Services:"
kubectl get services -n devops-api

echo ""
echo "🚪 ACCESSING THE API"
echo "==================="

# Get service URL
echo "1. Using port-forward (local access):"
echo "   kubectl port-forward -n devops-api service/devops-api-service 8080:80"
echo "   Then visit: http://localhost:8080"
echo "   Docs: http://localhost:8080/docs"

echo ""
echo "2. Using Minikube LoadBalancer:"
SERVICE_URL=$(minikube service -n devops-api devops-api-loadbalancer --url)
echo "   API URL: $SERVICE_URL"
echo "   Health: $SERVICE_URL/health"
echo "   Metrics: $SERVICE_URL/metrics"

echo ""
echo "🔧 USEFUL COMMANDS:"
echo "   View logs: kubectl logs -n devops-api -l app=devops-api"
echo "   Check events: kubectl get events -n devops-api"
echo "   Scale up: kubectl scale -n devops-api deployment/devops-api --replicas=3"
echo "   Delete: kubectl delete -f k8s/"

echo ""
echo "✅ DEPLOYMENT COMPLETE!"