# ============================================================================
# SentinelCore - Windows Agent Registration Script (PowerShell)
# ============================================================================
# Registers an existing Windows agent with the SentinelCore Manager.
# Usage: .\register-agent.ps1 -ManagerIP <IP> [-AgentName <NAME>]
# ============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ManagerIP,

    [Parameter(Mandatory=$false)]
    [string]$AgentName = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false)]
    [string]$AgentGroup = "windows",

    [Parameter(Mandatory=$false)]
    [string]$RegistrationPassword = ""
)

$ErrorActionPreference = "Stop"
$WazuhDir = "C:\Program Files (x86)\ossec-agent"
$AgentAuth = Join-Path $WazuhDir "agent-auth.exe"

# Validation
if (-not (Test-Path $WazuhDir)) {
    Write-Host "✗ Agent not installed at $WazuhDir" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $AgentAuth)) {
    Write-Host "✗ agent-auth.exe not found" -ForegroundColor Red
    exit 1
}

# Stop agent service
Write-Host "→ Stopping agent service..." -ForegroundColor Cyan
Stop-Service -Name "WazuhSvc" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Build registration args
$authArgs = "-m $ManagerIP -A $AgentName -G $AgentGroup"

if ($RegistrationPassword) {
    $passFile = Join-Path $WazuhDir "authd.pass"
    Set-Content -Path $passFile -Value $RegistrationPassword -Force
    $authArgs += " -P $passFile"
}

# Register
Write-Host "→ Registering agent '$AgentName' with $ManagerIP..." -ForegroundColor Cyan
$process = Start-Process -FilePath $AgentAuth -ArgumentList $authArgs -Wait -PassThru -NoNewWindow

if ($process.ExitCode -eq 0) {
    Write-Host "✓ Agent registered successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Registration failed (exit code: $($process.ExitCode))" -ForegroundColor Red
    exit 1
}

# Update config
$configFile = Join-Path $WazuhDir "ossec.conf"
if (Test-Path $configFile) {
    $content = Get-Content $configFile -Raw
    $content = $content -replace "<address>.*?</address>", "<address>$ManagerIP</address>"
    Set-Content -Path $configFile -Value $content -Force
    Write-Host "✓ Manager IP updated in config" -ForegroundColor Green
}

# Start agent
Write-Host "→ Starting agent service..." -ForegroundColor Cyan
Start-Service -Name "WazuhSvc"
Start-Sleep -Seconds 3

$service = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
if ($service.Status -eq "Running") {
    Write-Host "✓ Agent is running and connected" -ForegroundColor Green
} else {
    Write-Host "✗ Agent failed to start" -ForegroundColor Red
    exit 1
}
