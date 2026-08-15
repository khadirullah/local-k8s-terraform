#!/usr/bin/env bash
# ──────────────────────────────────────────────
# setup.sh - Download cloud image and prepare
# for Terraform deployment
# Supports: Ubuntu 22.04 and Fedora 40
# ──────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_DIR="/var/lib/libvirt/images"

# ── Image URLs ──
UBUNTU_IMAGE_NAME="ubuntu-22.04-cloud.qcow2"
UBUNTU_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

FEDORA_IMAGE_NAME="fedora-40-cloud.qcow2"
FEDORA_IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Local K8s Cluster - Setup Script           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Pre-flight checks ──
info "Running pre-flight checks..."

command -v terraform >/dev/null 2>&1 || err "Terraform is not installed. Install from https://www.terraform.io/downloads"
command -v virsh >/dev/null 2>&1     || err "virsh is not installed. Install libvirt (apt: libvirt-daemon-system / dnf: libvirt)"
command -v qemu-system-x86_64 >/dev/null 2>&1 || err "QEMU is not installed. Install (apt: qemu-system-x86 / dnf: qemu-kvm)"

log "All prerequisites found"

# ── Check libvirtd is running ──
if ! systemctl is-active --quiet libvirtd 2>/dev/null; then
    warn "libvirtd is not running. Starting it..."
    sudo systemctl start libvirtd
    sudo systemctl enable libvirtd
fi
log "libvirtd is running"

# ── Check KVM access ──
if [ ! -e /dev/kvm ]; then
    err "/dev/kvm not found. Enable virtualization in BIOS."
fi
log "KVM acceleration available"

# ── Select OS ──
echo ""
echo "Select the OS for your K8s nodes:"
echo ""
echo "  1) Fedora 40       (dnf-based, like Amazon Linux)"
echo "  2) Ubuntu 22.04    (apt-based)"
echo ""
read -p "Enter choice [1]: " OS_CHOICE
OS_CHOICE="${OS_CHOICE:-1}"

case "$OS_CHOICE" in
    1)
        OS_DISTRO="fedora"
        IMAGE_NAME="$FEDORA_IMAGE_NAME"
        IMAGE_URL="$FEDORA_IMAGE_URL"
        ;;
    2)
        OS_DISTRO="ubuntu"
        IMAGE_NAME="$UBUNTU_IMAGE_NAME"
        IMAGE_URL="$UBUNTU_IMAGE_URL"
        ;;
    *)
        err "Invalid choice. Pick 1 or 2."
        ;;
esac

log "Selected OS: $OS_DISTRO"

# ── Download cloud image ──
if [ -f "$IMAGE_DIR/$IMAGE_NAME" ]; then
    log "Cloud image already exists at $IMAGE_DIR/$IMAGE_NAME"
else
    info "Downloading $OS_DISTRO cloud image (~600 MB)..."
    info "URL: $IMAGE_URL"
    sudo wget --progress=bar:force -O "$IMAGE_DIR/$IMAGE_NAME" "$IMAGE_URL"
    log "Cloud image downloaded to $IMAGE_DIR/$IMAGE_NAME"
fi

# ── Check SSH key ──
SSH_KEY="$HOME/.ssh/id_ed25519.pub"
if [ ! -f "$SSH_KEY" ]; then
    warn "SSH public key not found at $SSH_KEY"
    info "Generating SSH key pair..."
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -q
    log "SSH key generated"
else
    log "SSH public key found at $SSH_KEY"
fi

# ── Initialize Terraform ──
info "Initializing Terraform..."
cd "$PROJECT_DIR/terraform"

if [ ! -f "terraform.tfvars" ]; then
    cp terraform.tfvars.example terraform.tfvars
    # Update the OS distro and image path in tfvars
    sed -i "s|os_distro.*=.*|os_distro = \"$OS_DISTRO\"|" terraform.tfvars
    sed -i "s|base_image_path.*=.*|base_image_path = \"$IMAGE_DIR/$IMAGE_NAME\"|" terraform.tfvars
    log "Created terraform.tfvars with os_distro=$OS_DISTRO"
else
    log "terraform.tfvars already exists (not overwritten)"
fi

terraform init
log "Terraform initialized"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║          Setup Complete! 🎉                   ║"
echo "╠══════════════════════════════════════════════╣"
echo "║                                              ║"
echo "║  OS: $OS_DISTRO                              ║"
echo "║  Image: $IMAGE_DIR/$IMAGE_NAME               ║"
echo "║                                              ║"
echo "║  Next steps:                                 ║"
echo "║                                              ║"
echo "║  1. Review terraform/terraform.tfvars        ║"
echo "║  2. cd terraform                             ║"
echo "║  3. terraform plan                           ║"
echo "║  4. terraform apply -auto-approve            ║"
echo "║  5. ../scripts/get-kubeconfig.sh             ║"
echo "║  6. kubectl get nodes                        ║"
echo "║                                              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
