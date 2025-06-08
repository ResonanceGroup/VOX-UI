# PowerShell script for local Ultravox setup
param(
    [string]$VenvPath = "..\ultravox_venv",
    [string]$CachePath = "..\hf_cache"
)

Write-Host "=== [UltraVox/KokoroTTS Local Setup] ==="
Write-Host "Virtual Environment will be created at: $([System.IO.Path]::GetFullPath($VenvPath))"
Write-Host "HuggingFace cache will be at: $([System.IO.Path]::GetFullPath($CachePath))"
Write-Host ""

$confirmation = Read-Host "Continue with these paths? (y/n)"
if ($confirmation -ne 'y') {
    Write-Host "Setup cancelled."
    exit
}

# Create Python venv
if (-not (Test-Path $VenvPath)) {
    Write-Host "Creating Python venv at $VenvPath"
    python -m venv $VenvPath
} else {
    Write-Host "Python venv already exists at $VenvPath"
}

# Activate venv
& "$VenvPath\Scripts\Activate.ps1"

# Install dependencies
Write-Host "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt --force-reinstall

# Set environment variables
if (-not (Test-Path $CachePath)) {
    New-Item -ItemType Directory -Path $CachePath
}
$env:HF_HOME = $CachePath

Write-Host "=== [Setup Complete] ==="
Write-Host ""
Write-Host "To start the server, run:"
Write-Host "  & '$VenvPath\Scripts\Activate.ps1'"
Write-Host "  `$env:HF_HOME = '$CachePath'"
Write-Host "  python speech_server.py"
Write-Host ""
Write-Host "The virtual environment is at: $([System.IO.Path]::GetFullPath($VenvPath))"
Write-Host "The HuggingFace cache is at: $([System.IO.Path]::GetFullPath($CachePath))"