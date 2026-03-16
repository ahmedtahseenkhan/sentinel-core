# SentinelCore Docker Stack

## Overview

Run the complete SentinelCore stack (Manager + Indexer + Dashboard) in Docker.

## Quick Start

```bash
cd docker/stack

# Step 1: Generate TLS certificates
docker-compose -f generate-certs.yml run --rm generator

# Step 2: Start the full stack
docker-compose up -d

# Step 3: Wait ~60 seconds for all services to initialize, then access:
#   Dashboard: https://localhost:443
#   Username:  admin
#   Password:  SecretPassword
```

## Connect Docker Agents

Once the stack is running, get your host machine's IP and launch agents:

```bash
# Get your host IP (not 127.0.0.1)
# Mac: ipconfig getifaddr en0
# Linux: hostname -I | awk '{print $1}'

cd ../agents
export MANAGER_IP=<your_host_ip>
docker-compose up -d --build
```

## Commands

```bash
# Check all services
docker-compose ps

# View manager logs
docker-compose logs -f sentinelcore-manager

# View indexer logs
docker-compose logs -f sentinelcore-indexer

# View dashboard logs
docker-compose logs -f sentinelcore-dashboard

# Stop everything
docker-compose down

# Stop and remove all data
docker-compose down -v
```

## Ports

| Port | Service |
|------|---------|
| 443 | Dashboard (Web UI) |
| 1514 | Agent communication |
| 1515 | Agent registration |
| 55000 | Manager API |
| 9200 | Indexer API |

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Dashboard | admin | SecretPassword |
| Manager API | wazuh-wui | MyS3cr37P450r.*- |

> ⚠️ **Change these passwords** for production use!
