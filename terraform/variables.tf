# ──────────────────────────────────────────────
# Input Variables
# ──────────────────────────────────────────────

variable "cluster_name" {
  description = "Name prefix for all cluster resources"
  type        = string
  default     = "k8s"
}

# ── Network ──

variable "network_name" {
  description = "Name of the libvirt network"
  type        = string
  default     = "k8s-net"
}

variable "network_cidr" {
  description = "CIDR block for the cluster network"
  type        = string
  default     = "192.168.100.0/24"
}

variable "network_bridge" {
  description = "Bridge device name for the network"
  type        = string
  default     = "virbr-k8s"
}

# ── OS Selection ──

variable "os_distro" {
  description = "OS distribution for the nodes: 'ubuntu' or 'fedora'"
  type        = string
  default     = "fedora"

  validation {
    condition     = contains(["ubuntu", "fedora"], var.os_distro)
    error_message = "os_distro must be 'ubuntu' or 'fedora'."
  }
}

variable "base_image_path" {
  description = "Path to the cloud image (qcow2). Use setup.sh to download."
  type        = string
  default     = "/var/lib/libvirt/images/fedora-40-cloud.qcow2"
}


# ── Master Node ──

variable "master_ip" {
  description = "Static IP for the master node"
  type        = string
  default     = "192.168.100.10"
}

variable "master_memory" {
  description = "RAM for master node in MB"
  type        = number
  default     = 2048
}

variable "master_vcpu" {
  description = "Number of vCPUs for master node"
  type        = number
  default     = 2
}

variable "master_disk_size" {
  description = "Disk size for master node in bytes (20 GB)"
  type        = number
  default     = 21474836480 # 20 GB
}

# ── Worker Nodes ──

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "worker_memory" {
  description = "RAM for each worker node in MB"
  type        = number
  default     = 1024
}

variable "worker_vcpu" {
  description = "Number of vCPUs for each worker node"
  type        = number
  default     = 1
}

variable "worker_disk_size" {
  description = "Disk size for each worker node in bytes (15 GB)"
  type        = number
  default     = 16106127360 # 15 GB
}

# ── SSH ──

variable "ssh_user" {
  description = "SSH username for cloud-init"
  type        = string
  default     = "km"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# ── Kubernetes ──

variable "k8s_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.30"
}

variable "pod_network_cidr" {
  description = "CIDR for the Kubernetes pod network (Calico default)"
  type        = string
  default     = "10.244.0.0/16"
}
