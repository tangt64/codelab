#!/usr/bin/env bash
set -euo pipefail
INV="${INV:-/etc/kolla/inventory}"
CAFILE="${CAFILE:-/etc/kolla/certificates/ca/root.crt}"
INT_FQDN="int.openstack.cluster"
EXT_FQDN="openstack.vlab.dustbox.kr"
echo "[1/4] HAProxy만 재구성"
kolla-ansible -i "${INV}" -t haproxy reconfigure
echo "[2/4] 주요 서비스 순차 재구성 (CA 갱신 반영)"
kolla-ansible -i "${INV}" -t keystone,horizon,skyline,memcached reconfigure
kolla-ansible -i "${INV}" -t glance,nova,neutron,cinder,placement reconfigure
kolla-ansible -i "${INV}" -t octavia,magnum,trove,zun,kuryr,mistral,barbican reconfigure || true
echo "[3/4] 체인 및 호스트명 검증"
if [[ -f "${CAFILE}" ]]; then
  openssl s_client -connect "${EXT_FQDN}:443" -servername "${EXT_FQDN}" -CAfile "${CAFILE}" -verify_return_error </dev/null | openssl x509 -noout -subject -issuer || true
  openssl s_client -connect "${INT_FQDN}:443" -servername "${INT_FQDN}" -CAfile "${CAFILE}" -verify_return_error </dev/null | openssl x509 -noout -subject -issuer
else
  echo "[i] CAFILE not found; skipping external -CAfile (public CA expected)"
  openssl s_client -connect "${EXT_FQDN}:443" -servername "${EXT_FQDN}" </dev/null | openssl x509 -noout -subject -issuer || true
  openssl s_client -connect "${INT_FQDN}:443" -servername "${INT_FQDN}" -CAfile "/etc/kolla/certificates/ca/root.crt" -verify_return_error </dev/null | openssl x509 -noout -subject -issuer || true
fi
echo "[4/4] Keystone 헬스체크"
if [[ -f "${CAFILE}" ]]; then
  curl -I "https://${INT_FQDN}:5000/" --cacert "${CAFILE}"
else
  curl -I "https://${EXT_FQDN}:5000/" || true
fi
echo "[✓] Done."
