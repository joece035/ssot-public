---
description: "Use when creating or editing any bash script (*.sh) in SSOT. Covers color API, CRLF safety, and verification."
applyTo: "**/*.sh"
---
# SSOT Bash Standards

- **Colors:** use `c` / `cn` / `color` / `rc` / `rc1` / `rc2` / `ctab` / `hline` from `core/01-colors.sh` (source it; provide `cn`/`c` fallback if standalone). NEVER emit raw ANSI (`\033[`, `\e[38;5`) outside `01-colors.sh`. No `$RED`/`$NC` variables.
- **Preamble:** `set -uo pipefail` (avoid `set -e` unless the script handles it). Mirror `JOE_ENV` path setup from `joe.sh`/`ssh_audit.sh` if the script runs standalone — never `source joe.sh` fully (triggers sshd/agent side-effects).
- **CRLF:** repo is LF. Never write `\r`. Strip `\r` from `powershell.exe`/`clip.exe` output with `tr -d '\r'`. Init output to stderr only (p10k-safe).
- **Verify after every edit:** `bash -n <file>` must pass. `grep -cE '\\033\[|\\e\[' <file>` must be `0` (except `core/01-colors.sh`).
- **Ports:** `wsl=2222`, `wsl2=2223` — read from `NODE_*_PORT` / `SSH_*_PORT`, never hardcode. Keep `joe.sh`, `bootstrap/script/ssh_audit.sh`, `bootstrap/script/mesh-regen.sh` in sync.
