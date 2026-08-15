# ──────────────────────────────────────────────
# Master Node VM
# ──────────────────────────────────────────────

# Select cloud-init template based on OS distro
locals {
  master_cloud_init = var.os_distro == "fedora" ? "fedora-master.yaml" : "master.yaml"
  worker_cloud_init = var.os_distro == "fedora" ? "fedora-worker.yaml" : "worker.yaml"
}

# Cloud-init disk for master
resource "libvirt_cloudinit_disk" "master" {
  name = "${var.cluster_name}-master-cloudinit.iso"
  pool = "default"

  user_data = templatefile("${path.module}/../cloud-init/${local.master_cloud_init}", {
    hostname       = "${var.cluster_name}-master"
    ssh_user       = var.ssh_user
    ssh_public_key = file(pathexpand(var.ssh_public_key_path))
    master_ip      = var.master_ip
    k8s_version    = var.k8s_version
    pod_cidr       = var.pod_network_cidr
    network_cidr   = var.network_cidr
  })

  network_config = templatefile("${path.module}/../cloud-init/network-config.yaml", {
    ip_address = var.master_ip
    gateway    = cidrhost(var.network_cidr, 1)
  })
}

# Master VM
resource "libvirt_domain" "master" {
  name   = "${var.cluster_name}-master"
  memory = var.master_memory
  vcpu   = var.master_vcpu

  cloudinit = libvirt_cloudinit_disk.master.id

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.master.id
  }

  network_interface {
    network_id     = libvirt_network.k8s.id
    addresses      = [var.master_ip]
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

  depends_on = [libvirt_network.k8s]
}
