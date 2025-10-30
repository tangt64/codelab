#!/usr/bin/env bash
set -euo pipefail
WORKDIR="/root/pki"
EXT_CN="openstack.vlab.dustbox.kr"
EXT_VIP_IP="192.168.1.250"
INT_CN="int.openstack.cluster"
INT_VIP_IP="192.168.1.250"
EXT_DNS=(
  "openstack.vlab.dustbox.kr"
  "horizon.vlab.dustbox.kr"
  "skyline.vlab.dustbox.kr"
  "tang.dustbox.kr"
  "www.dustbox.kr"
  "*.dustbox.kr"
  "*.vlab.dustbox.kr"
)
mkdir -p "$WORKDIR"
cd "$WORKDIR"
if [[ ! -f rootCA.key || ! -f rootCA.crt ]]; then
  openssl genrsa -out rootCA.key 4096
  openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650     -subj "/C=KR/O=dustbox/OU=CA/CN=dustbox-rootCA"     -out rootCA.crt
fi
cat > ext-openssl.cnf <<'EOF'
[req]
prompt = no
distinguished_name = dn
req_extensions = v3_req
[dn]
C = KR
O = dustbox
OU = openstack
CN = __EXT_CN__
[v3_req]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
__ALT_NAMES__
EOF
ALT_LINES=()
i=1
for name in "${EXT_DNS[@]}"; do
  ALT_LINES+=("DNS.${i} = ${name}")
  ((i++))
done
if [[ -n "${EXT_VIP_IP:-}" ]]; then
  ALT_LINES+=("IP.${i} = ${EXT_VIP_IP}")
fi
sed -i "s|__EXT_CN__|${EXT_CN}|g" ext-openssl.cnf
printf "%s\n" "${ALT_LINES[@]}" > /tmp/_alt.tmp
awk -v r="$(cat /tmp/_alt.tmp)" '{gsub(/__ALT_NAMES__/,r)}1' ext-openssl.cnf > ext-openssl.cnf.tmp
mv ext-openssl.cnf.tmp ext-openssl.cnf
rm -f /tmp/_alt.tmp
openssl genrsa -out haproxy-external.key 2048
openssl req -new -key haproxy-external.key -out haproxy-external.csr -config ext-openssl.cnf
openssl x509 -req -in haproxy-external.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial   -out haproxy-external.crt -days 825 -sha256 -extensions v3_req -extfile ext-openssl.cnf
cat haproxy-external.crt rootCA.crt haproxy-external.key > haproxy-full.pem
chmod 640 haproxy-full.pem
cat > int-openssl.cnf <<'EOF'
[req]
prompt = no
distinguished_name = dn
req_extensions = v3_req
[dn]
C = KR
O = dustbox
OU = openstack
CN = __INT_CN__
[v3_req]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = __INT_CN__
IP.1  = __INT_IP__
EOF
sed -i "s|__INT_CN__|${INT_CN}|g" int-openssl.cnf
sed -i "s|__INT_IP__|${INT_VIP_IP}|g" int-openssl.cnf
openssl genrsa -out haproxy-internal.key 2048
openssl req -new -key haproxy-internal.key -out haproxy-internal.csr -config int-openssl.cnf
openssl x509 -req -in haproxy-internal.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial   -out haproxy-internal.crt -days 825 -sha256 -extensions v3_req -extfile int-openssl.cnf
cat haproxy-internal.crt rootCA.crt haproxy-internal.key > haproxy-internal.pem
chmod 640 haproxy-internal.pem
echo "[✓] Done: $WORKDIR/{haproxy-full.pem, haproxy-internal.pem, rootCA.crt}"
