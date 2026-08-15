# ──────────────────────────────────────────────
# Worker Node VMs (count-based)
# ──────────────────────────────────────────────

# Cloud-init disks for workers (generates ISO locally)
resource "libvirt_cloudinit_disk" "worker" {
  count = var.worker_count

  name = "${var.cluster_name}-worker-${count.index + 1}-cloudinit.iso"

  meta_data = yamlencode({
    instance-id    = "${var.cluster_name}-worker-${count.index + 1}"
    local-hostname = "${var.cluster_name}-worker-${count.index + 1}"
  })

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

# Upload cloud-init ISOs to libvirt storage pool
resource "libvirt_volume" "worker_cloudinit" {
  count = var.worker_count

  name = "${var.cluster_name}-worker-${count.index + 1}-cloudinit.iso"
  pool = "default"

  target = {
    format = {
      type = "iso"
    }
  }

  create = {
    content = {
      url = libvirt_cloudinit_disk.worker[count.index].path
    }
  }
}

# Worker VMs — v0.9.8 schema (nested attributes with = assignment)
resource "libvirt_domain" "worker" {
  count = var.worker_count

  name        = "${var.cluster_name}-worker-${count.index + 1}"
  memory      = var.worker_memory
  memory_unit = "MiB"
  vcpu        = var.worker_vcpu
  type        = "kvm"
  running     = true

  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type      = "hvm"
    type_arch = "x86_64"
    boot_devices = [{ dev = "hd" }]
  }

  devices = {
    disks = [
      {
        device = "disk"
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          file = {
            file = libvirt_volume.worker[count.index].path
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device    = "cdrom"
        read_only = true
        driver = {
          name = "qemu"
          type = "raw"
        }
        source = {
          file = {
            file = libvirt_volume.worker_cloudinit[count.index].path
          }
        }
        target = {
          dev = "hda"
          bus = "ide"
        }
      }
    ]

    interfaces = [{
      source = {
        network = {
          network = libvirt_network.k8s.name
        }
      }
      model = {
        type = "virtio"
      }
    }]

    consoles = [{
      target = {
        type = "serial"
        port = 0
      }
    }]

    graphics = [{
      vnc = {
        auto_port = true
      }
    }]
  }

  depends_on = [
    libvirt_network.k8s,
    libvirt_domain.master
  ]
}
