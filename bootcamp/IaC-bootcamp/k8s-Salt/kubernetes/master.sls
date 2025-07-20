init-cluster:
  cmd.run:
    - name: kubeadm init --pod-network-cidr=10.244.0.0/16
    - unless: test -f /etc/kubernetes/admin.conf
    - require:
      - pkg: kubernetes.packages

copy-kubeconfig:
  cmd.run:
    - name: mkdir -p /root/.kube && cp -i /etc/kubernetes/admin.conf /root/.kube/config
    - unless: test -f /root/.kube/config
