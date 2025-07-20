base:
  '*':
    - kubernetes.common

  'k8s-master*':
    - kubernetes.master

  'k8s-worker*':
    - kubernetes.worker
