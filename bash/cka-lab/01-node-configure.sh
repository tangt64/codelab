#!/bin/bash


KUBERNETES_VERSION=v1.32
CRIO_VERSION=v1.32

dnf search kubectl kubeadm kubelet cri-o

dnf install -y cri-o kubelet kubeadm kubectl
systemctl enable --now crio.service kubelet
systemctl disable --now firewalld

cp kubernetes.repo cri-o.repo /etc/yum.repos.d/

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

cat <<EOF>> /etc/hosts
192.168.10.20 node1.example.com node1
192.168.10.21 node2.example.com node2
192.168.10.22 node3.example.com node3
EOF

