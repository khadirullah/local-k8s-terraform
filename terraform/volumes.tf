# ──────────────────────────────────────────────
# Storage Volumes
# Base cloud image + per-node cloned volumes
# ──────────────────────────────────────────────

# Base cloud image (downloaded separately via setup.sh)
# Works for both Ubuntu and Fedora depending on base_image_path
resource "libvirt_volume" "base" {
  name = "${var.cluster_name}-base.qcow2"
  pool = "default"

  target = {
    format = {
      type = "qcow2"
    }
  }

  # Upload the local image file into the volume
  create = {
    content = {
      url = var.base_image_path
    }
  }
}

# Master node volume (cloned from base, resized)
resource "libvirt_volume" "master" {
  name     = "${var.cluster_name}-master.qcow2"
  pool     = "default"
  capacity = var.master_disk_size

  backing_store = {
    path = libvirt_volume.base.path
    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

# Worker node volumes (cloned from base, resized)
resource "libvirt_volume" "worker" {
  count = var.worker_count

  name     = "${var.cluster_name}-worker-${count.index + 1}.qcow2"
  pool     = "default"
  capacity = var.worker_disk_size

  backing_store = {
    path = libvirt_volume.base.path
    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}
