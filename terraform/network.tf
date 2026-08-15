# ──────────────────────────────────────────────
# Libvirt NAT Network for K8s Cluster
# ──────────────────────────────────────────────

resource "libvirt_network" "k8s" {
  name      = var.network_name
  autostart = true

  forward = {
    mode = "nat"
  }

  domain = {
    name       = "${var.cluster_name}.local"
    local_only = "yes"
  }

  # ips is a list of nested objects (nesting_mode: list)
  ips = [{
    address = cidrhost(var.network_cidr, 1)
    netmask = cidrnetmask(var.network_cidr)
  }]

  dns = {
    enable = "yes"
  }
}
