#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Linux 보안 취약점 점검 스크립트 (U-01 ~ U-73) — 통합판 (RHEL/Alma/Rocky, Ubuntu/Debian, SUSE)
# - 진행바: 한 줄로만 갱신. 상세 결과는 파일에 기록. (PROG_MODE=full 로 바꾸면 콘솔에도 항목 로그 표시)
# - 사용: chmod +x vuln_scan_U01_U73_unified.sh && ./vuln_scan_U01_U73_unified.sh [out_dir]
set -o pipefail
IFS=$'\n\t'

OUT_DIR="${1:-scan-result}"
PROG_WIDTH="${PROG_WIDTH:-40}"
PROG_MODE="${PROG_MODE:-bar_only}"   # bar_only | full

HOST="$(hostname)"
DATE="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"
OUT_TXT="${OUT_DIR}/vuln_scan_${HOST}_${DATE}.txt"
OUT_TSV="${OUT_DIR}/vuln_scan_${HOST}_${DATE}.tsv"

# ---------- util: log ----------
log() { echo -e "$*" | tee -a "$OUT_TXT" >/dev/null; }
hdr() { log "\n==> [$1] $2"; }
kv()  { printf "%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" >> "$OUT_TSV"; }

pass(){ [[ "$PROG_MODE" == "full" ]] && echo "[PASS] $1" | tee -a "$OUT_TXT" >/dev/null || log "[PASS] $1"; kv "$ID" "$TITLE" "PASS" "$1"; }
fail(){ [[ "$PROG_MODE" == "full" ]] && echo "[FAIL] $1" | tee -a "$OUT_TXT" >/dev/null || log "[FAIL] $1"; kv "$ID" "$TITLE" "FAIL" "$1"; }
skip(){ [[ "$PROG_MODE" == "full" ]] && echo "[SKIP] $1" | tee -a "$OUT_TXT" >/dev/null || log "[SKIP] $1"; kv "$ID" "$TITLE" "SKIP" "$1"; }

# ---------- detect OS / helpers ----------
detect_os(){
  OS_ID=unknown; OS_VER=unknown
  if [[ -f /etc/os-release ]]; then . /etc/os-release; OS_ID="${ID:-unknown}"; OS_VER="${VERSION_ID:-unknown}"; fi
  echo "$OS_ID" "$OS_VER"
}
service_active(){
  # usage: service_active sshd ssh
  for name in "$@"; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${name}\.service" || systemctl status "$name" >/dev/null 2>&1; then
      systemctl is-active "$name" 2>/dev/null | grep -q active && return 0
    fi
  done
  return 1
}
service_enabled(){
  for name in "$@"; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${name}\.service"; then
      systemctl is-enabled "$name" 2>/dev/null | grep -q enabled && return 0
    fi
  done
  return 1
}
pm_check_updates(){
  # return code like each distro's native: 100 means updates available on yum/dnf; apt-get -s upgrade returns 0/2; zypper lu nonzero when updates exist.
  if command -v dnf >/dev/null 2>&1; then dnf -q check-update >/dev/null 2>&1; return $?; fi
  if command -v yum >/dev/null 2>&1; then yum -q check-update >/dev/null 2>&1; return $?; fi
  if command -v zypper >/dev/null 2>&1; then zypper --non-interactive --quiet lu >/dev/null 2>&1; return $?; fi
  if command -v apt-get >/dev/null 2>&1; then apt-get -s -o Debug::NoLocking=1 upgrade >/dev/null 2>&1; return $?; fi
  return 0
}

# PAM files to search (distro-aware)
PAM_AUTH_FILES=(/etc/pam.d/system-auth /etc/pam.d/system-auth-ac /etc/pam.d/common-auth /etc/pam.d/password-auth /etc/pam.d/login /etc/pam.d/sshd)

init_report(){
  : > "$OUT_TSV"
  echo -e "id\ttitle\tstatus\tmessage" >> "$OUT_TSV"
  read -r OS_ID OS_VER < <(detect_os)
  {
    echo "[#] Linux 보안 취약점 점검 (통합) — $HOST @ $DATE"
    echo "    OS: ${OS_ID} ${OS_VER}"
    echo "    Out: $OUT_TXT"
    echo "    TSV: $OUT_TSV"
    echo
  } | tee -a "$OUT_TXT" >/dev/null
}

# ---------- progress bar (single line) ----------
progress_bar(){
  local cur="$1" total="$2" width="$PROG_WIDTH"
  local pct=$(( cur * 100 / total ))
  local filled=$(( pct * width / 100 ))
  local bar=""; local i=0
  while [ $i -lt $filled ]; do bar="${bar}#"; i=$((i+1)); done
  while [ $i -lt $width ]; do bar="${bar}-"; i=$((i+1)); done
  printf "\r[%s] %3d%% (%d/%d)" "$bar" "$pct" "$cur" "$total"
}

# ---------- individual checks (same as earlier, but distro-safe) ----------
U01(){ ID="U-01"; TITLE="root 원격 접속 제한"; hdr "$ID" "$TITLE"
  grep -Eiq '^\s*PermitRootLogin\s+no' /etc/ssh/sshd_config && pass "PermitRootLogin no" || fail "PermitRootLogin no 미설정"
}
U02(){ ID="U-02"; TITLE="패스워드 최소 길이(>=8)"; hdr "$ID" "$TITLE"
  grep -Eq '^\s*minlen\s*=\s*([8-9]|[1-9][0-9]+)\b' /etc/security/pwquality.conf 2>/dev/null && pass "minlen >= 8" || fail "minlen 미흡/미설정"
}
U03(){ ID="U-03"; TITLE="/etc/passwd 권한 644"; hdr "$ID" "$TITLE"
  perm=$(stat -c %a /etc/passwd 2>/dev/null || stat -f %Lp /etc/passwd 2>/dev/null); [[ "$perm" == "644" ]] && pass "권한=$perm" || fail "권한=$perm (644 권장)"
}
U04(){ ID="U-04"; TITLE="/etc/shadow 권한 <=640"; hdr "$ID" "$TITLE"
  perm=$(stat -c %a /etc/shadow 2>/dev/null || stat -f %Lp /etc/shadow 2>/dev/null); [[ "$perm" =~ ^[4-6][0-4]0$ || "$perm" =~ ^40[0-7]$ || "$perm" =~ ^60[0-7]$ ]] && pass "권한=$perm" || fail "권한=$perm (400~640 권장)"
}
U05(){ ID="U-05"; TITLE="불필요 계정 점검"; hdr "$ID" "$TITLE"
  bad=$(awk -F: '{print $1}' /etc/passwd | egrep -x 'games|news' || true); [[ -n "$bad" ]] && fail "의심 계정: $bad" || pass "의심 없음"
}
U06(){ ID="U-06"; TITLE="PASS_MAX_DAYS <= 90"; hdr "$ID" "$TITLE"
  grep -Eq '^\s*PASS_MAX_DAYS\s+(9[0]|[1-8][0-9]|[1-9])\b' /etc/login.defs && pass "PASS_MAX_DAYS 적정" || fail "미설정/과다"
}
U07(){ ID="U-07"; TITLE="PASS_MIN_DAYS >= 1"; hdr "$ID" "$TITLE"
  grep -Eq '^\s*PASS_MIN_DAYS\s+([1-9]|[1-9][0-9]+)\b' /etc/login.defs && pass "PASS_MIN_DAYS 적정" || fail "미설정/미흡"
}
U08(){ ID="U-08"; TITLE="pwquality 복잡도"; hdr "$ID" "$TITLE"
  grep -Eq '^\s*(minlen|minclass|dcredit|ucredit|lcredit|ocredit)\s*=' /etc/security/pwquality.conf 2>/dev/null && pass "복잡도 파라미터 존재" || fail "미설정"
}
U09(){ ID="U-09"; TITLE="로그인 실패 잠금(faillock)"; hdr "$ID" "$TITLE"
  grep -Eq 'pam_faillock\.so' "${PAM_AUTH_FILES[@]}" 2>/dev/null && pass "faillock 사용" || fail "미구성"
}
U10(){ ID="U-10"; TITLE="비밀번호 이력 기억"; hdr "$ID" "$TITLE"
  grep -Eq 'pam_pwhistory\.so.*remember=' /etc/pam.d/* 2>/dev/null || grep -Eq '^\s*remember\s*=' /etc/security/pwquality.conf 2>/dev/null && pass "이력 기억" || fail "미구성"
}
U11(){ ID="U-11"; TITLE="su 제한(pam_wheel)"; hdr "$ID" "$TITLE"
  grep -Eq '^\s*auth\s+required\s+pam_wheel.so' /etc/pam.d/su 2>/dev/null && pass "su 제한" || fail "미구성"
}
U12(){ ID="U-12"; TITLE="SSH Protocol/Ciphers"; hdr "$ID" "$TITLE"
  p=$(grep -Eiq '^\s*Protocol\s+2\b' /etc/ssh/sshd_config && echo ok || echo ""); c=$(grep -Eiq '^\s*Ciphers\s+' /etc/ssh/sshd_config && echo ok || echo "")
  [[ -n "$p" && -n "$c" ]] && pass "Protocol 2 & Ciphers 지정" || fail "미흡"
}
U13(){ ID="U-13"; TITLE="nologin/false 셸 사용"; hdr "$ID" "$TITLE"
  bad=$(awk -F: '($7 ~ /(false|nologin)$/){print $1}' /etc/passwd | wc -l); pass "비로그인 셸 계정 수: $bad(참고)"
}
U14(){ ID="U-14"; TITLE="r-서비스 비활성"; hdr "$ID" "$TITLE"
  if systemctl list-unit-files 2>/dev/null | egrep -q 'rlogin|rsh|rexec'; then a=$(systemctl is-enabled rlogin.socket rsh.socket rexec.socket 2>/dev/null | grep -v disabled || true); [[ -n "$a" ]] && fail "활성 가능성: $a" || pass "비활성"; else pass "미설치/비활성"; fi
}
U15(){ ID="U-15"; TITLE="hosts.equiv/.rhosts 금지"; hdr "$ID" "$TITLE"
  [[ -f /etc/hosts.equiv ]] && fail "/etc/hosts.equiv 존재" || pass "/etc/hosts.equiv 없음"; if grep -Rqs ".rhosts" /home /root 2>/dev/null; then fail "~/.rhosts 존재"; else pass "~/.rhosts 없음"; fi
}
U16(){ ID="U-16"; TITLE="FTP 익명 금지"; hdr "$ID" "$TITLE"
  if service_active vsftpd; then grep -Eq '^\s*anonymous_enable\s*=\s*NO' /etc/vsftpd.conf 2>/dev/null && pass "vsftpd 익명 금지" || fail "vsftpd 익명 허용"; elif service_active proftpd; then skip "proftpd 수동 확인"; else pass "FTP 미사용/금지"; fi
}
U17(){ ID="U-17"; TITLE="NIS/yp 미사용"; hdr "$ID" "$TITLE"
  systemctl list-unit-files 2>/dev/null | grep -q ypserv && fail "ypserv 존재" || pass "NIS/yp 미사용"
}
U18(){ ID="U-18"; TITLE="finger 비활성"; hdr "$ID" "$TITLE"
  command -v finger >/dev/null 2>&1 && fail "finger 설치됨" || pass "finger 미설치"
}
U19(){ ID="U-19"; TITLE="tftp 비활성"; hdr "$ID" "$TITLE"
  if systemctl list-unit-files 2>/dev/null | grep -q tftp; then service_enabled tftp || pass "tftp 비활성" && return; fi; pass "tftp 미설치"
}
U20(){ ID="U-20"; TITLE="NFS/exports 확인"; hdr "$ID" "$TITLE"
  if service_active nfs-server nfs; then exp=$(exportfs 2>/dev/null | wc -l || echo 0); [[ "$exp" -gt 0 ]] && pass "export ${exp}개(접근통제 확인)" || pass "NFS active, export 없음"; else pass "NFS 미사용"; fi
}
U21(){ ID="U-21"; TITLE="RPC 점검"; hdr "$ID" "$TITLE"
  if command -v rpcinfo >/dev/null 2>&1; then rpcinfo -p 2>/dev/null | grep -q . && pass "RPC 사용(필요성 검토)" || pass "RPC 비활성"; else pass "rpcinfo 없음"; fi
}
U22(){ ID="U-22"; TITLE="cron 접근 통제"; hdr "$ID" "$TITLE"
  [[ -f /etc/cron.allow ]] && pass "cron.allow 존재" || [[ -f /etc/cron.deny ]] && pass "cron.deny 존재" || fail "cron 접근제어 미존재"
}
U23(){ ID="U-23"; TITLE="at 접근 통제"; hdr "$ID" "$TITLE"
  [[ -f /etc/at.allow ]] && pass "at.allow 존재" || [[ -f /etc/at.deny ]] && pass "at.deny 존재" || fail "at 접근제어 미존재"
}
U24(){ ID="U-24"; TITLE="SNMP community 변경"; hdr "$ID" "$TITLE"
  [[ -f /etc/snmp/snmpd.conf ]] && grep -Eq 'public|private' /etc/snmp/snmpd.conf && fail "기본 문자열 존재" || pass "기본값 미사용/미설치"
}
U25(){ ID="U-25"; TITLE="SMTP 릴레이 금지"; hdr "$ID" "$TITLE"
  if service_active postfix; then postconf -n 2>/dev/null | grep -Eq '^smtpd_recipient_restrictions' && pass "릴레이 제한" || skip "Postfix 상세 정책 수동 확인"; elif service_active sendmail; then skip "Sendmail access 수동 확인"; else pass "SMTP 미사용"; fi
}
U26(){ ID="U-26"; TITLE="익명 메일 금지"; hdr "$ID" "$TITLE"
  skip "메일 정책은 환경별 상이 — 수동 확인"
}
U27(){ ID="U-27"; TITLE="홈 디렉터리 권한"; hdr "$ID" "$TITLE"
  bad=$(awk -F: '$3>=1000 {print $6}' /etc/passwd | xargs -r -I{} bash -lc 'test -d "{}" && stat -c "%a:%n" "{}"' | awk -F: '$1>750{print $2}'); [[ -n "$bad" ]] && fail "권한 과다 홈: $(echo "$bad" | xargs)" || pass "홈 권한 <= 750"
}
U28(){ ID="U-28"; TITLE="PATH 안전성"; hdr "$ID" "$TITLE"
  echo "$PATH" | egrep -q '(^|:)\.(:|$)' && fail "PATH에 . 포함" || pass ". 미포함"
}
U29(){ ID="U-29"; TITLE="world-writable 디렉터리"; hdr "$ID" "$TITLE"
  ww=$(df -P | awk 'NR>1{print $6}' | xargs -I{} find {} -xdev -type d -perm -0002 -not -path '/proc/*' 2>/dev/null | head -n 5); [[ -n "$ww" ]] && fail "ww-dir 존재(일부): $(echo "$ww" | tr '\n' ' ')" || pass "없음/제한"
}
U30(){ ID="U-30"; TITLE="umask <= 027"; hdr "$ID" "$TITLE"
  cur=$(umask); cur=${cur#0}; [[ "$cur" -le 27 ]] && pass "umask=$cur" || fail "umask=$cur (<=027 권장)"
}
U31(){ ID="U-31"; TITLE="불필요 포트 점검"; hdr "$ID" "$TITLE"
  open=$(ss -tulpen 2>/dev/null | awk 'NR>1{print $1,$5,$7}' | head -n 10); [[ -n "$open" ]] && pass "열린 포트(상위10): $(echo "$open" | tr '\n' ' ')" || pass "열린 포트 없음"
}
U32(){ ID="U-32"; TITLE="IP 포워딩 비활성"; hdr "$ID" "$TITLE"
  v=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 0); [[ "$v" == "0" ]] && pass "ip_forward=0" || fail "활성"
}
U33(){ ID="U-33"; TITLE="SRC_ROUTE/REDIRECT 금지"; hdr "$ID" "$TITLE"
  a=$(sysctl -n net.ipv4.conf.all.accept_source_route 2>/dev/null || echo 0); r=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null || echo 0); [[ "$a" == "0" && "$r" == "0" ]] && pass "금지" || fail "허용됨"
}
U34(){ ID="U-34"; TITLE="ICMP 브로드캐스트 무시"; hdr "$ID" "$TITLE"
  v=$(sysctl -n net.ipv4.icmp_echo_ignore_broadcasts 2>/dev/null || echo 1); [[ "$v" == "1" ]] && pass "무시" || fail "허용"
}
U35(){ ID="U-35"; TITLE="시간 동기화 데몬"; hdr "$ID" "$TITLE"
  service_active chronyd && pass "chronyd" || service_active ntpd && pass "ntpd" || fail "비활성"
}
U36(){ ID="U-36"; TITLE="로깅 데몬"; hdr "$ID" "$TITLE"
  service_active rsyslog && pass "rsyslog" || service_active systemd-journald && pass "journald" || fail "비활성"
}
U37(){ ID="U-37"; TITLE="/var/log 권한"; hdr "$ID" "$TITLE"
  bad=$(find /var/log -type f -perm -o+w 2>/dev/null | head -n 5); [[ -n "$bad" ]] && fail "world-writable: $(echo "$bad" | tr '\n' ' ')" || pass "양호"
}
U38(){ ID="U-38"; TITLE="원격 syslog 전송"; hdr "$ID" "$TITLE"
  grep -Rqs '@@' /etc/rsyslog.* /etc/rsyslog.d 2>/dev/null && pass "원격 전송 설정" || pass "미사용(선택)"
}
U39(){ ID="U-39"; TITLE="auditd 활성"; hdr "$ID" "$TITLE"
  service_active auditd && pass "auditd 동작" || fail "비활성"
}
U40(){ ID="U-40"; TITLE="패키지 업데이트"; hdr "$ID" "$TITLE"
  pm_check_updates; rc=$?; [[ $rc -eq 100 ]] && fail "업데이트 필요" || pass "양호/확인불가(rc=$rc)"
}
U41(){ ID="U-41"; TITLE="방화벽 구성"; hdr "$ID" "$TITLE"
  service_active firewalld || command -v iptables >/dev/null 2>&1 || command -v nft >/dev/null 2>&1 && pass "방화벽 존재" || fail "미구성"
}
U42(){ ID="U-42"; TITLE="SUID/SGID 파일"; hdr "$ID" "$TITLE"
  suspicious=$(df -P | awk 'NR>1{print $6}' | xargs -I{} find {} -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -n 10); [[ -n "$suspicious" ]] && pass "존재(상위10): $(echo "$suspicious" | tr '\n' ' ')" || pass "없음/제한"
}
U43(){ ID="U-43"; TITLE="core dump 제한"; hdr "$ID" "$TITLE"
  egrep -q '^\s*\*\s+hard\s+core\s+0' /etc/security/limits.conf /etc/security/limits.d/* 2>/dev/null || sysctl fs.suid_dumpable 2>/dev/null | grep -q ': 0' && pass "제한" || fail "미구성"
}
U44(){ ID="U-44"; TITLE="서비스 배너/버전"; hdr "$ID" "$TITLE"
  [[ -f /etc/issue.net ]] && grep -qi 'authorized' /etc/issue.net && pass "배너 설정" || pass "선택 사항"
}
U45(){ ID="U-45"; TITLE="telnet/ssh 배너"; hdr "$ID" "$TITLE"
  [[ -f /etc/motd ]] || [[ -f /etc/issue ]] && pass "배너 파일 존재" || pass "선택 사항"
}
U46(){ ID="U-46"; TITLE="GUI 타겟 비활성(서버)"; hdr "$ID" "$TITLE"
  systemctl get-default 2>/dev/null | grep -qi graphical && fail "graphical target" || pass "텍스트/멀티유저"
}
U47(){ ID="U-47"; TITLE="컴파일러 제한"; hdr "$ID" "$TITLE"
  command -v gcc >/dev/null 2>&1 && fail "gcc 설치됨(불필요 시 제거)" || pass "미설치/제한"
}
U48(){ ID="U-48"; TITLE="NIS/NFS 홈"; hdr "$ID" "$TITLE"
  pass "환경 상이 — 접근제어/권한 수동 확인"
}
U49(){ ID="U-49"; TITLE="sudoers 구성"; hdr "$ID" "$TITLE"
  [[ -f /etc/sudoers ]] && grep -Eq '^%?wheel|sudo' /etc/sudoers /etc/sudoers.d/* 2>/dev/null && pass "구성 존재" || fail "미구성"
}
U50(){ ID="U-50"; TITLE="root PATH 안전"; hdr "$ID" "$TITLE"
  [[ "$EUID" -eq 0 ]] && echo "$PATH" | egrep -q '(^|:)\.(:|$)' && fail "PATH에 . 포함" || pass "안전"
}
U51(){ ID="U-51"; TITLE="SSH PasswordAuth"; hdr "$ID" "$TITLE"
  grep -Eiq '^\s*PasswordAuthentication\s+no' /etc/ssh/sshd_config && pass "비밀번호 인증 off" || pass "정책에 따름(수동검토)"
}
U52(){ ID="U-52"; TITLE="SSH X11Forwarding"; hdr "$ID" "$TITLE"
  grep -Eiq '^\s*X11Forwarding\s+no' /etc/ssh/sshd_config && pass "X11Forwarding no" || fail "활성"
}
U53(){ ID="U-53"; TITLE="SSH EmptyPasswords"; hdr "$ID" "$TITLE"
  grep -Eiq '^\s*PermitEmptyPasswords\s+no' /etc/ssh/sshd_config && pass "금지" || fail "허용 가능성"
}
U54(){ ID="U-54"; TITLE="SSH MaxAuthTries<=4"; hdr "$ID" "$TITLE"
  grep -Eiq '^\s*MaxAuthTries\s+[1-4]\b' /etc/ssh/sshd_config && pass "적정" || fail "과다/미설정"
}
U55(){ ID="U-55"; TITLE="SSH 세션 타임아웃"; hdr "$ID" "$TITLE"
  grep -Eiq '^\s*ClientAliveInterval\s+[1-9]' /etc/ssh/sshd_config && grep -Eiq '^\s*ClientAliveCountMax\s+[1-5]\b' /etc/ssh/sshd_config && pass "설정" || fail "미설정"
}
U56(){ ID="U-56"; TITLE="계정 잠금 시간"; hdr "$ID" "$TITLE"
  grep -Eq 'pam_faillock\.so.*deny=' /etc/pam.d/* 2>/dev/null && pass "잠금 정책" || fail "미구성"
}
U57(){ ID="U-57"; TITLE="불필요 계정 잠금/삭제"; hdr "$ID" "$TITLE"
  locked=$(awk -F: '($1!="root" && $3>=1000 && $7~/nologin|false/){print $1}' /etc/passwd | wc -l); pass "잠금/비활성 수(참고): $locked"
}
U58(){ ID="U-58"; TITLE="history 권한"; hdr "$ID" "$TITLE"
  bad=$(find /root /home -maxdepth 2 -name '.*history' -type f -perm -o+w 2>/dev/null | head -n 5); [[ -n "$bad" ]] && fail "world-writable: $(echo "$bad" | tr '\n' ' ')" || pass "양호"
}
U59(){ ID="U-59"; TITLE="/etc/hosts 권한"; hdr "$ID" "$TITLE"
  perm=$(stat -c %a /etc/hosts 2>/dev/null || stat -f %Lp /etc/hosts 2>/dev/null); [[ "$perm" -le 644 ]] && pass "권한=$perm" || fail "권한 과다=$perm"
}
U60(){ ID="U-60"; TITLE="xinetd 권한"; hdr "$ID" "$TITLE"
  if [[ -f /etc/xinetd.conf ]]; then perm=$(stat -c %a /etc/xinetd.conf 2>/dev/null || echo 644); [[ "$perm" -le 644 ]] && pass "권한=$perm" || fail "과다=$perm"; else pass "xinetd 미사용"; fi
}
U61(){ ID="U-61"; TITLE="nscd 설정(선택)"; hdr "$ID" "$TITLE"
  service_active nscd && pass "활성(선택)" || pass "미사용"
}
U62(){ ID="U-62"; TITLE="USB 저장장치"; hdr "$ID" "$TITLE"
  lsmod | grep -q usb_storage && pass "로드 — 정책 고려" || pass "미로드"
}
U63(){ ID="U-63"; TITLE="IPv6 필요 시만 사용"; hdr "$ID" "$TITLE"
  sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q ': 1' && pass "IPv6 비활성" || pass "활성(정책에 따름)"
}
U64(){ ID="U-64"; TITLE="불필요 서비스"; hdr "$ID" "$TITLE"
  enabled=$(systemctl list-unit-files --type=service --state=enabled 2>/dev/null | awk 'NR>1{print $1}' | head -n 10); pass "활성 서비스 상위10: $(echo "$enabled" | tr '\n' ' ')"
}
U65(){ ID="U-65"; TITLE="부팅 시 서비스 제한"; hdr "$ID" "$TITLE"
  pass "is-enabled 결과 기반 수동 검토 권장"
}
U66(){ ID="U-66"; TITLE="계정/그룹 정합성"; hdr "$ID" "$TITLE"
  pass "중복 UID/GID 등 별도 스크립트 권장"
}
U67(){ ID="U-67"; TITLE="shell 감사/이력"; hdr "$ID" "$TITLE"
  pass "auditd rules/TTY logging 수동 확인"
}
U68(){ ID="U-68"; TITLE="계정 만료/비활성"; hdr "$ID" "$TITLE"
  grep -Eq '^\s*INACTIVE\s*=\s*[1-9]' /etc/default/useradd 2>/dev/null && pass "INACTIVE 존재" || fail "미설정 가능성"
}
U69(){ ID="U-69"; TITLE="root 원격 IP 제한"; hdr "$ID" "$TITLE"
  grep -Eiq '^\s*AllowUsers\s+' /etc/ssh/sshd_config || grep -Eiq '^\s*AllowGroups\s+' /etc/ssh/sshd_config && pass "AllowUsers/Groups 설정" || pass "방화벽/보안그룹으로 제한 권장"
}
U70(){ ID="U-70"; TITLE="sudo 로그/감사"; hdr "$ID" "$TITLE"
  grep -Eq '^\s*Defaults\s+logfile=' /etc/sudoers /etc/sudoers.d/* 2>/dev/null && pass "sudo 로그 설정" || pass "journal/syslog 기록 가능"
}
U71(){ ID="U-71"; TITLE="cron 권한/소유자"; hdr "$ID" "$TITLE"
  bad=$(find /etc/cron.* -type f -perm -o+w 2>/dev/null | head -n 5); [[ -n "$bad" ]] && fail "world-writable: $(echo "$bad" | tr '\n' ' ')" || pass "양호"
}
U72(){ ID="U-72"; TITLE="SSH root 로그인 금지"; hdr "$ID" "$TITLE"
  grep -Eiq '^\s*PermitRootLogin\s+no' /etc/ssh/sshd_config && pass "금지" || fail "허용 가능성"
}
U73(){ ID="U-73"; TITLE="커널 네트워크 하드닝"; hdr "$ID" "$TITLE"
  s=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo 1); r=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null || echo 1); [[ "$s" == "1" && "$r" == "1" ]] && pass "tcp_syncookies=1, rp_filter=1" || fail "미흡(예시)"
}

main(){
  init_report
  total=73
  idx=1
  trap 'echo' EXIT
  for f in {01..73}; do
    func="U${f}"
    progress_bar "$idx" "$total"   # single-line 갱신
    if declare -f "$func" >/dev/null 2>&1; then
      if [[ "$PROG_MODE" == "full" ]]; then
        echo -e "\n[진행] ($idx/$total) ${func} 실행 중..." | tee -a "$OUT_TXT" >/dev/null
        "$func"
      else
        # 콘솔은 진행바만, 결과는 파일에만
        { "$func"; } >>"$OUT_TXT" 2>&1
      fi
    else
      kv "U-${f}" "미정의" "SKIP" "구현 없음"
    fi
    idx=$((idx+1))
  done
  echo   # 진행바 줄바꿈
  log "\n[#] 점검 완료"
}

main "$@"
