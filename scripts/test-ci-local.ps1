# scripts/test-ci-local.ps1
# Test CI/CD pipeline locally on Windows

Write-Host "🧪 Running CI/CD tests locally with venv" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Stop on error
$ErrorActionPreference = "Stop"
$apiJob = $null

try {
    # 1. Create virtual environment if not exists
    Write-Host "`n1️⃣ Setting up virtual environment..." -ForegroundColor Yellow
    if (-not (Test-Path "venv")) {
        python -m venv venv
        Write-Host "✅ Virtual environment created" -ForegroundColor Green
    } else {
        Write-Host "✅ Virtual environment already exists" -ForegroundColor Green
    }

    # 2. Activate venv
    Write-Host "`n2️⃣ Activating virtual environment..." -ForegroundColor Yellow
    & .\venv\Scripts\Activate.ps1
    Write-Host "✅ Virtual environment activated" -ForegroundColor Green

    # 3. Install dependencies
    Write-Host "`n3️⃣ Installing dependencies..." -ForegroundColor Yellow
    python -m pip install --upgrade pip --quiet
    pip install -r requirements.txt --quiet
    pip install pytest httpx requests bandit --quiet
    Write-Host "✅ Dependencies installed" -ForegroundColor Green

    # 4. Run security scan
    Write-Host "`n4️⃣ Running security scan with Bandit..." -ForegroundColor Yellow
    bandit -r app/ -f json -o bandit-report.json
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Security scan passed (no issues found)" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Security scan found issues (check bandit-report.json)" -ForegroundColor Yellow
    }

    # 5. Start API in background
    Write-Host "`n5️⃣ Starting API server..." -ForegroundColor Yellow
    $apiJob = Start-Job -ScriptBlock {
        Set-Location $using:PWD
        & .\venv\Scripts\Activate.ps1
        uvicorn app.main:app --host 0.0.0.0 --port 8000
    }
    Start-Sleep -Seconds 5
    Write-Host "✅ API server started (Job ID: $($apiJob.Id))" -ForegroundColor Green

    # 6. Run tests
    Write-Host "`n6️⃣ Running API tests..." -ForegroundColor Yellow
    python scripts\test_api.py

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ All API tests passed!" -ForegroundColor Green
    } else {
        Write-Host "❌ Some API tests failed" -ForegroundColor Red
        throw "Tests failed"
    }

    # 7. Docker build test
    Write-Host "`n7️⃣ Testing Docker build..." -ForegroundColor Yellow
    docker build -t devops-api:test .
    Write-Host "✅ Docker image built successfully" -ForegroundColor Green

    # 8. Test Docker container
    Write-Host "`n8️⃣ Testing Docker container..." -ForegroundColor Yellow
    docker run -d --name ci-test -p 8002:8000 devops-api:test
    Start-Sleep -Seconds 5
    
    $healthCheck = curl.exe -f http://localhost:8002/health
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker container health check passed" -ForegroundColor Green
    } else {
        Write-Host "❌ Docker container health check failed" -ForegroundColor Red
        docker logs ci-test
        throw "Docker test failed"
    }

    Write-Host "`n🎉 All CI/CD tests passed successfully!" -ForegroundColor Green

} catch {
    Write-Host "`n❌ CI/CD tests failed: $_" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    Write-Host "`n🧹 Cleaning up..." -ForegroundColor Yellow
    
    # Stop API job
    if ($apiJob) {
        Stop-Job -Job $apiJob -ErrorAction SilentlyContinue
        Remove-Job -Job $apiJob -ErrorAction SilentlyContinue
        Write-Host "  ✅ API server stopped" -ForegroundColor Green
    }
    
    # Stop and remove Docker test container
    docker stop ci-test 2>$null
    docker rm ci-test 2>$null
    Write-Host "  ✅ Docker test container removed" -ForegroundColor Green
    
    Write-Host "`n✨ Cleanup complete" -ForegroundColor Cyan
}
"@
