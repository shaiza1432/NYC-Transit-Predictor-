# ────────────────────────────────────────────────────────────────────
# tasks.ps1 — PowerShell task runner for Windows users.
# Mirrors the Makefile targets. Usage:
#
#   .\tasks.ps1 build
#   .\tasks.ps1 train
#   .\tasks.ps1 dashboard
#   .\tasks.ps1 help
# ────────────────────────────────────────────────────────────────────
param(
    [Parameter(Position=0)]
    [ValidateSet(
        'help', 'build', 'train', 'dashboard', 'notebook', 'logs', 'down', 'shell',
        'lint', 'format', 'typecheck', 'test', 'test-integration', 'test-all', 'clean'
    )]
    [string]$Task = 'help'
)

$ErrorActionPreference = 'Stop'

function Show-Help {
    Write-Host ""
    Write-Host "NYC Transit Predictor — task runner" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Docker workflow:" -ForegroundColor Yellow
    Write-Host "  .\tasks.ps1 build              Build the Docker image"
    Write-Host "  .\tasks.ps1 train              Run the training pipeline"
    Write-Host "  .\tasks.ps1 dashboard          Start dashboard (http://localhost:8501)"
    Write-Host "  .\tasks.ps1 notebook           Start Jupyter (http://localhost:8888)"
    Write-Host "  .\tasks.ps1 logs               Tail dashboard logs"
    Write-Host "  .\tasks.ps1 down               Stop all containers"
    Write-Host "  .\tasks.ps1 shell              Open shell inside container"
    Write-Host ""
    Write-Host "Code quality:" -ForegroundColor Yellow
    Write-Host "  .\tasks.ps1 lint               Lint with ruff"
    Write-Host "  .\tasks.ps1 format             Auto-format with ruff"
    Write-Host "  .\tasks.ps1 typecheck          Type-check with mypy"
    Write-Host "  .\tasks.ps1 test               Run unit tests"
    Write-Host "  .\tasks.ps1 test-integration   Run integration tests"
    Write-Host "  .\tasks.ps1 test-all           Run every test"
    Write-Host ""
    Write-Host "Housekeeping:" -ForegroundColor Yellow
    Write-Host "  .\tasks.ps1 clean              Remove caches, logs, model artefacts"
    Write-Host ""
}

switch ($Task) {
    'help'             { Show-Help }
    'build'            { docker compose build }
    'train'            { docker compose run --rm pipeline }
    'dashboard'        { docker compose up -d dashboard; Write-Host "Dashboard at http://localhost:8501" -ForegroundColor Green }
    'notebook'         { docker compose --profile dev up -d notebook; Write-Host "Notebook at http://localhost:8888" -ForegroundColor Green }
    'logs'             { docker compose logs -f dashboard }
    'down'             { docker compose down }
    'shell'            { docker compose run --rm dashboard bash }
    'lint'             { ruff check . }
    'format'           { ruff format . }
    'typecheck'        { mypy dashboard }
    'test'             { pytest -m "not slow" --cov=dashboard.src --cov-report=term-missing }
    'test-integration' { pytest -m "integration" }
    'test-all'         { pytest }
    'clean'            {
        Remove-Item -Recurse -Force 'models/rf_pipeline'         -ErrorAction SilentlyContinue
        Remove-Item -Force          'models/metrics.json'         -ErrorAction SilentlyContinue
        Get-ChildItem 'dashboard/static/plots' -Filter '*.png'    -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem 'logs' -Filter '*.log','*.zip'              -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -Path . -Filter '__pycache__'      -Recurse -Directory | Remove-Item -Recurse -Force
        Get-ChildItem -Path . -Filter '.pytest_cache'    -Recurse -Directory | Remove-Item -Recurse -Force
        Get-ChildItem -Path . -Filter '.mypy_cache'      -Recurse -Directory | Remove-Item -Recurse -Force
        Get-ChildItem -Path . -Filter '.ruff_cache'      -Recurse -Directory | Remove-Item -Recurse -Force
        Write-Host "Clean complete." -ForegroundColor Green
    }
}
