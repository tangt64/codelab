kubernetes.repo:
  cmd.run:
    - name: |
        cat <<EOF > /etc/yum.repos.d/kubernetes.repo
        [kubernetes]
        name=Kubernetes
        baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
        enabled=1
        gpgcheck=1
        gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
        EOF
    - unless: test -f /etc/yum.repos.d/kubernetes.repo

crio.repo:
  cmd.run:
    - name: |
        cat <<EOF > /etc/yum.repos.d/crio.repo
        [cri-o]
        name=CRI-O
        baseurl=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v1.32/rpm/
        enabled=1
        gpgcheck=1
        gpgkey=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v1.32/rpm/repodata/repomd.xml.key
        EOF
    - unless: test -f /etc/yum.repos.d/crio.repo

kubernetes.packages:
  pkg.installed:
    - pkgs:
      - kubelet
      - kubeadm
      - kubectl
      - cri-o
    - skip_verify: True
    - refresh: True

kubelet.service:
  service.running:
    - enable: True
