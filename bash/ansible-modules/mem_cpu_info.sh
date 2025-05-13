#!/bin/bash

echo "==== CPU 정보 ===="
lscpu | grep -E 'Model name|Socket|Core|Thread|CPU\(s\)'

echo ""
echo "==== 메모리 정보 ===="
free -h

echo ""
echo "==== Top 5 메모리 사용 프로세스 ===="
ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -n 6
