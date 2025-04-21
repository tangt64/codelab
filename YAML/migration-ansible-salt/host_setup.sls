set-hostname:
  cmd.run:
    - name: |
        if [ "$(hostname -I | grep 192.168.10.10)" ]; then hostnamectl set-hostname node1.example.com;
        elif [ "$(hostname -I | grep 192.168.10.20)" ]; then hostnamectl set-hostname node2.example.com;
        fi

update-packages:
  pkg.uptodate: []

partition-vdf:
  cmd.run:
    - name: |
        parted -s /dev/vdf mklabel gpt mkpart primary ext4 0% 50% mkpart primary xfs 50% 100%

format-vdf1:
  cmd.run:
    - name: mkfs.ext4 -F /dev/vdf1

format-vdf2:
  cmd.run:
    - name: mkfs.xfs -f /dev/vdf2

install-cockpit:
  pkg.installed:
    - name: cockpit

enable-cockpit:
  service.running:
    - names:
      - cockpit
      - cockpit.socket
    - enable: True

open-firewalld-port:
  firewalld.present:
    - port: 9090/tcp
    - permanent: True
    - immediate: True
    - require:
      - pkg: firewalld
