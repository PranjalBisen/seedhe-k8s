#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Generate the worker join command
#
# The control plane is already running.
#
# kubeadm now creates/prints the bootstrap information a new worker needs
# to securely join this cluster.
# ==============================================================================

CRI_SOCKET="unix:///run/containerd/containerd.sock"

# ------------------------------------------------------------------------------
# Make sure this is actually an initialized control plane.
# ------------------------------------------------------------------------------

if [[ ! -f /etc/kubernetes/admin.conf ]]; then
    echo "ERROR: /etc/kubernetes/admin.conf was not found."
    echo "Run this only after kubeadm init."
    exit 1
fi

# ------------------------------------------------------------------------------
# Generate a fresh bootstrap token and print the complete join command.
# ------------------------------------------------------------------------------
#
# The generated command contains:
#
#   <API server address>:6443
#   bootstrap token
#   CA discovery hash
#
# The worker uses these to contact and authenticate with the cluster during
# bootstrap.

JOIN_COMMAND="$(sudo kubeadm token create --print-join-command)"

echo
echo "=============================================="
echo " Worker join command"
echo "=============================================="
echo
echo "Run the following command on EACH worker:"
echo
echo "sudo ${JOIN_COMMAND} --cri-socket ${CRI_SOCKET}"
echo
echo "Do not run this on the control plane."
