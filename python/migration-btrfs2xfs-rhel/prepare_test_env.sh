#!/bin/bash

# 실험용 XFS 데이터 디렉터리 생성
mkdir -p /srv/xfs-data
echo "[+] Generating test files at /srv/xfs-data..."
for i in {1..10}; do
  dd if=/dev/urandom of=/srv/xfs-data/test_file_${i}.bin bs=10M count=10 status=none
done
echo "[+] 10 files created."

# Btrfs 파일 시스템 생성
echo "[+] Formatting /dev/vdb as Btrfs..."
mkfs.btrfs -f /dev/vdb

# 마운트 및 디렉터리 생성
mkdir -p /srv/btrfs
mount /dev/vdb /srv/btrfs
echo "[+] /dev/vdb mounted to /srv/btrfs"

# fstab 항목 생성
UUID=$(blkid -s UUID -o value /dev/vdb)
echo "UUID=$UUID /srv/btrfs btrfs defaults 0 0" | tee /tmp/btrfs_fstab.txt
echo "[+] fstab entry saved to /tmp/btrfs_fstab.txt"