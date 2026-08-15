# ──────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────

output "master_ip" {
  description = "IP address of the master node"
  value       = var.master_ip
}

output "worker_ips" {
  description = "IP addresses of the worker nodes"
  value       = [for i in range(var.worker_count) : cidrhost(var.network_cidr, 11 + i)]
}

output "ssh_master" {
  description = "SSH command to connect to the master node"
  value       = "ssh ${var.ssh_user}@${var.master_ip}"
}

output "ssh_workers" {
  description = "SSH commands to connect to worker nodes"
  value       = [for i in range(var.worker_count) : "ssh ${var.ssh_user}@${cidrhost(var.network_cidr, 11 + i)}"]
}

output "get_kubeconfig" {
  description = "Command to copy kubeconfig from master to local machine"
  value       = "scp ${var.ssh_user}@${var.master_ip}:/home/${var.ssh_user}/.kube/config ~/.kube/config-local-k8s"
}

output "cluster_info" {
  description = "Cluster summary"
  value = {
    master     = "${var.cluster_name}-master (${var.master_memory} MB, ${var.master_vcpu} vCPU)"
    workers    = [for i in range(var.worker_count) : "${var.cluster_name}-worker-${i + 1} (${var.worker_memory} MB, ${var.worker_vcpu} vCPU)"]
    network    = "${var.network_name} (${var.network_cidr})"
    k8s_version = var.k8s_version
  }
}
