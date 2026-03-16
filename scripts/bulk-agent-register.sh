#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Bulk Agent Registration
# ============================================================================
# Registers multiple agents from a CSV file.
# Usage: sudo bash bulk-agent-register.sh --file agents.csv --manager-ip <IP>
#
# CSV format: agent_name,agent_ip,agent_group
# Example:
#   web-server-01,10.0.2.10,linux
#   db-server-01,10.0.2.20,linux
#   win-desktop-01,10.0.3.10,windows
# ============================================================================

set -euo pipefail

MANAGER_IP="${SENTINELCORE_MANAGER_IP:-}"
API_USER="${SENTINELCORE_API_USER:-wazuh-wui}"
API_PASS="${SENTINELCORE_API_PASS:-SENTINELCORE_AUTH_PASS}"
AGENTS_FILE=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)       AGENTS_FILE="$2"; shift 2 ;;
        --manager-ip) MANAGER_IP="$2"; shift 2 ;;
        --user)       API_USER="$2"; shift 2 ;;
        --pass)       API_PASS="$2"; shift 2 ;;
        --help)       head -14 "$0" | grep "^#" | sed 's/^# *//'; exit 0 ;;
        *)            shift ;;
    esac
done

[[ -z "${MANAGER_IP}" ]] && { echo -e "${RED}--manager-ip required${NC}"; exit 1; }
[[ -z "${AGENTS_FILE}" ]] && { echo -e "${RED}--file required${NC}"; exit 1; }
[[ ! -f "${AGENTS_FILE}" ]] && { echo -e "${RED}File not found: ${AGENTS_FILE}${NC}"; exit 1; }

# Get token
TOKEN=$(curl -sk -X POST -u "${API_USER}:${API_PASS}" \
    "https://${MANAGER_IP}:55000/security/user/authenticate" 2>/dev/null | \
    jq -r '.data.token' 2>/dev/null || echo "")

[[ -z "${TOKEN}" || "${TOKEN}" == "null" ]] && { echo -e "${RED}API authentication failed${NC}"; exit 1; }

echo "Registering agents from ${AGENTS_FILE}..."
echo ""

TOTAL=0
SUCCESS=0
FAILED=0

while IFS=',' read -r name ip group || [[ -n "$name" ]]; do
    # Skip header/comments
    [[ "${name}" =~ ^#.*$ || "${name}" == "agent_name" ]] && continue
    [[ -z "${name}" ]] && continue

    TOTAL=$((TOTAL + 1))
    name=$(echo "${name}" | tr -d ' ')
    ip=$(echo "${ip}" | tr -d ' ')
    group=$(echo "${group}" | tr -d ' ')

    RESULT=$(curl -sk -X POST "https://${MANAGER_IP}:55000/agents" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${name}\",\"ip\":\"${ip}\"}" 2>/dev/null)

    AGENT_ID=$(echo "${RESULT}" | jq -r '.data.id' 2>/dev/null || echo "")

    if [[ -n "${AGENT_ID}" && "${AGENT_ID}" != "null" ]]; then
        # Assign group
        if [[ -n "${group}" ]]; then
            curl -sk -X PUT "https://${MANAGER_IP}:55000/agents/${AGENT_ID}/group/${group}" \
                -H "Authorization: Bearer ${TOKEN}" >/dev/null 2>&1
        fi
        echo -e "  ${GREEN}✓${NC} ${name} (${ip}) → Agent ID: ${AGENT_ID}, Group: ${group}"
        SUCCESS=$((SUCCESS + 1))
    else
        ERROR=$(echo "${RESULT}" | jq -r '.detail // .message // "Unknown error"' 2>/dev/null)
        echo -e "  ${RED}✗${NC} ${name} (${ip}) → Error: ${ERROR}"
        FAILED=$((FAILED + 1))
    fi
done < "${AGENTS_FILE}"

echo ""
echo "Results: ${SUCCESS}/${TOTAL} registered, ${FAILED} failed"
