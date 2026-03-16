#!/usr/bin/env bash
# ============================================================================
# SentinelCore Indexer - Installation Script
# ============================================================================
# Usage: sudo bash install-indexer.sh [OPTIONS]
#
# Options:
#   --version VERSION      Wazuh indexer version (default: 4.9.0)
#   --indexer-ip IP        Indexer bind IP
#   --node-name NAME       Node name (default: sentinelcore-indexer-1)
#   --heap-size SIZE       JVM heap size (default: auto-detected)
#   --help                 Show this help message
# ============================================================================

set -euo pipefail

# ========================= Configuration ====================================
WAZUH_VERSION="${WAZUH_VERSION:-4.9.0}"
INDEXER_IP="${SENTINELCORE_INDEXER_IP:-127.0.0.1}"
NODE_NAME="${SENTINELCORE_INDEXER_NODE:-sentinelcore-indexer-1}"
HEAP_SIZE=""
INSTALL_LOG="/var/log/sentinelcore-indexer-install.log"

# ========================= Colors ===========================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()         { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "${INSTALL_LOG}"; }
log_success() { log "${GREEN}✓ $1${NC}"; }
log_error()   { log "${RED}✗ $1${NC}"; }
log_step()    { echo ""; log "${BLUE}━━━ $1 ━━━${NC}"; }

show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   SentinelCore Indexer Installation            ║"
    echo "║   Version: ${WAZUH_VERSION}                            ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ========================= Parse Arguments ==================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)    WAZUH_VERSION="$2"; shift 2 ;;
        --indexer-ip) INDEXER_IP="$2"; shift 2 ;;
        --node-name)  NODE_NAME="$2"; shift 2 ;;
        --heap-size)  HEAP_SIZE="$2"; shift 2 ;;
        --help)       head -16 "$0" | grep "^#" | sed 's/^# *//'; exit 0 ;;
        *)            log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# ========================= Functions ========================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

detect_os() {
    . /etc/os-release 2>/dev/null || { log_error "Cannot detect OS"; exit 1; }
    case "${ID}" in
        ubuntu|debian) OS_FAMILY="debian" ;;
        rhel|centos|rocky|almalinux|fedora|amzn) OS_FAMILY="redhat" ;;
        *) log_error "Unsupported OS: ${ID}"; exit 1 ;;
    esac
    log_success "Detected: ${ID} ${VERSION_ID} (${OS_FAMILY})"
}

auto_detect_heap() {
    if [[ -z "${HEAP_SIZE}" ]]; then
        local total_ram_mb
        total_ram_mb=$(free -m | awk '/MemTotal/{print $2}')
        local heap_mb=$((total_ram_mb / 2))
        # Cap at 32GB
        if [[ ${heap_mb} -gt 32768 ]]; then
            heap_mb=32768
        fi
        # Minimum 1GB
        if [[ ${heap_mb} -lt 1024 ]]; then
            heap_mb=1024
        fi
        HEAP_SIZE="${heap_mb}m"
        log_success "Auto-detected heap size: ${HEAP_SIZE} (${total_ram_mb}MB total RAM)"
    fi
}

install_dependencies() {
    log_step "Installing Dependencies"
    case "${OS_FAMILY}" in
        debian)
            apt-get update -qq
            apt-get install -y -qq curl apt-transport-https gnupg2
            ;;
        redhat)
            yum install -y -q curl
            ;;
    esac
    log_success "Dependencies installed"
}

add_wazuh_repo() {
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
    log_success "Wazuh repository added"
}

install_indexer() {
    log_step "Installing SentinelCore Indexer"
    case "${OS_FAMILY}" in
        debian)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "wazuh-indexer=${WAZUH_VERSION}-1"
            ;;
        redhat)
            yum install -y -q "wazuh-indexer-${WAZUH_VERSION}"
            ;;
    esac
    log_success "Indexer package installed"
}

configure_indexer() {
    log_step "Configuring SentinelCore Indexer"
    local OPENSEARCH_YML="/etc/wazuh-indexer/opensearch.yml"
    local JVM_OPTIONS="/etc/wazuh-indexer/jvm.options"
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local REPO_ROOT="${SCRIPT_DIR}/.."

    # Backup originals
    [[ -f "${OPENSEARCH_YML}" ]] && cp "${OPENSEARCH_YML}" "${OPENSEARCH_YML}.bak"
    [[ -f "${JVM_OPTIONS}" ]] && cp "${JVM_OPTIONS}" "${JVM_OPTIONS}.bak"

    # Deploy custom config
    if [[ -f "${REPO_ROOT}/opensearch.yml" ]]; then
        cp "${REPO_ROOT}/opensearch.yml" "${OPENSEARCH_YML}"
        sed -i "s/SENTINELCORE_INDEXER_IP/${INDEXER_IP}/g" "${OPENSEARCH_YML}"
        log_success "OpenSearch config deployed"
    fi

    # Deploy JVM options
    if [[ -f "${REPO_ROOT}/jvm.options" ]]; then
        cp "${REPO_ROOT}/jvm.options" "${JVM_OPTIONS}"
    fi

    # Set heap size
    auto_detect_heap
    sed -i "s/-Xms4g/-Xms${HEAP_SIZE}/g" "${JVM_OPTIONS}"
    sed -i "s/-Xmx4g/-Xmx${HEAP_SIZE}/g" "${JVM_OPTIONS}"
    log_success "JVM heap set to ${HEAP_SIZE}"

    # Set memory lock
    mkdir -p /etc/systemd/system/wazuh-indexer.service.d/
    cat > /etc/systemd/system/wazuh-indexer.service.d/override.conf << EOF
[Service]
LimitMEMLOCK=infinity
EOF
    systemctl daemon-reload

    # Set permissions
    chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/
    log_success "Indexer configuration complete"
}

start_indexer() {
    log_step "Starting SentinelCore Indexer"
    systemctl daemon-reload
    systemctl enable wazuh-indexer
    systemctl start wazuh-indexer

    local retries=60
    while [[ ${retries} -gt 0 ]]; do
        if curl -s -o /dev/null -w "%{http_code}" -k "https://${INDEXER_IP}:9200" 2>/dev/null | grep -qE "200|401"; then
            log_success "Indexer is running and responding"
            return 0
        fi
        retries=$((retries - 1))
        sleep 3
    done
    log_error "Indexer failed to start. Check: journalctl -u wazuh-indexer"
    exit 1
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  SentinelCore Indexer - Install Complete       ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Endpoint: https://${INDEXER_IP}:9200          ║${NC}"
    echo -e "${GREEN}║  Node:     ${NODE_NAME}                       ║${NC}"
    echo -e "${GREEN}║  Heap:     ${HEAP_SIZE}                       ║${NC}"
    echo -e "${GREEN}║  Config:   /etc/wazuh-indexer/opensearch.yml  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
}

# ========================= Main =============================================
main() {
    show_banner
    check_root
    detect_os
    install_dependencies
    add_wazuh_repo
    install_indexer
    configure_indexer
    start_indexer
    print_summary
}

mkdir -p "$(dirname "${INSTALL_LOG}")"
main 2>&1 | tee -a "${INSTALL_LOG}"
