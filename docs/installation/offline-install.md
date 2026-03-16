# Offline (Air-Gapped) Installation Guide

## Overview

This guide covers installing SentinelCore in environments without internet access.

## Step 1: Download Packages (on internet-connected machine)

```bash
# Create package directory
mkdir -p sentinelcore-offline-packages/{manager,indexer,agent,filebeat}

# Manager
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-manager/wazuh-manager_4.9.0-1_amd64.deb \
  -O sentinelcore-offline-packages/manager/wazuh-manager_4.9.0-1_amd64.deb

# Indexer
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-indexer/wazuh-indexer_4.9.0-1_amd64.deb \
  -O sentinelcore-offline-packages/indexer/wazuh-indexer_4.9.0-1_amd64.deb

# Agent (Linux)
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.9.0-1_amd64.deb \
  -O sentinelcore-offline-packages/agent/wazuh-agent_4.9.0-1_amd64.deb

# Agent (Windows)
wget https://packages.wazuh.com/4.x/windows/wazuh-agent-4.9.0-1.msi \
  -O sentinelcore-offline-packages/agent/wazuh-agent-4.9.0-1.msi

# Filebeat
wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-oss-7.10.2-amd64.deb \
  -O sentinelcore-offline-packages/filebeat/filebeat-oss-7.10.2-amd64.deb

# Wazuh Filebeat module
wget https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.4.tar.gz \
  -O sentinelcore-offline-packages/filebeat/wazuh-filebeat-0.4.tar.gz
```

## Step 2: Transfer to Air-Gapped Network

Transfer `sentinelcore-offline-packages/` and the repository to the target network via:
- USB drive (encrypted recommended)
- Secure file transfer appliance
- Optical media

## Step 3: Install on Target Machines

### Manager
```bash
dpkg -i sentinelcore-offline-packages/manager/wazuh-manager_4.9.0-1_amd64.deb
# or
rpm -ivh sentinelcore-offline-packages/manager/wazuh-manager-4.9.0-1.x86_64.rpm
```

### Indexer
```bash
dpkg -i sentinelcore-offline-packages/indexer/wazuh-indexer_4.9.0-1_amd64.deb
```

### Agent
```bash
dpkg -i sentinelcore-offline-packages/agent/wazuh-agent_4.9.0-1_amd64.deb
```

## Step 4: Generate Certificates Offline

Certificates are generated using OpenSSL locally — no internet needed:
```bash
cd certificates
sudo bash generate-certs.sh
```

## Step 5: Apply Configuration

Follow the standard configuration steps from the installation guides.
