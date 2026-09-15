# AGENTS.md — SSOT (Joe's Personal Command Center)

Bash-only SSOT repo. Multi-env: `TERMUX` · `MUMU` · `OPPO` · `WSL` · `WSL2` · `GIT-BASH` · `ACODEX`.
Details: [README.md](README.md), [.env.example](.env.example)

## Load order (never reorder)

`profiles/<env>/.bashrc` → `~/.local/bin/env` (generated from `bootstrap/templates/env`, never hand-edit) → `~/.env` → `joe.sh` → `ssot_load()`:
`shared/00-env.sh` → `core/ssh-config.sh` → `core/3worlds.sh` → `shared/aliases.sh` → `core/profiles.sh` → `core/theme.sh` → `shared/functions/*.sh` → `shared/personal/*.sh`

`JOE_ENV` = UPPER canonical, pinned at line 1 of `~/.env`. `MY_DEVICE` = lowercase. Detection order: Git-Bash `uname` guard → Termux dir+`getprop` → `apk` (ACODEX **before** WSL) → `/proc/version`+`id -un` (WSL vs WSL2) → `MSYSTEM`/`OSTYPE`. See [joe.sh](joe.sh).

## Verify (run these, no CI)

```bash
bash -n <file>                                   # syntax check — required after every edit
bash bootstrap/script/mesh-regen.sh [--localhost-wsl]  # regen ~/.ssh/config mesh block only (safe)
bash bootstrap/script/ssh_audit.sh [--fix|--test]      # full audit; --fix touches perms/keys/agent (can hang on WSL)
node-status [--ssh|--json|--this|<name>]         # node health (see bootstrap/nodes/node-status.sh)
```

## Rules

- **Colors:** only `c`/`cn`/`color`/`rc`/`rc1`/`rc2`/`ctab`/`hline` from [core/01-colors.sh](core/01-colors.sh). NEVER hardcode `\033[`, `\e[38;5`, `echo -e "\e[..."` outside that file. No `$RED`/`$NC` vars.
- **Nodes:** schema `NODE_<NAME>_{HOST,USER,PORT,ST_PORT,ST_KEY,ST_ID,ST_URL}` in `bootstrap/nodes/*.node.env`, auto-loaded by [bootstrap/nodes/loader.sh](bootstrap/nodes/loader.sh). Primary identity = Tailscale MagicDNS hostname. Ports: `wsl=2222`, `wsl2=2223`, `termux=8022`, `mumu=8020`, `oppo=8023`, `acodex=8021`, `window=22` — keep in sync across `joe.sh` + `bootstrap/script/ssh_audit.sh` + `bootstrap/script/mesh-regen.sh` + `*.node.env`.
- **SSH config:** `~/.ssh/config` is generated (markers `JOE_SSOT_MESH_START/END`). Never hand-edit — regen. `window` (mirrored netns) must use `127.0.0.1:2222/2223` via `--localhost-wsl`; external nodes use MagicDNS. Background: [bootstrap/script/tailscale-separate.sh](bootstrap/script/tailscale-separate.sh).
- **CRLF:** repo is LF (`* text=auto eol=lf`). Syncthing/Windows can inject CRLF → bash breaks. `joe.sh:crlf()` self-heals; init output goes to stderr (p10k-safe). Strip `\r` from `powershell.exe`/`clip.exe` output.
- **Secrets:** never commit `~/.env` (gitignored, `600`). Template = `.env.example`. Encrypted = `core/.env.enc` + `core/pubkeys.enc` via `vault lock/unlock/status` ([bootstrap/vault/ssot-vault.sh](bootstrap/vault/ssot-vault.sh), `SSOT_VAULT_PASS` for non-interactive).
- **Keys:** `id_ed25519_node` + `IdentitiesOnly yes`. Termux daemon check via `pgrep -f "sshd.*-p.*$SSH_PORT"` (not `pgrep -x sshd`).

## Pitfalls

- WSL `Ubuntu`+`Ubuntu-22.04` share one mirrored netns: don't give both kernel TUN `tailscale0` + same UDP port (`wsl2` uses `--tun=userspace-networking --port=41642`, `wsl` uses `41643` — `41641` collides with Windows host).
- `ssh_audit.sh --fix` overwrites whole `~/.ssh/config` (backup `.bak.TIMESTAMP`); duplicate `Host` entries break mesh — regen instead.
- `WINDOWS`/`window` value in `JOE_ENV`/`MY_DEVICE` poisons profile selection — always normalize.
