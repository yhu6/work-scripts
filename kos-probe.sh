#!/usr/bin/bash
export KUBECONFIG="/etc/kubernetes/admin.conf"

target_pods=${1:-"ALL"}
if [[ x$target_pods == x"ALL" ]]; then
    kubectl -n openstack get pods
else
    kubectl -n openstack get pods | grep -i $target_pods
fi

