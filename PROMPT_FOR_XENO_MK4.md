# Prompt for Antigravity — Add agy-nvidia + opencode + Claude panel to XENO MK-4

**Paste this entire block into Antigravity (IDE or `agy`) with workspace `~/My Projects/XENO MK4` open:**

---

You are working in `~/My Projects/XENO MK4` (Python 3.12, PyQt6). Do NOT touch `~/.gemini` or the standalone Antigravity app.

**Goal:** Add `agy-nvidia` as a first-class XENO tool (feeds to NVIDIA `integrate.api.nvidia.com`), wire `opencode` and `claude` CLIs as tools, and add a unified **Tools Panel** in `ui.py`.

**Context you must read first:**
- `or_client.py:1` — generic OpenAI-compatible client (reads `config/api_keys.json` `llm_*` keys). Currently `llm_model: nvidia/nemotron-3.5-lightning-30b-a3b` which HANGS forever (verified 90s timeout) — do not use it.
- `actions/coding_agent.py:1` — already has `_run_with_opencode()` and `shutil.which("opencode")` detection, plus bash-only JSON loop. Extend this pattern.
- `core/local_llm.py:1` — local llama-server on `:8080` (keep as-is, don't break).
- `ui.py:1` — PyQt6 Terminal Velvet UI (left rail `_build_left_rail`, centre, header, bottom bar). Add a new nav item + panel.
- Existing working NVIDIA setup: `~/agy-nvidia/litellm.yaml` maps all `agy` Gemini names via YAML anchor `&nemotron` to `openai/deepseek-ai/deepseek-v4.1-flash` (stable ~0.9s). Verified good alternatives: `nvidia/nemotron-3-super-120b-a12b` (flaky 503), `nvidia/nemotron-3-ultra-550b-a55b` (flaky). Wrapper `~/.local/bin/agy-nvidia` uses `--gemini_dir=~/.gemini-agy-nvidia` + `GEMINI_API_KEY`/`GOOGLE_GEMINI_BASE_URL=http://127.0.0.1:4000` + LiteLLM proxy `:4000` (systemd unit `agy-nvidia-proxy`, `os.environ/NVIDIA_API_KEY` from `~/.config/agy-nvidia/.env`).

**Tasks:**

1. **Config — `config/api_keys.json` + `config/api_keys.example.json`:**
   - Add `code_api_key`/`code_base_url`/`code_model` already exist; also add `agy_nvidia_model` (default `deepseek-ai/deepseek-v4.1-flash`), `opencode_enabled` (bool), `claude_enabled` (bool). Keep secrets out of example file (empty strings). Do NOT commit real `nvapi-` keys.

2. **New tools — `actions/` (follow `coding_agent.py` patterns: `shutil.which` detection, timeout, truncation, `player.write_log`):**
   - `actions/agy_nvidia_tool.py` — `agy_nvidia_tool(parameters, player, ...)` runs `agy-nvidia -p "prompt"` (or `--dangerously-skip-permissions` if requested) via `subprocess` in project cwd, streams output, respects `GEMINI_API_KEY`/`GOOGLE_GEMINI_BASE_URL` (wrapper sets them). Fallback: if `agy-nvidia` not found, return clear error with install hint (`~/agy-nvidia/install.sh`).
   - `actions/opencode_tool.py` (or extend `coding_agent.py:_run_with_opencode`) — `opencode_tool(parameters, player, ...)` wraps `opencode run --auto` with same safety (`_DANGEROUS` regex, cwd jail, timeout). If `opencode` missing, return install hint.
   - `actions/claude_tool.py` — `claude_tool(parameters, player, ...)` wraps `claude -p "prompt"` (Anthropic Claude Code CLI) similarly. Detect via `shutil.which("claude")`. Support `--model` override from config.

3. **LLM routing — `or_client.py` or new `core/tool_router.py`:**
   - Keep `or_client.client` for XENO chat as-is, but fix default: if `llm_model` is `nvidia/nemotron-3.5-lightning-30b-a3b`, auto-fallback to `deepseek-ai/deepseek-v4.1-flash` with warning (since it hangs). Log via `logger.warning`.

4. **UI Panel — `ui.py`:**
   - In `_build_left_rail` add nav item `tools` (icon `🛠` or `◈`) after existing items. Reuse style `C.AMBER`/`C.BORDER`.
   - Build `_build_tools_panel()` / `_build_centre` integration: a `QStackedWidget` page with:
     - Header: "TOOLS — AGY-NVIDIA · OPENCODE · CLAUDE"
     - 3 cards (QFrame): **agy-nvidia**, **opencode**, **Claude** — each shows: status dot (green if `shutil.which` found else red), version (`--version` if found), model name (from `litellm.yaml` or `config/api_keys.json`), health (`curl http://127.0.0.1:4000/health/liveliness` for agy-nvidia proxy), and buttons: `[Run]` `[Logs]` `[Config]`.
     - Bottom: unified input `QLineEdit` + `[Run with ▼]` dropdown (select tool) + `[Stop]`; output `LogWidget`.
     - Wire: input → dispatcher calls the correct `actions/*_tool.py` function in background thread (like `coding_agent:run_background`), streams to `LogWidget` via `player.write_log`.
   - Keep existing metrics/hologram — do not break `MetricChip`/`HologramContainer`.

5. **Docs & install:**
   - Update `readme.md` section "Tools Panel" with usage.
   - Ensure `requirements.txt` unchanged (no new deps).

**Acceptance:**
- `python -m py_compile ui.py or_client.py actions/agy_nvidia_tool.py actions/opencode_tool.py actions/claude_tool.py` passes.
- With proxy running, `agy-nvidia -p "say OK"` returns `OK` (via wrapper).
- `opencode --version` / `claude --version` detection shows green when installed, red + hint when not.
- `config/api_keys.json` never committed with real keys (check `.gitignore`).
- Standalone Antigravity app untouched — no writes to `~/.gemini`.

Execute now. After done, print `git status --short` and files changed.
