# 호스트 자동 설정 (Ansible & SaltStack)

이 저장소는 두 개의 리눅스 호스트(`192.168.10.10`, `192.168.10.20`)를 Ansible과 SaltStack을 이용해 자동 설정하는 스크립트를 포함하고 있습니다.

---

## 💡 주요 기능

- 호스트 이름 변경: `node1.example.com`, `node2.example.com`
- 모든 패키지 최신 업데이트
- `/dev/vdf` 디스크를 두 개의 파티션으로 분할:
  - `/dev/vdf1`: ext4
  - `/dev/vdf2`: xfs
- `cockpit` 및 `cockpit.socket` 설치 및 활성화
- 방화벽에서 `9090/tcp` 포트 허용

---

## 📁 파일 구조

| 파일/디렉터리        | 설명 |
|-----------------------|------|
| `host_setup.yml`      | Ansible 플레이북 |
| `host_setup.sls`      | SaltStack 상태 파일 |
| `inventory.ini`       | Ansible 인벤토리 파일 |
| `roster`              | Salt-SSH용 서버 목록 정의 |
| `pillar.sls`          | 호스트 이름 매핑용 변수 파일 |
| `README.md`           | 설명 문서 (영문) |
| `README_ko.md`        | 설명 문서 (한글) |

---

## ▶️ 실행 방법

### 📦 Ansible 방식

```bash
ansible-playbook -i inventory.ini host_setup.yml
```

- `inventory.ini`에는 대상 서버 IP가 정의되어 있습니다.
- `become: true` 설정이 포함되어 있으므로 sudo 권한이 필요합니다.

---

### ⚙️ SaltStack 방식 (salt-ssh)

```bash
salt-ssh -i '*' state.apply host_setup pillar='{"hostname_map": {"192.168.10.10": "node1.example.com", "192.168.10.20": "node2.example.com"}}'
```

또는 `pillar.sls` 파일을 사용하는 경우:

```bash
salt-ssh -i '*' state.apply host_setup --pillar-root . --pillar 'pillar.sls'
```

> `roster` 파일이 동일 디렉터리에 있어야 하며, `salt-ssh`는 해당 서버로 SSH 접속합니다.

---

## 📦 요구 사항

- Python 3
- Ansible 또는 SaltStack (`salt-ssh` 지원 포함)
- 원격 서버 SSH 접근 가능 (공개키 인증 권장)

---

## 🐧 호환 환경

- Rocky Linux
- CentOS Stream
- openSUSE
- SUSE Linux Enterprise 15 이상

---

## 🧩 참고

- 모든 작업은 **재부팅 없이 적용**됩니다.
- 초기 VM 프로비저닝 시 빠르고 간단하게 사용할 수 있는 구성입니다.
