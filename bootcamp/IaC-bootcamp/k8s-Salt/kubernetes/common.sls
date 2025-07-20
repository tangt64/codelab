kube-dependencies:
  pkg.installed:
    - pkgs:
      - curl
      - apt-transport-https
      - ca-certificates
      - gnupg

kubernetes.repo:
  cmd.run:
    - name: |
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - &&
        echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list &&
        apt-get update

kubernetes.packages:
  pkg.installed:
    - pkgs:
      - kubelet
      - kubeadm
      - kubectl

kubelet.service:
  service.running:
    - enable: True
