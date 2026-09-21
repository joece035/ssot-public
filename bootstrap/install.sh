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
# Specify device (important for Termux — auto-detect returns "TERMUX" for all):
#   bash ~/ssot/bootstrap/install.sh <device>
#   bash ~/ssot/bootstrap/install.sh termux    # physical Android phone
#   bash ~/ssot/bootstrap/install.sh mumu      # MuMu emulator
#   bash ~/ssot/bootstrap/install.sh oppo      # Oppo phone
#
# Or set MY_DEVICE env var:
#   MY_DEVICE=oppo bash ~/ssot/bootstrap/install.sh
#
# Idempotent: safe to re-run. Skips completed steps.
# ============================================================

set -euo pipefail

#[[ -f "$HOME/ssot/joe.sh" ]] && source "$HOME/ssot/joe.sh"

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
# STAGE Pre-0 — Backup & Clean Previous Installation
# ============================================================
# Backs up all files that will be modified into $BACKUP_DIR/installationbk/
# then removes them so install starts from a clean state.
# ============================================================
STAGE_TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$HOME/.ssot-backups/installationbk/$STAGE_TS"
mkdir -p "$BACKUP_DIR"

log "Stage Pre-0: Backing up previous installation → $BACKUP_DIR"

# ── Backup files (copy, don't move — keep originals as safety net) ──
_backup_file() {
    local src="$1"
    if [[ -L "$src" ]]; then
        # Symlink: record target
        local tgt
        tgt="$(readlink "$src" 2>/dev/null)"
        echo "symlink → $tgt" > "$BACKUP_DIR/$(basename "$src").meta"
        ok "  Backed up symlink: $(basename "$src") → $tgt"
    elif [[ -f "$src" ]]; then
        cp "$src" "$BACKUP_DIR/$(basename "$src")"
        ok "  Backed up: $(basename "$src")"
    fi
}

_backup_file "$HOME/.bashrc"
_backup_file "$HOME/.zshrc"
_backup_file "$HOME/.bash_aliases"
_backup_file "$HOME/.local/bin/env"
_backup_file "$HOME/.ssh/config"
_backup_file "$HOME/.env"

# ── Backup and record all symlinks in ~/.local/bin/ ──
if [[ -d "$HOME/.local/bin" ]]; then
    _symlink_count=0
    while IFS= read -r -d '' link; do
        _tgt="$(readlink "$link" 2>/dev/null)"
        echo "symlink → $_tgt" > "$BACKUP_DIR/bin_$(basename "$link").meta"
        _symlink_count=$((_symlink_count + 1))
    done < <(find "$HOME/.local/bin" -maxdepth 1 -type l -print0 2>/dev/null)
    [[ $_symlink_count -gt 0 ]] && ok "  Backed up $_symlink_count symlink(s) from ~/.local/bin/"
fi

# ── Clean: Remove all previous installation artifacts ──
log "Stage Pre-0: Cleaning previous installation state"

# Remove ~/.local/bin/ contents (env, joe, syncctl, etc.)
if [[ -d "$HOME/.local/bin" ]]; then
    rm -f "$HOME/.local/bin/env"
    rm -f "$HOME/.local/bin/joe"
    rm -f "$HOME/.local/bin/syncctl"
    rm -f "$HOME/.local/bin/node-status"
    ok "  Cleaned ~/.local/bin/ (env, joe, syncctl, node-status)"
fi

# Remove shell profile symlinks (will be re-created in Stage 4)
for _rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -L "$_rc" ]]; then
        rm -f "$_rc"
        ok "  Removed symlink: $(basename "$_rc")"
    fi
done

# Remove .bash_aliases symlink if it exists
if [[ -L "$HOME/.bash_aliases" ]]; then
    rm -f "$HOME/.bash_aliases"
    ok "  Removed symlink: .bash_aliases"
fi

# Clean broken symlinks in ~/
while IFS= read -r -d '' link; do
    if [[ ! -e "$link" ]]; then
        rm -f "$link"
    fi
done < <(find "$HOME" -maxdepth 1 -type l -print0 2>/dev/null)

unset SSOT 2>/dev/null || true
ok "  Cleaned environment state"
ok "Stage Pre-0: Previous installation backed up & cleaned"

# ============================================================
# STAGE 0 — Detect Environment
# ============================================================
# Priority: argument > MY_DEVICE env > auto-detect
# Auto-detect limitations:
#   - Termux on ALL devices returns "TERMUX" (can't distinguish phone/emulator)
#   - Use argument or MY_DEVICE to specify: termux, mumu, oppo, etc.
# ============================================================
detect_joe_env() {
    # 1. Explicit argument (highest priority)
    if [[ -n "${1:-}" ]]; then
        echo "$1"
        return
    fi
    # 2. MY_DEVICE env var (set in ~/.env or before running)
    if [[ -n "${MY_DEVICE:-}" ]]; then
        echo "$MY_DEVICE"
        return
    fi
    # 3. Auto-detect (limited on Termux)
    if [[ -d "/data/data/com.termux" ]]; then
        # Check multiple properties for MuMu/emulator detection
        _model="$(getprop ro.product.model 2>/dev/null)"
        _brand="$(getprop ro.product.brand 2>/dev/null)"
        _hardware="$(getprop ro.hardware 2>/dev/null)"
        _display="$(getprop ro.build.display.id 2>/dev/null)"

        # MuMu indicators: model contains MuMu/vphone, or brand is MuMu
        if echo "$_model $_brand $_display" | grep -qiE '(MuMu|vphone)'; then
            echo "MUMU"
        # Standard emulator indicators: goldfish (QEMU), ranchu (Android Emulator)
        elif echo "$_hardware" | grep -qiE '(goldfish|ranchu)'; then
            echo "MUMU"  # Treat generic emulator as MuMu (user can override with arg)
        else
            echo "TERMUX"  # Physical device or unknown emulator
        fi
    # ACODEX must be checked BEFORE WSL — ACODEX runs on WSL filesystem so
    # /proc/version contains "microsoft", causing false WSL detection if order is wrong.
    # apk is the definitive ACODEX identifier (Alpine package manager).
    elif command -v apk >/dev/null 2>&1; then
        echo "ACODEX"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        if [[ $(id -un) == "joez" ]]; then
            echo "WSL2"
        else    
            echo "WSL"
        fi    
    elif [[ -n "${MSYSTEM:-}" ]] || [[ "${OSTYPE:-}" == "msys" ]]; then
        echo "GIT-BASH"
    elif command -v apt >/dev/null 2>&1; then
        echo "KALI"
    else
        echo "UNKNOWN"
    fi
}

log "Stage 0: Detecting environment"
JOE_ENV="$(detect_joe_env "${1:-}" | tr '[:lower:]' '[:upper:]')"
export JOE_ENV

# Also set MY_DEVICE if provided via argument (normalize to lowercase)
if [[ -n "${1:-}" ]]; then
    MY_DEVICE="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    export MY_DEVICE
fi

ok "Environment: $JOE_ENV (MY_DEVICE=${MY_DEVICE:-auto})"

# ============================================================
# ============================================================
# STAGE 1 — Install Essential Packages (All Environments)
# ============================================================
# git must already be available (user installs it manually before clone).
# This stage uses pkg_manager.sh to install remaining deps universally.
# Supported: TERMUX/MUMU (pkg), WSL/LINUX (apt), ACODEX (apk), GIT-BASH (pacman/winget)

log "Stage 1: Installing essential packages"

# ── Ensure Git for Windows paths are in PATH ──
# Git Bash may have rsync, ssh, etc. in /usr/bin or /mingw64/bin
# but these aren't always in PATH when running from external shells
if [[ "$JOE_ENV" == "GIT-BASH" ]]; then
    for _gfw_bin in "/usr/bin" "/mingw64/bin" "/mingw32/bin"; do
        [[ -d "$_gfw_bin" ]] && case ":${PATH}:" in
            *:"$_gfw_bin":*) ;;
            *) export PATH="$_gfw_bin:$PATH" ;;
        esac
    done
fi

# Source pkg_manager if available (repo may already be cloned)
# Canonical path is shared/functions/ (root functions/ is legacy and does not exist)
_PKG_MGR=""
for _cand_dir in "$HOME/ssot" "$HOME/bashscripts"; do
    if [[ -f "$_cand_dir/shared/functions/pkg_manager.sh" ]]; then
        _PKG_MGR="$_cand_dir/shared/functions/pkg_manager.sh"
        break
    fi
done
# Legacy fallback (pre-shared/ layout)
if [[ -z "$_PKG_MGR" && -f "$HOME/ssot/functions/pkg_manager.sh" ]]; then
    _PKG_MGR="$HOME/ssot/functions/pkg_manager.sh"
fi
if [[ -n "$_PKG_MGR" ]]; then
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
            TERMUX|MUMU|OPPO)
                local t_pkg="$pkg"
                [[ "$pkg" == "openssl" ]] && t_pkg="openssl-tool"
                pkg install -y "$t_pkg" 2>/dev/null || warn "  pkg install $pkg failed"
                ;;
            WSL|WSL2)
                sudo apt-get install -y "$pkg" 2>/dev/null || warn "  apt install $pkg failed"
                ;;
            KALI)
                sudo apt install -y "$pkg" 2>/dev/null || warn "  apt install $pkg failed"
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
    TERMUX|MUMU|OPPO)
        pkg update -y 2>/dev/null || warn "pkg update failed (non-fatal)"
        ;;
    WSL|WSL2)
        sudo apt-get update -qq 2>/dev/null || warn "apt update failed (non-fatal)"
        ;;
    ACODEX)
        apk update 2>/dev/null || warn "apk update failed (non-fatal)"
        ;;
    KALI)
        sudo apt update -qq 2>/dev/null || warn "apt update failed (non-fatal)"
        ;;
esac

# ── Install essential packages ──
# git: expected to exist already (user installs before clone)
# openssh, openssl, curl, jq, rsync: needed for vault/ssh/sync stages
_install_pkg openssh  ssh
_install_pkg openssl  openssl  "apk=openssl"
_install_pkg curl     curl
_install_pkg jq       jq      "winget=jqlang.jq"
_install_pkg make 	  make
_install_pkg gawk			gawk

# rsync: optional on Git Bash (not available via winget, skip gracefully)
if [[ "$JOE_ENV" == "GIT-BASH" ]]; then
    if command -v rsync >/dev/null 2>&1; then
        ok "  already installed: rsync"
    else
        warn "  rsync not available on Git Bash — skipping (use WSL for rsync)"
    fi
else
    _install_pkg rsync    rsync
fi

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
# Priority: $SSOT env > derive from script location ($0) > default ~/ssot
# Handles: bash (BASH_SOURCE), zsh (${(%):-%x}), plain sh ($0), curl|bash pipe
if [[ -z "${SSOT:-}" ]]; then
    # Resolve script path — zsh vs bash vs plain $0
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        _self="${(%):-%x}"          # zsh: expands to current script file
    elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        _self="${BASH_SOURCE[0]}"   # bash: reliable even when sourced
    else
        _self="$0"                  # fallback: plain sh / pipe
    fi
    _script_dir="$(cd "$(dirname "$_self")" 2>/dev/null && pwd)"
    _derived="$(cd "$_script_dir/.." 2>/dev/null && pwd)"
    if [[ -n "$_derived" && -f "$_derived/joe.sh" ]]; then
        SSOT="$_derived"
        ok "SSOT derived from script path: $SSOT"
    else
        SSOT="$HOME/ssot"
        ok "SSOT defaulting to: $SSOT"
    fi
fi
export SSOT

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
    touch "$ENV_FILE"
    ok "Created empty ~/.env"
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

# ── 2b-pre. Recover MY_DEVICE from previous ~/.env (re-runs keep identity) ──
if [[ -z "${MY_DEVICE:-}" ]]; then
    _saved_device="$(grep '^export MY_DEVICE=' "$ENV_FILE" 2>/dev/null | head -1 | sed 's/^export MY_DEVICE="//;s/"$//')"
    if [[ -n "$_saved_device" ]]; then
        MY_DEVICE="$_saved_device"
        export MY_DEVICE
        ok "MY_DEVICE recovered from ~/.env: $MY_DEVICE"
    fi
fi

# ── 2b. Vault Detection & Auto-Unlock ──
VAULT_FILE="$SSOT/core/.env.enc"
VAULT_SCRIPT="$SSOT/bootstrap/vault/ssot-vault.sh"

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
            # Non-interactive: passphrase provided via env var (safe to suppress stderr)
            if bash "$VAULT_SCRIPT" unlock 2>/dev/null; then
                ok "Vault unlocked (via SSOT_VAULT_PASS)"
            else
                warn "Vault unlock failed — run 'vault unlock' manually"
            fi
        else
            # Interactive: prompt user
            echo "  📦 Vault found: $VAULT_FILE"
            read -r -t 20 -p "   Unlock secrets now? [Y/n] (default: Y): " _vault_choice < /dev/tty || _vault_choice="Y"
            if [[ "${_vault_choice:-Y}" =~ ^[Yy]?$ ]]; then
                # Interactive: do NOT suppress stderr — password prompt writes there
                if bash "$VAULT_SCRIPT" unlock </dev/tty; then
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
# Always runs (idempotent): registers this device as an SSOT node member by
# creating bootstrap/nodes/<name>.node.env (full NODE_* schema) + pinning
# MY_DEVICE in ~/.env. This is what makes one-command onboarding work.
NODE_SCRIPT="$SSOT/bootstrap/nodes/node-register.sh"
if [[ -f "$NODE_SCRIPT" ]]; then
    log "Stage 3c: Registering node identity"
    if JOE_ENV="$JOE_ENV" SSOT="$SSOT" bash "$NODE_SCRIPT" --auto ${MY_DEVICE:+$MY_DEVICE} 2>&1 | sed 's/^/  /'; then
        ok "Node registered"
    else
        warn "Node registration failed — run 'node-register --auto' later"
    fi
    # Re-read MY_DEVICE (node-register pins it in ~/.env)
    _reg_device="$(grep '^export MY_DEVICE=' "$ENV_FILE" 2>/dev/null | head -1 | sed 's/^export MY_DEVICE="//;s/"$//')"
    if [[ -n "$_reg_device" ]]; then
        MY_DEVICE="$_reg_device"
        export MY_DEVICE
    fi
else
    # Fallback: just set MY_DEVICE in ~/.env
    if [[ -z "${MY_DEVICE:-}" ]]; then
        _def_device="$(echo "$JOE_ENV" | tr '[:upper:]' '[:lower:]')"
        case "$JOE_ENV" in
            GIT-BASH) _def_device="git-bash" ;;
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

# ── 3d. SSH Node Keypair Generation ──
log "Stage 3d: SSH node keypair"
_NODE_KEY="$HOME/.ssh/id_ed25519_node"
_NODE_PUB="$HOME/.ssh/id_ed25519_node.pub"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

if [[ ! -f "$_NODE_KEY" ]]; then
    _node_comment="${MY_DEVICE:-$(hostname)}-$(echo "$JOE_ENV" | tr '[:upper:]' '[:lower:]')"
    ssh-keygen -t ed25519 -C "$_node_comment" -f "$_NODE_KEY" -N "" -q
    ok "Generated SSH node keypair: $_NODE_KEY"
    ok "  Comment: $_node_comment"
else
    ok "SSH node keypair exists: $_NODE_KEY"
fi

# ── 3e. SSH Pubkey Vault Unlock ──
PUBKEY_SCRIPT="$SSOT/bootstrap/nodes/pubkey-manager.sh"
PUBKEY_VAULT="$SSOT/core/pubkeys.enc"

if [[ -f "$PUBKEY_VAULT" ]] && [[ -f "$PUBKEY_SCRIPT" ]]; then
    log "Stage 3e: Installing SSH pubkeys from vault (core/pubkeys.enc)"
    if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
        # Non-interactive: passphrase provided via env var
        if bash "$PUBKEY_SCRIPT" unlock 2>/dev/null; then
            ok "Pubkeys installed -> ~/.ssh/authorized_keys"
        else
            warn "Pubkey unlock failed -- run 'vault unlock_pubkey' manually"
        fi
    else
        # Interactive: write prompt directly to /dev/tty (avoids subshell rendering issue)
        printf "   🔑 Install SSH pubkeys from vault? [Y/n] (default: Y): " > /dev/tty
        read -r -t 15 _pk_choice < /dev/tty || _pk_choice="Y"
        if [[ "${_pk_choice:-Y}" =~ ^[Yy]?$ ]]; then
            if bash "$PUBKEY_SCRIPT" unlock < /dev/tty; then
                ok "Pubkeys installed -> ~/.ssh/authorized_keys"
            else
                warn "Pubkey unlock failed -- run 'vault unlock_pubkey' manually"
            fi
        else
            echo "  💡 Run 'vault unlock_pubkey' when ready"
        fi
    fi
else
    ok "No pubkey vault found -- skipping (core/pubkeys.enc)"
fi

# ── 3f. Publish this node's pubkey -> bootstrap/nodes/pending/ (Step C) ──
# Allows the hub (WSL2) to collect all pending keys with: vault lock_pubkey --collect
log "Stage 3f: Publishing node pubkey for hub collection"
_PENDING_DIR="$SSOT/bootstrap/nodes/pending"
_NODE_LABEL="${MY_DEVICE:-$(hostname)}"
_PENDING_FILE="$_PENDING_DIR/${_NODE_LABEL}.pub"

if [[ -f "$_NODE_PUB" ]]; then
    mkdir -p "$_PENDING_DIR"

    # Idempotent: only update if pubkey changed
    _current_pub="$(cat "$_NODE_PUB")"
    _stored_pub="$(cat "$_PENDING_FILE" 2>/dev/null || echo "")"

    if [[ "$_current_pub" == "$_stored_pub" ]]; then
        ok "Pubkey already published: bootstrap/nodes/pending/${_NODE_LABEL}.pub"
    else
        cp "$_NODE_PUB" "$_PENDING_FILE"
        ok "Published: bootstrap/nodes/pending/${_NODE_LABEL}.pub"

        # Ensure pending/*.pub are git-tracked (not ignored by parent .gitignore)
        _PENDING_GITIGNORE="$_PENDING_DIR/.gitignore"
        if [[ ! -f "$_PENDING_GITIGNORE" ]]; then
            printf '*\n!.gitignore\n!*.pub\n' > "$_PENDING_GITIGNORE"
        fi

        # Best-effort git push
        if git -C "$SSOT" remote get-url origin &>/dev/null; then
            echo "  📤 Pushing pubkey to git..."
            git -C "$SSOT" add "$_PENDING_FILE" "$_PENDING_GITIGNORE" 2>/dev/null || true
            if git -C "$SSOT" diff --cached --quiet 2>/dev/null; then
                ok "Nothing new to push (pubkey already committed)"
            else
                if git -C "$SSOT" commit -m "chore(pubkey): add ${_NODE_LABEL} pending pubkey" 2>/dev/null; then
                    if git -C "$SSOT" push 2>/dev/null; then
                        ok "Pushed! Hub can now run: vault lock_pubkey --collect"
                    else
                        warn "git push failed -- run: git -C $SSOT push"
                    fi
                else
                    warn "git commit failed -- run manually"
                fi
            fi
        else
            warn "No git remote -- skipping push"
            echo "  💡 Copy $_PENDING_FILE to hub and run: vault lock_pubkey --collect"
        fi
    fi
else
    warn "No node pubkey found at $_NODE_PUB -- skipping publish"
fi

# STAGE 4 — Wire Shell Profile
# ============================================================
log "Stage 4: Wiring shell profile"

# Determine which profile templates to symlink
case "$JOE_ENV" in
    TERMUX)
        PROFILE_DIR="$SSOT/profiles/termux"
        SHELL_RC="$HOME/.zshrc"    # Termux uses zsh
        ;;
    MUMU)
        PROFILE_DIR="$SSOT/profiles/mumu"
        SHELL_RC="$HOME/.zshrc"
        ;;
    OPPO)
        PROFILE_DIR="$SSOT/profiles/oppo"
        SHELL_RC="$HOME/.zshrc"
        ;;
    PI)
        PROFILE_DIR="$SSOT/profiles/termux"
        SHELL_RC="$HOME/.zshrc"
        ;;
    WSL)
        PROFILE_DIR="$SSOT/profiles/wsl"
        SHELL_RC="$HOME/.bashrc"   # WSL default is bash
        ;;
    WSL2)
        PROFILE_DIR="$SSOT/profiles/wsl2"
        SHELL_RC="$HOME/.bashrc"   # WSL default is bash
        ;;    
    GIT-BASH)
        PROFILE_DIR="$SSOT/profiles/git-bash"
        SHELL_RC="$HOME/.bashrc"
        ;;
    ACODEX)
        PROFILE_DIR="$SSOT/profiles/acodex"
        SHELL_RC="$HOME/.bashrc"
        ;;
		KALI)
        PROFILE_DIR="$SSOT/profiles/kali"
        SHELL_RC="$HOME/.bashrc"
        ;;
    		
    *)
        PROFILE_DIR="$SSOT/profiles/wsl"
        SHELL_RC="$HOME/.bashrc"
        ;;
esac

_link_profile() {
    local target="$1"
    local src="$2"
    [[ ! -f "$src" ]] && return 0
    # Guard: auto-strip CRLF ( from source template if present
    if grep -q $'\r' "$src" 2>/dev/null; then
        sed -i 's/\r$//' "$src" 2>/dev/null || true
    fi
    if [[ -L "$target" ]]; then
        local curr
        curr="$(readlink "$target")"
        if [[ "$curr" == "$src" ]]; then
            ok "$target already linked to correct profile"
            return 0
        else
            rm -f "$target"
            ln -sf "$src" "$target"
            ok "$target re-linked → $src"
            return 0
        fi
    elif [[ -f "$target" ]]; then
        local bak="${target}.bak.$(date +%s)"
        cp "$target" "$bak"
        warn "Backed up existing $target → $bak"
        rm -f "$target"  # MSYS/Git Bash: must remove before ln -sf can replace regular file
    fi
    ln -sf "$src" "$target"
    ok "$target → $src (symlinked)"
}

# ── Link shell profiles ──
# Symlink .bashrc (all environments)
_link_profile "$HOME/.bashrc" "$PROFILE_DIR/.bashrc"

# Symlink .zshrc (all environments except GIT-BASH)
if [[ "$JOE_ENV" != "GIT-BASH" && -f "$PROFILE_DIR/.zshrc" ]]; then
    _link_profile "$HOME/.zshrc" "$PROFILE_DIR/.zshrc"
fi

# ============================================================
# STAGE 4.5 — Generate Global Environment Manager (~/.local/bin/env)
# ============================================================
# This file provides:
#   - PATH setup (~/.local/bin)
#   - Load ~/.env (secrets & overrides)
#   - shell_setup() — symlink shell profiles
#   - repo() — switch between ~/bashscripts and ~/ssot
# ============================================================
log "Stage 4.5: Generating global environment manager"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

ENV_TARGET="$BIN_DIR/env"

# Find template: try $SSOT first, then fallback to ~/ssot
ENV_TEMPLATE=""
for _dir in "$SSOT" "$HOME/ssot" "$HOME/bashscripts"; do
    if [[ -f "$_dir/bootstrap/templates/env" ]]; then
        ENV_TEMPLATE="$_dir/bootstrap/templates/env"
        break
    fi
done

if [[ -n "$ENV_TEMPLATE" ]]; then
    cp "$ENV_TEMPLATE" "$ENV_TARGET"
    chmod +x "$ENV_TARGET"
    ok "Created: $ENV_TARGET (from $ENV_TEMPLATE)"
else
    warn "Template not found in any repo — generating minimal env"
    cat > "$ENV_TARGET" << 'ENVEOF'
#!/bin/bash
# ~/.local/bin/env — Global Environment Manager (minimal)

# PATH setup
case ":${PATH}:" in
    *:"$HOME/.local/bin":*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Load private env vars
[ -f ~/.env ] && . ~/.env

# SSOT auto-detection
if [[ -z "${SSOT:-}" ]]; then
    [[ -d "$HOME/bashscripts" ]] && export SSOT="$HOME/bashscripts"
    [[ -z "${SSOT:-}" && -d "$HOME/ssot" ]] && export SSOT="$HOME/ssot"
fi

# Source joe.sh if SSOT is set
[[ -n "${SSOT:-}" && -f "${SSOT}/joe.sh" ]] && source "${SSOT}/joe.sh" 2>/dev/null
ENVEOF
    chmod +x "$ENV_TARGET"
    ok "Created: $ENV_TARGET (minimal)"
fi

log "Stage 4.6: auto detect and install ble"

# Idempotent: quoted "~" never expands, so always test $HOME unquoted.
# Guarded with || warn (set -e is on — a failed clone must not abort install).
if [[ ! -f "$HOME/.local/share/blesh/ble.sh" ]]; then
    if [[ ! -d "$HOME/ble.sh" ]]; then
        git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git "$HOME/ble.sh" 2>/dev/null \
            || warn "ble.sh clone failed (non-fatal)"
    fi
    if [[ -d "$HOME/ble.sh" ]]; then
        make -C "$HOME/ble.sh" install PREFIX="$HOME/.local" 2>/dev/null \
            || warn "ble.sh install failed (non-fatal)"
    fi
else
    ok "ble.sh already installed"
fi
# ============================================================
# STAGE 4.7 — Broken Symlink Scanner & Cleanup
# ============================================================
# Scan critical directories for broken symlinks and remove them.
# This prevents issues from previous installs or manual edits.
# ============================================================
log "Stage 4.7: Scanning for broken symlinks"

_broken_count=0

# Helper: scan a directory for broken symlinks and remove them
_scan_broken() {
    local dir="$1"
    local label="$2"
    [[ ! -d "$dir" ]] && return 0

    while IFS= read -r -d '' link; do
        if [[ ! -e "$link" ]]; then
            warn "  Removing broken symlink: $link"
            rm -f "$link"
            _broken_count=$((_broken_count + 1))
        fi
    done < <(find "$dir" -maxdepth 1 -type l -print0 2>/dev/null)
}

# Scan ~/.local/bin/
_scan_broken "$HOME/.local/bin" "~/.local/bin"

# Scan ~/
_scan_broken "$HOME" "~"

if [[ $_broken_count -gt 0 ]]; then
    ok "Removed $_broken_count broken symlink(s)"
else
    ok "No broken symlinks found"
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
else
    ok "$BIN_DIR/syncctl not available (tools/syncctl not found) — skipping"
fi

# node-status command
if [[ ! -L "$BIN_DIR/node-status" ]]; then
    if [[ -f "$SSOT/bootstrap/nodes/node-status.sh" ]]; then
        ln -sf "$SSOT/bootstrap/nodes/node-status.sh" "$BIN_DIR/node-status"
        chmod +x "$SSOT/bootstrap/nodes/node-status.sh"
        ok "Created: $BIN_DIR/node-status → bootstrap/nodes/node-status.sh"
    else
        ok "$BIN_DIR/node-status not available (node-status.sh not found) — skipping"
    fi
else
    ok "$BIN_DIR/node-status already linked"
fi

# node-register command (one-short-command onboarding: node-register --auto <name>)
if [[ ! -L "$BIN_DIR/node-register" ]]; then
    if [[ -f "$SSOT/bootstrap/nodes/node-register.sh" ]]; then
        ln -sf "$SSOT/bootstrap/nodes/node-register.sh" "$BIN_DIR/node-register"
        chmod +x "$SSOT/bootstrap/nodes/node-register.sh"
        ok "Created: $BIN_DIR/node-register → bootstrap/nodes/node-register.sh"
    else
        ok "$BIN_DIR/node-register not available (node-register.sh not found) — skipping"
    fi
else
    ok "$BIN_DIR/node-register already linked"
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

# ── 7a. Critical file preservation checks ──
# These files MUST exist and NOT be empty after install
log "  Checking critical files..."

_critical_files=(
    "$HOME/.env"
    "$SSOT/joe.sh"
    "$SSOT/shared/00-env.sh"
    "$SSOT/core/01-colors.sh"
    "$SSOT/shared/aliases.sh"
    "$SSOT/core/3worlds.sh"
    "$HOME/.local/bin/env"
)

for _cf in "${_critical_files[@]}"; do
    if [[ -f "$_cf" ]]; then
        if [[ -s "$_cf" ]]; then
            ok "  $(basename "$_cf") — exists and not empty"
        else
            warn "  $(basename "$_cf") — exists but EMPTY!"
            _errors=$((_errors + 1))
        fi
    else
        warn "  $(basename "$_cf") — MISSING at $_cf"
        _errors=$((_errors + 1))
    fi
done

# ── 7b. Shell profile checks ──
# Verify .bashrc and .zshrc exist (as file or symlink)
for _rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -L "$_rc" ]]; then
        _target="$(readlink "$_rc" 2>/dev/null)"
        if [[ -e "$_rc" ]]; then
            ok "  $(basename "$_rc") — symlink → $(basename "$_target")"
        else
            warn "  $(basename "$_rc") — BROKEN symlink → $_target"
            rm -f "$_rc"
            _errors=$((_errors + 1))
        fi
    elif [[ -f "$_rc" ]]; then
        ok "  $(basename "$_rc") — regular file (not symlinked)"
    else
        warn "  $(basename "$_rc") — MISSING"
        _errors=$((_errors + 1))
    fi
done

# ── 7c. .bash_aliases check ──
if [[ -f "$HOME/.bash_aliases" ]]; then
    ok "  .bash_aliases — exists"
elif [[ -L "$HOME/.bash_aliases" ]]; then
    if [[ -e "$HOME/.bash_aliases" ]]; then
        ok "  .bash_aliases — symlink OK"
    else
        warn "  .bash_aliases — BROKEN symlink"
        rm -f "$HOME/.bash_aliases"
    fi
else
    warn "  .bash_aliases — not found (non-critical)"
fi

# ── 7d. joe.sh syntax check ──
if [[ -f "$SSOT/joe.sh" ]] && bash -n "$SSOT/joe.sh" 2>/dev/null; then
    ok "joe.sh — exists and syntax valid"
else
    warn "joe.sh — missing or syntax error"
    _errors=$((_errors + 1))
fi

# ── 7e. .env configuration check ──
if grep -q "^export JOE_ENV=" "$HOME/.env" 2>/dev/null; then
    ok "~/.env — JOE_ENV configured"
else
    warn "~/.env — JOE_ENV not set"
    _errors=$((_errors + 1))
fi

# ── 7f. Shell profile sources joe.sh check ──
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

# ── 7g. Key modules existence check ──
for _mod in "shared/00-env.sh" "core/01-colors.sh" "shared/aliases.sh" "core/3worlds.sh"; do
    if [[ -f "$SSOT/$_mod" ]]; then
        ok "$_mod — found"
    else
        warn "$_mod — missing"
        _errors=$((_errors + 1))
    fi
done

# ── 7h. Syntax check all .sh files ──
if command -v bash >/dev/null 2>&1; then
    _syntax_fails=0
    for _f in "$SSOT"/core/*.sh "$SSOT"/shared/functions/*.sh "$SSOT"/shared/personal/*.sh; do
        [[ -f "$_f" ]] || continue
        if ! bash -n "$_f" 2>/dev/null; then
            _syntax_fails=$((_syntax_fails + 1))
        fi
    done
    if [[ $_syntax_fails -eq 0 ]]; then
        ok "Syntax check — all core + shared .sh pass"
    else
        warn "Syntax check — $_syntax_fails file(s) have errors"
    fi
fi

# ── 7i. Final broken symlink scan ──
_final_broken=0
while IFS= read -r -d '' link; do
    if [[ ! -e "$link" ]]; then
        warn "Final scan: broken symlink at $link"
        rm -f "$link"
        _final_broken=$((_final_broken + 1))
    fi
done < <(find "$HOME/.local/bin" -maxdepth 1 -type l -print0 2>/dev/null)

if [[ $_final_broken -gt 0 ]]; then
    ok "Cleaned $_final_broken broken symlink(s) in final scan"
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
