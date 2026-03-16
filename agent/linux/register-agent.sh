#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Linux Agent Auto-Registration Script
# ============================================================================
# Registers an existing agent with the SentinelCore Manager.
# Usage: sudo bash register-agent.sh --manager-ip <IP> [OPTIONS]
# ============================================================================

set -euo pipefail

MANAGER_IP="${SENTINELCORE_MANAGER_IP:-}"
AGENT_NAME="${AGENT_NAME:-$(hostname)}"
AGENT_GROUP="${AGENT_GROUP:-linux}"
REG_PASSWORD="${SENTINELCORE_AGENT_PASS:-}"
OSSEC_DIR="/var/ossec"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()         { echo -e "[$(date '+%H:%M:%S')] $1"; }
log_success() { log "${GREEN}✓ $1${NC}"; }
log_error()   { log "${RED}✗ $1${NC}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manager-ip)  MANAGER_IP="$2"; shift 2 ;;
        --agent-name)  AGENT_NAME="$2"; shift 2 ;;
        --agent-group) AGENT_GROUP="$2"; shift 2 ;;
        --password)    REG_PASSWORD="$2"; shift 2 ;;
        --help)        head -8 "$0" | grep "^#" | sed 's/^# *//'; exit 0 ;;
        *)             log_error "Unknown: $1"; exit 1 ;;
    esac
done

# Validate
[[ $EUID -ne 0 ]] && { log_error "Must run as root"; exit 1; }
[[ -z "${MANAGER_IP}" ]] && { log_error "--manager-ip is required"; exit 1; }
[[ ! -d "${OSSEC_DIR}" ]] && { log_error "Agent not installed at ${OSSEC_DIR}"; exit 1; }

# Stop agent if running
systemctl stop wazuh-agent 2>/dev/null || true

# Build registration command
REG_CMD="${OSSEC_DIR}/bin/agent-auth"
REG_ARGS="-m ${MANAGER_IP} -A ${AGENT_NAME} -G ${AGENT_GROUP}"

if [[ -n "${REG_PASSWORD}" ]]; then
    echo "${REG_PASSWORD}" > "${OSSEC_DIR}/etc/authd.pass"
    chmod 640 "${OSSEC_DIR}/etc/authd.pass"
    REG_ARGS="${REG_ARGS} -P ${OSSEC_DIR}/etc/authd.pass"
fi

log "Registering agent '${AGENT_NAME}' with manager ${MANAGER_IP}..."

if ${REG_CMD} ${REG_ARGS}; then
    log_success "Agent registered successfully"
else
    log_error "Registration failed. Check: ${OSSEC_DIR}/logs/ossec.log"
    exit 1
fi

# Update manager IP in config
sed -i "s|<address>.*</address>|<address>${MANAGER_IP}</address>|" "${OSSEC_DIR}/etc/ossec.conf"

# Restart agent
systemctl start wazuh-agent
sleep 3

if systemctl is-active --quiet wazuh-agent; then
    log_success "Agent started and connected"
    # Display agent info
    if [[ -f "${OSSEC_DIR}/etc/client.keys" ]]; then
        log "Agent ID: $(cut -d' ' -f1 "${OSSEC_DIR}/etc/client.keys" | tail -1)"
    fi
else
    log_error "Agent failed to start after registration"
    exit 1
fi
