#!/usr/bin/env bash
# ============================================================================
# SentinelCore Manager - Post-Installation Configuration Script
# ============================================================================
# Usage: sudo bash configure-manager.sh [OPTIONS]
#
# Options:
#   --email EMAIL       Admin email for alerts
#   --domain DOMAIN     Company domain
#   --smtp-server HOST  SMTP server hostname
#   --api-user USER     API admin username (default: wazuh-wui)
#   --api-pass PASS     API admin password
#   --agent-pass PASS   Agent registration password
#   --help              Show this help message
# ============================================================================

set -euo pipefail

# ========================= Configuration ====================================
OSSEC_DIR="/var/ossec"
OSSEC_CONF="${OSSEC_DIR}/etc/ossec.conf"
ADMIN_EMAIL="${SENTINELCORE_ADMIN_EMAIL:-admin@SENTINELCORE_DOMAIN}"
COMPANY_DOMAIN="${SENTINELCORE_DOMAIN:-sentinelcore.local}"
SMTP_SERVER="smtp.${COMPANY_DOMAIN}"
API_USER="wazuh-wui"
API_PASSWORD="${SENTINELCORE_AUTH_PASS:-}"
AGENT_PASSWORD="${SENTINELCORE_AGENT_PASS:-}"

# ========================= Colors ===========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()         { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }

# ========================= Parse Arguments ==================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --email)       ADMIN_EMAIL="$2"; shift 2 ;;
        --domain)      COMPANY_DOMAIN="$2"; shift 2 ;;
        --smtp-server) SMTP_SERVER="$2"; shift 2 ;;
        --api-user)    API_USER="$2"; shift 2 ;;
        --api-pass)    API_PASSWORD="$2"; shift 2 ;;
        --agent-pass)  AGENT_PASSWORD="$2"; shift 2 ;;
        --help)        head -16 "$0" | grep "^#" | sed 's/^# *//'; exit 0 ;;
        *)             log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# ========================= Functions ========================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_manager_installed() {
    if [[ ! -d "${OSSEC_DIR}" ]]; then
        log_error "Wazuh Manager not found at ${OSSEC_DIR}. Install first."
        exit 1
    fi
    log_success "Manager installation found at ${OSSEC_DIR}"
}

configure_email_alerts() {
    log "Configuring email alerts..."

    if [[ -f "${OSSEC_CONF}" ]]; then
        sed -i "s|SENTINELCORE_ADMIN_EMAIL|${ADMIN_EMAIL}|g" "${OSSEC_CONF}"
        sed -i "s|SENTINELCORE_DOMAIN|${COMPANY_DOMAIN}|g" "${OSSEC_CONF}"
        sed -i "s|smtp\.SENTINELCORE_DOMAIN|${SMTP_SERVER}|g" "${OSSEC_CONF}"
        log_success "Email alerts configured: ${ADMIN_EMAIL}"
    else
        log_warning "ossec.conf not found, skipping email configuration"
    fi
}

configure_api_user() {
    log "Configuring API user..."

    if [[ -z "${API_PASSWORD}" ]]; then
        API_PASSWORD=$(openssl rand -base64 24)
        log_warning "Generated random API password: ${API_PASSWORD}"
    fi

    # Change API user password using Wazuh API tools
    if [[ -x "${OSSEC_DIR}/bin/wazuh-control" ]]; then
        # Create Python script to update API user
        local api_script="/tmp/sentinelcore_api_setup.py"
        cat > "${api_script}" << PYEOF
#!/usr/bin/env python3
import json
import subprocess
import sys

try:
    result = subprocess.run(
        ["${OSSEC_DIR}/framework/python/bin/python3", "-c",
         "from wazuh.core.security import update_user; print(update_user('${API_USER}', password='${API_PASSWORD}'))"],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode == 0:
        print("API user configured successfully")
    else:
        print(f"Warning: {result.stderr}", file=sys.stderr)
except Exception as e:
    print(f"Warning: Could not configure API user: {e}", file=sys.stderr)
PYEOF
        python3 "${api_script}" 2>/dev/null || log_warning "API user config may need manual setup"
        rm -f "${api_script}"
    fi

    log_success "API user configuration attempted"
}

configure_agent_registration() {
    log "Configuring agent registration..."

    if [[ -z "${AGENT_PASSWORD}" ]]; then
        AGENT_PASSWORD=$(openssl rand -base64 16)
        log_warning "Generated registration password: ${AGENT_PASSWORD}"
    fi

    echo "${AGENT_PASSWORD}" > "${OSSEC_DIR}/etc/authd.pass"
    chmod 640 "${OSSEC_DIR}/etc/authd.pass"
    chown root:wazuh "${OSSEC_DIR}/etc/authd.pass"

    log_success "Agent registration password configured"
}

configure_shared_groups() {
    log "Setting up agent groups..."

    # Create default groups
    for group in linux windows servers workstations dmz; do
        local group_dir="${OSSEC_DIR}/etc/shared/${group}"
        if [[ ! -d "${group_dir}" ]]; then
            mkdir -p "${group_dir}"
            chown wazuh:wazuh "${group_dir}"
            log_success "Created agent group: ${group}"
        fi
    done

    # Copy group-specific configs if available
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local REPO_ROOT="${SCRIPT_DIR}/.."

    if [[ -f "${REPO_ROOT}/etc/shared/groups/linux/agent.conf" ]]; then
        cp "${REPO_ROOT}/etc/shared/groups/linux/agent.conf" "${OSSEC_DIR}/etc/shared/linux/agent.conf"
        chown wazuh:wazuh "${OSSEC_DIR}/etc/shared/linux/agent.conf"
        log_success "Linux group config deployed"
    fi

    if [[ -f "${REPO_ROOT}/etc/shared/groups/windows/agent.conf" ]]; then
        cp "${REPO_ROOT}/etc/shared/groups/windows/agent.conf" "${OSSEC_DIR}/etc/shared/windows/agent.conf"
        chown wazuh:wazuh "${OSSEC_DIR}/etc/shared/windows/agent.conf"
        log_success "Windows group config deployed"
    fi
}

configure_integrations() {
    log "Configuring integrations directory..."

    local integrations_dir="${OSSEC_DIR}/integrations"
    mkdir -p "${integrations_dir}"
    chown wazuh:wazuh "${integrations_dir}"

    log_success "Integrations directory configured"
}

restart_services() {
    log "Restarting SentinelCore Manager..."

    systemctl restart wazuh-manager

    local retries=20
    while [[ ${retries} -gt 0 ]]; do
        if systemctl is-active --quiet wazuh-manager; then
            log_success "Manager restarted successfully"
            return 0
        fi
        retries=$((retries - 1))
        sleep 2
    done

    log_error "Manager failed to restart. Check: journalctl -u wazuh-manager"
    exit 1
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  SentinelCore Manager - Configuration Done    ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Admin Email: ${ADMIN_EMAIL}${NC}"
    echo -e "${GREEN}║  API User:    ${API_USER}${NC}"
    echo -e "${GREEN}║  Domain:      ${COMPANY_DOMAIN}${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
    echo ""
}

# ========================= Main =============================================
main() {
    echo -e "${BLUE}SentinelCore Manager - Post-Installation Configuration${NC}"
    echo ""
    check_root
    check_manager_installed
    configure_email_alerts
    configure_api_user
    configure_agent_registration
    configure_shared_groups
    configure_integrations
    restart_services
    print_summary
}

main
