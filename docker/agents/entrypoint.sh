#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Docker Agent Entrypoint
# ============================================================================
# Configures and starts the Wazuh agent inside a Docker container.
#
# Environment Variables:
#   WAZUH_MANAGER         - Manager IP/hostname (required)
#   WAZUH_AGENT_NAME      - Agent name (default: container hostname)
#   WAZUH_AGENT_GROUP     - Agent group (default: linux)
#   WAZUH_REGISTRATION_PASSWORD - Registration password (optional)
# ============================================================================

set -e

MANAGER="${WAZUH_MANAGER:-}"
AGENT_NAME="${WAZUH_AGENT_NAME:-$(hostname)}"
AGENT_GROUP="${WAZUH_AGENT_GROUP:-linux}"
REG_PASSWORD="${WAZUH_REGISTRATION_PASSWORD:-}"
OSSEC_DIR="/var/ossec"

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║   SentinelCore Agent - Docker Container        ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

# Validate
if [[ -z "${MANAGER}" ]]; then
    echo "ERROR: WAZUH_MANAGER environment variable is required"
    exit 1
fi

echo "  Manager:    ${MANAGER}"
echo "  Agent Name: ${AGENT_NAME}"
echo "  Group:      ${AGENT_GROUP}"
echo ""

# Apply custom config if available
if [[ -f /opt/sentinelcore/ossec.conf ]]; then
    cp /opt/sentinelcore/ossec.conf "${OSSEC_DIR}/etc/ossec.conf"
    echo "✓ Custom SentinelCore config applied"
fi

# Set manager IP in config
sed -i "s|SENTINELCORE_MANAGER_IP|${MANAGER}|g" "${OSSEC_DIR}/etc/ossec.conf"
sed -i "s|<address>.*</address>|<address>${MANAGER}</address>|" "${OSSEC_DIR}/etc/ossec.conf"

# Register agent (if not already registered)
if [[ ! -f "${OSSEC_DIR}/etc/client.keys" ]] || [[ ! -s "${OSSEC_DIR}/etc/client.keys" ]]; then
    echo "→ Registering agent with manager..."

    REG_ARGS="-m ${MANAGER} -A ${AGENT_NAME} -G ${AGENT_GROUP}"

    if [[ -n "${REG_PASSWORD}" ]]; then
        echo "${REG_PASSWORD}" > "${OSSEC_DIR}/etc/authd.pass"
        chmod 640 "${OSSEC_DIR}/etc/authd.pass"
        REG_ARGS="${REG_ARGS} -P ${OSSEC_DIR}/etc/authd.pass"
    fi

    # Retry registration (manager may not be ready yet)
    MAX_RETRIES=12
    RETRY_INTERVAL=10
    for i in $(seq 1 ${MAX_RETRIES}); do
        if ${OSSEC_DIR}/bin/agent-auth ${REG_ARGS} 2>/dev/null; then
            echo "✓ Agent registered successfully"
            break
        else
            if [[ ${i} -eq ${MAX_RETRIES} ]]; then
                echo "✗ Registration failed after ${MAX_RETRIES} attempts"
                exit 1
            fi
            echo "  Attempt ${i}/${MAX_RETRIES} failed, retrying in ${RETRY_INTERVAL}s..."
            sleep ${RETRY_INTERVAL}
        fi
    done
else
    echo "✓ Agent already registered"
fi

# Display agent ID
if [[ -f "${OSSEC_DIR}/etc/client.keys" ]]; then
    AGENT_ID=$(cut -d' ' -f1 "${OSSEC_DIR}/etc/client.keys" | tail -1)
    echo "  Agent ID: ${AGENT_ID}"
fi

echo ""
echo "→ Starting SentinelCore agent..."
echo ""

# Start the agent in the foreground (for Docker)
# Use wazuh-control to start all processes, then tail the log to keep container alive
${OSSEC_DIR}/bin/wazuh-control start

# Keep container running and follow logs
exec tail -F ${OSSEC_DIR}/logs/ossec.log
