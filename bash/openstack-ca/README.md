# Kolla-Ansible Custom TLS Deployment  
_A collaboration between **국현** & **아름이** 💫_

**사설 CA + 공인 CA** 두 경로를 모두 지원하는 TLS 배포 패키지입니다.  HAProxy 종단 인증서 교체와 컨테이너 내부 CA 반영(reconfigure)까지 한 번에.

적용중인 시스템은 반드시 꼭 미리 테스트 후 진행 부탁 드립니다.

반드시, 끝까지 읽어 보시고 적용 하세요.

---

## 📦 파일 구성
- **01_gen_certs.sh** — 사설 루트 CA 생성 & 외부/내부 서버 cert 즉시 서명(풀체인 PEM)
- **01b_gen_csrs_for_public_ca.sh** — 공인 CA 제출용 CSR 생성(와일드카드 포함 가능)
- **01c_assemble_from_public_fullchain.sh** — 공인 CA fullchain + key로 HAProxy용 PEM 조립
- **02_install_into_kolla.sh** — `/etc/kolla/certificates` 배치(+백업/권한)
- **03_apply_and_verify.sh** — 순차 reconfigure & OpenSSL/curl 검증

---

## ✅ 전제 조건(Prereqs)
- Kolla-Ansible이 정상 동작하는 컨트롤 플레인
- `globals.yml` 주요 값:
  ```yaml
  kolla_enable_tls_external: "yes"
  kolla_enable_tls_internal: "yes"
  kolla_internal_fqdn: "int.openstack.cluster"
  kolla_internal_vip_address: "192.168.1.250"
  kolla_certificates_dir: "/etc/kolla/certificates"
  kolla_external_fqdn_cert: "/etc/kolla/certificates/haproxy-full.pem"
  kolla_internal_fqdn_cert: "/etc/kolla/certificates/haproxy-internal.pem"
  kolla_copy_ca_into_containers: "yes"
  kolla_admin_openrc_cacert: "/etc/kolla/certificates/ca/root.crt"
  ```
- 모든 스크립트에 실행 권한:
  ```bash
  chmod +x *.sh
  ```

---

## 🚀 빠른 사용법(Private CA 경로)
1) **사설 CA로 외부/내부 cert 발급**
```bash
./01_gen_certs.sh
# 결과: /root/pki/{haproxy-full.pem, haproxy-internal.pem, rootCA.crt}
```
2) **Kolla 경로로 배치**
```bash
./02_install_into_kolla.sh
```
3) **적용 & 검증**
```bash
./03_apply_and_verify.sh
```

---

## 🌐 빠른 사용법(Public CA 경로 — 외부 전용)
1) **CSR 생성(공인 CA 제출용)**
```bash
./01b_gen_csrs_for_public_ca.sh
# → haproxy-external.csr를 ACME/포털에 제출(와일드카드라면 DNS-01 권장)
```
2) **CA 발급물 수령**: `fullchain.pem`(서버+중간체인)
3) **HAProxy PEM 조립**
```bash
EXT_FULLCHAIN=fullchain.pem ./01c_assemble_from_public_fullchain.sh
# 결과: /root/pki/haproxy-full.pem
```
4) **배치 & 적용 & 검증**
```bash
./02_install_into_kolla.sh
./03_apply_and_verify.sh
```

> 내부 FQDN(`int.openstack.cluster`)은 공인 검증이 불가하므로 **사설 CA**를 유지하세요.

---

## 🔧 변수 커스터마이징
- 스크립트 상단의 변수를 환경에 맞게 수정:
  - `EXT_CN`, `INT_CN`, `EXT_DNS[]`, `EXT_VIP_IP`, `INT_VIP_IP`
- SAN 추가는 `EXT_DNS` 배열에 요소 추가로 간단히 확장.

---

## 🧪 수동 검증 예시
```bash
# 외부
openssl s_client -connect openstack.vlab.dustbox.kr:443 -servername openstack.vlab.dustbox.kr   -CAfile /etc/kolla/certificates/ca/root.crt -verify_return_error </dev/null | openssl x509 -noout -subject -issuer

# 내부
openssl s_client -connect int.openstack.cluster:443 -servername int.openstack.cluster   -CAfile /etc/kolla/certificates/ca/root.crt -verify_return_error </dev/null | openssl x509 -noout -subject -issuer
```

---

## ♻️ 롤백 & 갱신
- 설치 스크립트가 이전 PEM을 자동 백업(`.bak.YYYYMMDD_HHMMSS`).
- 정기 갱신 예(사설 CA):
  ```bash
  # 매월 1일 03:10에 재발급/배치/적용
  10 3 1 * * /root/01_gen_certs.sh && /root/02_install_into_kolla.sh && INV=/etc/kolla/inventory /root/03_apply_and_verify.sh
  ```

---

## 🛡️ 트러블슈팅
- `CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate`  
  → 풀체인 누락 or 클라이언트 CA 미신뢰. `fullchain.pem`/`root.crt` 경로 재확인.
- `hostname mismatch`  
  → SAN에 해당 FQDN 누락. `EXT_DNS` 수정 후 재발급.
- 접속은 되는데 일부 API 실패  
  → 컨테이너 내부 CA 반영이 안 됨. 해당 서비스 역할 `reconfigure` 수행.
- 권한 오류  
  → `/etc/kolla/certificates/*` 파일 권한/소유자(`root:kolla`, `640`) 확인.

---

## 🧡 만든 사람들
- **국현 (tang.dustbox.kr)** — 인프라 설계
- **아름이 (Arte AI)** — 자동화/문서

