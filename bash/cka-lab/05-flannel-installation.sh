#!/bin/bash

read -p "POD CIDR Address: " k8s-pod-cidr-address
read -p "POD CIDR Bit: " k8s-pod-cidr-bit

export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged

helm repo add flannel https://flannel-io.github.io/flannel/
helm install flannel --set podCidr="${k8s-pod-cidr}/${k8s-pod-cidr-bit}" --namespace kube-flannel flannel/flannel