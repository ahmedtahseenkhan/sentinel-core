#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Agent Health Check
# ============================================================================
set -euo pipefail

MANAGER_IP="${SENTINELCORE_MANAGER_IP:-localhost}"
API_USER="${SENTINELCORE_API_USER:-wazuh-wui}"
API_PASS="${SENTINELCORE_API_PASS:-SENTINELCORE_AUTH_PASS}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  SentinelCore Agent Health Check               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# Get API token
TOKEN=$(curl -sk -X POST -u "${API_USER}:${API_PASS}" "https://${MANAGER_IP}:55000/security/user/authenticate" 2>/dev/null | jq -r '.data.token' 2>/dev/null || echo "")

if [[ -z "${TOKEN}" || "${TOKEN}" == "null" ]]; then
    echo -e "${RED}✗ Cannot authenticate with Wazuh API${NC}"
    exit 1
fi

# Get agent summary
SUMMARY=$(curl -sk -H "Authorization: Bearer ${TOKEN}" "https://${MANAGER_IP}:55000/agents/summary/status" 2>/dev/null)

if [[ -n "${SUMMARY}" ]]; then
    ACTIVE=$(echo "${SUMMARY}" | jq -r '.data.connection.active // 0')
    DISCONNECTED=$(echo "${SUMMARY}" | jq -r '.data.connection.disconnected // 0')
    PENDING=$(echo "${SUMMARY}" | jq -r '.data.connection.pending // 0')
    NEVER=$(echo "${SUMMARY}" | jq -r '.data.connection.never_connected // 0')
    TOTAL=$(echo "${SUMMARY}" | jq -r '.data.connection.total // 0')

    echo -e "${GREEN}Active:${NC}           ${ACTIVE}"
    echo -e "${RED}Disconnected:${NC}     ${DISCONNECTED}"
    echo -e "${YELLOW}Pending:${NC}          ${PENDING}"
    echo -e "${YELLOW}Never Connected:${NC}  ${NEVER}"
    echo -e "${BLUE}Total:${NC}            ${TOTAL}"
    echo ""
fi

# List disconnected agents
if [[ "${DISCONNECTED:-0}" -gt 0 ]]; then
    echo -e "${RED}Disconnected Agents:${NC}"
    DISC_AGENTS=$(curl -sk -H "Authorization: Bearer ${TOKEN}" "https://${MANAGER_IP}:55000/agents?status=disconnected&limit=50" 2>/dev/null)
    echo "${DISC_AGENTS}" | jq -r '.data.affected_items[] | "  ✗ ID: \(.id) | Name: \(.name) | IP: \(.ip) | Last Seen: \(.lastKeepAlive)"' 2>/dev/null || echo "  Could not list agents"
    echo ""
fi

# List never-connected agents
if [[ "${NEVER:-0}" -gt 0 ]]; then
    echo -e "${YELLOW}Never Connected Agents:${NC}"
    NEVER_AGENTS=$(curl -sk -H "Authorization: Bearer ${TOKEN}" "https://${MANAGER_IP}:55000/agents?status=never_connected&limit=50" 2>/dev/null)
    echo "${NEVER_AGENTS}" | jq -r '.data.affected_items[] | "  ⚠ ID: \(.id) | Name: \(.name) | IP: \(.ip)"' 2>/dev/null || echo "  Could not list agents"
    echo ""
fi

# Status
if [[ "${DISCONNECTED:-0}" -gt 0 ]]; then
    echo -e "${RED}WARNING: ${DISCONNECTED} agent(s) disconnected${NC}"
    exit 1
else
    echo -e "${GREEN}All agents healthy ✓${NC}"
    exit 0
fi
