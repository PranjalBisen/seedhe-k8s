#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Initialize the Kubernetes control plane
#
# Usage:
#   ./init-control-plane.sh <CONTROL_PLANE_IP>
#
# Example:
#   ./init-control-plane.sh 192.168.1.10
#
# What this script does:
#   - Tells kubeadm which IP the API server should advertise
#   - Reserves 10.244.0.0/16 for the Pod network
#   - Uses containerd as the CRI runtime
#   - Runs kubeadm init
#   - Configures kubectl for the current user
#
# This creates the control-plane components.
# Workers are NOT joined here.
# ==============================================================================

POD_CIDR="10.244.0.0/16"

CRI_SOCKET="unix:///run/containerd/containerd.sock"

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

CONTROL_PLANE_IP="${1:-}"

# ------------------------------------------------------------------------------
# 1. Require the control-plane IP from the user
# ------------------------------------------------------------------------------
# We do not hardcode the IP because every VM environment will have different
# addresses.

if [[ -z "$CONTROL_PLANE_IP" ]]; then
    echo "Usage: $0 <CONTROL_PLANE_IP>"
    echo
    echo "Example:"
    echo "  $0 192.168.1.10"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Prevent accidental re-initialization
# ------------------------------------------------------------------------------
# /etc/kubernetes/admin.conf is created as part of kubeadm init.
# If it already exists, this node probably already has a control plane.

if [[ -f /etc/kubernetes/admin.conf ]]; then
    echo "ERROR: This control plane already appears to be initialized."
    echo "Use reset.sh first if you intentionally want to rebuild it."
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Initialize Kubernetes
# ------------------------------------------------------------------------------
#
# --apiserver-advertise-address
#   The address other Kubernetes nodes should use to reach this API server.
#
# --pod-network-cidr
#   The IP range reserved for Pods.
#
# --cri-socket
#   Explicitly tells kubeadm to use containerd.

echo "==> Initializing Kubernetes control plane"

$SUDO kubeadm init \
    --apiserver-advertise-address="$CONTROL_PLANE_IP" \
    --pod-network-cidr="$POD_CIDR" \
    --cri-socket="$CRI_SOCKET"

# ------------------------------------------------------------------------------
# 4. Configure kubectl
# ------------------------------------------------------------------------------
# kubeadm creates /etc/kubernetes/admin.conf.
#
# Copying it to ~/.kube/config allows the current user to run:
#
#   kubectl get nodes
#   kubectl get pods -A
#   etc.
#
# kubectl is the client; the API server is where those requests actually go.

echo "==> Configuring kubectl"

mkdir -p "$HOME/.kube"

$SUDO cp -f \
    /etc/kubernetes/admin.conf \
    "$HOME/.kube/config"

$SUDO chown \
    "$(id -u):$(id -g)" \
    "$HOME/.kube/config"

echo
echo "=============================================="
echo " Control plane initialized"
echo "=============================================="

echo "API server endpoint : ${CONTROL_PLANE_IP}:6443"
echo "Pod CIDR            : ${POD_CIDR}"
echo
echo "At this point the control plane exists."
echo "The Pod network still needs to be installed."
