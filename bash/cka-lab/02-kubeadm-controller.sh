#!/bin/bash
read -p "API Address: " k8sapiaddress

cat <<EOF> kubeadm-controller-config.yaml
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  name: "cluster1-node1.example.com"
localAPIEndpoint:
  advertiseAddress: "${k8sapiaddress}"
  bindPort: 6443
bootstrapTokens:
  - token: "abcdef.0123456789abcdef"
    ttl: "24h0m0s"
    description: "bootstrap token"
    usages:
      - authentication
      - signing
    groups:
      - system:bootstrappers:kubeadm:default-node-token
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.30.0
networking:
  podSubnet: "192.168.0.0/16"
  serviceSubnet: "10.96.0.0/16"
  dnsDomain: "cluster.local"
controlPlaneEndpoint: "${k8sapiaddress}:6443"
EOF

kubeadm init --config=kubeadm-controller-config.yaml