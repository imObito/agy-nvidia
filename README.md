# agy-nvidia — Antigravity CLI via NVIDIA APIs

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![LiteLLM Proxy](https://img.shields.io/badge/Proxy-LiteLLM-green.svg)](https://github.com/BerriAI/litellm)
[![NVIDIA NIM](https://img.shields.io/badge/NVIDIA-API%20%2F%20NIM-76B900.svg)](https://build.nvidia.com)

**How to use Antigravity unlimited**: Run Google's **Antigravity CLI (`agy`)** against **NVIDIA's hosted API** (`integrate.api.nvidia.com`) with custom models without hitting Google account quota limits or touching your standalone Antigravity IDE.

> `agy` only supports custom endpoints via `modelProvider: "gemini"` + `GEMINI_API_KEY` + `GOOGLE_GEMINI_BASE_URL` (**Gemini `generateContent` protocol**).  
> NVIDIA only speaks **OpenAI `chat/completions` protocol**.  
> This repo provides an automated, isolated **LiteLLM** translation proxy in between.

```
agy  --(Gemini format, x-goog-api-key, :streamGenerateContent?alt=sse)-->  LiteLLM :4000  --(OpenAI format, Bearer nvapi-...)-->  integrate.api.nvidia.com
```

Verified end-to-end Sep 22 2026 on CachyOS. Standalone Antigravity IDE left untouched (isolated via `--gemini_dir`).

---

## 1. Quick start

```bash
# prerequisites: agy installed at ~/.local/bin/agy, uv installed
uv tool install --python 3.12 'litellm[proxy]'

# clone this repo
git clone https://github.com/imObito/agy-nvidia.git ~/agy-nvidia
cd ~/agy-nvidia

# install files (see install.sh)
bash install.sh

# put your NVIDIA API key in the env file (never commit this file)
echo 'NVIDIA_API_KEY=nvapi-...' > ~/.config/agy-nvidia/.env
chmod 600 ~/.config/agy-nvidia/.env

# run — TUI, same flags as plain agy
agy-nvidia
agy-nvidia -p "Reply with exactly: AGY NVIDIA WORKS"   # one-shot test
agy-nvidia -c                                           # continue last conversation
```

Plain `agy` still uses Google sign-in exactly as before.

Optional — start proxy at boot:

```bash
systemctl --user enable --now agy-nvidia-proxy
```

---

## 2. How to use

| Command | What it does |
|---|---|
| `agy-nvidia` | Interactive TUI (NVIDIA backend) |
| `agy-nvidia -p "prompt"` | Print mode (one turn, exits) |
| `agy-nvidia --help` | Same flags as `agy` |
| `agy` | Original Google-auth CLI (untouched) |

The wrapper `~/.local/bin/agy-nvidia` (20 lines) does:

1. Loads `~/.config/agy-nvidia/.env` (`NVIDIA_API_KEY`)
2. Starts LiteLLM on `:4000` if not already alive (health check `/health/liveliness`)
3. Sets `GEMINI_API_KEY` + `GOOGLE_GEMINI_BASE_URL=http://127.0.0.1:4000` (scoped to this process)
4. `exec agy --gemini_dir=~/.gemini-agy-nvidia "$@"`

---

## 3. Files & where things live

| Path | Purpose | Committed? |
|---|---|---|
| `litellm.yaml` | LiteLLM config — model alias table (all `agy` model names → one NVIDIA model via YAML anchor `&nemotron`) | ✅ |
| `agy-nvidia` | Wrapper script (`~/.local/bin/agy-nvidia`) | ✅ |
| `settings.json` | Template for `~/.gemini-agy-nvidia/antigravity-cli/settings.json` (`modelProvider: gemini`) | ✅ |
| `systemd/agy-nvidia-proxy.service` | Optional persistent systemd user unit | ✅ |
| `install.sh` | One-shot installer | ✅ |
| `~/.config/agy-nvidia/.env` | `NVIDIA_API_KEY=nvapi-...` — **never commit** | ❌ (gitignored) |
| `~/.gemini-agy-nvidia/` | Isolated `agy` config (history, conversations) — wrapper only | ❌ |
| `~/.gemini/` | Real Antigravity config — **never written** (verified via `stat` mtimes) | n/a |

---

## 4. Which models can I use?

### Official NVIDIA NIM Model Catalog (Free Tier Supported)

All models listed below are accessible via NVIDIA's official API (`integrate.api.nvidia.com`) with a free NVIDIA Developer account (includes **1,000 free build credits** with auto-renewal/free tier access).

#### 🟢 Featured Reasoning & Code Generation Models

| Model | NVIDIA NIM Identifier | Context | Status | Best Used For |
|---|---|---|---|---|
| **DeepSeek V4.1 Flash** | `deepseek-ai/deepseek-v4.1-flash` | 128k | 🟢 **Free / Active** | General coding, high-speed interactive agent turns *(Default)* |
| **Codestral 22B** | `mistralai/codestral-22b-instruct-v0.1` | 32k | 🟢 **Free / Active** | Multi-language code completion, refactoring, synthesis |
| **CodeLlama 70B** | `meta/codellama-70b` | 100k | 🟢 **Free / Active** | Complex software architecture, unit testing |
| **StarCoder2 15B** | `bigcode/starcoder2-15b` | 16k | 🟢 **Free / Active** | Fast inline code generation, script writing |
| **CodeGemma 7B** | `google/codegemma-7b` | 8k | 🟢 **Free / Active** | Lightweight code assistant, documentation generator |

#### 🟢 NVIDIA Nemotron & Llama Series

| Model | NVIDIA NIM Identifier | Context | Status | Best Used For |
|---|---|---|---|---|
| **Llama 3.1 Nemotron 70B** | `nvidia/llama-3.1-nemotron-70b-instruct` | 128k | 🟢 **Free / Active** | State-of-the-art general reasoning, complex agent workflows |
| **Llama 3.1 Nemotron 51B** | `nvidia/llama-3.1-nemotron-51b-instruct` | 128k | 🟢 **Free / Active** | High efficiency instruction following, agent tool calling |
| **Nemotron-4 340B** | `nvidia/nemotron-4-340b-instruct` | 4k | 🟢 **Free / Active** | High precision enterprise chat, synthetic data & reasoning |
| **Nemotron-3 Super 120B** | `nvidia/nemotron-3-super-120b-a12b` | 32k | 🟢 **Free / Active** | High throughput deep reasoning & analysis |
| **Mistral NeMo Minitron 8B** | `nvidia/mistral-nemo-minitron-8b-8k-instruct` | 8k | 🟢 **Free / Active** | Low latency, lightweight chat and summarization |

#### 🟢 General Purpose & Open Foundation Models

| Model | NVIDIA NIM Identifier | Context | Status | Best Used For |
|---|---|---|---|---|
| **Gemma 3 12B IT** | `google/gemma-3-12b-it` | 8k | 🟢 **Free / Active** | General instruction following, structured text generation |
| **Gemma 3 4B IT** | `google/gemma-3-4b-it` | 8k | 🟢 **Free / Active** | Fast edge/low-overhead task processing |
| **Phi-3.5 MoE Instruct** | `microsoft/phi-3.5-moe-instruct` | 128k | 🟢 **Free / Active** | Multi-domain reasoning, math, multilingual synthesis |
| **Mistral 7B Instruct v0.3** | `mistralai/mistral-7b-instruct-v0.3` | 32k | 🟢 **Free / Active** | Fast general dialogue, markdown generation |
| **Granite 3.0 8B Instruct** | `ibm/granite-3.0-8b-instruct` | 4k | 🟢 **Free / Active** | Enterprise workflows, tabular data processing |
| **Yi Large** | `01-ai/yi-large` | 32k | 🟢 **Free / Active** | Bilingual reasoning, long context analysis |

### Full catalog snapshot (82 models, `GET /v1/models`)

```text
01-ai/yi-large
adept/fuyu-8b
ai21labs/jamba-1.5-large-instruct
aisingapore/sea-lion-7b-instruct
bigcode/starcoder2-15b
databricks/dbrx-instruct
deepseek-ai/deepseek-coder-6.7b-instruct
deepseek-ai/deepseek-v4.1-flash
google/codegemma-1.1-7b
google/codegemma-7b
google/deplot
google/diffusiongemma-26b-a4b-it
google/gemma-2b
google/gemma-3-12b-it
google/gemma-3-4b-it
google/gemma-4-31b-it
google/recurrentgemma-2b
ibm/granite-3.0-3b-a800m-instruct
ibm/granite-3.0-8b-instruct
ibm/granite-34b-code-instruct
ibm/granite-8b-code-instruct
meta/codellama-70b
meta/llama-3.2-11b-vision-instruct
meta/llama-3.2-90b-vision-instruct
meta/llama-guard-4-12b
meta/llama2-70b
meta/muse-glimmer-30b
microsoft/kosmos-2
microsoft/phi-3-vision-128k-instruct
microsoft/phi-3.5-moe-instruct
mistralai/codestral-22b-instruct-v0.1
mistralai/mistral-7b-instruct-v0.3
mistralai/mistral-large
mistralai/mistral-large-2-instruct
mistralai/mistral-nemotron
mistralai/mixtral-8x22b-v0.1
moonshotai/kimi-k2.6
moonshotai/kimi-k3
nv-mistralai/mistral-nemo-12b-instruct
nvidia/ai-synthetic-video-detector
nvidia/cosmos-reason2-8b
nvidia/embed-qa-4
nvidia/ising-calibration-1.5-31b
nvidia/llama-3.1-nemoguard-8b-content-safety
nvidia/llama-3.1-nemoguard-8b-topic-control
nvidia/llama-3.1-nemotron-51b-instruct
nvidia/llama-3.1-nemotron-70b-instruct
nvidia/llama-3.1-nemotron-safety-guard-8b-v3
nvidia/llama-3.1-nemotron-ultra-253b-v1
nvidia/llama-3.2-nemoretriever-1b-vlm-embed-v1
nvidia/llama-3.2-nv-embedqa-1b-v1
nvidia/llama-nemotron-embed-vl-1b-v2
nvidia/llama3-chatqa-1.5-70b
nvidia/mistral-nemo-minitron-8b-8k-instruct
nvidia/nemotron-3-embed-1b
nvidia/nemotron-3-nano-omni-30b-a3b-reasoning
nvidia/nemotron-3-super-120b-a12b
nvidia/nemotron-3-ultra-550b-a55b
nvidia/nemotron-3.5-content-safety
nvidia/nemotron-3.5-lightning-30b-a3b
nvidia/nemotron-4-340b-instruct
nvidia/nemotron-4-340b-reward
nvidia/nemotron-nano-3-30b-a3b
nvidia/nemotron-parse
nvidia/nemotron-parse-2.0
nvidia/neva-22b
nvidia/nv-embedqa-mistral-7b-v2
nvidia/nvclip
nvidia/riva-translate-4b-instruct
nvidia/riva-translate-4b-instruct-v1.1
nvidia/riva-translate-4b-instruct-v2
nvidia/vila
openai/gpt-oss-20b
poolside/laguna-xs-2.1
snowflake/arctic-embed-l
writer/palmyra-creative-122b
writer/palmyra-fin-70b-32k
writer/palmyra-med-70b
writer/palmyra-med-70b-32k
z-ai/glm-5.3
```

---

## 5. How to switch models

### Test a model first (always do this)

```bash
KEY=$(grep NVIDIA_API_KEY ~/.config/agy-nvidia/.env | cut -d= -f2)
curl -s --max-time 20 https://integrate.api.nvidia.com/v1/chat/completions \
  -H "content-type: application/json" -H "Authorization: Bearer $KEY" \
  -d '{"model":"MODEL_HERE","messages":[{"role":"user","content":"say OK"}],"max_tokens":50}' \
  -w '\nHTTP %{http_code} in %{time_total}s\n' | head -c 400
# 200 quickly  → good;  000/timeout → hangs, skip;  404 → not available;  503 → temporarily overloaded, retry
```

### Switch every `agy` alias at once (common case)

All 20 `agy` model names in `litellm.yaml` share one YAML anchor `&nemotron`. Change that one line:

```bash
nano ~/.config/agy-nvidia/litellm.yaml
# edit:
#   model: openai/deepseek-ai/deepseek-v4.1-flash
# to e.g.:
#   model: openai/nvidia/nemotron-3-super-120b-a12b

# restart proxy (transient unit)
systemctl --user restart agy-nvidia-proxy
# or if not using systemd:
# pkill -f 'litellm --config'; sleep 2; agy-nvidia -p "hi" &

# verify
curl -s --max-time 3 http://127.0.0.1:4000/health/liveliness   # -> "I'm alive!"
```

### Map different `agy` names to different NVIDIA models

`agy` sends internal IDs like `gemini-3.1-pro-preview` (main agent, captured live) and `gemini-3.1-flash-lite-preview` (title generation). You can split them:

```yaml
model_list:
  - model_name: gemini-3.1-pro-preview       # main agent → big model
    litellm_params: &big
      model: openai/nvidia/nemotron-3-ultra-550b-a55b
      api_base: https://integrate.api.nvidia.com/v1
      api_key: os.environ/NVIDIA_API_KEY
  - model_name: gemini-3.1-flash-lite-preview  # titles → cheap/fast
    litellm_params:
      model: openai/deepseek-ai/deepseek-v4.1-flash
      api_base: https://integrate.api.nvidia.com/v1
      api_key: os.environ/NVIDIA_API_KEY
  # ... keep the rest as catch-alls: litellm_params: *big
```

If `agy` ever asks for a name not in `model_list`, LiteLLM returns 404 — add that `model_name` to the list (check `journalctl --user -u agy-nvidia-proxy -f` for the exact name).

---

## 6. Proxy management

```bash
systemctl --user status agy-nvidia-proxy      # running?
journalctl --user -u agy-nvidia-proxy -f       # live logs — shows each forwarded request
journalctl --user -u agy-nvidia-proxy -n 20    # recent logs
curl -s http://127.0.0.1:4000/health/liveliness # -> "I'm alive!"
systemctl --user restart agy-nvidia-proxy
systemctl --user stop agy-nvidia-proxy
systemctl --user enable --now agy-nvidia-proxy  # start at login
```

The wrapper `agy-nvidia` also auto-starts the proxy via `nohup` if the health check fails — so it self-heals even without the systemd unit.

---

## 7. Isolation — why the standalone app is safe

* **Separate config root**: wrapper passes `--gemini_dir=~/.gemini-agy-nvidia` (not `~/.gemini`). All history/conversations/settings live there.
* **Scoped env vars**: `GEMINI_API_KEY` / `GOOGLE_GEMINI_BASE_URL` are exported only inside the wrapper process.
* **Verified untouched**: `stat ~/.gemini/antigravity-cli/settings.json` mtime unchanged; standalone IDE (10 processes, `Apps/Antigravity IDE/antigravity-ide`) still running.
* **Plain `agy` unchanged**: launching `agy` without the wrapper uses Google sign-in as before.

> ⚠️ Do not edit `~/.gemini/antigravity-cli/settings.json` by hand — use the wrapper.  
> ⚠️ Keep `~/.config/agy-nvidia/.env` out of git (`chmod 600`, listed in `.gitignore`).

---

## 8. Architecture notes — why this design

The pasted instructions claiming `modelProvider: "openai-compatible"` + `baseURL` + `apiKey` in `settings.json` are **hallucinated** — binary verified: only `modelProvider: "gemini"` is recognized (everything else is silently ignored). Verified: `modelProvider: "gemini"` without `GEMINI_API_KEY` → immediate error `GEMINI_API_KEY environment variable is not set`. `GOOGLE_GEMINI_BASE_URL` only works with the Gemini protocol. `MCP` (`mcp_config.json`) only adds tools, it cannot change the model backend.

LiteLLM is used because it natively translates the Gemini `generateContent` SSE stream. The working Gemini route is `POST /v1beta/models/{model}:streamGenerateContent?alt=sse` with `x-goog-api-key` header (captured live). LiteLLM's `/v1beta/models/...` `google_endpoints` handles this faithfully — do **not** set `GOOGLE_GEMINI_BASE_URL` with a `/gemini` suffix (that hits the pass-through route which requires a Google `GEMINI_API_KEY`).

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Requests hang / HTTP 000 after 25-90s | Broken model upstream (verified for your `nemotron-3.5-lightning`) | `curl`-test the model directly, switch to a verified one |
| `503 Service temporarily overloaded` | NVIDIA side flaky (observed for `nemotron-3-super`) | Retry or switch |
| `404` from proxy | `agy` asked for a `model_name` not in `litellm.yaml` | Add that name to `model_list`; check logs for exact name |
| `Connection refused :4000` | Proxy down | `systemctl --user start agy-nvidia-proxy` or just run `agy-nvidia` again (auto-starts) |
| LiteLLM error `Required 'GEMINI_API_KEY'` | Wrong base URL with `/gemini` suffix | Ensure `GOOGLE_GEMINI_BASE_URL=http://127.0.0.1:4000` (no `/gemini`) |
| `agy` error `modelProvider is set to "gemini" but GEMINI_API_KEY not set` | Ran plain `agy` with isolated settings or missing `.env` | Use `agy-nvidia` wrapper; check `.env` |

---

## 10. Security

* API key is in `~/.config/agy-nvidia/.env` and (transiently) in the systemd unit's `Environment=` line. Never commit `.env` or the transient unit dump.
* This README and the repo contain **no secrets** (`grep -r nvapi-` must be empty before pushing).
* If your `nvapi-` key was pasted in a chat log, rotate it at https://build.nvidia.com.

---

## 11. Uninstall / reset

```bash
systemctl --user disable --now agy-nvidia-proxy 2>/dev/null
rm -rf ~/.gemini-agy-nvidia ~/.config/agy-nvidia
rm ~/.local/bin/agy-nvidia
# plain agy continues to work
```

---

*Generated Sep 22 2026. End-to-end verified: `agy-nvidia -p "Reply with exactly: AGY NVIDIA WORKS"` → `AGY NVIDIA WORKS` (HTTP 200, Gemini SSE via LiteLLM).*
