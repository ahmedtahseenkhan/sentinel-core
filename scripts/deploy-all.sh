#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Full Stack Deployment Script
# ============================================================================
# Deploys the entire SentinelCore stack (Manager, Indexer, Filebeat).
# Usage: sudo bash deploy-all.sh [--manager-ip IP] [--indexer-ip IP]
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
MANAGER_IP="${SENTINELCORE_MANAGER_IP:-}"
INDEXER_IP="${SENTINELCORE_INDEXER_IP:-}"
API_PASS="${SENTINELCORE_AUTH_PASS:-$(openssl rand -base64 24)}"
LOG="/var/log/sentinelcore-deploy.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()      { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "${LOG}"; }
log_ok()   { log "${GREEN}✓ $1${NC}"; }
log_err()  { log "${RED}✗ $1${NC}"; }
log_step() { echo ""; log "${BLUE}════════════════════════════════════════${NC}"; log "${BLUE}  $1${NC}"; log "${BLUE}════════════════════════════════════════${NC}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manager-ip) MANAGER_IP="$2"; shift 2 ;;
        --indexer-ip) INDEXER_IP="$2"; shift 2 ;;
        --api-pass)   API_PASS="$2"; shift 2 ;;
        --help)       echo "Usage: sudo bash deploy-all.sh [--manager-ip IP] [--indexer-ip IP] [--api-pass PASS]"; exit 0 ;;
        *)            shift ;;
    esac
done

[[ $EUID -ne 0 ]] && { log_err "Must run as root"; exit 1; }

if [[ -z "${MANAGER_IP}" || -z "${INDEXER_IP}" ]]; then
    log_err "Both --manager-ip and --indexer-ip are required"
    exit 1
fi

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════╗"
echo "║     SentinelCore Full Stack Deployment        ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Manager: ${MANAGER_IP}"
echo "║  Indexer: ${INDEXER_IP}"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Generate Certificates
log_step "Step 1/5: Generating Certificates"
cd "${REPO_ROOT}/certificates"
bash generate-certs.sh --output "${REPO_ROOT}/certificates/certs" 2>&1 | tee -a "${LOG}"
log_ok "Certificates generated"

# Step 2: Install Indexer
log_step "Step 2/5: Installing SentinelCore Indexer"
cd "${REPO_ROOT}/indexer/scripts"
bash install-indexer.sh --indexer-ip "${INDEXER_IP}" 2>&1 | tee -a "${LOG}"
bash init-security.sh 2>&1 | tee -a "${LOG}"
bash create-indices.sh --indexer-ip "${INDEXER_IP}" 2>&1 | tee -a "${LOG}"
log_ok "Indexer deployed"

# Step 3: Install Manager
log_step "Step 3/5: Installing SentinelCore Manager"
cd "${REPO_ROOT}/manager/scripts"
bash install-manager.sh --manager-ip "${MANAGER_IP}" --api-pass "${API_PASS}" 2>&1 | tee -a "${LOG}"
bash configure-manager.sh --api-pass "${API_PASS}" 2>&1 | tee -a "${LOG}"
log_ok "Manager deployed"

# Step 4: Install Filebeat
log_step "Step 4/5: Installing Filebeat"
cd "${REPO_ROOT}/filebeat"
bash install-filebeat.sh --indexer-ip "${INDEXER_IP}" 2>&1 | tee -a "${LOG}"
log_ok "Filebeat deployed"

# Step 5: Verify
log_step "Step 5/5: Verifying Deployment"
cd "${REPO_ROOT}/monitoring/health-checks"
bash check-cluster.sh 2>&1 | tee -a "${LOG}" || true

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     SentinelCore Deployment Complete! ✓       ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Dashboard: https://${MANAGER_IP}:443         ${NC}"
echo -e "${GREEN}║  API:       https://${MANAGER_IP}:55000       ${NC}"
echo -e "${GREEN}║  Indexer:   https://${INDEXER_IP}:9200        ${NC}"
echo -e "${GREEN}║  Log:       ${LOG}             ${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
