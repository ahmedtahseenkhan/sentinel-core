# SentinelCore Docker Agents

Run 3 Wazuh agents in Docker containers that connect to your SentinelCore manager.

## Quick Start

```bash
cd docker/agents

# Set your manager IP
export MANAGER_IP=10.0.1.100

# (Optional) Set registration password if your manager requires one
export AGENT_PASSWORD=YourRegistrationPassword

# Build and launch all 3 agents
docker-compose up -d --build
```

## Commands

```bash
# Check status
docker-compose ps

# View all agent logs
docker-compose logs -f

# View a specific agent's logs
docker-compose logs -f sentinelcore-agent-1

# Stop all agents
docker-compose down

# Restart a specific agent
docker-compose restart sentinelcore-agent-2

# Scale to more agents (optional)
docker-compose up -d --scale sentinelcore-agent-1=1 --scale sentinelcore-agent-2=1 --scale sentinelcore-agent-3=1
```

## Verify on Manager

```bash
# List connected agents via API
curl -sk -u wazuh-wui:YourPassword \
  "https://MANAGER_IP:55000/agents?pretty"

# Or via CLI on the manager
/var/ossec/bin/agent_control -l
```

## Files

| File | Description |
|------|-------------|
| `Dockerfile` | Agent image based on Ubuntu 22.04 |
| `docker-compose.yml` | Defines 3 agent services |
| `entrypoint.sh` | Handles registration and startup |
| `ossec.conf` | Container-optimized agent config |

## Customization

- **Add more agents**: Duplicate a service block in `docker-compose.yml` with a new name
- **Change group**: Set `WAZUH_AGENT_GROUP` to a different group name
- **Mount host logs**: Add volume mounts to monitor host files from inside the container:
  ```yaml
  volumes:
    - /var/log:/host/var/log:ro
  ```
