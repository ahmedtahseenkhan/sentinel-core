# ============================================================================
# SentinelCore - Windows Agent Installation Script (PowerShell)
# ============================================================================
# Usage: .\install-agent.ps1 -ManagerIP <IP> [-AgentName <NAME>] [-AgentGroup <GROUP>]
#
# Requirements:
#   - Windows 10/11, Windows Server 2016+
#   - PowerShell 5.1+
#   - Administrator privileges
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
    [string]$Version = "4.9.0",

    [Parameter(Mandatory=$false)]
    [string]$RegistrationPassword = "",

    [Parameter(Mandatory=$false)]
    [string]$InstallerPath = ""
)

# ========================= Configuration ====================================
$ErrorActionPreference = "Stop"
$WazuhDir = "C:\Program Files (x86)\ossec-agent"
$LogFile = "C:\sentinelcore-agent-install.log"
$DownloadURL = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$Version-1.msi"

# ========================= Functions ========================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logEntry
    switch ($Level) {
        "SUCCESS" { Write-Host "  ✓ $Message" -ForegroundColor Green }
        "ERROR"   { Write-Host "  ✗ $Message" -ForegroundColor Red }
        "WARNING" { Write-Host "  ⚠ $Message" -ForegroundColor Yellow }
        default   { Write-Host "  → $Message" -ForegroundColor Cyan }
    }
}

function Show-Banner {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   SentinelCore Agent - Windows Installer       ║" -ForegroundColor Cyan
    Write-Host "║   Version: $Version                            ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "This script must be run as Administrator" "ERROR"
        exit 1
    }
    Write-Log "Running as Administrator" "SUCCESS"
}

function Test-NetworkConnectivity {
    Write-Log "Testing connectivity to manager $ManagerIP..."
    if (Test-Connection -ComputerName $ManagerIP -Count 2 -Quiet -ErrorAction SilentlyContinue) {
        Write-Log "Manager $ManagerIP is reachable" "SUCCESS"
    } else {
        Write-Log "Cannot reach manager at $ManagerIP (may still work if firewall allows 1514/TCP)" "WARNING"
    }
}

function Get-WazuhInstaller {
    if ($InstallerPath -and (Test-Path $InstallerPath)) {
        Write-Log "Using local installer: $InstallerPath" "SUCCESS"
        return $InstallerPath
    }

    $msiPath = "$env:TEMP\wazuh-agent-$Version.msi"

    if (Test-Path $msiPath) {
        Write-Log "Installer already downloaded: $msiPath" "SUCCESS"
        return $msiPath
    }

    Write-Log "Downloading Wazuh agent v$Version..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($DownloadURL, $msiPath)
        Write-Log "Download complete" "SUCCESS"
    } catch {
        Write-Log "Download failed: $_" "ERROR"
        exit 1
    }

    return $msiPath
}

function Install-WazuhAgent {
    param([string]$MsiPath)

    Write-Log "Installing SentinelCore Agent..."

    $installArgs = @(
        "/i", $MsiPath,
        "/q",
        "WAZUH_MANAGER=$ManagerIP",
        "WAZUH_AGENT_NAME=$AgentName",
        "WAZUH_AGENT_GROUP=$AgentGroup"
    )

    if ($RegistrationPassword) {
        $installArgs += "WAZUH_REGISTRATION_PASSWORD=$RegistrationPassword"
    }

    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-Log "Agent installed successfully" "SUCCESS"
    } else {
        Write-Log "Installation failed with exit code: $($process.ExitCode)" "ERROR"
        exit 1
    }
}

function Set-CustomConfig {
    Write-Log "Applying custom configuration..."

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $customConfig = Join-Path $scriptDir "ossec.conf"

    if (Test-Path $customConfig) {
        $agentConfig = Join-Path $WazuhDir "ossec.conf"

        # Backup original
        if (Test-Path $agentConfig) {
            Copy-Item $agentConfig "$agentConfig.bak" -Force
        }

        # Copy and update custom config
        $content = Get-Content $customConfig -Raw
        $content = $content -replace "SENTINELCORE_MANAGER_IP", $ManagerIP
        Set-Content -Path $agentConfig -Value $content -Force

        Write-Log "Custom config deployed" "SUCCESS"
    } else {
        Write-Log "No custom config found, using default" "WARNING"
    }
}

function Start-WazuhAgent {
    Write-Log "Starting SentinelCore Agent service..."

    Start-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5

    $service = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Write-Log "Agent service is running" "SUCCESS"
    } else {
        Write-Log "Agent service failed to start" "ERROR"
        exit 1
    }
}

function Show-Summary {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  SentinelCore Agent - Install Complete         ║" -ForegroundColor Green
    Write-Host "╠═══════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║  Agent Name: $AgentName" -ForegroundColor Green
    Write-Host "║  Manager:    $ManagerIP" -ForegroundColor Green
    Write-Host "║  Group:      $AgentGroup" -ForegroundColor Green
    Write-Host "║  Config:     $WazuhDir\ossec.conf" -ForegroundColor Green
    Write-Host "║  Logs:       $WazuhDir\ossec.log" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

# ========================= Main =============================================
try {
    Show-Banner
    Test-Administrator
    Test-NetworkConnectivity

    $msiPath = Get-WazuhInstaller
    Install-WazuhAgent -MsiPath $msiPath
    Set-CustomConfig
    Start-WazuhAgent
    Show-Summary
} catch {
    Write-Log "Installation failed: $_" "ERROR"
    exit 1
}
