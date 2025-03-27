#!/bin/bash

read -p "Controller API Address: " k8s_api_address

cat <<EOF>> kubeadm-compute-join.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken:
    apiServerEndpoint: "${k8s_api_address}:6443"
    token: abcdef.0123456789abcdef
    unsafeSkipCAVerification: true
  timeout: 5m0s
  tlsBootstrapToken: abcdef.0123456789abcdef
EOF


kubeadm join --config=kubeadm-compute-join.yaml