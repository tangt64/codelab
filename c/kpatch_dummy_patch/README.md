# kpatch Dummy Patch

## 목적
이 코드는 테스트용 kpatch 패치 모듈입니다. 실제 커널 함수를 패치하는 것이 아니라,
`patched_function()` 이라는 테스트 함수를 정의하여 kpatch 프레임워크와 통합되는지만 확인합니다.

## 구성 파일
- `fix_hello.c`: 패치 대상 함수 정의
- `Makefile`: 커널 모듈 빌드용
- `README.md`: 설명

## 사용 방법

```bash
# 커널 개발 헤더 설치 (RHEL/Rocky 기준)
sudo dnf install -y kernel-devel gcc make

# 빌드
make

# 확인
ls *.ko

# 로드 테스트 (단순 모듈 로딩 용도)
sudo insmod fix_hello.ko
dmesg | tail
```

> 이 모듈은 실제 커널 함수 패치는 수행하지 않으며, 예제로만 활용됩니다.

# SUSE 및 RHEL용 Kpatch 더미 패치

이 패치는 `sys_getpid` 시스템 호출을 더미 구현으로 교체하여  
항상 `99999`를 반환하도록 합니다.  
이는 `kpatch-build` 기능을 테스트하기 위한 용도로 설계되었습니다.

---

## 필요 조건

- SUSE Linux Enterprise Server 또는 RHEL
- 커널 헤더 설치 (`kernel-devel` 또는 `kernel-source`)
- `kpatch`, `kpatch-build` 패키지 설치

---

## 빌드 방법

```bash
kpatch-build -s /usr/src/linux -v $(uname -r) \
  -t vmlinux -p getpid_patch.c -o kpatch_getpid.ko
```

---

## 모듈 로드

```bash
sudo insmod kpatch_getpid.ko
```

---

## 로그 확인

```bash
dmesg | tail
```


