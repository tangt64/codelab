#!/usr/bin/env bash
# 목적:
# - Kolla 기본 CA(root.crt/root.key)를 "내가 만든 사설 CA"로 교체
# - 컨테이너 내부 CA 번들을 최신으로 반영(순차 reconfigure)
# - 안전한 백업/롤백 포인트 생성
#
# 전제:
# - /root/pki/rootCA.crt (필수), /root/pki/rootCA.key(선택: 사설CA 키를 교체할 때만)
# - /etc/kolla/globals.yml 에서 kolla_copy_ca_into_containers: "yes"
# - 01~03 단계를 이미 완료했거나, 최소한 haproxy PEM 교체는 끝난 상태
set -euo pipefail

# ===== 사용자 환경 변수 =====
INV="${INV:-/etc/kolla/inventory}"          # kolla-ansible 인벤토리 경로
SRC_CA="${SRC_CA:-/root/pki/rootCA.crt}"    # 새 루트CA(필수)
SRC_KEY="${SRC_KEY:-/root/pki/rootCA.key}"  # 새 루트CA 개인키(선택)
DST_DIR="/etc/kolla/certificates"
DST_CA_DIR="${DST_DIR}/ca"
NOW="$(date +%Y%m%d_%H%M%S)"

INT_FQDN="${INT_FQDN:-int.openstack.cluster}"
EXT_FQDN="${EXT_FQDN:-openstack.vlab.dustbox.kr}"
CAFILE="${CAFILE:-${DST_CA_DIR}/root.crt}"

# ===== 사전 점검 =====
if [[ ! -f "${SRC_CA}" ]]; then
  echo "ERROR: ${SRC_CA} not found. (새 루트CA 인증서 필요)" >&2
  exit 1
fi

echo "[1/6] 백업 디렉터리 준비"
install -d "${DST_CA_DIR}"
pushd "${DST_CA_DIR}" >/dev/null
# 기존 CA/키 백업
[[ -f root.crt ]] && cp -a root.crt "root.crt.bak.${NOW}"
[[ -f root.key ]] && cp -a root.key "root.key.bak.${NOW}"
popd >/dev/null

echo "[2/6] Kolla 기본 CA를 나의 CA로 교체"
cp -a "${SRC_CA}" "${DST_CA_DIR}/root.crt"
if [[ -f "${SRC_KEY}" ]]; then
  # 선택: 사설 CA 키까지 교체할 경우에만 복사
  cp -a "${SRC_KEY}" "${DST_CA_DIR}/root.key"
else
  echo "[i] ${SRC_KEY} 가 없어 root.key는 교체하지 않습니다(필수 아님)."
fi

# 권한/소유자
chmod 640 "${DST_CA_DIR}/root.crt" || true
[[ -f "${DST_CA_DIR}/root.key" ]] && chmod 600 "${DST_CA_DIR}/root.key" || true
chown -R root:kolla "${DST_CA_DIR}" || true

echo "[3/6] HAProxy만 우선 재구성 (이미 교체된 PEM을 다시 로드)"
kolla-ansible -i "${INV}" -t haproxy reconfigure

echo "[4/6] 서비스별 순차 reconfigure로 컨테이너 내부 CA 반영"
# A. 인증/프론트
kolla-ansible -i "${INV}" -t keystone,horizon,skyline,memcached reconfigure
# B. 코어 API
kolla-ansible -i "${INV}" -t glance,nova,neutron,cinder,placement reconfigure
# C. 선택 서비스(있을 때)
kolla-ansible -i "${INV}" -t octavia,magnum,trove,zun,kuryr,mistral,barbican reconfigure || true
# D. 메시징/DB (대개 불필요. 외부 TLS 검증 의존 시 야간에 수행 권장)
# kolla-ansible -i "${INV}" -t rabbitmq,mariadb reconfigure

echo "[5/6] 체인/이름 검증"
if [[ -f "${CAFILE}" ]]; then
  openssl s_client -connect "${EXT_FQDN}:443" -servername "${EXT_FQDN}" \
    -CAfile "${CAFILE}" -verify_return_error </dev/null \
    | openssl x509 -noout -subject -issuer || true
  openssl s_client -connect "${INT_FQDN}:443" -servername "${INT_FQDN}" \
    -CAfile "${CAFILE}" -verify_return_error </dev/null \
    | openssl x509 -noout -subject -issuer || true
else
  echo "[i] ${CAFILE} 미발견: 외부는 공인CA 사용 시 -CAfile 없이도 검증 가능."
fi

echo "[6/6] Keystone 헬스체크"
if [[ -f "${CAFILE}" ]]; then
  curl -I "https://${INT_FQDN}:5000/" --cacert "${CAFILE}" || true
else
  curl -I "https://${EXT_FQDN}:5000/" || true
fi

cat <<'EOS'

[✓] 완료!
- 기존 Kolla 기본 CA는 *.bak.TIMESTAMP 로 백업됨.
- 새 root.crt(및 선택적으로 root.key)가 배포/반영됨.
- 컨테이너 내부 신뢰 CA 번들도 reconfigure 로 동기화됨.

[롤백 방법]
1) /etc/kolla/certificates/ca/root.crt(.key) 를 .bak.TIMESTAMP 로 되돌림
2) kolla-ansible -i INVENTORY -t haproxy reconfigure
3) kolla-ansible -i INVENTORY reconfigure (또는 역할 단위 순차 적용)

EOS
