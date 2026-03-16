#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Linux Agent Installation Script
# ============================================================================
# Usage: sudo bash install-agent.sh --manager-ip <IP> --agent-name <NAME> [OPTIONS]
#
# Options:
#   --manager-ip IP       Manager IP address (required)
#   --agent-name NAME     Agent name (default: hostname)
#   --agent-group GROUP   Agent group (default: linux)
#   --version VERSION     Wazuh version (default: 4.9.0)
#   --password PASS       Registration password
#   --help                Show this help message
#
# Supports: Ubuntu/Debian, RHEL/CentOS/Rocky/Alma, Amazon Linux
# ============================================================================

set -euo pipefail

# ========================= Configuration ====================================
MANAGER_IP="${SENTINELCORE_MANAGER_IP:-}"
AGENT_NAME="${AGENT_NAME:-$(hostname)}"
AGENT_GROUP="${AGENT_GROUP:-linux}"
WAZUH_VERSION="${WAZUH_VERSION:-4.9.0}"
REG_PASSWORD="${SENTINELCORE_AGENT_PASS:-}"
OSSEC_DIR="/var/ossec"
INSTALL_LOG="/var/log/sentinelcore-agent-install.log"

# ========================= Colors ===========================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()         { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "${INSTALL_LOG}"; }
log_success() { log "${GREEN}✓ $1${NC}"; }
log_warning() { log "${YELLOW}⚠ $1${NC}"; }
log_error()   { log "${RED}✗ $1${NC}"; }
log_step()    { echo ""; log "${BLUE}━━━ $1 ━━━${NC}"; }

show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   SentinelCore Agent - Linux Installer         ║"
    echo "║   Version: ${WAZUH_VERSION}                            ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ========================= Parse Arguments ==================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --manager-ip)   MANAGER_IP="$2"; shift 2 ;;
        --agent-name)   AGENT_NAME="$2"; shift 2 ;;
        --agent-group)  AGENT_GROUP="$2"; shift 2 ;;
        --version)      WAZUH_VERSION="$2"; shift 2 ;;
        --password)     REG_PASSWORD="$2"; shift 2 ;;
        --help)         head -18 "$0" | grep "^#" | sed 's/^# *//'; exit 0 ;;
        *)              log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# ========================= Validation =======================================
check_root() {
    [[ $EUID -ne 0 ]] && { log_error "Must run as root"; exit 1; }
}

validate_input() {
    if [[ -z "${MANAGER_IP}" ]]; then
        log_error "Manager IP is required. Use --manager-ip <IP>"
        exit 1
    fi
    log_success "Manager IP: ${MANAGER_IP}"
    log_success "Agent Name: ${AGENT_NAME}"
    log_success "Agent Group: ${AGENT_GROUP}"
}

detect_os() {
    . /etc/os-release 2>/dev/null || { log_error "Cannot detect OS"; exit 1; }
    case "${ID}" in
        ubuntu|debian) OS_FAMILY="debian" ;;
        rhel|centos|rocky|almalinux|fedora|amzn) OS_FAMILY="redhat" ;;
        *) log_error "Unsupported OS: ${ID}"; exit 1 ;;
    esac
    log_success "OS: ${ID} ${VERSION_ID} (${OS_FAMILY})"
}

# ========================= Install ==========================================
install_dependencies() {
    log_step "Installing Dependencies"
    case "${OS_FAMILY}" in
        debian) apt-get update -qq && apt-get install -y -qq curl apt-transport-https gnupg2 ;;
        redhat) yum install -y -q curl ;;
    esac
    log_success "Dependencies installed"
}

add_repo() {
    log_step "Adding Wazuh Repository"
    local GPG_KEY="https://packages.wazuh.com/key/GPG-KEY-WAZUH"
    case "${OS_FAMILY}" in
        debian)
            curl -s "${GPG_KEY}" | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import 2>/dev/null && chmod 644 /usr/share/keyrings/wazuh.gpg
            echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
            apt-get update -qq
            ;;
        redhat)
            rpm --import "${GPG_KEY}"
            cat > /etc/yum.repos.d/wazuh.repo << 'REPO'
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh repository
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
REPO
            ;;
    esac
    log_success "Repository added"
}

install_agent() {
    log_step "Installing SentinelCore Agent"

    export WAZUH_MANAGER="${MANAGER_IP}"
    export WAZUH_AGENT_NAME="${AGENT_NAME}"
    export WAZUH_AGENT_GROUP="${AGENT_GROUP}"

    if [[ -n "${REG_PASSWORD}" ]]; then
        export WAZUH_REGISTRATION_PASSWORD="${REG_PASSWORD}"
    fi

    case "${OS_FAMILY}" in
        debian)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "wazuh-agent=${WAZUH_VERSION}-1"
            ;;
        redhat)
            yum install -y -q "wazuh-agent-${WAZUH_VERSION}"
            ;;
    esac
    log_success "Agent package installed"
}

configure_agent() {
    log_step "Configuring Agent"
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Deploy custom config
    if [[ -f "${SCRIPT_DIR}/ossec.conf" ]]; then
        cp "${OSSEC_DIR}/etc/ossec.conf" "${OSSEC_DIR}/etc/ossec.conf.bak"
        cp "${SCRIPT_DIR}/ossec.conf" "${OSSEC_DIR}/etc/ossec.conf"
        sed -i "s/SENTINELCORE_MANAGER_IP/${MANAGER_IP}/g" "${OSSEC_DIR}/etc/ossec.conf"
        log_success "Custom config deployed"
    else
        # Just update manager IP in existing config
        sed -i "s|<address>.*</address>|<address>${MANAGER_IP}</address>|" "${OSSEC_DIR}/etc/ossec.conf"
        log_success "Manager IP set in config"
    fi

    chown -R wazuh:wazuh "${OSSEC_DIR}/etc/"
    chmod 640 "${OSSEC_DIR}/etc/ossec.conf"
}

start_agent() {
    log_step "Starting SentinelCore Agent"
    systemctl daemon-reload
    systemctl enable wazuh-agent
    systemctl start wazuh-agent

    sleep 5
    if systemctl is-active --quiet wazuh-agent; then
        log_success "Agent is running"
    else
        log_error "Agent failed to start. Check: ${OSSEC_DIR}/logs/ossec.log"
        exit 1
    fi
}

verify_agent() {
    log_step "Verifying Agent"

    if systemctl is-active --quiet wazuh-agent; then
        log_success "Service: Active"
    else
        log_error "Service: Inactive"
    fi

    # Check agent status
    local agent_status
    agent_status=$(${OSSEC_DIR}/bin/wazuh-control status 2>/dev/null || echo "unknown")
    log "Status: ${agent_status}"

    # Check manager connection
    if grep -q "Connected to" "${OSSEC_DIR}/logs/ossec.log" 2>/dev/null; then
        log_success "Connected to manager"
    else
        log_warning "May not yet be connected to manager (check logs)"
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  SentinelCore Agent - Install Complete         ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Agent Name: ${AGENT_NAME}${NC}"
    echo -e "${GREEN}║  Manager:    ${MANAGER_IP}${NC}"
    echo -e "${GREEN}║  Group:      ${AGENT_GROUP}${NC}"
    echo -e "${GREEN}║  Config:     ${OSSEC_DIR}/etc/ossec.conf${NC}"
    echo -e "${GREEN}║  Logs:       ${OSSEC_DIR}/logs/ossec.log${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
}

# ========================= Main =============================================
main() {
    show_banner
    check_root
    validate_input
    detect_os
    install_dependencies
    add_repo
    install_agent
    configure_agent
    start_agent
    verify_agent
    print_summary
}

mkdir -p "$(dirname "${INSTALL_LOG}")"
main 2>&1 | tee -a "${INSTALL_LOG}"
