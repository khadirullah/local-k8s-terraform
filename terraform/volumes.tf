# ──────────────────────────────────────────────
# Storage Volumes
# Base cloud image + per-node cloned volumes
# ──────────────────────────────────────────────

# Base Ubuntu 22.04 cloud image (downloaded separately)
resource "libvirt_volume" "ubuntu_base" {
  name   = "${var.cluster_name}-ubuntu-base.qcow2"
  pool   = "default"
  source = var.base_image_path
  format = "qcow2"
}

# Master node volume (cloned from base, resized)
resource "libvirt_volume" "master" {
  name           = "${var.cluster_name}-master.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.master_disk_size
  format         = "qcow2"
}

# Worker node volumes (cloned from base, resized)
resource "libvirt_volume" "worker" {
  count = var.worker_count

  name           = "${var.cluster_name}-worker-${count.index + 1}.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.worker_disk_size
  format         = "qcow2"
}
