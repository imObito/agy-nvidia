# Copy-paste this prompt into Antigravity

Upload the local folder `~/agy-nvidia` to GitHub as a new repo. Requirements:

1. Work only inside `~/agy-nvidia`. Do NOT touch `~/.gemini`, `~/.gemini-agy-nvidia`, or `~/.config/agy-nvidia/.env` (contains secrets).
2. Verify `.gitignore` excludes `.env` and `*.log`. Run `grep -rE 'nvapi-[A-Za-z0-9_-]{20,}' ~/agy-nvidia/` — it must return nothing before any commit. If it matches a real key, abort.
3. `git init` (if not already), `git add .`, `git commit -m "feat: agy-nvidia — Antigravity CLI via NVIDIA APIs"`.
4. Create a new GitHub repo (use `gh` CLI if available: `gh repo create agy-nvidia --private --source=. --remote=origin --push`). If `gh` not authenticated, create the repo manually on github.com and then `git remote add origin <url>` + `git push -u origin main`.
5. The README.md already documents everything: how to run (`agy-nvidia`), which models are verified (deepseek-v4.1-flash stable, nemotron variants flaky, others hang/404), how to test/switch models (edit litellm.yaml `model:` line + `systemctl --user restart agy-nvidia-proxy`), proxy management, and isolation guarantees. Do not add secrets to it.
6. After push, print the GitHub URL and `git log --oneline -1`.
