#!/bin/bash
# ============================================================
# 🚀 SSOT Bootstrap Installer — One-Shot Fresh Setup
# ============================================================
# Target Environment: Termux, MuMu, WSL, Git-Bash
# Usage:
#   bash bootstrap/script/ssot_install.sh [ENV_OVERRIDE]
# ============================================================
set -eo pipefail

pkg_helper() {
    # 1. Validation: ตรวจสอบว่ามีการส่งชื่อแพ็กเกจมาหรือไม่
    if [ "$#" -eq 0 ]; then
        echo "❌ Usage: pkg_helper <package_1> [package_2 ...]" >&2
        return 1
    fi

    # 2. Package Manager Detection & Execution
    if command -v pkg >/dev/null 2>&1; then
        # Environment: Termux
        pkg update -y && pkg upgrade -y
        pkg install -y "$@"

    elif command -v apt >/dev/null 2>&1; then
        # Environment: Ubuntu (WSL2), Debian, VPS
        local sudo_cmd=""
        if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
            sudo_cmd="sudo"
        fi

        # ใช้ Non-interactive mode เพื่อป้องกัน Prompt ค้างระหว่าง Auto-install
        DEBIAN_FRONTEND=noninteractive $sudo_cmd apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive $sudo_cmd apt-get install -y -qq "$@"

    elif command -v apk >/dev/null 2>&1; then
        # Environment: Alpine Linux (VPS / Container)
        apk update && apk add --no-cache "$@"

    elif command -v pacman >/dev/null 2>&1; then
        # Environment: Arch Linux
        local sudo_cmd=""
        [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && sudo_cmd="sudo"
        $sudo_cmd pacman -Sy --noconfirm "$@"

    else
        echo "❌ Error: No supported package manager found (pkg, apt, apk, pacman)" >&2
        return 1
    fi
}
clone_(){
    if ! command -v git 2>/dev/null; then
        pkg_helper "git"
    fi    
        
    SSOT_REPO="https://github.com/joece035/ssot-public.git"
    SSOT_TARGET="$HOME/ssot"

    if [[ ! -d "$SSOT_TARGET/.git" ]]; then
        echo "📥 Cloning SSOT repository..."
        git clone "$SSOT_REPO" "$SSOT_TARGET"
    else
        echo "🔄 SSOT repository already exists at $SSOT_TARGET"
        echo "⬇️  Updating SSOT to latest from GitHub..."
        git -C "$SSOT_TARGET" fetch origin main 2>/dev/null && git -C "$SSOT_TARGET" reset --hard origin/main 2>/dev/null || true
    fi

    cd "$SSOT_TARGET"
    source "$HOME/ssot/.bash_helper"
    source "$HOME/ssot/joe.sh"
}
clone_




# ── [1] DETECT ENVIRONMENT ──
_JOE_ENV() {
    if [[ -n "${1:-}" ]]; then
        echo "$1"
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
    elif command -v apk >/dev/null 2>&1; then
        echo "ACODEX"
    else
        echo "LINUX"
    fi
}
DETECTED_ENV="$(_JOE_ENV "${1:-}")"
export JOE_ENV="$DETECTED_ENV"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   🚀  SSOT Bootstrap Installer                  ║"
printf "║   🌍 Environment : %-30s║\n" "$JOE_ENV"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── [2] TERMUX STORAGE SETUP ──
if [[ "$JOE_ENV" == "TERMUX" || "$JOE_ENV" == "MUMU" ]]; then
    if [[ ! -d "$HOME/storage" ]]; then
        echo "📂 Setting up Termux storage..."
        termux-setup-storage </dev/null || true
    fi
fi

# ── [3] UPDATE & INSTALL CORE PACKAGES (Batch) ──
#echo "📦 Updating repositories & installing core packages..."



pkg_install() {
    local ssl_pkg="openssl"
    if [[ "$JOE_ENV" == "TERMUX" || "$JOE_ENV" == "MUMU" ]]; then
        ssl_pkg="openssl-tool"
    fi
    local pack=(
        "git:git"
        "openssh:ssh"
        "ncurses-utils:tput"
        "curl:curl"
        "micro:micro"
        "which:which"
        "find:find"
        "${ssl_pkg}:openssl"
    )
    for item in "${pack[@]}"; do
        local p="${item%%:*}"
        local b="${item##*:}"
        if command -v pkg_manager >/dev/null 2>&1; then
            pkg_manager "${p}" "${b}"
        fi
        echo "installed ${p}"
    done
}
pkg_install
# ── [4] CLONE / UPDATE REPO ──


# ── [5] CONFIGURE .env & SECRET VAULT ──
echo "⚙️  Configuring environment variables & secrets..."

# 5.1 Check if Encrypted Secret Vault exists
if [[ -f "$SSOT_TARGET/core/.env.enc" ]]; then
    echo ""
    echo "🔐 Found SSOT Encrypted Vault ($SSOT_TARGET/core/.env.enc)"
    echo "   Would you like to unlock secrets now with your Master Passphrase? [Y/n]"
    read -r -t 15 -p "   Selection (default: Y): " _vault_choice < /dev/tty || _vault_choice="Y"
    if [[ "${_vault_choice:-Y}" =~ ^[Yy]?$ ]]; then
        "$SSOT_TARGET/tools/ssot-vault.sh" unlock || echo "⚠️  Vault unlock skipped/failed. You can run 'vault unlock' anytime later."
    fi
fi

# 5.2 Fallback to template if .env still doesn't exist
if [[ ! -f "$HOME/.env" ]]; then
    if [[ -f "$SSOT_TARGET/.env.example" ]]; then
        cp "$SSOT_TARGET/.env.example" "$HOME/.env"
        echo "  📄 Initialized ~/.env from .env.example"
    else
        touch "$HOME/.env"
    fi
fi

# 5.3 Ensure JOE_ENV is set correctly
if grep -q "^export JOE_ENV=" "$HOME/.env" 2>/dev/null; then
    sed -i "s/^export JOE_ENV=.*/export JOE_ENV=\"$JOE_ENV\"/" "$HOME/.env"
else
    echo "export JOE_ENV=\"$JOE_ENV\"" >> "$HOME/.env"
fi

# 5.4 Dynamic Node Identity Registration (MY_DEVICE)
if ! grep -q "^export MY_DEVICE=" "$HOME/.env" 2>/dev/null; then
    _def_device="node-$(hostname 2>/dev/null || echo "$JOE_ENV" | tr '[:upper:]' '[:lower:]')"
    if [[ "$JOE_ENV" == "TERMUX" ]]; then
        _brand="$(getprop ro.product.brand 2>/dev/null | tr '[:upper:]' '[:lower:]')"
        [[ -n "$_brand" ]] && _def_device="$_brand"
    elif [[ "$JOE_ENV" == "MUMU" ]]; then
        _def_device="mumu"
    elif [[ "$JOE_ENV" == "WSL" ]]; then
        _def_device="wsl"
    fi
    echo ""
    echo "📱 Node Identity Registration:"
    read -r -t 10 -p "   Name this node in the SSOT mesh (default: $_def_device): " _chosen_dev < /dev/tty || _chosen_dev="$_def_device"
    _chosen_dev="${_chosen_dev:-$_def_device}"
    echo "export MY_DEVICE=\"$_chosen_dev\"" >> "$HOME/.env"
    echo "  ✅ Registered node: MY_DEVICE=$_chosen_dev"
fi

# 5.5 Canonical Symlink and Permissions
chmod 600 "$HOME/.env"
ln -sf "$HOME/.env" "$SSOT_TARGET/.env"
echo "  ✅ Configured ~/.env and symlinked to $SSOT_TARGET/.env"

# ── [6] PERMISSIONS ──
echo "🔑 Updating execution permissions..."
for f in bootstrap/script/*.sh core/*.sh; do
    [[ -f "$f" ]] && chmod +x "$f"
done
echo "  ✅ Permissions granted"

# ── [7] RUN SETUP & SSH AUDIT ──
echo ""
echo "🔧 Running setup.sh ($JOE_ENV)..."
./bootstrap/script/setup.sh "$JOE_ENV"

echo ""
echo "🛡️  Running SSH Mesh Self-Healing..."
./bootstrap/script/ssh_audit.sh --fix

# ── [8] AUTO-START SSHD FOR TERMUX ──
if [[ "$JOE_ENV" == "TERMUX" || "$JOE_ENV" == "MUMU" ]]; then
    SSH_TARGET_PORT="${SSH_PORT:-8022}"
    [[ "$JOE_ENV" == "MUMU" ]] && SSH_TARGET_PORT=8020
    if ! pgrep -f "sshd.*-p.*${SSH_TARGET_PORT}" >/dev/null 2>&1 && ! pgrep -x sshd >/dev/null 2>&1; then
        echo ""
        echo "🔌 Starting local sshd daemon on port ${SSH_TARGET_PORT}..."
        sshd -p "${SSH_TARGET_PORT}" && echo "  ✅ sshd started successfully" || echo "  ⚠️ sshd start failed (run 'sshd -p ${SSH_TARGET_PORT}' manually)"
    fi
fi

# ── [9] SUMMARY & ACTIVATION ──
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🎉 SSOT Installation and Configuration Complete!"
echo "═══════════════════════════════════════════════════════════"
echo "To activate your environment immediately, run:"
echo ""
echo "    exec bash"
echo "  or"
echo "    source ~/.bashrc"
echo ""
echo "═══════════════════════════════════════════════════════════"
