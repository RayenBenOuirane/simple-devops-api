# Deploy DevOps API to Minikube (PowerShell)
Write-Host "[DEPLOY] DevOps API to Minikube" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Check if Minikube is installed
$minikube = Get-Command minikube -ErrorAction SilentlyContinue
if (-not $minikube) {
    Write-Host "[ERROR] Minikube is not installed!" -ForegroundColor Red
    Write-Host "Please install Minikube: https://minikube.sigs.k8s.io/docs/start/" -ForegroundColor Yellow
    exit 1
}

# Check if kubectl is installed
$kubectl = Get-Command kubectl -ErrorAction SilentlyContinue
if (-not $kubectl) {
    Write-Host "[ERROR] kubectl is not installed!" -ForegroundColor Red
    exit 1
}

# Start Minikube if not running
Write-Host "`n[*] Checking Minikube status..." -ForegroundColor Yellow
try {
    $minikubeStatus = minikube status 2>&1 | Out-String
    if ($minikubeStatus -match "Running") {
        Write-Host "[OK] Minikube is already running" -ForegroundColor Green
    } else {
        Write-Host "Starting Minikube..." -ForegroundColor Yellow
        minikube start --driver=docker --cpus=2 --memory=4096
    }
} catch {
    Write-Host "Starting Minikube (first time)..." -ForegroundColor Yellow
    minikube start --driver=docker --cpus=2 --memory=4096
}

# Build Docker image directly in Minikube
Write-Host "`n[*] Building Docker image in Minikube..." -ForegroundColor Yellow

# Method 1: Use minikube image build (preferred)
Write-Host "[*] Attempting to build with minikube image build..." -ForegroundColor Gray
$buildOutput = minikube image build -t devops-api:latest . 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Minikube image build failed. Trying alternative method..." -ForegroundColor Red
    Write-Host "Error: $buildOutput" -ForegroundColor Red
    
    # Method 2: Use Minikube's Docker daemon
    Write-Host "`n[*] Configuring Docker to use Minikube's daemon..." -ForegroundColor Yellow
    $envVars = minikube docker-env --shell powershell | Out-String
    # Parse and set environment variables
    $envVars -split "`n" | Where-Object { $_ -match '^\$Env:' } | ForEach-Object {
        Invoke-Expression $_
    }
    
    Write-Host "[*] Building image with Minikube's Docker daemon..." -ForegroundColor Yellow
    docker build -t devops-api:latest .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[ERROR] Docker build failed!" -ForegroundColor Red
        Write-Host "Please check your Dockerfile and try again." -ForegroundColor Red
        exit 1
    }
}

Write-Host "[OK] Image built successfully" -ForegroundColor Green

# Verify image exists
Write-Host "`n[*] Verifying image..." -ForegroundColor Yellow
$imageCheck = minikube image ls | Select-String "devops-api"
if ($imageCheck) {
    Write-Host "[OK] Image found in Minikube registry" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Image not found in registry!" -ForegroundColor Red
    exit 1
}

# Apply Kubernetes manifests
Write-Host "`n[*] Applying Kubernetes manifests..." -ForegroundColor Yellow

# Create namespace
kubectl apply -f k8s/namespace.yaml

# Apply ConfigMap
kubectl apply -f k8s/configmap.yaml

# Apply Deployment
kubectl apply -f k8s/deployment.yaml

# Apply Service
kubectl apply -f k8s/service.yaml

# Wait for deployment
Write-Host "`n[*] Waiting for deployment to be ready..." -ForegroundColor Yellow
kubectl rollout status deployment/devops-api -n devops-api --timeout=120s

# Show deployment info
Write-Host "`n📊 DEPLOYMENT STATUS" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

Write-Host "`n🔍 Namespace:" -ForegroundColor Yellow
kubectl get namespace devops-api

Write-Host "`n📦 Pods:" -ForegroundColor Yellow
kubectl get pods -n devops-api -o wide

Write-Host "`n🔄 Deployment:" -ForegroundColor Yellow
kubectl get deployment -n devops-api

Write-Host "`n🌐 Services:" -ForegroundColor Yellow
kubectl get services -n devops-api

Write-Host "`n🚪 ACCESSING THE API" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

Write-Host "`n1. Using port-forward for local access:" -ForegroundColor Green
Write-Host "   kubectl port-forward -n devops-api service/devops-api-service 8080:80" -ForegroundColor Gray
Write-Host "   Then visit: http://localhost:8080" -ForegroundColor Gray
Write-Host "   Docs: http://localhost:8080/docs" -ForegroundColor Gray

Write-Host "`n2. Using Minikube LoadBalancer:" -ForegroundColor Green
$serviceUrl = minikube service -n devops-api devops-api-loadbalancer --url
Write-Host "   API URL: $serviceUrl" -ForegroundColor Gray
Write-Host "   Health: $serviceUrl/health" -ForegroundColor Gray
Write-Host "   Metrics: $serviceUrl/metrics" -ForegroundColor Gray

Write-Host "`n🔧 USEFUL COMMANDS:" -ForegroundColor Cyan
Write-Host "   View logs: kubectl logs -n devops-api -l app=devops-api" -ForegroundColor Gray
Write-Host "   Check events: kubectl get events -n devops-api" -ForegroundColor Gray
Write-Host "   Scale up: kubectl scale -n devops-api deployment/devops-api --replicas=3" -ForegroundColor Gray
Write-Host "   Delete: kubectl delete -f k8s/" -ForegroundColor Gray

Write-Host "`n[OK] DEPLOYMENT COMPLETE!" -ForegroundColor Green