# AGENTS.md — SSOT (Joe's Personal Command Center)

Bash-only repo, no CI. Multi-env: `TERMUX` · `MUMU` · `OPPO` · `WSL` · `WSL2` · `GIT-BASH` · `ACODEX`.
Canonical per-file rules: [.github/instructions/bash-standards.instructions.md](.github/instructions/bash-standards.instructions.md).
Node/SSH workflows: `.github/skills/ssot-node-onboard/`, `.github/skills/mesh-repair/`.
`README.md` structure tree is stale (still shows `core/aliases.sh`, `functions/`, `tools/`) — trust the repo layout, not the README.

## Load order (never reorder)

`profiles/<env>/.bashrc` (symlinked to `~/.bashrc` by `shell_setup`) → `~/.local/bin/env` (generated from `bootstrap/templates/env`, never hand-edit) → `~/.env` → `joe.sh` → `ssot_load()` (`joe.sh:190`):
`shared/00-env.sh` → `core/ssh_toolkit.sh` → `core/3worlds.sh` → `shared/aliases.sh` → `core/profiles.sh` → `core/theme.sh` → `shared/functions/*.sh` (sorted) → `shared/personal/*.sh` (sorted) → other `shared/` subdirs (sorted, `mindepth 2`).

`JOE_ENV` pinned in `~/.env` wins — `_check_JOE_ENV` (`shared/.bash_helper:302`) respects existing value unless `--force`. Detection order (do not reorder): Termux dir + `getprop` (`MUMU` if model/brand/display matches MuMu/vphone or hardware is goldfish/ranchu, else `TERMUX`) → `apk` = `ACODEX` (must precede WSL check) → `/proc/version` microsoft + `id -un` (`joez` = `WSL2`, else `WSL`) → `MSYSTEM`/`OSTYPE` = `GIT-BASH`. Detector never emits `OPPO` — OPPO nodes only work via `JOE_ENV=OPPO` pinned in `~/.env`. `bootstrap/templates/env` force-sets `JOE_ENV=GIT-BASH` on `MINGW*|MSYS*|CYGWIN*` via `uname`.

## Verify (run these, no CI)

```bash
bash -n <file>                                   # required after every edit
grep -cE '\\033\[|\\e\[' <file>                  # must be 0 (except core/01-colors.sh)
bash bootstrap/script/mesh-regen.sh [--localhost-wsl]  # regen ~/.ssh/config mesh block only (safe)
bash bootstrap/script/ssh_audit.sh [--fix|--test]      # --fix rewrites whole ~/.ssh/config (backup .bak.TIMESTAMP); can hang on WSL
node-status [--ssh|--json|--this|<name>]         # node health (see bootstrap/nodes/node-status.sh)
bash bootstrap/install.sh <device>               # one-command fresh-device onboard (termux|mumu|oppo|wsl|wsl2|acodex)
node-register --auto [<name>]                    # (re-)register this device as node member
vault status | pubkey-fix | pubkey-sync          # secret audit | repair authorized_keys | install vault keys (corrector = canonical, fingerprint dedup)
```

## Rules

- **Colors:** only `c`/`cn`/`color`/`rc`/`rc1`/`rc2`/`ctab`/`hline` from [core/01-colors.sh](core/01-colors.sh). Never hardcode `\033[`, `\e[38;5` outside that file. No `$RED`/`$NC` vars. Standalone scripts must source it and provide `c`/`cn` fallback.
- **Standalone scripts:** preamble `set -uo pipefail`, never `set -e`. Never `source joe.sh` fully (triggers sshd/agent side-effects) — mirror the `JOE_ENV` path setup from `joe.sh`/`ssh_audit.sh` instead. Init output to stderr only (p10k-safe).
- **Ports:** `wsl=2222`, `wsl2=2223`, `termux=8022`, `mumu=8020`, `oppo=8023`, `acodex=8021`, `window=22`. Read from `NODE_*_PORT` / `SSH_*_PORT`, never hardcode — keep in sync across `joe.sh` + `bootstrap/script/ssh_audit.sh` + `bootstrap/script/mesh-regen.sh` + `*.node.env`.
- **Nodes:** schema `NODE_<NAME>_{HOST,USER,PORT,ST_PORT,ST_KEY,ST_ID,ST_URL}` in `bootstrap/nodes/*.node.env`, auto-sourced by [bootstrap/nodes/loader.sh](bootstrap/nodes/loader.sh). Primary identity = Tailscale MagicDNS hostname.
- **SSH config:** `~/.ssh/config` is generated (markers `JOE_SSOT_MESH_START/END`). Never hand-edit — regen. `window` (mirrored netns) must use `127.0.0.1:2222/2223` via `--localhost-wsl`; external nodes use MagicDNS. Background: [bootstrap/script/tailscale-separate.sh](bootstrap/script/tailscale-separate.sh).
- **CRLF:** repo is LF (`* text=auto eol=lf`). Syncthing/Windows can inject CRLF → bash breaks. `joe.sh:crlf()` self-heals; init output goes to stderr (p10k-safe). Strip `\r` from `powershell.exe`/`clip.exe` output (`tr -d '\r'`).
- **Secrets:** never commit `~/.env` (gitignored, `600`). Template = `.env.example`. Encrypted = `core/.env.enc` (+ `core/pubkeys.enc`) via `vault lock/unlock/status` ([bootstrap/vault/ssot-vault.sh](bootstrap/vault/ssot-vault.sh), `SSOT_VAULT_PASS` for non-interactive).
- **Keys:** `~/.ssh/id_ed25519_node` + `IdentitiesOnly yes` (mesh-regen writes both). Termux daemon check via `pgrep -f "sshd.*-p.*$SSH_PORT"` (not `pgrep -x sshd` — process renamed to `sshd-session`).

## Pitfalls

- WSL `Ubuntu`+`Ubuntu-22.04` share one mirrored netns: don't give both kernel TUN `tailscale0` + same UDP port (`wsl` = kernel TUN + `41643`, `wsl2` = `--tun=userspace-networking --port=41642`; `41641` collides with Windows host).
- `ssh_audit.sh --fix` rewrites the whole `~/.ssh/config`, not just the mesh block — duplicate `Host` entries break the mesh, so regen instead of appending.
