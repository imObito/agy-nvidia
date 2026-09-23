#!/usr/bin/env bash
# switch-model.sh — change agy-nvidia model groups and restart the router.
set -euo pipefail

CFG_DIR="$HOME/.config/agy-nvidia"
YAML="$CFG_DIR/litellm.yaml"
REPO_YAML="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/litellm.yaml"
ENV_FILE="$CFG_DIR/.env"

usage() {
  cat <<'EOF'
Usage:
  ./switch-model.sh                       apply the repository preset
  ./switch-model.sh list                  show aliases, key status, proxy status
  ./switch-model.sh key nvapi-...         update NVIDIA_API_KEY
  ./switch-model.sh 3.7 MODEL_ID          change all Gemini 3.7 aliases
  ./switch-model.sh 3.8 MODEL_ID          change all Gemini 3.8 aliases
  ./switch-model.sh 3.6 MODEL_ID          change all Gemini 3.6 aliases
  ./switch-model.sh pro MODEL_ID          change Gemini pro/flash aliases

MODEL_ID must be an NVIDIA model ID, for example:
  nvidia/nemotron-3-super-120b-a12b
The script adds the openai/ provider prefix only when it is missing.
EOF
}

normalize_model() {
  local model="${1#openai/}"
  [[ "$model" =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "Invalid model ID: $1" >&2; exit 1; }
  printf '%s' "$model"
}

restart_proxy() {
  if command -v systemctl >/dev/null 2>&1 && systemctl --user cat agy-nvidia-proxy.service >/dev/null 2>&1; then
    systemctl --user restart agy-nvidia-proxy.service
  else
    pkill -f 'litellm.*--port 4000' 2>/dev/null || true
    pkill -f 'agy-nvidia-router' 2>/dev/null || true
  fi
  for _ in $(seq 1 60); do
    sleep 1
    if curl -fsS --max-time 2 http://127.0.0.1:4000/health/liveliness >/dev/null 2>&1; then
      echo "proxy: UP"
      return 0
    fi
  done
  echo "proxy did not become ready; inspect: journalctl --user -u agy-nvidia-proxy -n 50" >&2
  return 1
}

list_models() {
  python3 - "$YAML" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
anchors = {m.group(1): m.group(2) for m in re.finditer(r"&(\w+)\s*\n\s*model:\s*openai/(\S+)", text)}
for m in re.finditer(r"model_name:\s*(\S+)\s*\n\s*litellm_params:\s*(?:&(\w+)|\*(\w+))", text):
    print(f"{m.group(1):35} -> {anchors.get(m.group(2) or m.group(3), '?')}")
PY
  printf 'KEY: '
  if grep -q '^NVIDIA_API_KEY=' "$ENV_FILE" 2>/dev/null; then echo 'set'; else echo 'not set'; fi
  if curl -fsS --max-time 2 http://127.0.0.1:4000/health/liveliness >/dev/null 2>&1; then
    echo 'proxy: UP (router :4000 -> LiteLLM :4001)'
  else
    echo 'proxy: DOWN'
  fi
}

set_group() {
  local group="$1" model pattern anchor
  model="$(normalize_model "$2")"
  case "$group" in
    3.7) anchor=super; pattern='gemini-3.7-flash' ;;
    3.8) anchor=ultra; pattern='gemini-3.8-flash' ;;
    3.6) anchor=free;  pattern='gemini-3.6-flash' ;;
    pro)  anchor=pro;   pattern='gemini-3.1-pro|claude|gpt-oss|gemini-3-flash|gemini-3.5' ;;
    *) echo "unknown group: $group" >&2; exit 1 ;;
  esac
  python3 - "$YAML" "$anchor" "$model" <<'PY'
import re, sys
path, anchor, model = sys.argv[1:]
text = open(path, encoding="utf-8").read()
pattern = rf'(&{re.escape(anchor)}\s*\n\s*model:\s*)openai/\S+'
text, count = re.subn(pattern, rf'\g<1>openai/{model}', text, count=1)
if count != 1:
    raise SystemExit(f'could not find YAML anchor &{anchor}')
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY
  cp "$YAML" "$REPO_YAML"
  echo "$pattern -> $model"
  restart_proxy
}

case "${1:-}" in
  '') cp "$REPO_YAML" "$YAML"; restart_proxy; echo 'preset applied'; list_models ;;
  list|--list|-l) list_models ;;
  key)
    [[ -n "${2:-}" ]] || { usage; exit 1; }
    [[ "$2" == nvapi-* ]] || { echo 'key must start with nvapi-' >&2; exit 1; }
    umask 077; printf 'NVIDIA_API_KEY=%s\n' "$2" > "$ENV_FILE"
    echo "key updated in $ENV_FILE"; restart_proxy ;;
  3.7|3.8|3.6|pro)
    [[ -n "${2:-}" ]] || { usage; exit 1; }
    set_group "$1" "$2" ;;
  help|--help|-h) usage ;;
  *) echo "unknown argument: $1" >&2; usage; exit 1 ;;
esac
