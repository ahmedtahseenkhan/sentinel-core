#!/usr/bin/env bash
# ============================================================================
# SentinelCore - System Health Check
# ============================================================================
# Runs all health checks and outputs a summary report.
# Usage: sudo bash health-check.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_DIR="${SCRIPT_DIR}/../monitoring/health-checks"

echo "╔═══════════════════════════════════════════════╗"
echo "║  SentinelCore System Health Check              ║"
echo "║  $(date '+%Y-%m-%d %H:%M:%S')                          ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

TOTAL=0
PASSED=0

run_check() {
    local name="$1" script="$2"
    TOTAL=$((TOTAL + 1))
    echo "── ${name} ──"
    if bash "${script}" 2>/dev/null; then
        PASSED=$((PASSED + 1))
    fi
    echo ""
}

# Run checks
[[ -f "${HEALTH_DIR}/check-cluster.sh" ]] && run_check "Cluster Health" "${HEALTH_DIR}/check-cluster.sh"
[[ -f "${HEALTH_DIR}/check-agents.sh" ]] && run_check "Agent Health" "${HEALTH_DIR}/check-agents.sh"

# Disk space check
TOTAL=$((TOTAL + 1))
echo "── Disk Space ──"
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
if [[ ${DISK_USAGE} -lt 85 ]]; then
    echo "  ✓ Disk usage: ${DISK_USAGE}%"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ Disk usage: ${DISK_USAGE}% (>85% threshold)"
fi
echo ""

# Summary
echo "════════════════════════════════════════"
echo "Results: ${PASSED}/${TOTAL} checks passed"
if [[ ${PASSED} -eq ${TOTAL} ]]; then
    echo "Status: ALL HEALTHY ✓"
    exit 0
else
    echo "Status: ISSUES DETECTED ✗"
    exit 1
fi
