#!/usr/bin/env bash
set -euo pipefail
SRC="/root/pki"
DST="/etc/kolla/certificates"
TODAY="$(date +%Y%m%d_%H%M%S)"
install -d "${DST}/ca"
if [[ -f "${DST}/haproxy-full.pem" ]]; then
  cp -a "${DST}/haproxy-full.pem" "${DST}/haproxy-full.pem.bak.${TODAY}"
fi
if [[ -f "${DST}/haproxy-internal.pem" ]]; then
  cp -a "${DST}/haproxy-internal.pem" "${DST}/haproxy-internal.pem.bak.${TODAY}"
fi
if [[ -f "${DST}/ca/root.crt" ]]; then
  cp -a "${DST}/ca/root.crt" "${DST}/ca/root.crt.bak.${TODAY}"
fi
[[ -f "${SRC}/haproxy-full.pem" ]] && cp -a "${SRC}/haproxy-full.pem" "${DST}/"
[[ -f "${SRC}/haproxy-internal.pem" ]] && cp -a "${SRC}/haproxy-internal.pem" "${DST}/"
[[ -f "${SRC}/rootCA.crt" ]] && cp -a "${SRC}/rootCA.crt" "${DST}/ca/root.crt" || true
chmod 640 "${DST}/haproxy-full.pem" "${DST}/haproxy-internal.pem" 2>/dev/null || true
chmod 640 "${DST}/ca/root.crt" 2>/dev/null || true
chown root:kolla "${DST}/haproxy-full.pem" "${DST}/haproxy-internal.pem" 2>/dev/null || true
chown root:kolla "${DST}/ca/root.crt" 2>/dev/null || true
echo "[✓] Installed to ${DST}"
