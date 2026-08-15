# ──────────────────────────────────────────────
# Worker Node VMs (count-based)
# ──────────────────────────────────────────────

# Cloud-init disks for workers
resource "libvirt_cloudinit_disk" "worker" {
  count = var.worker_count

  name = "${var.cluster_name}-worker-${count.index + 1}-cloudinit.iso"
  pool = "default"

  user_data = templatefile("${path.module}/../cloud-init/${local.worker_cloud_init}", {
    hostname       = "${var.cluster_name}-worker-${count.index + 1}"
    ssh_user       = var.ssh_user
    ssh_public_key = file(pathexpand(var.ssh_public_key_path))
    worker_ip      = cidrhost(var.network_cidr, 11 + count.index)
    master_ip      = var.master_ip
    k8s_version    = var.k8s_version
  })

  network_config = templatefile("${path.module}/../cloud-init/network-config.yaml", {
    ip_address = cidrhost(var.network_cidr, 11 + count.index)
    gateway    = cidrhost(var.network_cidr, 1)
  })
}

# Worker VMs
resource "libvirt_domain" "worker" {
  count = var.worker_count

  name   = "${var.cluster_name}-worker-${count.index + 1}"
  memory = var.worker_memory
  vcpu   = var.worker_vcpu

  cloudinit = libvirt_cloudinit_disk.worker[count.index].id

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.worker[count.index].id
  }

  network_interface {
    network_id     = libvirt_network.k8s.id
    addresses      = [cidrhost(var.network_cidr, 11 + count.index)]
    wait_for_lease = false
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }

  depends_on = [
    libvirt_network.k8s,
    libvirt_domain.master
  ]
}
