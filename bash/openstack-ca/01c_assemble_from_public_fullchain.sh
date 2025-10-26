#!/usr/bin/env bash
set -euo pipefail
WORKDIR="/root/pki"
cd "$WORKDIR"
EXT_FULLCHAIN="${EXT_FULLCHAIN:-fullchain.pem}"
INT_FULLCHAIN="${INT_FULLCHAIN:-}"
if [[ ! -f "${EXT_FULLCHAIN}" ]]; then
  echo "ERROR: ${EXT_FULLCHAIN} not found. Put your public CA fullchain here." >&2
  exit 1
fi
if [[ ! -f haproxy-external.key ]]; then
  echo "ERROR: haproxy-external.key not found. Generate with 01b_gen_csrs_for_public_ca.sh." >&2
  exit 1
fi
cat "${EXT_FULLCHAIN}" haproxy-external.key > haproxy-full.pem
chmod 640 haproxy-full.pem
echo "[✓] Built external PEM: $PWD/haproxy-full.pem"
if [[ -n "${INT_FULLCHAIN}" ]]; then
  if [[ ! -f haproxy-internal.key ]]; then
    echo "ERROR: haproxy-internal.key not found." >&2
    exit 1
  fi
  cat "${INT_FULLCHAIN}" haproxy-internal.key > haproxy-internal.pem
  chmod 640 haproxy-internal.pem
  echo "[✓] Built internal PEM from public fullchain: $PWD/haproxy-internal.pem"
else
  echo "[i] Internal cert usually uses private CA. If you used 01_gen_certs.sh it already exists."
fi
