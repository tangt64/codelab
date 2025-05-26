#!/bin/bash

# pacemaker.xml 마이그레이션 전 필수 리소스 확인 및 필터링

XML_FILE="$1"

if [ -z "$XML_FILE" ]; then
    echo "Usage: $0 <pacemaker.xml>"
    exit 1
fi

echo "🔍 Checking for unsupported or missing resource agents..."

# 리소스 에이전트 경로 필터
echo "== Resource Agent Types in XML =="
grep -oP 'ocf:[^"]+' "$XML_FILE" | sort | uniq

echo ""
echo "📌 TIP: Make sure the following agents exist under /usr/lib/ocf/resource.d/"

echo ""
echo "🔍 Checking STONITH devices..."
grep -i stonith "$XML_FILE" | grep -i primitive || echo "No explicit STONITH device found."

echo ""
echo "🧠 Suggestion: If migrating to RHEL, ensure 'fence-agents-all' is installed."

echo ""
echo "✅ Node name(s) used in XML:"
grep '<node ' "$XML_FILE" | sed -E 's/.*uname="([^"]+)".*/\1/' | sort

echo ""
echo "Done. Review output above before using 'cibadmin --replace'."
