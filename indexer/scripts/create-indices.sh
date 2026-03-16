#!/usr/bin/env bash
# ============================================================================
# SentinelCore Indexer - Create Custom Indices
# ============================================================================
# Creates custom SentinelCore index templates and initial indices.
# Usage: sudo bash create-indices.sh [--indexer-ip IP] [--user USER] [--pass PASS]
# ============================================================================

set -euo pipefail

INDEXER_IP="${SENTINELCORE_INDEXER_IP:-127.0.0.1}"
INDEXER_PORT="9200"
ADMIN_USER="${SENTINELCORE_API_USER:-admin}"
ADMIN_PASS="${SENTINELCORE_AUTH_PASS:-admin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/../templates"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()         { echo -e "[$(date '+%H:%M:%S')] $1"; }
log_success() { log "${GREEN}✓ $1${NC}"; }
log_error()   { log "${RED}✗ $1${NC}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --indexer-ip) INDEXER_IP="$2"; shift 2 ;;
        --user)       ADMIN_USER="$2"; shift 2 ;;
        --pass)       ADMIN_PASS="$2"; shift 2 ;;
        --help)       head -8 "$0" | grep "^#" | sed 's/^# *//'; exit 0 ;;
        *)            log_error "Unknown: $1"; exit 1 ;;
    esac
done

BASE_URL="https://${INDEXER_IP}:${INDEXER_PORT}"
CURL_OPTS="-sk -u ${ADMIN_USER}:${ADMIN_PASS}"

# Check connectivity
log "Checking indexer connectivity..."
HTTP_CODE=$(curl ${CURL_OPTS} -o /dev/null -w "%{http_code}" "${BASE_URL}" 2>/dev/null || echo "000")
if [[ "${HTTP_CODE}" != "200" ]]; then
    log_error "Cannot connect to indexer (HTTP ${HTTP_CODE})"
    exit 1
fi
log_success "Connected to indexer"

# Apply alerts template
if [[ -f "${TEMPLATES_DIR}/alerts-template.json" ]]; then
    log "Applying sentinelcore-alerts template..."
    RESULT=$(curl ${CURL_OPTS} -X PUT "${BASE_URL}/_template/sentinelcore-alerts" \
        -H "Content-Type: application/json" \
        -d @"${TEMPLATES_DIR}/alerts-template.json" 2>/dev/null)
    echo "${RESULT}" | grep -q '"acknowledged":true' && log_success "Alerts template applied" || log_error "Failed: ${RESULT}"
fi

# Apply states template
if [[ -f "${TEMPLATES_DIR}/states-template.json" ]]; then
    log "Applying sentinelcore-states template..."
    RESULT=$(curl ${CURL_OPTS} -X PUT "${BASE_URL}/_template/sentinelcore-states" \
        -H "Content-Type: application/json" \
        -d @"${TEMPLATES_DIR}/states-template.json" 2>/dev/null)
    echo "${RESULT}" | grep -q '"acknowledged":true' && log_success "States template applied" || log_error "Failed: ${RESULT}"
fi

# Create initial indices
log "Creating initial indices..."
CURRENT_DATE=$(date '+%Y.%m.%d')

for INDEX_NAME in "sentinelcore-alerts-${CURRENT_DATE}" "sentinelcore-states-vulnerabilities" "sentinelcore-states-inventory"; do
    RESULT=$(curl ${CURL_OPTS} -X PUT "${BASE_URL}/${INDEX_NAME}" \
        -H "Content-Type: application/json" -d '{}' 2>/dev/null)
    if echo "${RESULT}" | grep -qE '"acknowledged":true|"already exists"'; then
        log_success "Index created: ${INDEX_NAME}"
    else
        log_error "Failed to create ${INDEX_NAME}: ${RESULT}"
    fi
done

# Apply performance settings
PERF_SETTINGS="${SCRIPT_DIR}/../performance/index-settings.json"
if [[ -f "${PERF_SETTINGS}" ]]; then
    log "Applying performance settings..."
    RESULT=$(curl ${CURL_OPTS} -X PUT "${BASE_URL}/sentinelcore-alerts-*/_settings" \
        -H "Content-Type: application/json" \
        -d @"${PERF_SETTINGS}" 2>/dev/null)
    echo "${RESULT}" | grep -q '"acknowledged":true' && log_success "Performance settings applied" || log_error "Settings: ${RESULT}"
fi

# Verify
log "Listing SentinelCore indices..."
curl ${CURL_OPTS} "${BASE_URL}/_cat/indices/sentinelcore-*?v" 2>/dev/null || true

echo ""
log_success "Index creation complete!"
