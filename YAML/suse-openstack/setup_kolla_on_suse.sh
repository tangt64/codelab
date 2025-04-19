#!/bin/bash
# SUSE에서 Kolla-Ansible 설치 자동화 스크립트
set -e

echo "[1/5] 필수 패키지 설치"
sudo zypper install -y python3 python3-pip gcc libffi-devel openssl-devel git docker python3-devel

echo "[2/5] Docker 활성화"
sudo systemctl enable --now docker

echo "[3/5] Python 가상환경 및 Kolla-Ansible 설치"
python3 -m venv kolla-venv
source kolla-venv/bin/activate
pip install -U pip
pip install 'ansible<8.0.0' kolla-ansible

echo "[4/5] Kolla-Ansible 설정 복사"
mkdir -p /etc/kolla
cp -r $(python -c 'import kolla_ansible; print(kolla_ansible.__path__[0])')/etc/kolla/* /etc/kolla/

echo "[5/5] Kolla 인벤토리 초기화"
cd /etc/kolla
cp -r /usr/share/kolla-ansible/ansible/inventory/* . 2>/dev/null || true
kolla-genpwd

echo "Kolla-Ansible 설치 완료! /etc/kolla/globals.yml을 수정하세요."
