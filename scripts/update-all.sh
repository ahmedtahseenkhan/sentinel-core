#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Update All Components
# ============================================================================
# Usage: sudo bash update-all.sh --version <VERSION>
# ============================================================================

set -euo pipefail

VERSION="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --help)    echo "Usage: sudo bash update-all.sh --version <VERSION>"; exit 0 ;;
        *)         shift ;;
    esac
done

[[ $EUID -ne 0 ]] && { echo -e "${RED}Must run as root${NC}"; exit 1; }
[[ -z "${VERSION}" ]] && { echo -e "${RED}--version is required${NC}"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}Updating SentinelCore to version ${VERSION}...${NC}"
echo ""

# Backup first
echo -e "${BLUE}Creating backup...${NC}"
bash "${SCRIPT_DIR}/backup-all.sh" || true

# Detect OS
. /etc/os-release
case "${ID}" in
    ubuntu|debian) PKG="apt-get" ;;
    rhel|centos|*) PKG="yum" ;;
esac

# Update Manager
echo -e "${BLUE}Updating Manager...${NC}"
systemctl stop wazuh-manager
${PKG} install -y "wazuh-manager=${VERSION}-1" 2>/dev/null || ${PKG} install -y "wazuh-manager-${VERSION}" 2>/dev/null
systemctl start wazuh-manager
echo -e "${GREEN}✓ Manager updated${NC}"

# Update Indexer
echo -e "${BLUE}Updating Indexer...${NC}"
systemctl stop wazuh-indexer
${PKG} install -y "wazuh-indexer=${VERSION}-1" 2>/dev/null || ${PKG} install -y "wazuh-indexer-${VERSION}" 2>/dev/null
systemctl start wazuh-indexer
echo -e "${GREEN}✓ Indexer updated${NC}"

# Health check
echo ""
bash "${SCRIPT_DIR}/../monitoring/health-checks/check-cluster.sh" || true

echo ""
echo -e "${GREEN}Update to ${VERSION} complete!${NC}"
