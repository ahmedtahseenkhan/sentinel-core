#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Agent Self-Update Script
# ============================================================================
# Usage: sudo bash agent-upgrade.sh [--version VERSION] [--force]
# Upgrades the Wazuh agent to the specified version.
# ============================================================================

set -euo pipefail

TARGET_VERSION="${1:-}"
FORCE="no"
OSSEC_DIR="/var/ossec"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()         { echo -e "[$(date '+%H:%M:%S')] $1"; }
log_success() { log "${GREEN}✓ $1${NC}"; }
log_error()   { log "${RED}✗ $1${NC}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) TARGET_VERSION="$2"; shift 2 ;;
        --force)   FORCE="yes"; shift ;;
        --help)    echo "Usage: sudo bash agent-upgrade.sh [--version VERSION] [--force]"; exit 0 ;;
        *)         shift ;;
    esac
done

[[ $EUID -ne 0 ]] && { log_error "Must run as root"; exit 1; }
[[ ! -d "${OSSEC_DIR}" ]] && { log_error "Agent not installed"; exit 1; }

# Get current version
CURRENT_VERSION=$(${OSSEC_DIR}/bin/wazuh-control info 2>/dev/null | grep "WAZUH_VERSION" | cut -d'=' -f2 | tr -d '"' || echo "unknown")
log "Current version: ${CURRENT_VERSION}"

if [[ -z "${TARGET_VERSION}" ]]; then
    log_error "Target version required: --version <VERSION>"
    exit 1
fi

if [[ "${CURRENT_VERSION}" == "${TARGET_VERSION}" && "${FORCE}" != "yes" ]]; then
    log_success "Already at version ${TARGET_VERSION}. Use --force to reinstall."
    exit 0
fi

log "Upgrading from ${CURRENT_VERSION} to ${TARGET_VERSION}..."

# Backup config
cp "${OSSEC_DIR}/etc/ossec.conf" "${OSSEC_DIR}/etc/ossec.conf.pre-upgrade.$(date +%Y%m%d)"
log_success "Configuration backed up"

# Detect OS
. /etc/os-release 2>/dev/null
case "${ID}" in
    ubuntu|debian)
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "wazuh-agent=${TARGET_VERSION}-1"
        ;;
    rhel|centos|rocky|almalinux|fedora|amzn)
        yum install -y -q "wazuh-agent-${TARGET_VERSION}"
        ;;
    *)
        log_error "Unsupported OS: ${ID}"
        exit 1
        ;;
esac

# Restart agent
systemctl restart wazuh-agent
sleep 3

NEW_VERSION=$(${OSSEC_DIR}/bin/wazuh-control info 2>/dev/null | grep "WAZUH_VERSION" | cut -d'=' -f2 | tr -d '"' || echo "unknown")

if [[ "${NEW_VERSION}" == "${TARGET_VERSION}" ]]; then
    log_success "Upgrade complete: ${CURRENT_VERSION} → ${NEW_VERSION}"
else
    log_error "Upgrade may have failed. Current: ${NEW_VERSION}, Expected: ${TARGET_VERSION}"
    exit 1
fi
