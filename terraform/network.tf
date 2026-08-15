# ──────────────────────────────────────────────
# Libvirt NAT Network for K8s Cluster
# ──────────────────────────────────────────────

resource "libvirt_network" "k8s" {
  name      = var.network_name
  mode      = "nat"
  autostart = true

  domain = "${var.cluster_name}.local"

  addresses = [var.network_cidr]

  dhcp {
    enabled = false
  }

  dns {
    enabled    = true
    local_only = true
  }
}
