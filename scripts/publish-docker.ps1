# Docker Hub Publishing Script
# Usage: .\scripts\publish-docker.ps1 -Username "your-dockerhub-username"

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$Tag = "latest"
)

Write-Host "`n[DOCKER HUB] Publishing Image" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

# Check if Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Host "`n[ERROR] Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Login to Docker Hub
Write-Host "`n[*] Logging in to Docker Hub..." -ForegroundColor Yellow
docker login

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERROR] Docker login failed!" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Logged in successfully" -ForegroundColor Green

# Build the image
Write-Host "`n[*] Building Docker image..." -ForegroundColor Yellow
docker build -t devops-api:$Tag .

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERROR] Docker build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Image built successfully" -ForegroundColor Green

# Tag the image for Docker Hub
$remoteTag = "${Username}/devops-api:${Tag}"
Write-Host "`n[*] Tagging image as $remoteTag..." -ForegroundColor Yellow
docker tag devops-api:$Tag $remoteTag

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERROR] Docker tag failed!" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Image tagged successfully" -ForegroundColor Green

# Push to Docker Hub
Write-Host "`n[*] Pushing image to Docker Hub..." -ForegroundColor Yellow
Write-Host "This may take a few minutes..." -ForegroundColor Gray
docker push $remoteTag

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERROR] Docker push failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n[OK] PUBLISH COMPLETE!" -ForegroundColor Green
Write-Host "`nYour image is now available at:" -ForegroundColor Cyan
Write-Host "  docker pull $remoteTag" -ForegroundColor White

Write-Host "`nDocker Hub URL:" -ForegroundColor Cyan
Write-Host "  https://hub.docker.com/r/$Username/devops-api" -ForegroundColor White

Write-Host "`nTo use in Kubernetes, update deployment.yaml:" -ForegroundColor Cyan
Write-Host "  image: $remoteTag" -ForegroundColor White
