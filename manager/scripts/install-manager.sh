#!/usr/bin/env bash
# ============================================================================
# SentinelCore Manager - Installation Script
# ============================================================================
# Usage: sudo bash install-manager.sh [OPTIONS]
#
# Options:
#   --version VERSION    Wazuh version to install (default: 4.9.0)
#   --cluster-key KEY    Cluster encryption key
#   --manager-ip IP      Manager IP address
#   --api-pass PASS      API user password
#   --help               Show this help message
#
# Prerequisites:
#   - Root privileges
#   - Ubuntu 20.04+, Debian 10+, RHEL 8+, or CentOS 8+
#   - Minimum 4GB RAM, 2 CPU cores
#   - Internet access (or offline packages)
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# ========================= Configuration ====================================
WAZUH_VERSION="${WAZUH_VERSION:-4.9.0}"
WAZUH_MANAGER_IP="${SENTINELCORE_MANAGER_IP:-127.0.0.1}"
CLUSTER_KEY="${SENTINELCORE_CLUSTER_KEY:-}"
API_PASSWORD="${SENTINELCORE_AUTH_PASS:-}"
NODE_NAME="sentinelcore-manager-1"
INSTALL_LOG="/var/log/sentinelcore-manager-install.log"

# ========================= Colors ===========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ========================= Functions ========================================

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[${timestamp}]${NC} $1" | tee -a "${INSTALL_LOG}"
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

log_warning() {
    log "${YELLOW}⚠ $1${NC}"
}

log_error() {
    log "${RED}✗ $1${NC}"
}

log_step() {
    echo ""
    log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${BLUE}  $1${NC}"
    log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║                                              ║"
    echo "║    SentinelCore Manager Installation          ║"
    echo "║    Version: ${WAZUH_VERSION}                           ║"
    echo "║                                              ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_help() {
    head -20 "$0" | grep "^#" | sed 's/^# *//'
    exit 0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="${ID}"
        OS_VERSION="${VERSION_ID}"
        OS_FAMILY=""
        case "${OS_NAME}" in
            ubuntu|debian)
                OS_FAMILY="debian"
                ;;
            rhel|centos|rocky|almalinux|fedora|amzn)
                OS_FAMILY="redhat"
                ;;
            *)
                log_error "Unsupported OS: ${OS_NAME}"
                exit 1
                ;;
        esac
        log_success "Detected OS: ${OS_NAME} ${OS_VERSION} (${OS_FAMILY})"
    else
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
}

check_requirements() {
    log_step "Checking System Requirements"

    # Check CPU cores
    local cpu_cores
    cpu_cores=$(nproc)
    if [[ ${cpu_cores} -lt 2 ]]; then
        log_warning "Minimum 2 CPU cores recommended (found: ${cpu_cores})"
    else
        log_success "CPU cores: ${cpu_cores}"
    fi

    # Check RAM
    local total_ram_mb
    total_ram_mb=$(free -m | awk '/MemTotal/{print $2}')
    if [[ ${total_ram_mb} -lt 3800 ]]; then
        log_warning "Minimum 4GB RAM recommended (found: ${total_ram_mb}MB)"
    else
        log_success "RAM: ${total_ram_mb}MB"
    fi

    # Check disk space
    local free_disk_gb
    free_disk_gb=$(df -BG / | awk 'NR==2{print $4}' | tr -d 'G')
    if [[ ${free_disk_gb} -lt 20 ]]; then
        log_error "Insufficient disk space. Need at least 20GB (found: ${free_disk_gb}GB)"
        exit 1
    fi
    log_success "Free disk: ${free_disk_gb}GB"

    # Check network connectivity
    if ping -c 1 packages.wazuh.com &>/dev/null; then
        log_success "Network connectivity: OK"
    else
        log_warning "Cannot reach packages.wazuh.com. Ensure network access or use offline install."
    fi
}

install_dependencies() {
    log_step "Installing Dependencies"

    case "${OS_FAMILY}" in
        debian)
            apt-get update -qq
            apt-get install -y -qq curl apt-transport-https lsb-release gnupg2 jq net-tools
            ;;
        redhat)
            yum install -y -q curl policycoreutils automake autoconf libtool jq net-tools
            ;;
    esac
    log_success "Dependencies installed"
}

add_wazuh_repo() {
    log_step "Adding Wazuh Repository"

    local GPG_KEY="https://packages.wazuh.com/key/GPG-KEY-WAZUH"

    case "${OS_FAMILY}" in
        debian)
            curl -s "${GPG_KEY}" | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
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
name=EL-$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
REPO
            ;;
    esac
    log_success "Wazuh repository added"
}

install_wazuh_manager() {
    log_step "Installing SentinelCore Manager (Wazuh ${WAZUH_VERSION})"

    case "${OS_FAMILY}" in
        debian)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wazuh-manager="${WAZUH_VERSION}-1"
            ;;
        redhat)
            yum install -y -q "wazuh-manager-${WAZUH_VERSION}"
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        log_success "SentinelCore Manager installed successfully"
    else
        log_error "Failed to install SentinelCore Manager"
        exit 1
    fi
}

configure_manager() {
    log_step "Configuring SentinelCore Manager"

    local OSSEC_CONF="/var/ossec/etc/ossec.conf"
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local REPO_ROOT="${SCRIPT_DIR}/.."

    # Backup original configuration
    if [[ -f "${OSSEC_CONF}" ]]; then
        cp "${OSSEC_CONF}" "${OSSEC_CONF}.bak.$(date +%Y%m%d%H%M%S)"
        log_success "Original config backed up"
    fi

    # Copy custom configuration
    if [[ -f "${REPO_ROOT}/etc/ossec.conf" ]]; then
        cp "${REPO_ROOT}/etc/ossec.conf" "${OSSEC_CONF}"
        log_success "Custom ossec.conf deployed"
    fi

    # Copy custom rules
    if [[ -f "${REPO_ROOT}/etc/local_rules.xml" ]]; then
        cp "${REPO_ROOT}/etc/local_rules.xml" /var/ossec/etc/rules/local_rules.xml
        log_success "Custom rules deployed"
    fi

    # Copy custom decoders
    if [[ -f "${REPO_ROOT}/etc/local_decoders.xml" ]]; then
        cp "${REPO_ROOT}/etc/local_decoders.xml" /var/ossec/etc/decoders/local_decoder.xml
        log_success "Custom decoders deployed"
    fi

    # Replace placeholders in configuration
    if [[ -n "${WAZUH_MANAGER_IP}" ]]; then
        sed -i "s/SENTINELCORE_MANAGER_IP/${WAZUH_MANAGER_IP}/g" "${OSSEC_CONF}"
    fi

    # Set authd password
    if [[ -n "${API_PASSWORD}" ]]; then
        echo "${API_PASSWORD}" > /var/ossec/etc/authd.pass
        chmod 640 /var/ossec/etc/authd.pass
        chown root:wazuh /var/ossec/etc/authd.pass
        log_success "Auth password configured"
    fi

    # Set proper permissions
    chown -R wazuh:wazuh /var/ossec/etc/
    chmod 640 "${OSSEC_CONF}"

    log_success "Manager configured"
}

start_manager() {
    log_step "Starting SentinelCore Manager"

    systemctl daemon-reload
    systemctl enable wazuh-manager
    systemctl start wazuh-manager

    # Wait for the service to be ready
    local retries=30
    while [[ ${retries} -gt 0 ]]; do
        if systemctl is-active --quiet wazuh-manager; then
            log_success "SentinelCore Manager is running"
            return 0
        fi
        retries=$((retries - 1))
        sleep 2
    done

    log_error "Manager failed to start. Check logs: /var/ossec/logs/ossec.log"
    exit 1
}

verify_installation() {
    log_step "Verifying Installation"

    # Check service status
    if systemctl is-active --quiet wazuh-manager; then
        log_success "Service: Running"
    else
        log_error "Service: Not running"
    fi

    # Check API
    local api_status
    api_status=$(curl -s -o /dev/null -w "%{http_code}" -k https://localhost:55000/ 2>/dev/null || echo "000")
    if [[ "${api_status}" == "401" || "${api_status}" == "200" ]]; then
        log_success "API: Responding (HTTP ${api_status})"
    else
        log_warning "API: Not responding (HTTP ${api_status})"
    fi

    # Check listening ports
    for port in 1514 1515 55000; do
        if ss -tlnp | grep -q ":${port} "; then
            log_success "Port ${port}: Listening"
        else
            log_warning "Port ${port}: Not listening"
        fi
    done

    # Print version
    local version
    version=$(/var/ossec/bin/wazuh-control info 2>/dev/null | grep "WAZUH_VERSION" | cut -d'=' -f2 || echo "unknown")
    log_success "Installed version: ${version}"
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   SentinelCore Manager - Install Complete    ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  API:   https://localhost:55000              ║${NC}"
    echo -e "${GREEN}║  Logs:  /var/ossec/logs/ossec.log            ║${NC}"
    echo -e "${GREEN}║  Config:/var/ossec/etc/ossec.conf            ║${NC}"
    echo -e "${GREEN}║  Log:   ${INSTALL_LOG}  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

# ========================= Parse Arguments ==================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)    WAZUH_VERSION="$2"; shift 2 ;;
        --cluster-key) CLUSTER_KEY="$2"; shift 2 ;;
        --manager-ip) WAZUH_MANAGER_IP="$2"; shift 2 ;;
        --api-pass)   API_PASSWORD="$2"; shift 2 ;;
        --help)       show_help ;;
        *)            log_error "Unknown option: $1"; show_help ;;
    esac
done

# ========================= Main Execution ===================================
main() {
    show_banner
    check_root
    detect_os
    check_requirements
    install_dependencies
    add_wazuh_repo
    install_wazuh_manager
    configure_manager
    start_manager
    verify_installation
    print_summary
}

# Create log directory
mkdir -p "$(dirname "${INSTALL_LOG}")"
main 2>&1 | tee -a "${INSTALL_LOG}"
