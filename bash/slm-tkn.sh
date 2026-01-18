#!/usr/bin/env bash
set -euo pipefail

SLM_URL="${SLM_URL:-http://localhost:8080}"
MODEL="${MODEL:-local}"

SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a Tekton expert. Generate valid Tekton YAML only. No explanation. No markdown.}"

PROMPT=""
PROMPT_FILE=""
OUT=""
TIMEOUT="${TIMEOUT:-60}"

usage() {
  cat <<'EOF'
Usage:
  slm-tekton.sh --prompt "..." [--out out.yaml]
  slm-tekton.sh --prompt-file prompt.txt [--out out.yaml]

Env:
  SLM_URL=http://localhost:8080
  MODEL=local
  SYSTEM_PROMPT="..."
  TIMEOUT=60
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERR] Required command not found: $1" >&2
    exit 1
  }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) PROMPT="${2:-}"; shift 2 ;;
    --prompt-file) PROMPT_FILE="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERR] Unknown option: $1"; usage; exit 1 ;;
  esac
done

need_cmd curl
need_cmd jq

if [[ -n "${PROMPT_FILE}" ]]; then
  [[ -f "${PROMPT_FILE}" ]] || { echo "[ERR] prompt file not found: ${PROMPT_FILE}" >&2; exit 1; }
  PROMPT="$(cat "${PROMPT_FILE}")"
fi

if [[ -z "${PROMPT}" ]]; then
  echo "[ERR] Missing --prompt or --prompt-file" >&2
  usage
  exit 1
fi

payload="$(jq -n \
  --arg model "${MODEL}" \
  --arg sys "${SYSTEM_PROMPT}" \
  --arg user "${PROMPT}" \
  '{
    model: $model,
    messages: [
      {role:"system", content:$sys},
      {role:"user", content:$user}
    ]
  }')"

echo "[*] Requesting YAML from SLM: ${SLM_URL}"
resp="$(curl -fsS --max-time "${TIMEOUT}" \
  -H "Content-Type: application/json" \
  -d "${payload}" \
  "${SLM_URL}/v1/chat/completions")"

yaml="$(echo "${resp}" | jq -r '.choices[0].message.content // empty')"

if [[ -z "${yaml}" || "${yaml}" == "null" ]]; then
  echo "[ERR] Empty response. Raw response:" >&2
  echo "${resp}" >&2
  exit 1
fi

# 아주 가벼운 안전장치: YAML처럼 시작하는지 체크 (완벽하진 않지만 강의용으로 충분)
if ! echo "${yaml}" | grep -Eq '^(apiVersion:|kind:|---)'; then
  echo "[WARN] Output does not look like Tekton YAML. Printing anyway." >&2
fi

if [[ -n "${OUT}" ]]; then
  printf "%s\n" "${yaml}" > "${OUT}"
  echo "[OK] Saved: ${OUT}"
else
  printf "%s\n" "${yaml}"
fi
