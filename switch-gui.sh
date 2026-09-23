#!/usr/bin/env bash
# switch-gui.sh — Zenity GUI for agy-nvidia (3-step flow)
# 1: check all models | 2: insert new nvidia api | 3: model change -> choose group (3.8/3.7/3.6/3.1 pro) -> choose free LLM (same for low/mid/high)
set -euo pipefail
CFG="$HOME/.config/agy-nvidia/litellm.yaml"
ENV="$HOME/.config/agy-nvidia/.env"
REPO="$(dirname "$(realpath "$0")")/litellm.yaml"

if ! command -v zenity >/dev/null; then
  zenity 2>&1 | head -1
  echo "zenity not found: sudo pacman -S zenity"
  exit 1
fi

# Free NVIDIA LLMs — flat array: model, notes, model, notes...
FREE_MODELS=(
  "deepseek-ai/deepseek-v4.1-flash" "FREE stable ~0.9s"
  "meta/llama-3.2-11b-vision-instruct" "FREE vision 11B stable"
  "nvidia/nemotron-3-super-120b-a12b" "FREE super 120B flaky"
  "nvidia/nemotron-3-ultra-550b-a55b" "FREE ultra 550B flaky"
  "z-ai/glm-5.3" "FREE glm 5.3"
  "z-ai/glm-5.3-flash" "FREE glm 5.3 flash"
  "moonshotai/kimi-k3" "FREE kimi-k3 vision"
  "nvidia/nemotron-parse-2.0" "FREE parse 2.0"
  "nvidia/nemotron-3.5-lightning-30b-a3b" "FREE lightning 30B"
  "nvidia/nemotron-4-340b-instruct" "FREE nemotron 4 340B"
  "openai/gpt-oss-20b" "FREE gpt-oss 20B"
  "writer/palmyra-creative-122b" "FREE palmyra"
  "google/gemma-3-12b-it" "FREE gemma 3 12B"
  "meta/llama-3.1-nemotron-51b-instruct" "FREE 51B"
  "nvidia/kumo-relational" "FREE kumo (structured)"
)

while true; do
  CHOICE=$(zenity --list --title="agy-nvidia — Switch GUI" --text="Choose action:" \
    --column="Option" --column="Description" \
    "1" "Check all models (health test via LiteLLM)" \
    "2" "Insert new NVIDIA API key" \
    "3" "Model change" \
    --width=600 --height=250 2>/dev/null)
  [ -z "$CHOICE" ] && exit 0

  case "$CHOICE" in
    1)
      KEY=$(grep NVIDIA_API_KEY "$ENV" 2>/dev/null | cut -d= -f2 || echo "")
      TMPLOG=$(mktemp)
      # helper: check one model via LiteLLM — use larger maxOutputTokens (deepseek needs >20 due to reasoning)
      check_one() {
        local alias="$1" label="$2"
        local code body
        body=$(mktemp)
        code=$(timeout 25 curl -s --max-time 20 -o "$body" -w "%{http_code}" -X POST "http://127.0.0.1:4000/v1beta/models/$alias:streamGenerateContent?alt=sse" -H "x-goog-api-key: $KEY" -H "content-type: application/json" -d '{"contents":[{"role":"user","parts":[{"text":"say OK"}]}],"generationConfig":{"maxOutputTokens":64}}' 2>/dev/null || echo "000")
        if [ "$code" = "200" ] && grep -q "candidates" "$body" 2>/dev/null; then
          echo "$label: ✅ OK (HTTP $code)" >> "$TMPLOG"
        else
          # also valid if we get any candidates even on MAX_TOKENS
          if grep -q "candidates" "$body" 2>/dev/null; then
            echo "$label: ✅ OK (HTTP $code, MAX_TOKENS)" >> "$TMPLOG"
          else
            echo "$label: ❌ FAIL (HTTP $code)" >> "$TMPLOG"
            # log first line of body for debug
            head -c 120 "$body" 2>/dev/null | tr -d '\n' >> "$TMPLOG" || true
            echo "" >> "$TMPLOG"
          fi
        fi
        rm -f "$body"
      }
      {
        echo "10"; echo "# Testing gemini-3.1 pro..."
        check_one "gemini-3.1-pro-preview" "gemini-3.1 pro"
        echo "35"; echo "# Testing gemini-3.6 flash..."
        check_one "gemini-3.6-flash-medium" "gemini-3.6 flash"
        echo "60"; echo "# Testing gemini-3.7 flash..."
        check_one "gemini-3.7-flash-medium" "gemini-3.7 flash"
        echo "85"; echo "# Testing gemini-3.8 flash..."
        check_one "gemini-3.8-flash-medium" "gemini-3.8 flash"
        echo "100"
      } | zenity --progress --title="Checking all models" --text="Testing..." --percentage=0 --auto-close --width=400 2>/dev/null || true
      zenity --text-info --title="Check Result" --width=500 --height=300 --filename="$TMPLOG" 2>/dev/null || cat "$TMPLOG"
      rm -f "$TMPLOG"
      ;;
    2)
      NEWKEY=$(zenity --entry --title="Insert NVIDIA API Key" --text="Paste new nvapi- key:" --width=500 2>/dev/null)
      [ -z "$NEWKEY" ] && continue
      # validate format
      if [[ ! "$NEWKEY" =~ ^nvapi- ]]; then
        zenity --error --text="Key must start with nvapi-" --width=300 2>/dev/null
        continue
      fi
      bash "$(dirname "$0")/switch-model.sh" key "$NEWKEY" >/tmp/switch_key.log 2>&1 || true
      if grep -q "key updated" /tmp/switch_key.log 2>/dev/null; then
        zenity --info --text="API key updated in:\n$ENV\n\nProxy restarted." --width=400 2>/dev/null
      else
        zenity --error --text="Failed to update key. Check $ENV" --width=400 2>/dev/null
      fi
      ;;
    3)
      GROUP_CHOICE=$(zenity --list --title="Model Change — Choose Group" --text="Which Gemini group to change? (low/mid/high will all use same model)" \
        --column="Group" --column="Applies to" \
        "gemini 3.8 flash" "gemini-3.8-flash, -high, -medium, -low (4 aliases)" \
        "gemini 3.7 flash" "gemini-3.7-flash-high, -medium, -low (3 aliases)" \
        "gemini 3.6 flash" "gemini-3.6-flash-high, -medium, -low (3 aliases)" \
        "gemini 3.1 pro" "gemini-3.1-pro*, claude*, gpt-oss (14 aliases, low/mid/high/pro)" \
        --width=650 --height=300 2>/dev/null)
      [ -z "$GROUP_CHOICE" ] && continue
      # map display name to switch-model.sh group arg
      case "$GROUP_CHOICE" in
        "gemini 3.8 flash") G="3.8" ;;
        "gemini 3.7 flash") G="3.7" ;;
        "gemini 3.6 flash") G="3.6" ;;
        "gemini 3.1 pro") G="pro" ;;
        *) continue ;;
      esac
      MODEL_CHOICE=$(zenity --list --title="Choose free NVIDIA LLM for $GROUP_CHOICE" --text="All low/mid/high of this group will use the same model. Fallback on quota (429) goes to next free model." \
        --column="Model ID" --column="Notes" "${FREE_MODELS[@]}" --width=800 --height=400 2>/dev/null)
      [ -z "$MODEL_CHOICE" ] && continue
      # confirm
      if ! zenity --question --title="Confirm" --text="Change $GROUP_CHOICE (all low/mid/high) →\n$MODEL_CHOICE ?" --width=450 2>/dev/null; then continue; fi
      LOG=$(mktemp)
      bash "$(dirname "$0")/switch-model.sh" "$G" "$MODEL_CHOICE" > "$LOG" 2>&1 || true
      zenity --text-info --title="Updating $GROUP_CHOICE" --width=600 --height=200 --filename="$LOG" 2>/dev/null || cat "$LOG"
      rm -f "$LOG"
      # show new mapping
      bash "$(dirname "$0")/switch-model.sh" list | zenity --text-info --title="New Mapping" --width=650 --height=400 2>/dev/null || true
      ;;
  esac
done
