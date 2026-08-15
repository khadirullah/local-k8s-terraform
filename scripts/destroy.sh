#!/usr/bin/env bash
# ──────────────────────────────────────────────
# destroy.sh - Clean teardown of all K8s VMs,
# volumes, and network
# ──────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Local K8s Cluster - Destroy                ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

read -p "Are you sure you want to destroy the entire K8s cluster? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

info "Destroying Terraform-managed resources..."
cd "$PROJECT_DIR/terraform"
terraform destroy -auto-approve

log "All VMs, volumes, and network destroyed"

# Clean up local kubeconfig
LOCAL_KUBECONFIG="$HOME/.kube/config-local-k8s"
if [ -f "$LOCAL_KUBECONFIG" ]; then
    rm -f "$LOCAL_KUBECONFIG"
    log "Removed local kubeconfig: $LOCAL_KUBECONFIG"
fi

echo ""
log "Cluster fully destroyed. Your host resources are freed."
echo ""
