# Setup Prompt for Any AI — agy-nvidia (Windows & Linux)

**Copy-paste this entire prompt into any AI (Antigravity, Claude, ChatGPT, etc.) with the `~/agy-nvidia` folder available:**

---

You are setting up **agy-nvidia** — Google Antigravity CLI (`agy`) via NVIDIA APIs (`integrate.api.nvidia.com`) without touching the standalone Antigravity IDE.

**Project location:** `~/agy-nvidia` (contains `litellm.yaml`, `agy-nvidia`, `switch-model.sh/.bat`, `switch-gui.sh`, `settings.json`, `api_keys.txt`, `systemd/agy-nvidia-proxy.service`)

**Architecture:**
```
agy / AGY NVIDIA Studio --(Gemini format)--> agy-nvidia-router :4000 --> LiteLLM :4001 --(OpenAI format)--> integrate.api.nvidia.com
```
`agy` only supports `modelProvider: "gemini"` + `GEMINI_API_KEY` + `GOOGLE_GEMINI_BASE_URL` (Gemini protocol). NVIDIA speaks OpenAI `chat/completions`. The router translates the request boundary, performs bounded pre-stream fallback, and can run parallel tiny `"yo"` health probes across eligible models. LiteLLM handles the protocol translation.

**Tasks — do both Windows and Linux:**

1. **Prerequisites:**
   - `agy` installed at `~/.local/bin/agy` (Linux) or `%USERPROFILE%\.local\bin\agy.exe` (Windows) — verify with `agy --version`
   - Python 3.12 + `uv` (https://docs.astral.sh/uv/) — required for `uv tool install --python 3.12 'litellm[proxy]'`
   - NVIDIA API key(s) from `api_keys.txt` (`NVIDIA_API_KEY=nvapi-...`) — never log the full key, never commit `api_keys.txt` to public GitHub

2. **Install (run `install.sh`):**
   - **Linux:** `bash ~/agy-nvidia/install.sh` — installs LiteLLM via `uv`, installs the router and `agy-nvidia web`, copies the UI assets, copies `litellm.yaml` to `~/.config/agy-nvidia/litellm.yaml`, creates `~/.config/agy-nvidia/.env` (paste `NVIDIA_API_KEY` from `api_keys.txt`, `chmod 600`), installs `~/.local/bin/agy-nvidia` and the systemd router service. Run `agy-nvidia web` for the local web interface.
   - **Windows:** `powershell -ExecutionPolicy Bypass -File ~/agy-nvidia/install.ps1` (or manually: `uv tool install --python 3.12 litellm[proxy]` via `pipx`, copy `litellm.yaml` to `%USERPROFILE%\.config\agy-nvidia\litellm.yaml`, create `%USERPROFILE%\.config\agy-nvidia\.env` with `NVIDIA_API_KEY`, copy `agy-nvidia` wrapper as `agy-nvidia.bat` to `%USERPROFILE%\.local\bin`)

3. **Configuration:**
   - `litellm.yaml` preset: `3.7` → `nvidia/nemotron-3-super-120b-a12b`, `3.8` → `nvidia/nemotron-3-ultra-550b-a55b`, `3.6` → `meta/llama-3.2-11b-vision-instruct` (free stable), `pro/low/high` → `deepseek-ai/deepseek-v4.1-flash`. All low/mid/high of a group share same model via YAML anchors `&super`/`&ultra`/`&free`/`&pro`. Use `switch-model.sh`/`switch-model.bat` or `switch-gui.sh` (zenity) / `switch-dialog.ps1` (WinForms) to change.
   - `settings.json` template: `{"modelProvider":"gemini","model":"Gemini 3.1 Pro (Low)"}` — isolated via `agy --gemini_dir=~/.gemini-agy-nvidia`, never writes to `~/.gemini`

4. **Verify:**
   - **Linux:** `systemctl --user enable --now agy-nvidia-proxy` then `curl -s http://127.0.0.1:4000/health/liveliness` → `"I'm alive!"`
   - Test NVIDIA directly: `curl -s https://integrate.api.nvidia.com/v1/chat/completions -H "Authorization: Bearer $NVIDIA_API_KEY" -H "Content-Type: application/json" -d '{"model":"deepseek-ai/deepseek-v4.1-flash","messages":[{"role":"user","content":"say OK"}],"max_tokens":20}'` → `HTTP 200`
   - Test via proxy (Gemini format): `curl -s -X POST "http://127.0.0.1:4000/v1beta/models/gemini-3.1-pro-preview:streamGenerateContent?alt=sse" -H "x-goog-api-key: $NVIDIA_API_KEY" -H "content-type: application/json" -d '{"contents":[{"role":"user","parts":[{"text":"say OK"}]}],"generationConfig":{"maxOutputTokens":64}}'` → `candidates`
   - End-to-end: `agy-nvidia -p "Reply with exactly: AGY NVIDIA WORKS"` → `AGY NVIDIA WORKS` (exit 0). Plain `agy` must still work via Google sign-in (check `stat ~/.gemini/antigravity-cli/settings.json` mtime unchanged, `pgrep -f Apps/Antigravity` alive)

5. **Usage:**
   - `agy-nvidia` (TUI), `agy-nvidia -p "prompt"`, `agy-nvidia web` (local web UI), `agy-nvidia --help` (same flags as `agy`)
   - The model catalog is larger than the four current router defaults; eligible chat models can be added to the health-check candidate list. Do not probe embeddings, safety, moderation, image, or video models as chat models.

6. **Troubleshooting:**
   - `400 Invalid model name gemini-3.7-flash` → missing base alias in `litellm.yaml` (add `gemini-3.7-flash: *super`, `gemini-3.6-flash: *free`), restart proxy
   - `3.1 pro: FAIL` → `deepseek` overloaded (HTTP 000 timeout, `MAX_TOKENS` at `maxOutputTokens:20`) — fallback to `3.6` via `fallbacks:` in `litellm.yaml` keeps working, increase to `64`
   - `503 Service temporarily overloaded` / `404 Not Found for account` → NVIDIA model not available for that key/account, switch to `deepseek`/`llama-vision` or use different `nvapi-` key from `api_keys.txt`
   - `GEMINI_API_KEY not set` → not using wrapper, always use `agy-nvidia` not `agy --gemini_dir`
   - `switch-model.bat` fails on Linux → use `switch-model.sh`/`switch-gui.sh`; `powershell` not found is expected on Linux, fallback to `python3`

7. **Security:**
   - `api_keys.txt` and `~/.config/agy-nvidia/.env` contain real `nvapi-` keys — `chmod 600`, gitignored, never push to public repo. If pasted in chat, rotate at build.nvidia.com. Backup tarball `agy-nvidia-backup-with-keys-*.tar.gz` is local only.

After setup, print `bash ~/agy-nvidia/switch-model.sh list` and `agy-nvidia -p "say OK"` output, plus `git status` if inside `~/agy-nvidia` git repo.

---

**End of prompt.**
