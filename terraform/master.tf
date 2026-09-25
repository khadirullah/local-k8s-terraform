# ──────────────────────────────────────────────
# Master Node VM
# ──────────────────────────────────────────────

# Select cloud-init template based on OS distro
locals {
  master_cloud_init = var.os_distro == "fedora" ? "fedora-master.yaml" : "master.yaml"
  worker_cloud_init = var.os_distro == "fedora" ? "fedora-worker.yaml" : "worker.yaml"

  # DNS domain of the cluster network, also used for each node's FQDN
  cluster_domain = "${var.cluster_name}.local"

  # A fixed MAC per node, built from the last three octets of its IP.
  # network-config.yaml matches the NIC by this MAC, because Fedora's
  # NetworkManager can't match an interface name pattern like en*.
  master_mac = format("52:54:00:%02x:%02x:%02x", [for o in slice(split(".", var.master_ip), 1, 4) : tonumber(o)]...)
  worker_macs = [
    for i in range(var.worker_count) :
    format("52:54:00:%02x:%02x:%02x", [for o in slice(split(".", cidrhost(var.network_cidr, 11 + i)), 1, 4) : tonumber(o)]...)
  ]
}

# Cloud-init disk for master (generates ISO locally)
resource "libvirt_cloudinit_disk" "master" {
  name = "${var.cluster_name}-master-cloudinit.iso"

  meta_data = yamlencode({
    instance-id    = "${var.cluster_name}-master"
    local-hostname = "${var.cluster_name}-master"
  })

  user_data = templatefile("${path.module}/../cloud-init/${local.master_cloud_init}", {
    hostname       = "${var.cluster_name}-master"
    domain         = local.cluster_domain
    ssh_user       = var.ssh_user
    ssh_public_key = file(pathexpand(var.ssh_public_key_path))
    master_ip      = var.master_ip
    k8s_version    = var.k8s_version
    pod_cidr       = var.pod_network_cidr
    network_cidr   = var.network_cidr
  })

  network_config = templatefile("${path.module}/../cloud-init/network-config.yaml", {
    ip_address  = var.master_ip
    gateway     = cidrhost(var.network_cidr, 1)
    mac_address = local.master_mac
  })
}

# Upload cloud-init ISO to libvirt storage pool
resource "libvirt_volume" "master_cloudinit" {
  name = "${var.cluster_name}-master-cloudinit.iso"
  pool = "default"

  target = {
    format = {
      type = "iso"
    }
  }

  create = {
    content = {
      url = libvirt_cloudinit_disk.master.path
    }
  }
}

# Master VM — v0.9.8 schema (nested attributes with = assignment)
resource "libvirt_domain" "master" {
  name        = "${var.cluster_name}-master"
  memory      = var.master_memory
  memory_unit = "MiB"
  vcpu        = var.master_vcpu
  type        = "kvm"
  running     = true

  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
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
            file = libvirt_volume.master.path
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
            file = libvirt_volume.master_cloudinit.path
          }
        }
        target = {
          dev = "hda"
          bus = "ide"
        }
      }
    ]

    interfaces = [{
      mac = {
        address = local.master_mac
      }
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

  depends_on = [libvirt_network.k8s]
}
