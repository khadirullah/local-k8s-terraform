#!/usr/bin/env bash
# ──────────────────────────────────────────────
# get-kubeconfig.sh - Copy kubeconfig from master
# node to local machine for kubectl access
# ──────────────────────────────────────────────

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Read variables from Terraform output
cd "$PROJECT_DIR/terraform"
MASTER_IP=$(terraform output -raw master_ip 2>/dev/null || echo "192.168.100.10")
SSH_USER=$(grep 'ssh_user' terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "km")

LOCAL_KUBECONFIG="$HOME/.kube/config-local-k8s"
MAX_RETRIES=30
RETRY_INTERVAL=10

echo ""
info "Waiting for master node ($MASTER_IP) to finish K8s initialization..."

for i in $(seq 1 $MAX_RETRIES); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
       "$SSH_USER@$MASTER_IP" "test -f /home/$SSH_USER/.kube/config" 2>/dev/null; then

        info "Master is ready! Copying kubeconfig..."
        mkdir -p "$HOME/.kube"
        scp -o StrictHostKeyChecking=no \
            "$SSH_USER@$MASTER_IP:/home/$SSH_USER/.kube/config" \
            "$LOCAL_KUBECONFIG"

        # Update the server address in kubeconfig to use the master IP
        sed -i "s|server: https://.*:6443|server: https://$MASTER_IP:6443|g" "$LOCAL_KUBECONFIG"

        log "Kubeconfig saved to $LOCAL_KUBECONFIG"

        echo ""
        echo "To use this cluster:"
        echo ""
        echo "  export KUBECONFIG=$LOCAL_KUBECONFIG"
        echo "  kubectl get nodes"
        echo ""
        echo "Or merge with existing kubeconfig:"
        echo ""
        echo "  KUBECONFIG=$HOME/.kube/config:$LOCAL_KUBECONFIG kubectl config view --flatten > /tmp/merged && mv /tmp/merged $HOME/.kube/config"
        echo ""

        # Quick test
        export KUBECONFIG="$LOCAL_KUBECONFIG"
        if kubectl get nodes 2>/dev/null; then
            log "Cluster is accessible! All nodes shown above."
        else
            warn "Kubeconfig copied but nodes may still be joining. Wait a minute and try: kubectl get nodes"
        fi
        exit 0
    fi

    echo "  Attempt $i/$MAX_RETRIES - Master not ready yet. Waiting ${RETRY_INTERVAL}s..."
    sleep $RETRY_INTERVAL
done

err "Master node did not become ready after $MAX_RETRIES attempts. Check: ssh $SSH_USER@$MASTER_IP"
