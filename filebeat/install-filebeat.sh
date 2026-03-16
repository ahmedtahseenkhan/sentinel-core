#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Filebeat Installation Script
# ============================================================================
# Usage: sudo bash install-filebeat.sh [--indexer-ip IP] [--version VERSION]
# Installs and configures Filebeat on the SentinelCore Manager node.
# ============================================================================

set -euo pipefail

WAZUH_VERSION="${WAZUH_VERSION:-4.9.0}"
INDEXER_IP="${SENTINELCORE_INDEXER_IP:-127.0.0.1}"
FILEBEAT_VERSION="7.10.2"
INSTALL_LOG="/var/log/sentinelcore-filebeat-install.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()         { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "${INSTALL_LOG}"; }
log_success() { log "${GREEN}✓ $1${NC}"; }
log_error()   { log "${RED}✗ $1${NC}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --indexer-ip) INDEXER_IP="$2"; shift 2 ;;
        --version)    WAZUH_VERSION="$2"; shift 2 ;;
        --help)       head -8 "$0" | grep "^#" | sed 's/^# *//'; exit 0 ;;
        *)            shift ;;
    esac
done

[[ $EUID -ne 0 ]] && { log_error "Must run as root"; exit 1; }

# Detect OS
. /etc/os-release 2>/dev/null
case "${ID}" in
    ubuntu|debian) OS_FAMILY="debian" ;;
    rhel|centos|rocky|almalinux|fedora|amzn) OS_FAMILY="redhat" ;;
    *) log_error "Unsupported OS"; exit 1 ;;
esac

log "Installing Filebeat for SentinelCore..."

# Install Filebeat
case "${OS_FAMILY}" in
    debian)
        curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - 2>/dev/null
        apt-get install -y -qq filebeat="${FILEBEAT_VERSION}" 2>/dev/null || {
            # Fallback: download directly
            curl -sO "https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.4.tar.gz"
            apt-get install -y -qq filebeat
        }
        ;;
    redhat)
        yum install -y -q filebeat-"${FILEBEAT_VERSION}" 2>/dev/null || yum install -y -q filebeat
        ;;
esac
log_success "Filebeat installed"

# Deploy Wazuh module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
curl -sO "https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.4.tar.gz"
tar -xzf wazuh-filebeat-0.4.tar.gz -C /usr/share/filebeat/module 2>/dev/null || true
rm -f wazuh-filebeat-0.4.tar.gz

# Download alerts template
curl -so /etc/filebeat/wazuh-template.json "https://raw.githubusercontent.com/wazuh/wazuh/v${WAZUH_VERSION}/extensions/elasticsearch/7.x/wazuh-template.json" 2>/dev/null || true

# Deploy custom config
if [[ -f "${SCRIPT_DIR}/filebeat.yml" ]]; then
    cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak 2>/dev/null || true
    cp "${SCRIPT_DIR}/filebeat.yml" /etc/filebeat/filebeat.yml
    sed -i "s/SENTINELCORE_INDEXER_IP/${INDEXER_IP}/g" /etc/filebeat/filebeat.yml
    log_success "Custom Filebeat config deployed"
fi

# Deploy module config
if [[ -f "${SCRIPT_DIR}/modules.d/wazuh.yml" ]]; then
    mkdir -p /etc/filebeat/modules.d/
    cp "${SCRIPT_DIR}/modules.d/wazuh.yml" /etc/filebeat/modules.d/
    log_success "Wazuh module config deployed"
fi

# Create certs directory
mkdir -p /etc/filebeat/certs
log_success "Certificate directory created at /etc/filebeat/certs"

# Start Filebeat
systemctl daemon-reload
systemctl enable filebeat
systemctl start filebeat

sleep 3
if systemctl is-active --quiet filebeat; then
    log_success "Filebeat is running"
else
    log_error "Filebeat failed to start"
fi

# Test output
filebeat test output 2>&1 | tee -a "${INSTALL_LOG}" || log_error "Output test failed (expected if certs not yet deployed)"

log_success "Filebeat installation complete!"
