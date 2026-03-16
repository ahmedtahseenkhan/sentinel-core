# Windows Agent Installation Guide

## Quick Install (PowerShell)

```powershell
# Run as Administrator
.\agent\windows\install-agent.ps1 -ManagerIP "10.0.1.100" -AgentName "WIN-SERVER-01" -AgentGroup "windows"
```

## Manual Installation

### 1. Download the MSI Package

```powershell
$version = "4.9.0"
$url = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$version-1.msi"
Invoke-WebRequest -Uri $url -OutFile "$env:TEMP\wazuh-agent.msi"
```

### 2. Install with Parameters

```powershell
msiexec.exe /i "$env:TEMP\wazuh-agent.msi" /q `
  WAZUH_MANAGER="SENTINELCORE_MANAGER_IP" `
  WAZUH_AGENT_NAME="$env:COMPUTERNAME" `
  WAZUH_AGENT_GROUP="windows" `
  WAZUH_REGISTRATION_PASSWORD="RegistrationPassword"
```

### 3. Start the Service

```powershell
Start-Service -Name "WazuhSvc"
Get-Service -Name "WazuhSvc"
```

## Registration Only

```powershell
.\agent\windows\register-agent.ps1 -ManagerIP "10.0.1.100" -AgentName "WIN-SERVER-01"
```

## Configuration

The configuration file is at:
```
C:\Program Files (x86)\ossec-agent\ossec.conf
```

## Verify Connection

```powershell
# Check service status
Get-Service -Name "WazuhSvc"

# Check logs
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 50
```

## Sysmon Integration

Install Sysmon for enhanced Windows logging:
```powershell
# Download Sysmon
Invoke-WebRequest -Uri "https://live.sysinternals.com/Sysmon64.exe" -OutFile sysmon64.exe

# Install with default config
.\sysmon64.exe -accepteula -i

# The agent config already monitors Microsoft-Windows-Sysmon/Operational
```
