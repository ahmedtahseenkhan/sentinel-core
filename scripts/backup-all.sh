#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Full System Backup
# ============================================================================
# Backs up all SentinelCore components (Manager, Indexer configs, Filebeat).
# Usage: sudo bash backup-all.sh [--dest DIR] [--retention DAYS]
# ============================================================================

set -euo pipefail

BACKUP_DEST="${BACKUP_DEST:-/var/backups/sentinelcore}"
RETENTION_DAYS=30
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dest)      BACKUP_DEST="$2"; shift 2 ;;
        --retention) RETENTION_DAYS="$2"; shift 2 ;;
        --help)      echo "Usage: sudo bash backup-all.sh [--dest DIR] [--retention DAYS]"; exit 0 ;;
        *)           shift ;;
    esac
done

[[ $EUID -ne 0 ]] && { echo -e "${RED}Must run as root${NC}"; exit 1; }

BACKUP_DIR="${BACKUP_DEST}/full-backup-${TIMESTAMP}"
mkdir -p "${BACKUP_DIR}"

echo -e "${BLUE}SentinelCore Full Backup${NC}"
echo "Destination: ${BACKUP_DIR}"
echo ""

# Manager backup
if [[ -d /var/ossec ]]; then
    echo -n "  Manager config... "
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    bash "${SCRIPT_DIR}/../manager/scripts/backup-manager.sh" --dest "${BACKUP_DIR}" --quiet 2>/dev/null && \
        echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAILED${NC}"
fi

# Indexer config backup
if [[ -d /etc/wazuh-indexer ]]; then
    echo -n "  Indexer config... "
    mkdir -p "${BACKUP_DIR}/indexer"
    cp -a /etc/wazuh-indexer/opensearch.yml "${BACKUP_DIR}/indexer/" 2>/dev/null
    cp -a /etc/wazuh-indexer/jvm.options "${BACKUP_DIR}/indexer/" 2>/dev/null
    cp -a /etc/wazuh-indexer/certs "${BACKUP_DIR}/indexer/" 2>/dev/null || true
    echo -e "${GREEN}OK${NC}"
fi

# Filebeat config backup
if [[ -d /etc/filebeat ]]; then
    echo -n "  Filebeat config... "
    mkdir -p "${BACKUP_DIR}/filebeat"
    cp -a /etc/filebeat/filebeat.yml "${BACKUP_DIR}/filebeat/" 2>/dev/null
    cp -a /etc/filebeat/certs "${BACKUP_DIR}/filebeat/" 2>/dev/null || true
    echo -e "${GREEN}OK${NC}"
fi

# Compress
echo -n "  Compressing... "
cd "${BACKUP_DEST}"
tar -czf "full-backup-${TIMESTAMP}.tar.gz" "full-backup-${TIMESTAMP}/" 2>/dev/null
rm -rf "${BACKUP_DIR}"
SIZE=$(du -sh "full-backup-${TIMESTAMP}.tar.gz" | cut -f1)
echo -e "${GREEN}OK (${SIZE})${NC}"

# Cleanup
find "${BACKUP_DEST}" -name "full-backup-*" -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true

echo ""
echo -e "${GREEN}Backup complete: ${BACKUP_DEST}/full-backup-${TIMESTAMP}.tar.gz${NC}"
