#!/bin/bash

read -p "POD CIDR Address: " k8s_pod_cidr_address
read -p "POD CIDR Bit: " k8s_pod_cidr_bit

export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged

helm repo add flannel https://flannel-io.github.io/flannel/
helm install flannel --set podCidr="${k8s_pod_cidr}/${k8s_pod_cidr_bit}" --namespace kube-flannel flannel/flannel