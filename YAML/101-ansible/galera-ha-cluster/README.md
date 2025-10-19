# Galera + HAProxy (Basic)

이 리포는 MariaDB Galera Cluster(3노드 권장) + HAProxy 프록시(RW/RO 분리) 기본 구성을 위한 Ansible 템플릿입니다.

## 요구사항
- RHEL/Rocky 9 계열
- Ansible 2.15+
- community.mysql 컬렉션 (`ansible-galaxy collection install community.mysql`)

## 인벤토리 편집
- `inventory.ini`에서 HAProxy와 Galera 노드 IP/옵션 수정
- 최초 라이터 노드에 `primary_writer=true`

## 실행 순서
```bash
# 1) Galera 설치/설정/헬스체크
ansible-playbook -i inventory.ini site.yml --limit galera

# 2) 첫 번째 Galera 노드에서 클러스터 부트스트랩
ssh db1
sudo galera_new_cluster

# 3) 나머지 Galera 노드 가입 (각 노드에서)
sudo systemctl restart mariadb

# 4) HAProxy 배포
ansible-playbook -i inventory.ini site.yml --limit haproxy
```

## 포트
- HAProxy RW: 3306/tcp
- HAProxy RO: 3307/tcp
- Agent (RO/RW): 9200/9201/tcp (로컬 systemd-socket)

## 주의
- 완전 자동 라이터 선출이 필요하면 Orchestrator 등의 외부 컴포넌트 연동을 고려하세요.
