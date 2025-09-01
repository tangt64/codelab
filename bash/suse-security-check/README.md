
# Linux 보안 취약점 점검 스크립트 (U-01 ~ U-73) 사용 가이드

- 스크립트: `vuln_scan_U01_U73_unified.sh` — RHEL/Alma/Rocky, Ubuntu/Debian, SUSE 통합 지원
- 콘솔에는 기본적으로 **한 줄 진행바**만 갱신되고, 결과는 파일에 기록된다.
- `PROG_MODE=full`로 설정하면 콘솔에도 항목 로그가 출력된다.

## 사용법
```bash
chmod +x vuln_scan_U01_U73_unified.sh

# 기본 실행
./vuln_scan_U01_U73_unified.sh

# 출력 디렉터리 지정
./vuln_scan_U01_U73_unified.sh /path/to/outdir

# 콘솔 로그까지 보고 싶으면
PROG_MODE=full ./vuln_scan_U01_U73_unified.sh

# 진행바 폭(칸 수) 조절
PROG_WIDTH=60 ./vuln_scan_U01_U73_unified.sh
```

## 출력물
- 텍스트: `scan-result/vuln_scan_<HOST>_<YYYYMMDD_HHMMSS>.txt`
- TSV: `scan-result/vuln_scan_<HOST>_<YYYYMMDD_HHMMSS>.tsv` (열: id, title, status, message)
