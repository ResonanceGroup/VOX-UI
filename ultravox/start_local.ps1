# PowerShell script to start Ultravox server locally
param(
    [string]$VenvPath = "..\ultravox_venv",
    [string]$CachePath = "..\hf_cache"
)

Write-Host "=== [UltraVox/KokoroTTS Local Server] ==="
Write-Host "Using virtual environment from: $([System.IO.Path]::GetFullPath($VenvPath))"
Write-Host "Using HuggingFace cache from: $([System.IO.Path]::GetFullPath($CachePath))"
Write-Host ""

# Activate venv
& "$VenvPath\Scripts\Activate.ps1"

# Set environment variables
$env:HF_HOME = $CachePath

# Start the server
Write-Host "Starting Ultravox server..."
python speech_server.py