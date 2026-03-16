# API Usage Examples

## Authentication

```bash
# Get JWT token
TOKEN=$(curl -sk -u wazuh-wui:SENTINELCORE_AUTH_PASS \
  -X POST "https://SENTINELCORE_MANAGER_IP:55000/security/user/authenticate" | \
  jq -r '.data.token')

# Use token in subsequent requests
curl -sk -H "Authorization: Bearer $TOKEN" "https://SENTINELCORE_MANAGER_IP:55000/"
```

## Agent Management

```bash
# List all agents
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/agents?pretty"

# Get agent by ID
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/agents/001?pretty"

# Get active agents
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/agents?status=active&pretty"

# Get agent summary
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/agents/summary/status?pretty"

# Delete agent
curl -sk -H "Authorization: Bearer $TOKEN" \
  -X DELETE "https://SENTINELCORE_MANAGER_IP:55000/agents?agents_list=002&status=all&older_than=0s&pretty"

# Restart agent
curl -sk -H "Authorization: Bearer $TOKEN" \
  -X PUT "https://SENTINELCORE_MANAGER_IP:55000/agents/001/restart?pretty"
```

## Rules and Decoders

```bash
# List rules
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/rules?pretty&limit=10"

# Get rule by ID
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/rules/100010?pretty"

# List decoders
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/decoders?pretty&limit=10"
```

## Manager Information

```bash
# Manager info
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/manager/info?pretty"

# Manager stats
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/manager/stats?pretty"

# Cluster status
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/cluster/status?pretty"

# Manager logs
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/manager/logs?pretty&limit=20"
```

## Vulnerability Detection

```bash
# Get vulnerabilities for an agent
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/vulnerability/001?pretty&limit=20"
```

## SCA (Security Configuration Assessment)

```bash
# Get SCA results for agent
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/sca/001?pretty"

# Get SCA check results
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://SENTINELCORE_MANAGER_IP:55000/sca/001/checks/cis_ubuntu22-04?pretty"
```

## Python Example

```python
import requests
import urllib3
urllib3.disable_warnings()

MANAGER = "https://SENTINELCORE_MANAGER_IP:55000"
USER = "wazuh-wui"
PASS = "SENTINELCORE_AUTH_PASS"

# Authenticate
resp = requests.post(f"{MANAGER}/security/user/authenticate",
                     auth=(USER, PASS), verify=False)
token = resp.json()["data"]["token"]
headers = {"Authorization": f"Bearer {token}"}

# List agents
agents = requests.get(f"{MANAGER}/agents", headers=headers, verify=False)
for agent in agents.json()["data"]["affected_items"]:
    print(f"  {agent['id']}: {agent['name']} ({agent['status']})")
```
