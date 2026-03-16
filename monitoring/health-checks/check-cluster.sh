#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Cluster Health Check
# ============================================================================
set -euo pipefail

MANAGER_IP="${SENTINELCORE_MANAGER_IP:-localhost}"
INDEXER_IP="${SENTINELCORE_INDEXER_IP:-localhost}"
API_USER="${SENTINELCORE_API_USER:-wazuh-wui}"
API_PASS="${SENTINELCORE_API_PASS:-SENTINELCORE_AUTH_PASS}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ERRORS=0

check() {
    local name="$1" result="$2"
    if [[ "${result}" == "OK" ]]; then
        echo -e "  ${GREEN}✓${NC} ${name}"
    else
        echo -e "  ${RED}✗${NC} ${name}: ${result}"
        ERRORS=$((ERRORS + 1))
    fi
}

echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  SentinelCore Cluster Health Check             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# Manager checks
echo -e "${BLUE}Manager (${MANAGER_IP}):${NC}"
if systemctl is-active --quiet wazuh-manager 2>/dev/null; then
    check "Service" "OK"
else
    check "Service" "NOT RUNNING"
fi

API_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${MANAGER_IP}:55000/" 2>/dev/null || echo "000")
[[ "${API_CODE}" =~ ^(200|401)$ ]] && check "API (port 55000)" "OK" || check "API (port 55000)" "HTTP ${API_CODE}"

for port in 1514 1515; do
    ss -tlnp 2>/dev/null | grep -q ":${port} " && check "Port ${port}" "OK" || check "Port ${port}" "NOT LISTENING"
done

echo ""

# Indexer checks
echo -e "${BLUE}Indexer (${INDEXER_IP}):${NC}"
if systemctl is-active --quiet wazuh-indexer 2>/dev/null; then
    check "Service" "OK"
else
    check "Service" "NOT RUNNING"
fi

HEALTH=$(curl -sk -u "${API_USER}:${API_PASS}" "https://${INDEXER_IP}:9200/_cluster/health" 2>/dev/null)
if [[ -n "${HEALTH}" ]]; then
    STATUS=$(echo "${HEALTH}" | jq -r '.status' 2>/dev/null || echo "unknown")
    case "${STATUS}" in
        green)  check "Cluster health" "OK (green)" ;;
        yellow) echo -e "  ${YELLOW}⚠${NC} Cluster health: YELLOW"; ERRORS=$((ERRORS + 1)) ;;
        *)      check "Cluster health" "${STATUS}" ;;
    esac
    NODES=$(echo "${HEALTH}" | jq -r '.number_of_nodes' 2>/dev/null || echo "?")
    check "Nodes" "OK (${NODES} nodes)"
else
    check "Connection" "UNREACHABLE"
fi

echo ""

# Filebeat checks
echo -e "${BLUE}Filebeat:${NC}"
if systemctl is-active --quiet filebeat 2>/dev/null; then
    check "Service" "OK"
else
    check "Service" "NOT RUNNING"
fi

echo ""

# Summary
if [[ ${ERRORS} -eq 0 ]]; then
    echo -e "${GREEN}All checks passed ✓${NC}"
    exit 0
else
    echo -e "${RED}${ERRORS} check(s) failed ✗${NC}"
    exit 1
fi
