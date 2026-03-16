#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Certificate Renewal Script
# ============================================================================
# Renews TLS certificates before they expire.
# Usage: sudo bash renew-certs.sh [--days-before N] [--output DIR]
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"
DAYS_BEFORE=30
VALIDITY_DAYS=3650
KEY_SIZE=2048

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()         { echo -e "[$(date '+%H:%M:%S')] $1"; }
log_success() { log "${GREEN}✓ $1${NC}"; }
log_warning() { log "${YELLOW}⚠ $1${NC}"; }
log_error()   { log "${RED}✗ $1${NC}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --days-before) DAYS_BEFORE="$2"; shift 2 ;;
        --output)      CERTS_DIR="$2"; shift 2 ;;
        --help)        echo "Usage: sudo bash renew-certs.sh [--days-before N] [--output DIR]"; exit 0 ;;
        *)             shift ;;
    esac
done

[[ $EUID -ne 0 ]] && { log_error "Must run as root"; exit 1; }

check_expiry() {
    local cert_file="$1"
    local cert_name
    cert_name=$(basename "${cert_file}" .pem)

    if [[ ! -f "${cert_file}" ]]; then
        log_warning "Certificate not found: ${cert_file}"
        return 1
    fi

    local expiry_date
    expiry_date=$(openssl x509 -in "${cert_file}" -noout -enddate 2>/dev/null | cut -d'=' -f2)
    local expiry_epoch
    expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -jf "%b %d %T %Y %Z" "${expiry_date}" +%s 2>/dev/null || echo 0)
    local now_epoch
    now_epoch=$(date +%s)
    local days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

    if [[ ${days_remaining} -le 0 ]]; then
        log_error "${cert_name}: EXPIRED (${expiry_date})"
        return 0
    elif [[ ${days_remaining} -le ${DAYS_BEFORE} ]]; then
        log_warning "${cert_name}: Expires in ${days_remaining} days (${expiry_date})"
        return 0
    else
        log_success "${cert_name}: Valid for ${days_remaining} more days"
        return 1
    fi
}

renew_cert() {
    local cert_name="$1"
    local cert_file="${CERTS_DIR}/${cert_name}.pem"
    local key_file="${CERTS_DIR}/${cert_name}-key.pem"

    log "Renewing certificate: ${cert_name}"

    # Backup existing cert
    local backup_dir="${CERTS_DIR}/backup-$(date +%Y%m%d)"
    mkdir -p "${backup_dir}"
    cp "${cert_file}" "${backup_dir}/" 2>/dev/null || true
    cp "${key_file}" "${backup_dir}/" 2>/dev/null || true

    # Get subject from existing cert
    local subject
    subject=$(openssl x509 -in "${cert_file}" -noout -subject 2>/dev/null | sed 's/subject=//' || echo "/CN=${cert_name}")

    # Generate new key and CSR
    openssl genrsa -out "${cert_name}-key-temp.pem" ${KEY_SIZE} 2>/dev/null
    openssl pkcs8 -inform PEM -outform PEM -in "${cert_name}-key-temp.pem" -topk8 -nocrypt -out "${key_file}" 2>/dev/null
    openssl req -new -key "${key_file}" -out "${cert_name}.csr" -subj "${subject}" 2>/dev/null

    # Sign with Root CA
    openssl x509 -req -in "${cert_name}.csr" \
        -CA "${CERTS_DIR}/root-ca.pem" -CAkey "${CERTS_DIR}/root-ca-key.pem" \
        -CAcreateserial -out "${cert_file}" -days ${VALIDITY_DAYS} -sha256 2>/dev/null

    rm -f "${cert_name}.csr" "${cert_name}-key-temp.pem"
    chmod 400 "${key_file}"
    chmod 444 "${cert_file}"

    log_success "${cert_name}: Renewed successfully"
}

# ========================= Main =============================================
log "Checking certificate expiry (threshold: ${DAYS_BEFORE} days)..."
echo ""

NEEDS_RENEWAL=()

for cert_file in "${CERTS_DIR}"/*.pem; do
    [[ ! -f "${cert_file}" ]] && continue
    [[ "${cert_file}" == *"-key.pem" ]] && continue
    [[ "${cert_file}" == *"root-ca.pem" ]] && continue

    if check_expiry "${cert_file}"; then
        cert_name=$(basename "${cert_file}" .pem)
        NEEDS_RENEWAL+=("${cert_name}")
    fi
done

echo ""

if [[ ${#NEEDS_RENEWAL[@]} -eq 0 ]]; then
    log_success "All certificates are valid. No renewal needed."
    exit 0
fi

log "Certificates needing renewal: ${NEEDS_RENEWAL[*]}"
echo ""

for cert_name in "${NEEDS_RENEWAL[@]}"; do
    renew_cert "${cert_name}"
done

echo ""
log_success "Certificate renewal complete!"
log_warning "Remember to deploy renewed certificates and restart services."
log "  - Indexer:   sudo systemctl restart wazuh-indexer"
log "  - Manager:   sudo systemctl restart wazuh-manager"
log "  - Dashboard: sudo systemctl restart wazuh-dashboard"
log "  - Filebeat:  sudo systemctl restart filebeat"
