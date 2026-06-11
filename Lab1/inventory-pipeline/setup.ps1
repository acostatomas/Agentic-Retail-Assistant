# PowerShell version of setup.sh for Windows users
# Drives the three-step inventory pipeline against a Confluent Platform
# installation running inside Minikube on a remote VM.
#
# Step 1: create the source Kafka topic (inventory.transactions)
# Step 2: create the derived ksqlDB stream + CTAS table -> inventory.availability
# Step 3: produce 20 sample messages
#
# Each step runs as a one-off Kubernetes Job inside the cluster

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("1", "2", "3", "all")]
    [string]$Step = "all",
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanupExe,
    
    [Parameter(Mandatory=$false)]
    [switch]$Cleanup
)

$ErrorActionPreference = "Stop"

# Auto-configure execution policy for this script
$currentPolicy = Get-ExecutionPolicy -Scope Process
if ($currentPolicy -eq 'Undefined' -or $currentPolicy -eq 'Restricted') {
    try {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Write-Host "==> Execution policy set to Bypass for this session"
    } catch {
        Write-Warning "Could not set execution policy: $_"
    }
}

# Unblock this script file
try {
    Unblock-File -Path $PSCommandPath -ErrorAction SilentlyContinue
} catch {
    # Silently ignore if unblock fails
}

# Load .env file - go up two levels from script directory
$envPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) ".env"
$SSH_HOST = $null
$SSH_KEY = $null

if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        $line = $_.Trim()
        # Skip comments and empty lines
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim().Trim('"').Trim("'")
                if ($key -eq "SSH_HOST") { $SSH_HOST = $value }
                if ($key -eq "SSH_KEY") { $SSH_KEY = $value }
            }
        }
    }
} else {
    Write-Error ".env file not found at: $envPath"
    exit 1
}

if (-not $SSH_HOST) {
    Write-Error "SSH_HOST not found in .env"
    exit 1
}

if (-not $SSH_KEY) {
    Write-Error "SSH_KEY not found in .env"
    exit 1
}

# Resolve SSH_KEY path - it's relative to the root .env location
$envDir = Split-Path $envPath -Parent
$keyPath = Join-Path $envDir $SSH_KEY
if (-not (Test-Path $keyPath)) {
    Write-Error "SSH key not found: $keyPath"
    exit 1
}

# Fix SSH key permissions for Windows using icacls (doesn't require admin)
Write-Host "==> Fixing SSH key permissions..."
try {
    # Remove inheritance and all existing permissions
    $null = icacls $keyPath /inheritance:r 2>&1
    
    # Grant read permission to current user only
    $null = icacls $keyPath /grant "${env:USERNAME}:R" 2>&1
    
    Write-Host "==> SSH key permissions fixed. Only ${env:USERNAME} has read access."
} catch {
    Write-Warning "Failed to set SSH key permissions: $_"
    Write-Warning "Continuing anyway..."
}
Write-Host ""

$REMOTE_DIR = "/root/inventory-pipeline"

Write-Host "==> Target:    $SSH_HOST"
Write-Host "==> Key:       $keyPath"
Write-Host "==> .env:      $envPath"
Write-Host "==> Remote:    $REMOTE_DIR"
if ($Cleanup) {
    Write-Host "==> Mode:      Cleanup ONLY"
} elseif ($CleanupExe) {
    Write-Host "==> Step:      $Step"
    Write-Host "==> Cleanup:   Before setup"
} else {
    Write-Host "==> Step:      $Step"
    Write-Host "==> Cleanup:   No"
}
Write-Host ""

Write-Host "==> Pushing scripts and .env..."

# Create remote directory
ssh -i $keyPath -o StrictHostKeyChecking=no $SSH_HOST "mkdir -p $REMOTE_DIR"

# Create temp .env without SSH_HOST and SSH_KEY
$tempEnv = [System.IO.Path]::GetTempFileName()
Get-Content $envPath | Where-Object { $_ -notmatch '^\s*(SSH_HOST|SSH_KEY)\s*=' } | Set-Content $tempEnv

# Upload files
scp -i $keyPath -o StrictHostKeyChecking=no $tempEnv "${SSH_HOST}:${REMOTE_DIR}/.env"

$filesToUpload = @(
    "create_topic.py",
    "create_derived_topic.py", 
    "produce_messages.py",
    "run_in_cluster.sh"
)

# Add delete_topics.py if cleanup is requested
if ($CleanupExe -or $Cleanup) {
    $filesToUpload += "delete_topics.py"
}

foreach ($file in $filesToUpload) {
    $localPath = Join-Path $PSScriptRoot $file
    if (-not (Test-Path $localPath)) {
        Write-Error "Missing local file: $localPath"
        exit 1
    }
    scp -i $keyPath -o StrictHostKeyChecking=no $localPath "${SSH_HOST}:${REMOTE_DIR}/$file"
}

# Make script executable
ssh -i $keyPath -o StrictHostKeyChecking=no $SSH_HOST "chmod +x ${REMOTE_DIR}/run_in_cluster.sh"

# Clean up temp file
Remove-Item $tempEnv

function Run-Step {
    param(
        [string]$Name,
        [string]$Title
    )
    
    Write-Host ""
    Write-Host "================================================================"
    Write-Host "==> Step: $Title"
    Write-Host "================================================================"
    ssh -i $keyPath -o StrictHostKeyChecking=no $SSH_HOST "bash ${REMOTE_DIR}/run_in_cluster.sh $Name"
}

# Run cleanup if requested
if ($CleanupExe -or $Cleanup) {
    Write-Host ""
    Write-Host "================================================================"
    Write-Host "==> CLEANUP: Deleting existing topics and ksqlDB objects"
    Write-Host "================================================================"
    ssh -i $keyPath -o StrictHostKeyChecking=no $SSH_HOST "bash ${REMOTE_DIR}/run_in_cluster.sh delete_topics"
    Write-Host ""
    
    if ($Cleanup) {
        Write-Host "==> Cleanup completed."
        exit 0
    }
    
    Write-Host "==> Cleanup completed. Proceeding with setup..."
    Start-Sleep -Seconds 2
}

# Run the requested step(s)
switch ($Step) {
    "1" {
        Run-Step "create_topic" "create inventory.transactions topic"
    }
    "2" {
        Run-Step "create_derived_topic" "create ksqlDB stream + inventory.availability"
    }
    "3" {
        Run-Step "produce_messages" "publish 20 sample messages"
    }
    "all" {
        Run-Step "create_topic" "create inventory.transactions topic"
        Run-Step "create_derived_topic" "create ksqlDB stream + inventory.availability"
        Run-Step "produce_messages" "publish 20 sample messages"
    }
}

Write-Host ""
Write-Host "==> Done."

# Made with Bob