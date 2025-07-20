join-cluster:
  cmd.run:
    - name: kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
    - unless: test -f /etc/kubernetes/kubelet.conf
    - require:
      - pkg: kubernetes.packages
