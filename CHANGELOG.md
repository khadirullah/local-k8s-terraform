# Changelog

This file lists the notable changes in each release.

## [2.1] - 2026-09-25

Upgrading from 2.0 means rebuilding the cluster with `scripts/destroy.sh`, `scripts/setup.sh` and `terraform apply`. cloud-init only runs on first boot, so VMs built by 2.0 keep the old join server, token and network setup until you rebuild them. The README section "Upgrading from v2.0" has the steps.

### Security

- The join server on port 8000 served all of `/home/km`, including the admin kubeconfig, so any VM or pod that reached the port could download cluster-admin. It now serves only `/srv/k8s-join` and runs as a throwaway systemd user that cannot see `/home`. `21b9466`
- The served join token lasted 24 hours, long enough for anything on the network to join a rogue node and have pods and their secrets scheduled onto it. The token now expires after one hour. `cf7a694`

### Fixed

- The Fedora option never booted in 2.0 because `setup.sh` asked for the wrong image file name and every mirror answered 404. It now downloads `Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2`. `2b8e245`
- A failed image download left a small error page named like the image, and the next run built VMs from it. Downloads now go to a `.part` file that only gets renamed once wget succeeds. `0a89550`
- Changing the OS in the `setup.sh` menu after the first run only changed which image got downloaded, and Terraform kept building the old OS. `setup.sh` now updates `os_distro` and `base_image_path` in `terraform.tfvars` on every run and leaves your other settings alone. `a5dcd29`
- Fedora nodes never got an IP address because NetworkManager ignores the `en*` interface match in network-config. Each node now gets a fixed MAC derived from its IP, and network-config matches on that MAC on both Fedora and Ubuntu. `f7e43cb`
- On Fedora 44, dnf5 rejected `--disableexcludes`, so kubeadm, kubelet and kubectl never installed. The install now uses `--setopt=disable_excludes=kubernetes`, and a routine `dnf upgrade` still leaves Kubernetes alone. `6e6bd8d`
- Fedora's zram swap came back after `swapoff -a`, so kubelet refused to start and `kubeadm init` timed out. cloud-init now disables the zram generator, and swap stays off across reboots. `296730f`
- Fedora nodes registered as `k8s-master.k8s.local` while Ubuntu nodes registered as `k8s-master`. Both now use the short hostname, and the FQDN domain in cloud-init follows `cluster_name` instead of a hard-coded `k8s.local`. `f26ce4b`
- The control plane ran at the `.0` patch release while kubelets ran the newest patch, so the API server missed patch fixes. kubeadm now reads the version from the installed kubeadm just before init. `3be1b87`

### Changed

- Terraform now checks `k8s_version` at plan time. A patch number, a leading `v`, or anything below 1.31 fails right away instead of minutes later inside the VM. `3be1b87`

### Docs

- The README explains what values `k8s_version` takes, why the default is 1.36, and that changing it does not upgrade a running cluster. `9c8ffc1`
- The README explains the MAC address match and the Fedora 44 dnf5 and zram changes. `5b82930`
- The README says that `cluster_name` sets the node names and adds an "Upgrading from v2.0" section. This changelog is new in 2.1.

## [2.0] - 2026-08-16

This release moves every part of the stack to current versions. A cluster built with 1.0 has to be destroyed before you apply 2.0, because the new libvirt provider cannot read the old Terraform state. `69e19f0`

### Changed

- The libvirt provider goes from 0.8.0 to 0.9.8, a rewrite on the Terraform Plugin Framework with new resource schemas. `69e19f0`
- Kubernetes goes from 1.30 to 1.36, and the kubeadm config moves from v1beta3 to v1beta4. `69e19f0`
- Calico goes from the v3.27.0 manifest to v3.32.1 installed by the Tigera Operator. `69e19f0`
- containerd uses config version 3, and the pause image goes from 3.9 to 3.11. `69e19f0`
- The base images go from Ubuntu 22.04 to 24.04 and from Fedora 40 to 44. `69e19f0`

### Fixed

- cloud-init no longer races the Calico CRDs during setup. `69e19f0`

### Docs

- The README covers installing Terraform on Fedora, Ubuntu and RHEL, the delay before Calico networking comes up, and how to upgrade from 1.0. `69e19f0`

## [1.0] - 2026-08-15

Initial release. Terraform and the libvirt provider build a 3-node Kubernetes cluster on local QEMU/KVM VMs, one master and two workers, on Ubuntu or Fedora cloud images. cloud-init and kubeadm do the whole install, and `scripts/setup.sh` takes you from nothing to `kubectl get nodes` in one command. `86ec2d6`
