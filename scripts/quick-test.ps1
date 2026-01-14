# Quick CI Test - Simple version
Write-Host "🧪 Quick CI/CD Test" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

# 1. Create venv
if (-not (Test-Path "venv")) {
    Write-Host "`n1. Creating venv..." -ForegroundColor Yellow
    python -m venv venv
}

# 2. Activate and install
Write-Host "`n2. Installing dependencies..." -ForegroundColor Yellow
& .\venv\Scripts\Activate.ps1
pip install -q -r requirements.txt
pip install -q requests

# 3. Start API
Write-Host "`n3. Starting API..." -ForegroundColor Yellow
Start-Job -ScriptBlock {
    Set-Location $using:PWD
    & .\venv\Scripts\Activate.ps1
    uvicorn app.main:app --host 0.0.0.0 --port 8000
} | Out-Null
Start-Sleep -Seconds 5

# 4. Run tests
Write-Host "`n4. Running tests..." -ForegroundColor Yellow
python scripts\test_api.py

# 5. Cleanup
Write-Host "`n5. Cleanup..." -ForegroundColor Yellow
Get-Job | Stop-Job
Get-Job | Remove-Job

Write-Host "`n✅ Done!" -ForegroundColor Green
