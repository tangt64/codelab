#!/bin/bash

TYPE="$1"

case "$TYPE" in
  cpumem)
    echo "==== CPU 정보 ===="
    lscpu | grep -E 'Model name|Socket|Core|Thread|CPU\(s\)'

    echo ""
    echo "==== 메모리 정보 ===="
    free -h

    echo ""
    echo "==== Top 5 메모리 사용 프로세스 ===="
    ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -n 6
    ;;
  disk)
    echo "==== 디스크 사용량 ===="
    df -h
    ;;
  uptime)
    echo "==== 시스템 업타임 ===="
    uptime

    echo ""
    echo "==== 현재 load average ===="
    cat /proc/loadavg
    ;;
  network)
    echo "==== 네트워크 인터페이스 사용량 ===="
    ip -o -4 addr show | awk '{print $2 " -> " $4}'
    echo ""

    echo "==== 인터페이스별 트래픽 (rx/tx 바이트 기준) ===="
    for iface in $(ls /sys/class/net/ | grep -v lo); do
      RX=$(cat /sys/class/net/$iface/statistics/rx_bytes)
      TX=$(cat /sys/class/net/$iface/statistics/tx_bytes)
      echo "$iface : RX=$((RX/1024)) KB, TX=$((TX/1024)) KB"
    done
    ;;
  *)
    echo "지원하지 않는 type입니다: $TYPE"
    echo "사용 가능한 옵션: cpumem, disk, uptime, network"
    exit 1
    ;;
esac
