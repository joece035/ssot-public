# 🚀 SSOT — Joe's Personal Command Center

**Single Source of Truth** for bash configuration across all devices.

Works on: **Termux** · **MuMu** · **WSL** · **Git Bash** · **AcodeX**

## ⚡ Quick Install (New Device)

One short command — installs deps, wires shell, unlocks vault, and registers
this device as an SSOT node member (`bootstrap/nodes/<name>.node.env`):

```bash
# Clone first, then install with your device name as $1

git clone https://github.com/joece035/ssot-public.git ~/ssot
bash ~/ssot/bootstrap/install.sh <device>
#  e.g. termux | mumu | oppo | wsl | wsl2 | acodex   (Git-Bash auto-detects)

# Or set MY_DEVICE env var (same effect):
MY_DEVICE=oppo bash ~/ssot/bootstrap/install.sh

# Fully remote one-liner (device via MY_DEVICE, defaults to auto-detect):
curl -fsSL https://raw.githubusercontent.com/joece035/ssot-public/main/bootstrap/install.sh | bash
```

The installer will:
1. Detect your environment (Termux/WSL/GitBash/MuMu) — `$1`/`MY_DEVICE` wins over auto-detect
2. Install essential packages
3. Clone the repo (if not already present)
4. Create `~/.env` from template (pins `JOE_ENV` at top, recovers `MY_DEVICE` on re-runs)
5. Unlock vault secrets (`core/.env.enc`, needs `SSOT_VAULT_PASS` non-interactively)
6. Register node identity → `bootstrap/nodes/<name>.node.env` + publish pubkey for hub collection
7. Wire your shell profile (`.bashrc` / `.zshrc`)
8. Create tool symlinks (`joe`, `syncctl`, `node-status`, `node-register`)
9. Run SSH audit
10. Verify installation

## 📁 Structure

```
ssot/
├── joe.sh                  # Main entry point (auto-detects environment)
├── bootstrap/
│   ├── install.sh          # One-shot installer for new devices
│   ├── 00-env.sh           # Environment variables (SSOT)
│   ├── nodes/              # Node identity & status
│   ├── vault/              # Encrypted secrets manager
│   └── script/             # Setup & audit scripts
├── core/
│   ├── 01-colors.sh        # V2.5 hybrid color system (256-color inline)
│   ├── aliases.sh          # Shell aliases
│   ├── 3worlds.sh          # Multi-world context switcher
│   ├── profiles.sh         # Device profile loader
│   ├── ssh-config.sh       # SSH configuration
│   ├── ssh_toolkit.sh      # SSH helper functions
│   ├── bash-manager.sh     # Bash session manager
│   └── theme.sh            # Terminal theme
├── functions/
│   ├── pkg_manager.sh      # Cross-platform package manager
│   ├── tools.sh            # Utility functions
│   ├── backup.sh           # Backup helpers
│   ├── clean.sh            # Cleanup functions
│   └── ...
├── profiles/               # Per-device shell profiles
│   ├── termux/
│   ├── wsl/
│   ├── git-bash/
│   ├── mumu/
│   ├── oppo/
│   └── acodex/
├── tools/                  # Standalone tools
│   ├── env-manager.sh
│   ├── git_tools.sh
│   └── ...
└── deprecated/             # Archived lessons & modules
```

## 🔐 Secret Management

Secrets live in `~/.env` (gitignored) and are managed via encrypted vault:

```bash
vault init      # Interactive wizard to set up secrets
vault lock      # Encrypt ~/.env → core/.env.enc
vault unlock    # Decrypt core/.env.enc → ~/.env
vault status    # Check all secrets are set
```

## 🌍 Multi-World Support

SSOT auto-detects your environment and loads the appropriate config:

| World     | Device                    | Shell  |
|-----------|---------------------------|--------|
| `TERMUX`  | Android phone             | zsh    |
| `MUMU`    | MuMu emulator             | zsh    |
| `WSL`     | Windows Subsystem Linux    | bash   |
| `GIT-BASH`| Windows Git Bash           | bash   |
| `ACODEX`  | AcodeX editor             | bash   |

## 🎨 Color System (V2.5 Hybrid)

4 layers of color API — pick what fits:

```bash
# V3 inline — zero drift, zero variables
printf '\e[38;5;196mred\e[0m\n'

# V3 helper — minimal one-liner
c 202 b 'hello'

# V2 helper — short name + 256 + style
color r b 'red bold'

# V2 random — Joe's tuned palettes
rc b 'rainbow'
rc1 'pastel'
rc2 b 'neon'
```

## 📝 License

Personal use — this is Joe's private command center.
