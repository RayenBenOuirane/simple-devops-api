# scripts/security-scan.ps1 - clean, ASCII only
Write-Host "SECURITY SCAN" -ForegroundColor Cyan
Write-Host "==============" -ForegroundColor Cyan

# 1. Bandit (SAST)
Write-Host "`n[1/3] Running Bandit SAST..." -ForegroundColor Yellow
bandit -r app/ -c .bandit.yml -f txt
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: Bandit found no issues" -ForegroundColor Green
} else {
    Write-Host "WARN: Bandit reported issues (see output above)" -ForegroundColor Yellow
}

# 2. Safety (dependencies)
Write-Host "`n[2/3] Running Safety dependency scan..." -ForegroundColor Yellow
safety check -r requirements.txt
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: Safety found no vulnerabilities" -ForegroundColor Green
} else {
    Write-Host "WARN: Safety reported vulnerabilities (see output above)" -ForegroundColor Yellow
}

# 3. Basic header check (use GET to avoid 405 on HEAD)
Write-Host "`n[3/3] Checking basic security headers..." -ForegroundColor Yellow
Write-Host "   Starting API..." -NoNewline
$api = Start-Process -PassThru -NoNewWindow -FilePath "python" -ArgumentList "-m uvicorn app.main:app --host 0.0.0.0 --port 8000"
Start-Sleep -Seconds 5
Write-Host " done" -ForegroundColor Green

try {
    Write-Host "   Testing headers (GET /)..." -NoNewline
    $response = Invoke-WebRequest -Uri "http://localhost:8000/" -Method Get
    $requiredHeaders = @("X-Content-Type-Options", "X-Frame-Options", "X-XSS-Protection")
    $missing = @()
    foreach ($h in $requiredHeaders) {
        if (-not $response.Headers[$h]) { $missing += $h }
    }
    if ($missing.Count -eq 0) {
        Write-Host " ok" -ForegroundColor Green
        Write-Host "   All checked headers present" -ForegroundColor Green
    } else {
        Write-Host " missing" -ForegroundColor Yellow
        Write-Host ("   Missing headers: {0}" -f ($missing -join ", ")) -ForegroundColor Yellow
    }
} catch {
    Write-Host " failed" -ForegroundColor Red
    Write-Host "   Error while checking headers: $_" -ForegroundColor Red
} finally {
    if ($api) { Stop-Process -Id $api.Id -Force -ErrorAction SilentlyContinue }
}

Write-Host "`n" + ("=" * 40) -ForegroundColor Cyan
Write-Host "SECURITY SCAN COMPLETE" -ForegroundColor Cyan
Write-Host ("=" * 40) -ForegroundColor Cyan
Write-Host "Run 'bandit -r app/' for detailed SAST" -ForegroundColor Gray
Write-Host "Run 'safety check -r requirements.txt' for dependency details" -ForegroundColor Gray
