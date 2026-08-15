# ──────────────────────────────────────────────
# Terraform Provider Configuration
# Uses the dmacvicar/libvirt provider for QEMU/KVM
# ──────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.8"
    }
  }
}

# Connect to the local QEMU/KVM hypervisor
provider "libvirt" {
  uri = "qemu:///system"
}
