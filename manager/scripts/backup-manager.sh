#!/usr/bin/env bash
# ============================================================================
# SentinelCore Manager - Backup Script
# ============================================================================
# Usage: sudo bash backup-manager.sh [OPTIONS]
#
# Options:
#   --dest DIR       Backup destination directory (default: /var/backups/sentinelcore)
#   --retention DAYS Number of days to keep backups (default: 30)
#   --compress       Use gzip compression (default: yes)
#   --quiet          Suppress output
#   --help           Show this help message
#
# Creates a timestamped backup of all SentinelCore Manager data including
# configurations, rules, decoders, agent keys, and databases.
# ============================================================================

set -euo pipefail

# ========================= Configuration ====================================
OSSEC_DIR="/var/ossec"
BACKUP_DEST="${BACKUP_DEST:-/var/backups/sentinelcore}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
COMPRESS="yes"
QUIET="no"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_NAME="sentinelcore-manager-backup-${TIMESTAMP}"

# ========================= Colors ===========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    [[ "${QUIET}" == "yes" ]] && return
    echo -e "[$(date '+%H:%M:%S')] $1"
}

# ========================= Parse Arguments ==================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dest)       BACKUP_DEST="$2"; shift 2 ;;
        --retention)  RETENTION_DAYS="$2"; shift 2 ;;
        --compress)   COMPRESS="yes"; shift ;;
        --quiet)      QUIET="yes"; shift ;;
        --help)       head -18 "$0" | grep "^#" | sed 's/^# *//'; exit 0 ;;
        *)            echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ========================= Pre-flight Checks ================================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

if [[ ! -d "${OSSEC_DIR}" ]]; then
    echo -e "${RED}Error: Wazuh directory not found at ${OSSEC_DIR}${NC}"
    exit 1
fi

# ========================= Backup Process ===================================
BACKUP_DIR="${BACKUP_DEST}/${BACKUP_NAME}"

log "${GREEN}Starting SentinelCore Manager Backup${NC}"
log "Destination: ${BACKUP_DIR}"

mkdir -p "${BACKUP_DIR}"

# Backup configuration files
log "Backing up configuration files..."
mkdir -p "${BACKUP_DIR}/etc"
cp -a "${OSSEC_DIR}/etc/ossec.conf" "${BACKUP_DIR}/etc/" 2>/dev/null || true
cp -a "${OSSEC_DIR}/etc/internal_options.conf" "${BACKUP_DIR}/etc/" 2>/dev/null || true
cp -a "${OSSEC_DIR}/etc/local_internal_options.conf" "${BACKUP_DIR}/etc/" 2>/dev/null || true
cp -a "${OSSEC_DIR}/etc/client.keys" "${BACKUP_DIR}/etc/" 2>/dev/null || true
cp -a "${OSSEC_DIR}/etc/sslmanager.cert" "${BACKUP_DIR}/etc/" 2>/dev/null || true
cp -a "${OSSEC_DIR}/etc/sslmanager.key" "${BACKUP_DIR}/etc/" 2>/dev/null || true
cp -a "${OSSEC_DIR}/etc/authd.pass" "${BACKUP_DIR}/etc/" 2>/dev/null || true

# Backup custom rules and decoders
log "Backing up rules and decoders..."
mkdir -p "${BACKUP_DIR}/etc/rules" "${BACKUP_DIR}/etc/decoders"
cp -a "${OSSEC_DIR}/etc/rules/"* "${BACKUP_DIR}/etc/rules/" 2>/dev/null || true
cp -a "${OSSEC_DIR}/etc/decoders/"* "${BACKUP_DIR}/etc/decoders/" 2>/dev/null || true

# Backup shared agent configurations
log "Backing up shared agent configurations..."
if [[ -d "${OSSEC_DIR}/etc/shared" ]]; then
    cp -a "${OSSEC_DIR}/etc/shared" "${BACKUP_DIR}/etc/"
fi

# Backup lists (CDB lists)
log "Backing up CDB lists..."
if [[ -d "${OSSEC_DIR}/etc/lists" ]]; then
    cp -a "${OSSEC_DIR}/etc/lists" "${BACKUP_DIR}/etc/"
fi

# Backup API configuration
log "Backing up API configuration..."
mkdir -p "${BACKUP_DIR}/api"
cp -a "${OSSEC_DIR}/api/configuration/" "${BACKUP_DIR}/api/" 2>/dev/null || true

# Backup agent info (groups, keys)
log "Backing up agent information..."
mkdir -p "${BACKUP_DIR}/queue"
cp -a "${OSSEC_DIR}/queue/agent-groups" "${BACKUP_DIR}/queue/" 2>/dev/null || true
cp -a "${OSSEC_DIR}/queue/agent-info" "${BACKUP_DIR}/queue/" 2>/dev/null || true

# Backup databases
log "Backing up databases..."
mkdir -p "${BACKUP_DIR}/var/db"
cp -a "${OSSEC_DIR}/var/db/global.db" "${BACKUP_DIR}/var/db/" 2>/dev/null || true
cp -a "${OSSEC_DIR}/var/db/cluster.db" "${BACKUP_DIR}/var/db/" 2>/dev/null || true

# Create manifest
log "Creating backup manifest..."
cat > "${BACKUP_DIR}/MANIFEST.txt" << EOF
SentinelCore Manager Backup
===========================
Date:      $(date '+%Y-%m-%d %H:%M:%S %Z')
Hostname:  $(hostname)
Manager:   ${OSSEC_DIR}
Version:   $(${OSSEC_DIR}/bin/wazuh-control info 2>/dev/null | grep WAZUH_VERSION | cut -d= -f2 || echo 'unknown')
Agents:    $(${OSSEC_DIR}/bin/agent_control -l 2>/dev/null | grep -c "ID:" || echo '0')
EOF

find "${BACKUP_DIR}" -type f -printf '%P\t%s\t%T@\n' >> "${BACKUP_DIR}/MANIFEST.txt" 2>/dev/null || \
    find "${BACKUP_DIR}" -type f >> "${BACKUP_DIR}/MANIFEST.txt"

# Compress backup
if [[ "${COMPRESS}" == "yes" ]]; then
    log "Compressing backup..."
    cd "${BACKUP_DEST}"
    tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}/"
    rm -rf "${BACKUP_DIR}"
    BACKUP_FILE="${BACKUP_DEST}/${BACKUP_NAME}.tar.gz"
    local_size=$(du -sh "${BACKUP_FILE}" | cut -f1)
    log "${GREEN}✓ Backup compressed: ${BACKUP_FILE} (${local_size})${NC}"
else
    BACKUP_FILE="${BACKUP_DIR}"
    log "${GREEN}✓ Backup created: ${BACKUP_FILE}${NC}"
fi

# Cleanup old backups
if [[ ${RETENTION_DAYS} -gt 0 ]]; then
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."
    find "${BACKUP_DEST}" -name "sentinelcore-manager-backup-*" -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true
    log "Old backups cleaned"
fi

log "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${GREEN}Backup completed successfully!${NC}"
log "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
