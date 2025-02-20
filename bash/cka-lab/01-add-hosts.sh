#!/bin/bash
cat <<EOF>> /etc/hosts
192.168.10.20 cluster1-node1.example.com cluster1-node1
192.168.10.21 cluster1-node2.example.com cluster1-node2
192.168.10.22 cluster1.node3.example.com cluster1-node3

192.168.10.30 cluster2-node1.example.com cluster2-node1
192.168.10.31 cluster2-node2.example.com cluster2-node2
192.168.10.32 cluster2.node3.example.com cluster2-node3
EOF