#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Add the conventional "worker" role label to nodes.
#
# IMPORTANT:
#   This does NOT change the node's actual identity.
#   We are simply adding a Kubernetes label.
#
# Why?
#   kubectl get nodes will then display:
#
#   worker-1   Ready   worker
#   worker-2   Ready   worker
#
# The label can also be used by scheduling rules later.
# ==============================================================================

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <worker-node> [worker-node ...]"
    exit 1
fi

for NODE in "$@"; do

    # Make sure the node actually exists before trying to label it.
    kubectl get node "$NODE" >/dev/null

    echo "==> Labelling ${NODE} as a worker"

    kubectl label node "$NODE" \
        node-role.kubernetes.io/worker= \
        --overwrite
done

echo
echo "=============================================="
echo " Cluster nodes"
echo "=============================================="

kubectl get nodes -o wide
