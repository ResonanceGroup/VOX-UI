# PowerShell script to send backend files to RunPod
param(
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath = "/workspace/vox-backend"
)

# Store the original location
$originalLocation = Get-Location

try {
    # Change to the project root directory
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location (Split-Path -Parent $scriptPath)
    
    Write-Host "Creating zip file..."
    Compress-Archive -Path "backend\*" -DestinationPath "backend.zip" -Force
    
    Write-Host "Sending zip file to RunPod..."
    $transferResult = & "./runpodctl" send "backend.zip" 2>&1 | Out-String
    Write-Host "Transfer output:`n$transferResult"
    
    if ($transferResult -match "Code is: ([^\r\n]+)") {
        $code = $matches[1].Trim()
        Write-Host "Found transfer code: $code"
        
        Write-Host "Setting up workspace on RunPod..."
        $setupCommands = @(
            "mkdir -p /workspace/vox-backend",
            "cd /workspace",
            "runpodctl receive $code",
            "unzip -o backend.zip -d /workspace/vox-backend",
            "rm backend.zip",
            "chmod +x /workspace/vox-backend/setup_pod.sh",
            "ls -la /workspace/vox-backend"
        )
        
        $setupResult = ../runpodctl exec -- ($setupCommands -join " && ")
        Write-Host "Setup result:`n$setupResult"
    }
    else {
        Write-Host "ERROR: Could not find transfer code in output"
        Write-Host "Full transfer output was:`n$transferResult"
    }
    
    # Clean up local zip file
    Remove-Item "backend.zip"
    
    Write-Host "Transfer complete! Files should be in $DestinationPath"
}
finally {
    # Return to the original location
    Set-Location $originalLocation
}
