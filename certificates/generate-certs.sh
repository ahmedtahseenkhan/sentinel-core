#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Certificate Generation Script
# ============================================================================
# Generates TLS certificates for all SentinelCore components.
# Usage: sudo bash generate-certs.sh [--config FILE] [--output DIR]
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yml.template"
OUTPUT_DIR="${SCRIPT_DIR}/certs"
VALIDITY_DAYS=3650
KEY_SIZE=2048

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()         { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config) CONFIG_FILE="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --days)   VALIDITY_DAYS="$2"; shift 2 ;;
        --help)   echo "Usage: sudo bash generate-certs.sh [--config FILE] [--output DIR] [--days N]"; exit 0 ;;
        *)        log_error "Unknown: $1"; exit 1 ;;
    esac
done

[[ $EUID -ne 0 ]] && { log_error "Must run as root"; exit 1; }

# Check for openssl
if ! command -v openssl &>/dev/null; then
    log_error "openssl is required but not installed"
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
cd "${OUTPUT_DIR}"

log "Generating SentinelCore TLS certificates..."
log "Output: ${OUTPUT_DIR}"
log "Validity: ${VALIDITY_DAYS} days"

# ========================= Root CA ==========================================
log ""
log "${BLUE}━━━ Generating Root CA ━━━${NC}"

openssl genrsa -out root-ca-key.pem ${KEY_SIZE} 2>/dev/null
openssl req -new -x509 -sha256 -key root-ca-key.pem -out root-ca.pem \
    -days ${VALIDITY_DAYS} \
    -subj "/C=US/ST=NA/L=Security/O=SentinelCore/OU=SentinelCore CA/CN=SentinelCore Root CA" \
    2>/dev/null
log_success "Root CA generated"

# ========================= Admin Certificate =================================
log ""
log "${BLUE}━━━ Generating Admin Certificate ━━━${NC}"

openssl genrsa -out admin-key-temp.pem ${KEY_SIZE} 2>/dev/null
openssl pkcs8 -inform PEM -outform PEM -in admin-key-temp.pem -topk8 -nocrypt -out admin-key.pem 2>/dev/null
openssl req -new -key admin-key.pem -out admin.csr \
    -subj "/C=US/ST=NA/L=Security/O=SentinelCore/OU=SentinelCore/CN=admin" \
    2>/dev/null
openssl x509 -req -in admin.csr -CA root-ca.pem -CAkey root-ca-key.pem \
    -CAcreateserial -out admin.pem -days ${VALIDITY_DAYS} -sha256 2>/dev/null
rm -f admin.csr admin-key-temp.pem
log_success "Admin certificate generated"

# ========================= Node Certificates =================================
generate_node_cert() {
    local NODE_NAME="$1"
    local NODE_IP="$2"

    log "Generating certificate for ${NODE_NAME} (${NODE_IP})..."

    # Create SAN config
    cat > "${NODE_NAME}.cnf" << EOF
[req]
distinguished_name = req_dn
[req_dn]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${NODE_NAME}
IP.1 = ${NODE_IP}
IP.2 = 127.0.0.1
EOF

    openssl genrsa -out "${NODE_NAME}-key-temp.pem" ${KEY_SIZE} 2>/dev/null
    openssl pkcs8 -inform PEM -outform PEM -in "${NODE_NAME}-key-temp.pem" -topk8 -nocrypt -out "${NODE_NAME}-key.pem" 2>/dev/null
    openssl req -new -key "${NODE_NAME}-key.pem" -out "${NODE_NAME}.csr" \
        -subj "/C=US/ST=NA/L=Security/O=SentinelCore/OU=SentinelCore/CN=${NODE_NAME}" \
        2>/dev/null
    openssl x509 -req -in "${NODE_NAME}.csr" -CA root-ca.pem -CAkey root-ca-key.pem \
        -CAcreateserial -out "${NODE_NAME}.pem" -days ${VALIDITY_DAYS} -sha256 \
        -extfile "${NODE_NAME}.cnf" -extensions v3_req 2>/dev/null
    rm -f "${NODE_NAME}.csr" "${NODE_NAME}-key-temp.pem" "${NODE_NAME}.cnf"
    log_success "${NODE_NAME}: OK"
}

log ""
log "${BLUE}━━━ Generating Node Certificates ━━━${NC}"

# Parse config file and generate certs for each node
# For simplicity, generate for the common nodes
# In production, parse config.yml.template
generate_node_cert "sentinelcore-indexer-1" "SENTINELCORE_INDEXER_IP"
generate_node_cert "sentinelcore-manager-1" "SENTINELCORE_MANAGER_IP"
generate_node_cert "sentinelcore-dashboard-1" "SENTINELCORE_DASHBOARD_IP"

# Create Filebeat certificate (used on manager for Filebeat→Indexer)
generate_node_cert "filebeat" "SENTINELCORE_MANAGER_IP"

# ========================= Set Permissions ====================================
chmod 400 *-key.pem
chmod 444 *.pem
log_success "Permissions set (keys: 400, certs: 444)"

# ========================= Summary ==========================================
echo ""
log "${GREEN}━━━ Certificate Generation Complete ━━━${NC}"
echo ""
ls -la "${OUTPUT_DIR}/"*.pem 2>/dev/null
echo ""
log "Root CA:    ${OUTPUT_DIR}/root-ca.pem"
log "Admin:      ${OUTPUT_DIR}/admin.pem"
log "Indexer:    ${OUTPUT_DIR}/sentinelcore-indexer-1.pem"
log "Manager:    ${OUTPUT_DIR}/sentinelcore-manager-1.pem"
log "Dashboard:  ${OUTPUT_DIR}/sentinelcore-dashboard-1.pem"
log "Filebeat:   ${OUTPUT_DIR}/filebeat.pem"
echo ""
log "${YELLOW}⚠ Replace SENTINELCORE_*_IP placeholders in cert SANs before use!${NC}"
log "${YELLOW}⚠ Keep root-ca-key.pem secure and backed up!${NC}"
