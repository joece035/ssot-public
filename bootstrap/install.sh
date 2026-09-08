#!/bin/bash
# ============================================================
# SSOT Bootstrap Installer — Single Entry Point
# ============================================================
# One-shot installer for the ssot ecosystem.
# Works on: Termux, MuMu, WSL, Git Bash.
#
# Usage:
    
#   curl -fsSL https://raw.githubusercontent.com/joece035/ssot-public/main/bootstrap/install.sh | bash
#
# Or clone first, then run:
#   git clone https://github.com/joece035/ssot-public.git ~/ssot
#   bash ~/ssot/bootstrap/install.sh
#
# Idempotent: safe to re-run. Skips completed steps.
# ============================================================

set -euo pipefail

# ── Minimal color helpers (no dependency on 01-colors.sh yet) ──
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && tput sgr0 >/dev/null 2>&1; then
    _BOLD="$(tput bold)"; _RESET="$(tput sgr0)"
    _GREEN="$(tput setaf 2)"; _YELLOW="$(tput setaf 3)"
    _RED="$(tput setaf 1)"; _CYAN="$(tput setaf 6)"
else
    _BOLD=""; _RESET=""; _GREEN=""; _YELLOW=""; _RED=""; _CYAN=""
fi

log()  { printf '%s==>%s %s\n' "${_BOLD}${_CYAN}" "${_RESET}" "$*"; }
ok()   { printf '   %s✓%s %s\n' "${_GREEN}" "${_RESET}" "$*"; }
warn() { printf '   %s!%s %s\n' "${_YELLOW}" "${_RESET}" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "${_BOLD}${_RED}" "${_RESET}" "$*" >&2; exit 1; }

# ============================================================
# STAGE 0 — Detect Environment
# ============================================================
detect_joe_env() {
    # Allow override via argument or MY_DEVICE env var
    if [[ -n "${1:-}" ]]; then
        echo "$1"
        return
    fi
    if [[ -n "${MY_DEVICE:-}" ]]; then
        echo "$MY_DEVICE"
        return
    fi
    if [[ -d "/data/data/com.termux" ]]; then
        if getprop ro.product.model 2>/dev/null | grep -qiE '(MuMu|vphone)'; then
            echo "MUMU"
        else
            echo "TERMUX"
        fi
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        echo "WSL"
    elif [[ -n "${MSYSTEM:-}" ]] || [[ "${OSTYPE:-}" == "msys" ]]; then
        echo "GIT-BASH"
    elif command -v apk 2>/dev/null; then
        echo "ACODEX"
    else
        echo "${1:-${MY_DEVICE:-$JOE_ENV}}"
    fi
}

log "Stage 0: Detecting environment"
JOE_ENV="$(detect_joe_env "${1:-}")"
export JOE_ENV
ok "Environment: $JOE_ENV"

# ============================================================
# ============================================================
# STAGE 1 — Install Essential Packages (All Environments)
# ============================================================
# git must already be available (user installs it manually before clone).
# This stage uses pkg_manager.sh to install remaining deps universally.
# Supported: TERMUX/MUMU (pkg), WSL/LINUX (apt), ACODEX (apk), GIT-BASH (pacman/winget)

log "Stage 1: Installing essential packages"

# Source pkg_manager if available (repo may already be cloned)
_PKG_MGR="$HOME/ssot/functions/pkg_manager.sh"
if [[ -f "$_PKG_MGR" ]]; then
    # shellcheck source=/dev/null
    source "$_PKG_MGR"
    _HAVE_PKGMGR=true
else
    _HAVE_PKGMGR=false
    warn "pkg_manager.sh not found yet — using native fallback for this run"
fi

# Helper: install one package via pkg_manager or native fallback
_install_pkg() {
    local pkg="$1"
    local bin="${2:-$1}"
    local overrides="${3:-}"

    if command -v "$bin" >/dev/null 2>&1; then
        ok "  already installed: $bin"
        return 0
    fi

    if [[ "$_HAVE_PKGMGR" == "true" ]]; then
        pkg_manager "$pkg" "$bin" "$overrides" 2>&1 | sed 's/^/  /'
    else
        # Native fallback — runs only on first boot before repo is cloned
        case "$JOE_ENV" in
            TERMUX|MUMU)
                local t_pkg="$pkg"
                [[ "$pkg" == "openssl" ]] && t_pkg="openssl-tool"
                pkg install -y "$t_pkg" 2>/dev/null || warn "  pkg install $pkg failed"
                ;;
            WSL|LINUX)
                sudo apt-get install -y "$pkg" 2>/dev/null || warn "  apt install $pkg failed"
                ;;
            ACODEX)
                apk add "$pkg" 2>/dev/null || warn "  apk add $pkg failed"
                ;;
            *)
                warn "  No package manager for $JOE_ENV — install $pkg manually"
                ;;
        esac
    fi
}

# ── Update package index (once, best-effort) ──
case "$JOE_ENV" in
    TERMUX|MUMU)
        pkg update -y 2>/dev/null || warn "pkg update failed (non-fatal)"
        ;;
    WSL|LINUX)
        sudo apt-get update -qq 2>/dev/null || warn "apt update failed (non-fatal)"
        ;;
    ACODEX)
        apk update 2>/dev/null || warn "apk update failed (non-fatal)"
        ;;
esac

# ── Install essential packages ──
# git: expected to exist already (user installs before clone)
# openssh, openssl, curl, jq, rsync: needed for vault/ssh/sync stages
_install_pkg openssh  ssh
_install_pkg openssl  openssl  "apk=openssl"
_install_pkg curl     curl
_install_pkg jq       jq
_install_pkg rsync    rsync

ok "Stage 1: Essential packages ready"

# ── Termux-specific: Storage access ──
if [[ "$JOE_ENV" == "TERMUX" || "$JOE_ENV" == "MUMU" ]]; then
    if [[ ! -d "$HOME/storage" ]]; then
        log "  Requesting storage access..."
        termux-setup-storage </dev/null || warn "termux-setup-storage failed (approve manually)"
    else
        ok "  Storage already accessible"
    fi
fi

# STAGE 2 — Locate or Clone Repository
# ============================================================
SSOT="${SSOT:-$HOME/ssot}"

if [[ -f "$SSOT/joe.sh" ]]; then
    ok "SSOT repo found at $SSOT"
else
    log "Stage 2: Cloning SSOT repository"
    if [[ -d "$SSOT/.git" ]]; then
        warn "Partial repo at $SSOT (no joe.sh) — removing and re-cloning"
        rm -rf "$SSOT"
    fi

    REPO_URL="https://github.com/joece035/ssot-public.git"
    if command -v git >/dev/null 2>&1; then
        git clone --depth=1 "$REPO_URL" "$SSOT" || die "git clone failed"
    else
        warn "git not found — attempting HTTPS download"
        command -v curl >/dev/null 2>&1 || die "Neither git nor curl available"
        TMPDIR="$(mktemp -d)"
        curl -fsSL "${REPO_URL%.git}/archive/refs/heads/main.tar.gz" \
            | tar -xz -C "$TMPDIR" || die "Download failed"
        mv "$TMPDIR/ssot-main" "$SSOT"
        rm -rf "$TMPDIR"
    fi
    ok "Repository cloned to $SSOT"
fi

# Ensure we're working from the canonical SSOT path
cd "$SSOT"

# ============================================================
# STAGE 3 — Create ~/.env (idempotent)
# ============================================================
log "Stage 3: Configuring ~/.env"
ENV_FILE="$HOME/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    if [[ -f "$SSOT/.env.example" ]]; then
        cp "$SSOT/.env.example" "$ENV_FILE"
        ok "Created ~/.env from .env.example"
    else
        touch "$ENV_FILE"
        ok "Created empty ~/.env"
    fi
else
    ok "~/.env already exists"
fi

# Pin JOE_ENV at the VERY TOP of ~/.env so early case statements get it
if grep -q "^export JOE_ENV=" "$ENV_FILE" 2>/dev/null; then
    sed -i "/^export JOE_ENV=/d" "$ENV_FILE"
fi
# Insert at line 1
printf 'export JOE_ENV="%s"\n%s' "$JOE_ENV" "$(cat "$ENV_FILE" 2>/dev/null)" > "$ENV_FILE"
ok "~/.env: JOE_ENV=$JOE_ENV (pinned at top)"

# Symlink $SSOT/.env → ~/.env (so joe.sh / 00-env.sh can find it)
if [[ ! -L "$SSOT/.env" ]]; then
    ln -sf "$ENV_FILE" "$SSOT/.env"
    ok "Symlinked $SSOT/.env → ~/.env"
fi

chmod 600 "$ENV_FILE" 2>/dev/null || true

# ── 2b. Vault Detection & Auto-Unlock ──
VAULT_FILE="$SSOT/core/.env.enc"
VAULT_SCRIPT="$SSOT/bootstrap/ssot-vault.sh"

# Check if secrets are already populated
_secrets_populated=false
if [[ -f "$ENV_FILE" ]]; then
    if grep -qE '^[^#]*=[^"'"'"'\s]+[^\s]' "$ENV_FILE" 2>/dev/null; then
        _secrets_populated=true
    fi
fi

if [[ -f "$VAULT_FILE" ]] && [[ "$_secrets_populated" == "false" ]]; then
    log "Stage 3b: Vault detected — attempting auto-unlock"
    if [[ -f "$VAULT_SCRIPT" ]] && command -v openssl >/dev/null 2>&1; then
        if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
            # Non-interactive: passphrase provided via env var
            if "$VAULT_SCRIPT" unlock 2>/dev/null; then
                ok "Vault unlocked (via SSOT_VAULT_PASS)"
            else
                warn "Vault unlock failed — run 'vault unlock' manually"
            fi
        else
            # Interactive: prompt user
            echo "  📦 Vault found: $VAULT_FILE"
            read -r -t 20 -p "   Unlock secrets now? [Y/n] (default: Y): " _vault_choice < /dev/tty || _vault_choice="Y"
            if [[ "${_vault_choice:-Y}" =~ ^[Yy]?$ ]]; then
                if "$VAULT_SCRIPT" unlock 2>/dev/null; then
                    ok "Vault unlocked"
                else
                    warn "Vault unlock failed — run 'vault unlock' later"
                fi
            else
                echo "  💡 Run 'vault unlock' when ready"
            fi
        fi
    else
        warn "Cannot auto-unlock (openssl missing or vault script not found)"
        echo "  💡 Install openssl, then run: vault unlock"
    fi
elif [[ -f "$VAULT_FILE" ]] && [[ "$_secrets_populated" == "true" ]]; then
    ok "Secrets already populated — vault unlock not needed"
else
    ok "No vault found — using template .env"
    echo "  💡 Edit ~/.env or use 'vault lock' to encrypt"
fi

# ── 2c. Node Identity Registration ──
NODE_SCRIPT="$SSOT/bootstrap/nodes/node-register.sh"
if [[ -f "$NODE_SCRIPT" ]]; then
    log "Stage 3c: Registering node identity"
    if [[ -n "${MY_DEVICE:-}" ]]; then
        ok "MY_DEVICE already set: $MY_DEVICE"
    else
        # Auto-detect and register node (non-interactive)
        if JOE_ENV="$JOE_ENV" SSOT="$SSOT" bash "$NODE_SCRIPT" --auto 2>/dev/null; then
            ok "Node registered"
        else
            warn "Node registration skipped — run 'node-register' later"
        fi
    fi
else
    # Fallback: just set MY_DEVICE in ~/.env
    if [[ -z "${MY_DEVICE:-}" ]]; then
        _def_device="$(echo "$JOE_ENV" | tr '[:upper:]' '[:lower:]')"
        case "$JOE_ENV" in
            GIT-BASH) _def_device="window" ;;
        esac
        if grep -q "^export MY_DEVICE=" "$ENV_FILE" 2>/dev/null; then
            sed -i "s/^export MY_DEVICE=.*/export MY_DEVICE=\"$_def_device\"/" "$ENV_FILE"
        else
            printf '\nexport MY_DEVICE="%s"\n' "$_def_device" >> "$ENV_FILE"
        fi
        ok "MY_DEVICE=$_def_device (fallback)"
    fi
fi

# ============================================================

# \u2500\u2500 2d. SSH Pubkey Vault Unlock \u2500\u2500
PUBKEY_SCRIPT="$SSOT/bootstrap/nodes/pubkey-manager.sh"
PUBKEY_VAULT="$SSOT/core/pubkeys.enc"

if [[ -f "$PUBKEY_VAULT" ]] && [[ -f "$PUBKEY_SCRIPT" ]]; then
    log "Stage 3d: Installing SSH pubkeys from vault (core/pubkeys.enc)"
    if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
        # Non-interactive: passphrase provided via env var
        if bash "$PUBKEY_SCRIPT" unlock 2>/dev/null; then
            ok "Pubkeys installed \u2192 ~/.ssh/authorized_keys"
        else
            warn "Pubkey unlock failed \u2014 run 'vault unlock_pubkey' manually"
        fi
    else
        # Interactive: prompt user
        read -r -t 15 -p "   \ud83d\udd11 Install SSH pubkeys from vault? [Y/n] (default: Y): " _pk_choice < /dev/tty || _pk_choice="Y"
        if [[ "${_pk_choice:-Y}" =~ ^[Yy]?$ ]]; then
            if bash "$PUBKEY_SCRIPT" unlock 2>/dev/null; then
                ok "Pubkeys installed \u2192 ~/.ssh/authorized_keys"
            else
                warn "Pubkey unlock failed \u2014 run 'vault unlock_pubkey' manually"
            fi
        else
            echo "  \ud83d\udca1 Run 'vault unlock_pubkey' when ready"
        fi
    fi
else
    ok "No pubkey vault found \u2014 skipping (core/pubkeys.enc)"
fi

# STAGE 4 — Wire Shell Profile
# ============================================================
log "Stage 4: Wiring shell profile"

# Determine which profile templates to symlink
case "$JOE_ENV" in
    TERMUX)
        PROFILE_DIR="$SSOT/profiles/termux"
        SHELL_RC="$HOME/.zshrc"    # Termux uses zsh
        BASH_RC="$HOME/.bashrc"
        ;;
    MUMU)
        PROFILE_DIR="$SSOT/profiles/mumu"
        SHELL_RC="$HOME/.zshrc"
        BASH_RC="$HOME/.bashrc"
        ;;
    WSL)
        PROFILE_DIR="$SSOT/profiles/wsl"
        SHELL_RC="$HOME/.bashrc"   # WSL default is bash
        BASH_RC="$HOME/.bashrc"
        ;;
    GIT-BASH)
        PROFILE_DIR="$SSOT/profiles/git-bash"
        SHELL_RC="$HOME/.bashrc"
        BASH_RC="$HOME/.bashrc"
        ;;
    *)
        PROFILE_DIR="$SSOT/profiles/wsl"
        SHELL_RC="$HOME/.bashrc"
        BASH_RC="$HOME/.bashrc"
        ;;
esac

_link_profile() {
    local target="$1"
    local src="$2"
    [[ ! -f "$src" ]] && return 0
    if [[ -L "$target" ]]; then
        local curr
        curr="$(readlink "$target")"
        if [[ "$curr" == "$src" ]]; then
            ok "$target already linked to correct profile"
            return 0
        else
            ln -sf "$src" "$target"
            ok "$target re-linked → $src"
            return 0
        fi
    elif [[ -f "$target" ]]; then
        local bak="${target}.bak.$(date +%s)"
        cp "$target" "$bak"
        warn "Backed up existing $target → $bak"
    fi
    ln -sf "$src" "$target"
    ok "$target → $src (symlinked)"
}

# Symlink primary shell profile (e.g. .zshrc)
_link_profile "$SHELL_RC" "$PROFILE_DIR/$(basename "$SHELL_RC")"

# Also symlink .bashrc if different from primary (e.g. on Android/Termux where both bash and zsh exist)
if [[ "$SHELL_RC" != "$BASH_RC" ]]; then
    _link_profile "$BASH_RC" "$PROFILE_DIR/.bashrc"
fi

# ============================================================
# STAGE 5 — Create Tool Symlinks
# ============================================================
log "Stage 5: Creating tool symlinks"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# joe command
if [[ ! -L "$BIN_DIR/joe" ]]; then
    ln -sf "$SSOT/joe.sh" "$BIN_DIR/joe"
    chmod +x "$SSOT/joe.sh"
    ok "Created: $BIN_DIR/joe → joe.sh"
else
    ok "$BIN_DIR/joe already linked"
fi

# syncctl command
if [[ ! -L "$BIN_DIR/syncctl" ]] && [[ -f "$SSOT/tools/syncctl/syncctl" ]]; then
    ln -sf "$SSOT/tools/syncctl/syncctl" "$BIN_DIR/syncctl"
    chmod +x "$SSOT/tools/syncctl/syncctl"
    ok "Created: $BIN_DIR/syncctl → tools/syncctl/syncctl"
fi

# node-status command
if [[ ! -L "$BIN_DIR/node-status" ]] && [[ -f "$SSOT/tools/node-status.sh" ]]; then
    ln -sf "$SSOT/tools/node-status.sh" "$BIN_DIR/node-status"
    chmod +x "$SSOT/tools/node-status.sh"
    ok "Created: $BIN_DIR/node-status → tools/node-status.sh"
fi

# STAGE 6 — SSH Audit & Self-Healing
# ============================================================
if [[ -f "$SSOT/bootstrap/script/ssh_audit.sh" ]]; then
    log "Stage 6: SSH audit"
    bash "$SSOT/bootstrap/script/ssh_audit.sh" --fix 2>&1 | while IFS= read -r _line; do
        printf '  %s\n' "$_line"
    done
    ok "SSH audit complete"
else
    warn "ssh_audit.sh not found — skipping SSH setup"
fi

# ============================================================
# STAGE 7 — Verify Installation
# ============================================================
log "Stage 7: Verification"

_errors=0

# Check joe.sh exists and is valid
if [[ -f "$SSOT/joe.sh" ]] && bash -n "$SSOT/joe.sh" 2>/dev/null; then
    ok "joe.sh — exists and syntax valid"
else
    warn "joe.sh — missing or syntax error"
    _errors=$((_errors + 1))
fi

# Check .env has JOE_ENV
if grep -q "^export JOE_ENV=" "$HOME/.env" 2>/dev/null; then
    ok "~/.env — JOE_ENV configured"
else
    warn "~/.env — JOE_ENV not set"
    _errors=$((_errors + 1))
fi

# Check shell profile sources joe.sh
if [[ -L "$SHELL_RC" ]]; then
    _target="$(readlink "$SHELL_RC")"
    if grep -q "joe.sh" "$_target" 2>/dev/null; then
        ok "$SHELL_RC — sources joe.sh"
    else
        warn "$SHELL_RC — profile may not source joe.sh"
    fi
else
    if grep -q "joe.sh" "$SHELL_RC" 2>/dev/null; then
        ok "$SHELL_RC — sources joe.sh"
    else
        warn "$SHELL_RC — does not source joe.sh (may need manual fix)"
    fi
fi

# Check key modules exist
for _mod in "bootstrap/00-env.sh" "core/01-colors.sh" "core/aliases.sh" "core/3worlds.sh"; do
    if [[ -f "$SSOT/$_mod" ]]; then
        ok "$_mod — found"
    else
        warn "$_mod — missing"
        _errors=$((_errors + 1))
    fi
done

# Syntax-check all .sh files in core/ (quick scan)
if command -v bash >/dev/null 2>&1; then
    _syntax_fails=0
    for _f in "$SSOT"/core/*.sh "$SSOT"/functions/*.sh; do
        [[ -f "$_f" ]] || continue
        if ! bash -n "$_f" 2>/dev/null; then
            _syntax_fails=$((_syntax_fails + 1))
        fi
    done
    if [[ $_syntax_fails -eq 0 ]]; then
        ok "Syntax check — all core/*.sh and functions/*.sh pass"
    else
        warn "Syntax check — $_syntax_fails file(s) have errors"
    fi
fi

# ============================================================
# DONE — Summary
# ============================================================
printf '\n'
if [[ $_errors -eq 0 ]]; then
    printf '%s════════════════════════════════════════════════════%s\n' "${_BOLD}${_GREEN}" "${_RESET}"
    printf '%s  ✅ SSOT bootstrap complete!%s\n' "${_BOLD}${_GREEN}" "${_RESET}"
    printf '%s════════════════════════════════════════════════════%s\n' "${_BOLD}${_GREEN}" "${_RESET}"
else
    printf '%s════════════════════════════════════════════════════%s\n' "${_BOLD}${_YELLOW}" "${_RESET}"
    printf '%s  ⚠️  SSOT bootstrap complete with %d warning(s)%s\n' "${_BOLD}${_YELLOW}" "$_errors" "${_RESET}"
    printf '%s════════════════════════════════════════════════════%s\n' "${_BOLD}${_YELLOW}" "${_RESET}"
fi

printf '\n'
printf 'Next steps:\n'
printf '  1. %sRestart your shell:%s\n' "${_BOLD}" "${_RESET}"
if [[ "$JOE_ENV" == "TERMUX" ]]; then
    printf '       %sexec zsh%s\n' "${_BOLD}" "${_RESET}"
else
    printf '       %ssource %s%s\n' "${_BOLD}" "$SHELL_RC" "${_RESET}"
fi
printf '  2. %snode-status%s — verify all registered nodes and cluster health\n' "${_BOLD}" "${_RESET}"
printf '  3. (Optional) %sp10k configure%s — customize your prompt\n' "${_BOLD}" "${_RESET}"
printf '  4. %spf mom%s — seed AI API keys\n' "${_BOLD}" "${_RESET}"
printf '\n'
