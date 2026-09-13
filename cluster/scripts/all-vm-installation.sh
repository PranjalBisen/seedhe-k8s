#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes node preparation
#
# Run this script on:
#   1. Control-plane VM
#   2. Worker-1 VM
#   3. Worker-2 VM
#
# What this script does:
#   - Disables swap because kubelet rejects swap by default
#   - Installs containerd (our Kubernetes container runtime)
#   - Configures containerd to use systemd cgroups
#   - Enables required Linux networking settings
#   - Installs CNI plugin binaries
#   - Installs kubeadm, kubelet and kubectl
#
# This script does NOT create a Kubernetes cluster yet.
# That happens later with kubeadm init/join.
# ==============================================================================

K8S_MINOR="v1.37"
CNI_PLUGINS_VERSION="v1.7.1"

# Allow the script to work whether it is run as root or as a normal user.
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ------------------------------------------------------------------------------
# 1. Check the operating system
# ------------------------------------------------------------------------------
# This version of the lab targets Debian/Ubuntu-style systems because we use apt.

source /etc/os-release

case "${ID:-}" in
    ubuntu|debian)
        ;;
    *)
        echo "ERROR: This script currently supports Ubuntu/Debian only."
        exit 1
        ;;
esac

# ------------------------------------------------------------------------------
# 2. Disable swap
# ------------------------------------------------------------------------------
# kubelet normally refuses to start when swap is enabled.
# swapoff disables it immediately.
# The /etc/fstab change prevents it from coming back after reboot.

echo "==> Disabling swap"

$SUDO swapoff -a

$SUDO sed -ri \
    's/^[[:space:]]*([^#][^[:space:]]*[[:space:]]+swap[[:space:]]+.*)$/# \1/' \
    /etc/fstab

# ------------------------------------------------------------------------------
# 3. Install basic host dependencies + containerd
# ------------------------------------------------------------------------------
# containerd is the container runtime Kubernetes will use.
#
# Kubernetes talks to a runtime through CRI
# (Container Runtime Interface).
#
# Docker Engine does not implement CRI directly, which is why we are using
# containerd for this lab instead of adding cri-dockerd.

echo "==> Installing host dependencies and containerd"

$SUDO apt-get update

$SUDO apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gpg \
    containerd \
    conntrack \
    socat \
    ethtool \
    ebtables

# ------------------------------------------------------------------------------
# 4. Load Linux kernel modules required by container networking
# ------------------------------------------------------------------------------
# These kernel modules provide networking functionality needed by
# Kubernetes/container networking.

echo "==> Loading kernel modules"

$SUDO tee /etc/modules-load.d/k8s.conf >/dev/null <<'EOF'
overlay
br_netfilter
EOF

$SUDO modprobe overlay
$SUDO modprobe br_netfilter

# ------------------------------------------------------------------------------
# 5. Configure Linux networking
# ------------------------------------------------------------------------------
# ip_forward allows Linux to forward IP packets.
#
# br_netfilter allows bridged traffic to be visible to iptables/nftables,
# which Kubernetes networking relies on.

echo "==> Configuring kernel networking"

$SUDO tee /etc/sysctl.d/99-kubernetes-cri.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

$SUDO sysctl --system >/dev/null

# ------------------------------------------------------------------------------
# 6. Generate containerd's configuration
# ------------------------------------------------------------------------------
# containerd works with a default configuration, but Kubernetes works best
# when the runtime and kubelet use the same systemd cgroup driver.
#
# We generate a clean config first, then change SystemdCgroup to true.

echo "==> Configuring containerd"

$SUDO mkdir -p /etc/containerd

$SUDO sh -c \
    'containerd config default > /etc/containerd/config.toml'

# IMPORTANT:
# The exact TOML path differs between containerd major versions.
#
# This lab uses the version packaged by the OS and supports the common
# containerd 1.x configuration layout.

$SUDO sed -i \
    's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml

$SUDO systemctl enable --now containerd
$SUDO systemctl restart containerd

# ------------------------------------------------------------------------------
# 7. Add the official Kubernetes apt repository
# ------------------------------------------------------------------------------
# Kubernetes uses a separate package repository for each minor version.
#
# We explicitly choose v1.37 so all three nodes install the same Kubernetes
# minor version.

echo "==> Adding Kubernetes ${K8S_MINOR} repository"

$SUDO mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL \
    "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
    | $SUDO gpg --dearmor --yes \
        -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat <<EOF | $SUDO tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /
EOF

$SUDO apt-get update

# ------------------------------------------------------------------------------
# 8. Install Kubernetes node binaries
# ------------------------------------------------------------------------------
#
# kubeadm  -> bootstraps/initializes the cluster
# kubelet  -> agent running on every node; actually starts/manages Pods
# kubectl  -> CLI used by us to talk to the Kubernetes API
#
# These are installed on all three machines.
#
# Kubernetes recommends holding these packages so a normal apt upgrade does
# not unexpectedly change the Kubernetes version.

echo "==> Installing kubeadm, kubelet and kubectl"

$SUDO apt-get install -y kubeadm kubelet kubectl

$SUDO apt-mark hold kubeadm kubelet kubectl

$SUDO systemctl enable kubelet

# ------------------------------------------------------------------------------
# 9. Install standard CNI plugin binaries
# ------------------------------------------------------------------------------
# IMPORTANT:
#
# "CNI" has two related pieces:
#
#   1. CNI plugin binaries on the Linux nodes
#   2. The actual Kubernetes networking plugin we will deploy later
#      (Flannel)
#
# These binaries provide the low-level executable plugins that networking
# components can call.
#
# The actual Pod network is installed later by install-cni.sh.

echo "==> Installing CNI plugin binaries"

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64)
        CNI_ARCH="amd64"
        ;;
    aarch64|arm64)
        CNI_ARCH="arm64"
        ;;
    armv7l|armv7*)
        CNI_ARCH="arm"
        ;;
    ppc64le)
        CNI_ARCH="ppc64le"
        ;;
    s390x)
        CNI_ARCH="s390x"
        ;;
    riscv64)
        CNI_ARCH="riscv64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

$SUDO mkdir -p /opt/cni/bin

curl -fsSL \
    "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${CNI_ARCH}-${CNI_PLUGINS_VERSION}.tgz" \
    | $SUDO tar -C /opt/cni/bin -xz

# ------------------------------------------------------------------------------
# 10. Print what we installed
# ------------------------------------------------------------------------------

echo
echo "=============================================="
echo " Node preparation complete"
echo "=============================================="

echo "containerd:"
containerd --version

echo
echo "kubeadm:"
kubeadm version -o short

echo
echo "kubelet:"
kubelet --version

echo
echo "kubectl:"
kubectl version --client -o yaml | awk -F': ' '/gitVersion:/ {print $2; exit}'

echo
echo "CNI architecture: ${CNI_ARCH}"

echo
echo "This node is now prepared."
echo "Next step depends on the node role:"
echo "  Control plane -> kubeadm init"
echo "  Worker        -> kubeadm join"
