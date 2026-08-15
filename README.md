# Local Kubernetes Cluster with Terraform + QEMU/KVM

Provision a production-like 3-node Kubernetes cluster (1 master + 2 workers) on your local machine using Terraform and the libvirt provider. Fully automated with cloud-init and kubeadm — from zero to `kubectl get nodes` in one command.

![Terraform](https://img.shields.io/badge/Terraform-v1.5+-7B42BC?logo=terraform&logoColor=white)
![QEMU/KVM](https://img.shields.io/badge/QEMU/KVM-Hypervisor-FF6600?logo=qemu&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.36-326CE5?logo=kubernetes&logoColor=white)
![Fedora](https://img.shields.io/badge/Fedora-44_Cloud-51A2DA?logo=fedora&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_Cloud-E95420?logo=ubuntu&logoColor=white)
![Calico](https://img.shields.io/badge/Calico-v3.32.1_CNI-FC6D26?logoColor=white)
![Libvirt Provider](https://img.shields.io/badge/Libvirt_Provider-v0.9.8-7B42BC?logoColor=white)

## Architecture

```mermaid
graph TB
    subgraph "Host Machine"
        TF["Terraform<br/>(Libvirt Provider v0.9.8)"]
        subgraph "QEMU/KVM Hypervisor"
            subgraph "k8s-net (192.168.100.0/24)"
                M["k8s-master<br/>192.168.100.10<br/>2 GB RAM · 2 vCPU"]
                W1["k8s-worker-1<br/>192.168.100.11<br/>1 GB RAM · 1 vCPU"]
                W2["k8s-worker-2<br/>192.168.100.12<br/>1 GB RAM · 1 vCPU"]
            end
        end
        KC["~/.kube/config<br/>kubectl access"]
    end

    TF -->|"1. provisions VMs"| M
    TF -->|"1. provisions VMs"| W1
    TF -->|"1. provisions VMs"| W2
    M -->|"2. kubeadm init<br/>+ Calico CNI<br/>(Tigera Operator)"| M
    M -->|"3. serves join token<br/>HTTP :8000"| W1
    M -->|"3. serves join token<br/>HTTP :8000"| W2
    W1 -->|"4. kubeadm join"| M
    W2 -->|"4. kubeadm join"| M
    M -->|"5. kubeconfig"| KC
```

## How It Works (Fully Automatic)

After `terraform apply`, everything happens without any manual steps:

```
terraform apply
│
├─ Creates libvirt NAT network (192.168.100.0/24)
│
├─ Creates k8s-master VM
│    └─ cloud-init runs automatically:
│         1. Disables swap, SELinux, firewalld
│         2. Installs containerd + kubeadm via dnf/apt
│         3. Runs kubeadm init (creates control plane)
│         4. Installs Calico CNI via Tigera Operator (pod networking)
│         5. Generates join token
│         6. Starts HTTP server on port 8000
│            (python3 -m http.server serving join-command.sh)
│
├─ Creates k8s-worker-1 VM
│    └─ cloud-init runs automatically:
│         1. Disables swap, SELinux, firewalld
│         2. Installs containerd + kubeadm via dnf/apt
│         3. Polls http://192.168.100.10:8000/join-command.sh
│            (retries every 10s until master is ready)
│         4. Runs kubeadm join automatically
│
└─ Creates k8s-worker-2 VM (same as worker-1)

~5-10 minutes later → kubectl get nodes → 3 nodes Ready ✅
```

> **How workers get the join token:** The master runs a Python HTTP server (systemd service) that serves the `kubeadm join` command as a file. Workers `curl` this URL in a retry loop. No SSH keys needed between nodes.

## Project Structure

```
local-k8s-terraform/
├── terraform/
│   ├── providers.tf              # Libvirt provider v0.9.8 configuration
│   ├── variables.tf              # Configurable variables (OS, RAM, CPU, etc.)
│   ├── network.tf                # Libvirt NAT network (DHCP disabled, static IPs)
│   ├── volumes.tf                # Base cloud image + per-node cloned disks
│   ├── master.tf                 # Master node VM + cloud-init selector
│   ├── workers.tf                # Worker node VMs (count-based)
│   ├── outputs.tf                # Node IPs, SSH commands, kubeconfig path
│   └── terraform.tfvars.example  # Example configuration
├── cloud-init/
│   ├── master.yaml               # Ubuntu: apt + kubeadm init + Calico Tigera Operator
│   ├── worker.yaml               # Ubuntu: apt + kubeadm join via HTTP
│   ├── fedora-master.yaml        # Fedora/RHEL: dnf + kubeadm init + Calico Tigera Operator
│   ├── fedora-worker.yaml        # Fedora/RHEL: dnf + kubeadm join via HTTP
│   └── network-config.yaml       # Static IP assignment template
├── scripts/
│   ├── setup.sh                  # Interactive OS selection + cloud image download
│   ├── get-kubeconfig.sh         # Copy kubeconfig from master to host
│   └── destroy.sh                # Clean teardown of cluster
├── .gitignore
└── README.md
```

## Supported Operating Systems

| OS | Package Manager | Cloud Image | Best For |
|----|----------------|-------------|----------|
| **Fedora 44** (default) | `dnf` | [Fedora Cloud](https://fedoraproject.org/cloud/download) | Matches Amazon Linux / RHEL workflow |
| **Ubuntu 24.04** | `apt` | [Ubuntu Cloud](https://cloud-images.ubuntu.com/) | Debian-based environments |

Select your OS during `scripts/setup.sh` or set `os_distro` in `terraform.tfvars`.

## Prerequisites

- Linux host with KVM support (`/dev/kvm` exists)
- [QEMU/KVM](https://www.qemu.org/) and [libvirt](https://libvirt.org/) installed
- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- At least 4 GB free RAM (2 GB master + 1 GB × 2 workers)

### Install Terraform (if not installed)

> Official docs: [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install)

```bash
# Fedora
wget -O- https://rpm.releases.hashicorp.com/fedora/hashicorp.repo | sudo tee /etc/yum.repos.d/hashicorp.repo
sudo dnf -y install terraform
```

```bash
# Ubuntu / Debian
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

```bash
# RHEL / CentOS
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install terraform
```

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/khadirullah/local-k8s-terraform.git
cd local-k8s-terraform
```

### 2. Run Setup (downloads cloud image + inits Terraform)

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
# → Select OS: Fedora (1) or Ubuntu (2)
# → Downloads cloud image to /var/lib/libvirt/images/
# → Creates terraform.tfvars
# → Runs terraform init
```

### 3. Provision the Cluster

```bash
cd terraform
terraform plan
terraform apply -auto-approve
```

This creates 3 VMs. Cloud-init automatically installs K8s and joins workers to the master.

### 4. Get Kubeconfig

```bash
cd ..
./scripts/get-kubeconfig.sh
# → Waits for master to be ready
# → Copies kubeconfig to ~/.kube/config-local-k8s
```

### 5. Verify

```bash
export KUBECONFIG=~/.kube/config-local-k8s
kubectl get nodes
```

> [!IMPORTANT]
> **Nodes will show `NotReady` for ~5 minutes** — this is normal. The `get-kubeconfig.sh` script returns as soon as the API server is reachable, but the Calico CNI pods (installed via Tigera Operator) take a few minutes to pull images and reach `Running` state. Nodes transition to `Ready` only after Calico is fully initialized.

Initial output (expected — Calico is still initializing):
```
NAME           STATUS     ROLES           AGE   VERSION
k8s-master     NotReady   control-plane   14s   v1.36.x
k8s-worker-1   NotReady   <none>          21s   v1.36.x
k8s-worker-2   NotReady   <none>          15s   v1.36.x
```

After ~5-7 minutes (all nodes Ready ✅):
```
NAME           STATUS   ROLES           AGE     VERSION
k8s-master     Ready    control-plane   6m44s   v1.36.x
k8s-worker-1   Ready    <none>          6m18s   v1.36.x
k8s-worker-2   Ready    <none>          6m12s   v1.36.x
```

To monitor Calico pod status while waiting:
```bash
kubectl get pods -n calico-system -w
kubectl get pods -n tigera-operator -w
```

## Manual Worker Join (Alternative)

If you prefer to join workers manually (to understand the process):

```bash
# 1. SSH into the master node
ssh km@192.168.100.10

# 2. View the join command
cat ~/join-command.sh
# Output: kubeadm join 192.168.100.10:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# 3. SSH into a worker node
ssh km@192.168.100.11

# 4. Run the join command as root
sudo kubeadm join 192.168.100.10:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# 5. Verify from master
kubectl get nodes
```

If the token has expired (tokens expire after 24 hours):
```bash
# On master, generate a new join command
kubeadm token create --print-join-command
```

## Resource Allocation

| Node | RAM | vCPU | Disk | IP |
|------|-----|------|------|------|
| k8s-master | 2 GB | 2 | 20 GB | 192.168.100.10 |
| k8s-worker-1 | 1 GB | 1 | 15 GB | 192.168.100.11 |
| k8s-worker-2 | 1 GB | 1 | 15 GB | 192.168.100.12 |
| **Total** | **4 GB** | **4** | **50 GB** | |

All values are configurable in `terraform.tfvars`.

## Technology Stack

| Component | Version | Purpose |
|---|---|---|
| Terraform Provider (dmacvicar/libvirt) | v0.9.8 | VM provisioning via QEMU/KVM |
| Kubernetes | v1.36 | Container orchestration |
| Calico (Tigera Operator) | v3.32.1 | CNI / Pod networking + NetworkPolicy |
| containerd | 2.x | Container runtime (CRI) |
| kubeadm | v1.36 | Cluster bootstrapping |
| Pause container | 3.11 | Infrastructure pod container |

## Key Design Decisions

1. **Cloud Images over ISOs**: Using official cloud images (Fedora/Ubuntu) with cloud-init instead of ISO installers. VM provisioning is reproducible and fast (~30 seconds per VM boot).

2. **HTTP-based Join Token**: The master serves the `kubeadm join` command via a Python HTTP server (systemd service on port 8000). Workers `curl` this endpoint in a retry loop. This avoids SSH key distribution complexity between nodes.

3. **Calico CNI via Tigera Operator**: Using the Tigera Operator for Calico lifecycle management, which is the recommended production approach. Provides NetworkPolicy support essential for production-like environments.

4. **kubeadm**: The official Kubernetes bootstrapping tool. Mirrors how production clusters are built and gives full control over cluster configuration.

5. **NAT Network with Static IPs**: VMs use a libvirt NAT network with DHCP disabled. Static IPs are assigned via cloud-init network config, making the cluster deterministic and reproducible.

6. **Fedora as Default**: Fedora uses `dnf`, same as Amazon Linux 2023 and RHEL. Practicing locally on Fedora means the same commands work on AWS.

7. **Libvirt Provider v0.9.x**: Uses the rewritten provider that maps 1:1 with libvirt XML schemas, providing more control and better validation of VM configurations.

8. **qcow2 Backing Store (Thin Clones)**: The base cloud image is uploaded once to the libvirt storage pool as a read-only backing file. Each VM's disk is a thin copy-on-write (CoW) overlay — only the diffs are stored. This means 3 VMs share one base image and use minimal extra disk space instead of duplicating the full image per node.

## What You Can Do After Setup

- Deploy the monitoring stack from [`terraform-eks-monitoring`](https://github.com/khadirullah/terraform-eks-monitoring) K8s manifests
- Deploy the DevSecOps app from [`devsecops-pipeline`](https://github.com/khadirullah/devsecops-pipeline) K8s manifests
- Practice with Deployments, Services, Ingress, RBAC, NetworkPolicies
- Test ArgoCD GitOps workflows locally
- Simulate node failures (stop a VM in virt-manager, watch K8s reschedule pods)

## Cleanup

To completely tear down the cluster and free up your system resources, you can use the provided script:

```bash
./scripts/destroy.sh
```

**Alternatively**, you can run the manual commands:

```bash
cd terraform
terraform destroy -auto-approve

# (Optional) Clean up the downloaded local kubeconfig file:
rm ~/.kube/config-local-k8s
```

## Upgrading from v1.0

> [!WARNING]
> If you have a cluster running from v1.0, you must **destroy it first** before using v2.0.
>
> ```bash
> cd terraform
> terraform destroy -auto-approve
> ```

**Why?** The Libvirt Terraform provider was completely rewritten between v0.8.0 → v0.9.8. It moved from Terraform's old SDK to the modern Plugin Framework, changing all resource attribute schemas:

```hcl
# v1.0 (provider 0.8.x) — flat attributes
resource "libvirt_volume" "master" {
  format         = "qcow2"
  base_volume_id = libvirt_volume.base.id
  size           = var.master_disk_size
}

# v2.0 (provider 0.9.x) — nested blocks (maps 1:1 to libvirt XML)
resource "libvirt_volume" "master" {
  target        = { format = { type = "qcow2" } }
  backing_store = { path = libvirt_volume.base.path }
  capacity      = var.master_disk_size
}
```

Terraform's state file (`.tfstate`) stores the old attribute names. The new provider can't read the old state format, so `terraform plan` would fail. Destroying first removes the old state cleanly.

> [!NOTE]
> This only affects this local lab project. In production environments, providers typically include automatic state migration code that handles schema changes transparently — you'd never need to destroy production infrastructure for a provider upgrade.

## Related Blog Posts

- [How to Create Linked Clones in Virt-Manager](https://khadirullah.com/blog/virt-manager-linked-clones/) — The qcow2 backing store technique used by this project to save disk space
- [How to Run Amazon Linux 2023 Locally with QEMU/KVM](https://khadirullah.com/blog/amazon-linux-qemu-local-lab/) — Running cloud images locally with Cloud-Init — the foundational concept behind this project

## License

MIT License

## Author

**Khadirullah Mohammad** — [khadirullah.com](https://khadirullah.com) | [LinkedIn](https://linkedin.com/in/khadirullah) | [GitHub](https://github.com/khadirullah)
