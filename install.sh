#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HOME/.config/agy-nvidia"
BIN="$HOME/.local/bin"
ISO="$HOME/.gemini-agy-nvidia/antigravity-cli"

command -v uv  >/dev/null || { echo "uv required: https://docs.astral.sh/uv/"; exit 1; }
command -v agy >/dev/null || [ -x "$HOME/.local/bin/agy" ] || echo "warning: agy not found in PATH"

echo "==> installing LiteLLM (uv tool, python 3.12)"
uv tool install --python 3.12 'litellm[proxy]' >/dev/null 2>&1 || true

echo "==> $CFG"
mkdir -p "$CFG" "$BIN" "$ISO"
install -m 644 "$HERE/litellm.yaml" "$CFG/litellm.yaml"
if [ ! -f "$CFG/.env" ]; then
  cat > "$CFG/.env" <<ENVEOF
NVIDIA_API_KEY=paste-your-nvapi-key-here
ENVEOF
  chmod 600 "$CFG/.env"
  echo "    EDIT $CFG/.env and paste your nvapi- key"
else
  echo "    $CFG/.env already exists — not overwriting"
fi
chmod 600 "$CFG/.env"

echo "==> $BIN/agy-nvidia"
install -m 755 "$HERE/agy-nvidia" "$BIN/agy-nvidia"

echo "==> $BIN/agy-nvidia-router"
install -m 755 "$HERE/router.py" "$BIN/agy-nvidia-router"

echo "==> $BIN/agy-nvidia-web"
install -m 755 "$HERE/agy-nvidia-web" "$BIN/agy-nvidia-web"
install -m 755 "$HERE/web_server.py" "$BIN/agy-nvidia-web-server"
WEB_ROOT="$HOME/.local/share/agy-nvidia-web"
rm -rf "$WEB_ROOT"
mkdir -p "$WEB_ROOT"
cp -a "$HERE/ui/." "$WEB_ROOT/"

if [ -f "$HERE/switch-model.ps1" ]; then
  install -m 644 "$HERE/switch-model.ps1" "$BIN/switch-model.ps1"
fi

echo "==> $ISO/settings.json"
if [ ! -f "$ISO/settings.json" ]; then
  install -m 600 "$HERE/settings.json" "$ISO/settings.json"
else
  echo "    $ISO/settings.json already exists — not overwriting"
fi

echo "==> systemd unit (optional)"
mkdir -p ~/.config/systemd/user
if [ ! -f ~/.config/systemd/user/agy-nvidia-proxy.service ]; then
  install -m 644 "$HERE/systemd/agy-nvidia-proxy.service" ~/.config/systemd/user/agy-nvidia-proxy.service
  systemctl --user daemon-reload
  echo "    installed; enable with: systemctl --user enable --now agy-nvidia-proxy"
else
  echo "    ~/.config/systemd/user/agy-nvidia-proxy.service already exists"
fi

echo ""
echo "Done. Test with: agy-nvidia -p \"Reply with exactly: AGY NVIDIA WORKS\""
