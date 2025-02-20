#!/bin/bash

export KUBERNETES_VERSION=v1.30
export CRIO_VERSION=v1.30

read -p "hostname: " vhostname

hostnamectl set-hostname $vhostname

cp kubernetes.repo cri-o.repo /etc/yum.repos.d/

dnf install -y cri-o kubelet kubeadm kubectl
systemctl enable --now crio.service kubelet
systemctl disable --now firewalld


sed -i 's/enforcing/permissive/g' /etc/selinux/config
setenforce 0
getenforce

swapon -s
swapoff -a

sed -i 's/\/dev\/mapper\/rl-swap/\#\/dev\/mapper\/rl-swap/g' /etc/fstab
systemctl daemon-reload

cat <<EOF> /etc/sysctl.d/k8s-mod.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sysctl --system -q

cat <<EOF> /etc/modules-load.d/k8s-modules.conf
br_netfilter
overlay
EOF
modprobe br_netfilter
modprobe overlay

