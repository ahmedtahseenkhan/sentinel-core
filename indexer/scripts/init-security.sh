#!/usr/bin/env bash
# ============================================================================
# SentinelCore Indexer - Security Plugin Initialization
# ============================================================================
# Initializes the OpenSearch security plugin with custom certificates
# and admin credentials for the SentinelCore deployment.
#
# Usage: sudo bash init-security.sh [--admin-cert PATH] [--admin-key PATH]
# ============================================================================

set -euo pipefail

INDEXER_DIR="/etc/wazuh-indexer"
SECURITY_PLUGIN="/usr/share/wazuh-indexer/plugins/opensearch-security"
SECURITY_TOOL="${SECURITY_PLUGIN}/tools/securityadmin.sh"
ADMIN_CERT="${INDEXER_DIR}/certs/admin.pem"
ADMIN_KEY="${INDEXER_DIR}/certs/admin-key.pem"
ROOT_CA="${INDEXER_DIR}/certs/root-ca.pem"
INDEXER_IP="${SENTINELCORE_INDEXER_IP:-127.0.0.1}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()         { echo -e "[$(date '+%H:%M:%S')] $1"; }
log_success() { log "${GREEN}✓ $1${NC}"; }
log_error()   { log "${RED}✗ $1${NC}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --admin-cert) ADMIN_CERT="$2"; shift 2 ;;
        --admin-key)  ADMIN_KEY="$2"; shift 2 ;;
        --help)       head -12 "$0" | grep "^#" | sed 's/^# *//'; exit 0 ;;
        *)            log_error "Unknown: $1"; exit 1 ;;
    esac
done

# Pre-flight checks
[[ $EUID -ne 0 ]] && { log_error "Must run as root"; exit 1; }
[[ ! -f "${SECURITY_TOOL}" ]] && { log_error "Security plugin not found at ${SECURITY_TOOL}"; exit 1; }
[[ ! -f "${ADMIN_CERT}" ]] && { log_error "Admin certificate not found: ${ADMIN_CERT}"; exit 1; }
[[ ! -f "${ADMIN_KEY}" ]] && { log_error "Admin key not found: ${ADMIN_KEY}"; exit 1; }
[[ ! -f "${ROOT_CA}" ]] && { log_error "Root CA not found: ${ROOT_CA}"; exit 1; }

log "Waiting for indexer to be ready..."
retries=30
while [[ ${retries} -gt 0 ]]; do
    if curl -sk "https://${INDEXER_IP}:9200" &>/dev/null; then
        break
    fi
    retries=$((retries - 1))
    sleep 2
done
[[ ${retries} -eq 0 ]] && { log_error "Indexer not responding"; exit 1; }

log "Initializing security plugin..."
export JAVA_HOME=/usr/share/wazuh-indexer/jdk

"${SECURITY_TOOL}" \
    -cd "${SECURITY_PLUGIN}/securityconfig/" \
    -icl \
    -nhnv \
    -cacert "${ROOT_CA}" \
    -cert "${ADMIN_CERT}" \
    -key "${ADMIN_KEY}" \
    -p 9200 \
    -h "${INDEXER_IP}"

if [[ $? -eq 0 ]]; then
    log_success "Security plugin initialized successfully"
else
    log_error "Security plugin initialization failed"
    exit 1
fi

# Verify
log "Verifying security setup..."
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
    --cert "${ADMIN_CERT}" --key "${ADMIN_KEY}" \
    "https://${INDEXER_IP}:9200/_plugins/_security/health" 2>/dev/null || echo "000")

if [[ "${HTTP_CODE}" == "200" ]]; then
    log_success "Security plugin is healthy (HTTP ${HTTP_CODE})"
else
    log_error "Security health check returned HTTP ${HTTP_CODE}"
fi

log_success "Security initialization complete"
