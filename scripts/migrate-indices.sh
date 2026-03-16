#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Index Migration Script
# ============================================================================
# Migrates indices from old naming to SentinelCore naming convention.
# Usage: sudo bash migrate-indices.sh --from "wazuh-alerts-*" --to "sentinelcore-alerts"
# ============================================================================

set -euo pipefail

INDEXER_IP="${SENTINELCORE_INDEXER_IP:-localhost}"
ADMIN_USER="admin"
ADMIN_PASS="${SENTINELCORE_AUTH_PASS:-admin}"
FROM_PATTERN=""
TO_PREFIX=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)       FROM_PATTERN="$2"; shift 2 ;;
        --to)         TO_PREFIX="$2"; shift 2 ;;
        --indexer-ip) INDEXER_IP="$2"; shift 2 ;;
        --user)       ADMIN_USER="$2"; shift 2 ;;
        --pass)       ADMIN_PASS="$2"; shift 2 ;;
        --help)       echo "Usage: sudo bash migrate-indices.sh --from 'wazuh-alerts-*' --to 'sentinelcore-alerts'"; exit 0 ;;
        *)            shift ;;
    esac
done

[[ -z "${FROM_PATTERN}" ]] && { echo -e "${RED}--from pattern required${NC}"; exit 1; }
[[ -z "${TO_PREFIX}" ]] && { echo -e "${RED}--to prefix required${NC}"; exit 1; }

BASE_URL="https://${INDEXER_IP}:9200"
CURL="curl -sk -u ${ADMIN_USER}:${ADMIN_PASS}"

echo "Migrating indices from '${FROM_PATTERN}' to '${TO_PREFIX}-*'..."
echo ""

# List source indices
INDICES=$(${CURL} "${BASE_URL}/_cat/indices/${FROM_PATTERN}?h=index" 2>/dev/null | sort)

if [[ -z "${INDICES}" ]]; then
    echo -e "${YELLOW}No indices matching '${FROM_PATTERN}' found${NC}"
    exit 0
fi

COUNT=$(echo "${INDICES}" | wc -l)
echo "Found ${COUNT} indices to migrate"
echo ""

MIGRATED=0
for INDEX in ${INDICES}; do
    # Extract date suffix
    DATE_SUFFIX=$(echo "${INDEX}" | grep -oP '\d{4}\.\d{2}\.\d{2}$' || echo "")
    if [[ -n "${DATE_SUFFIX}" ]]; then
        NEW_INDEX="${TO_PREFIX}-${DATE_SUFFIX}"
    else
        NEW_INDEX="${TO_PREFIX}-$(echo "${INDEX}" | sed "s/${FROM_PATTERN%\*}//")"
    fi

    echo -n "  ${INDEX} → ${NEW_INDEX} ... "

    # Reindex
    RESULT=$(${CURL} -X POST "${BASE_URL}/_reindex" \
        -H "Content-Type: application/json" \
        -d "{
            \"source\": {\"index\": \"${INDEX}\"},
            \"dest\": {\"index\": \"${NEW_INDEX}\"}
        }" 2>/dev/null)

    TOTAL=$(echo "${RESULT}" | jq -r '.total // 0' 2>/dev/null)
    FAILURES=$(echo "${RESULT}" | jq -r '.failures | length // 0' 2>/dev/null)

    if [[ "${FAILURES}" == "0" ]]; then
        echo -e "${GREEN}OK (${TOTAL} docs)${NC}"
        MIGRATED=$((MIGRATED + 1))
    else
        echo -e "${RED}FAILED${NC}"
    fi
done

echo ""
echo "Migration complete: ${MIGRATED}/${COUNT} indices migrated"
echo -e "${YELLOW}Note: Original indices were NOT deleted. Remove them manually if desired.${NC}"
