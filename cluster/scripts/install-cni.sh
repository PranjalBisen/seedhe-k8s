#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Install the Pod network
#
# We use Flannel for this learning cluster.
#
# Important:
#   kubeadm knows what Pod CIDR we want,
#   but kubeadm does NOT build the Pod network itself.
#
#   Flannel is the networking implementation that makes that Pod network work.
# ==============================================================================

FLANNEL_VERSION="v0.28.8"

POD_CIDR="10.244.0.0/16"

MANIFEST_URL="https://github.com/flannel-io/flannel/releases/download/${FLANNEL_VERSION}/kube-flannel.yml"

echo "==> Downloading Flannel manifest"

TMP_FILE="$(mktemp)"

# Always delete the temporary manifest when the script exits.
trap 'rm -f "$TMP_FILE"' EXIT

curl -fsSL "$MANIFEST_URL" -o "$TMP_FILE"

# ------------------------------------------------------------------------------
# Verify that the Flannel manifest uses the same Pod network we gave kubeadm.
# ------------------------------------------------------------------------------
#
# kubeadm:
#   --pod-network-cidr=10.244.0.0/16
#
# Flannel:
#   Network=10.244.0.0/16
#
# These need to agree.

echo "==> Verifying Flannel Pod CIDR"

grep -q "\"Network\": \"${POD_CIDR}\"" "$TMP_FILE" || {
    echo "ERROR: Flannel manifest does not use ${POD_CIDR}."
    exit 1
}

# ------------------------------------------------------------------------------
# Install Flannel into the cluster.
# ------------------------------------------------------------------------------
#
# kubectl sends the manifest to the Kubernetes API server.
# Kubernetes then creates the Flannel resources, including its DaemonSet.

echo "==> Installing Flannel ${FLANNEL_VERSION}"

kubectl apply -f "$TMP_FILE"

# ------------------------------------------------------------------------------
# Wait for CoreDNS.
# ------------------------------------------------------------------------------
#
# CoreDNS is deployed by kubeadm, but it cannot become fully functional
# until the Pod network exists.
#
# Once Flannel is working, CoreDNS should be able to run normally.

echo "==> Waiting for CoreDNS"

kubectl -n kube-system rollout status \
    deployment/coredns \
    --timeout=180s

echo
echo "=============================================="
echo " Pod network installed"
echo "=============================================="

kubectl get pods -A
