#!/bin/bash
# ============================================================
# 🚀 SSOT Bootstrap Installer — One-Shot Fresh Setup
# Target Environment: Termux, MuMu, WSL2, Git-Bash, Linux
# ============================================================

set -eo pipefail

SSOT_REPO="https://github.com/joece035/ssot-public.git"
SSOT_TARGET="$HOME/ssot"

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
echo "║   🚀  SSOT Bootstrap Installer                   ║"
printf "║   🌍 Environment : %-30s║\n" "$JOE_ENV"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── [2] PACKAGE MANAGER HELPER ──
pkg_helper() {
    if [ "$#" -eq 0 ]; then
        echo "❌ Usage: pkg_helper <package_1> [package_2 ...]" >&2
        return 1
    fi

    if command -v pkg >/dev/null 2>&1; then
        pkg update -y && pkg install -y "$@"
    elif command -v apt-get >/dev/null 2>&1 || command -v apt >/dev/null 2>&1; then
        local sudo_cmd=""
        if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
            sudo_cmd="sudo"
        fi
        DEBIAN_FRONTEND=noninteractive $sudo_cmd apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive $sudo_cmd apt-get install -y -qq "$@"
    elif command -v apk >/dev/null 2>&1; then
        apk update && apk add --no-cache "$@"
    elif command -v pacman >/dev/null 2>&1; then
        local sudo_cmd=""
        [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && sudo_cmd="sudo"
        $sudo_cmd pacman -Sy --noconfirm "$@"
    else
        echo "❌ Error: No supported package manager found" >&2
        return 1
    fi
}

# ── [3] TERMUX STORAGE SETUP ──
if [[ "$JOE_ENV" == "TERMUX" || "$JOE_ENV" == "MUMU" ]]; then
    if [[ ! -d "$HOME/storage" ]]; then
        echo "📂 Setting up Termux storage..."
        termux-setup-storage </dev/null || true
    fi
fi

# ── [4] BATCH INSTALL CORE PACKAGES ──
pkg_install() {
    local ssl_pkg="openssl"
    if [[ "$JOE_ENV" == "TERMUX" || "$JOE_ENV" == "MUMU" ]]; then
        ssl_pkg="openssl-tool"
    fi

    local pkgs_to_install=()
    local pack=(
        "git:git"
        "openssh:ssh"
        "ncurses-utils:tput"
        "curl:curl"
        "micro:micro"
        "which:which"
        "findutils:find"
        "${ssl_pkg}:openssl"
    )

    for item in "${pack[@]}"; do
        local p="${item%%:*}"
        local b="${item##*:}"
        if ! command -v "$b" >/dev/null 2>&1; then
            pkgs_to_install+=("$p")
        fi
    done

    if [ "${#pkgs_to_install[@]}" -gt 0 ]; then
        echo "📦 Installing missing core packages: ${pkgs_to_install[*]}"
        pkg_helper "${pkgs_to_install[@]}"
    else
        echo "✅ All core dependencies are already satisfied."
    fi
}
pkg_install

# ── [5] CLONE / UPDATE REPO (SSOT) ──
clone_repo() {
    if [[ ! -d "$SSOT_TARGET/.git" ]]; then
        echo "📥 Cloning SSOT repository..."
        git clone "$SSOT_REPO" "$SSOT_TARGET"
    else
        echo "🔄 SSOT repository exists at $SSOT_TARGET. Updating..."
        git -C "$SSOT_TARGET" fetch origin main 2>/dev/null && \
        git -C "$SSOT_TARGET" reset --hard origin/main 2>/dev/null || true
    fi

    cd "$SSOT_TARGET"
    
    # Source helper files only AFTER successful clone
    [[ -f "$SSOT_TARGET/.bash_helper" ]] && source "$SSOT_TARGET/.bash_helper"
    [[ -f "$SSOT_TARGET/joe.sh" ]] && source "$SSOT_TARGET/joe.sh"
}
clone_repo

# ── [6] CONFIGURE .env & SECRET VAULT ──
echo "⚙️  Configuring environment variables & secrets..."

if [[ -f "$SSOT_TARGET/core/.env.enc" ]]; then
    echo ""
    echo "🔐 Found SSOT Encrypted Vault ($SSOT_TARGET/core/.env.enc)"
    read -r -t 15 -p "   Unlock secrets now? [Y/n] (default: Y): " _vault_choice < /dev/tty || _vault_choice="Y"
    if [[ "${_vault_choice:-Y}" =~ ^[Yy]?$ ]]; then
        "$SSOT_TARGET/bootstrap/vault/ssot-vault.sh" unlock || echo "⚠️  Vault unlock skipped/failed."
    fi
fi

if [[ ! -f "$HOME/.env" ]]; then
    if [[ -f "$SSOT_TARGET/.env.example" ]]; then
        cp "$SSOT_TARGET/.env.example" "$HOME/.env"
        echo "  📄 Initialized ~/.env from .env.example"
    else
        touch "$HOME/.env"
    fi
fi

# Set JOE_ENV in ~/.env
if grep -q "^export JOE_ENV=" "$HOME/.env" 2>/dev/null; then
    sed -i "s/^export JOE_ENV=.*/export JOE_ENV=\"$JOE_ENV\"/" "$HOME/.env"
else
    echo "export JOE_ENV=\"$JOE_ENV\"" >> "$HOME/.env"
fi

# Set MY_DEVICE in ~/.env
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
    read -r -t 10 -p "📱 Name this node (default: $_def_device): " _chosen_dev < /dev/tty || _chosen_dev="$_def_device"
    _chosen_dev="${_chosen_dev:-$_def_device}"
    echo "export MY_DEVICE=\"$_chosen_dev\"" >> "$HOME/.env"
    echo "  ✅ Registered node: MY_DEVICE=$_chosen_dev"
fi

chmod 600 "$HOME/.env"
ln -sf "$HOME/.env" "$SSOT_TARGET/.env"

# ── [7] RC AUTO-LINKING (Single Source Concept) ──
# แม้ Termux ใช้ .zshrc แต่เรากำหนดให้ทุก RC ไป source Entry Point เดียวกัน
LINK_TARGET='[ -f "$HOME/ssot/joe.sh" ] && source "$HOME/ssot/joe.sh"'

for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc_file" ]] || [[ "$rc_file" == "$HOME/.zshrc" && "$JOE_ENV" == "TERMUX" ]]; then
        if ! grep -q "ssot/joe.sh" "$rc_file" 2>/dev/null; then
            echo -e "\n# SSOT Entry point\n$LINK_TARGET" >> "$rc_file"
            echo "  ✅ Linked SSOT entry point to $rc_file"
        fi
    fi
done

# ── [8] PERMISSIONS & SUB-SCRIPTS ──
echo "🔑 Updating execution permissions..."
find bootstrap/script core/ tools/ -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

echo ""
echo "🔧 Running setup.sh ($JOE_ENV)..."
[[ -f ./bootstrap/script/setup.sh ]] && ./bootstrap/script/setup.sh "$JOE_ENV"

echo ""
echo "🛡️  Running SSH Mesh Self-Healing..."
[[ -f ./bootstrap/script/ssh_audit.sh ]] && ./bootstrap/script/ssh_audit.sh --fix

# ── [9] AUTO-START SSHD FOR TERMUX ──
if [[ "$JOE_ENV" == "TERMUX" || "$JOE_ENV" == "MUMU" ]]; then
    SSH_TARGET_PORT="${SSH_PORT:-8022}"
    [[ "$JOE_ENV" == "MUMU" ]] && SSH_TARGET_PORT=8020
    if ! pgrep -f "sshd.*-p.*${SSH_TARGET_PORT}" >/dev/null 2>&1 && ! pgrep -x sshd >/dev/null 2>&1; then
        echo ""
        echo "🔌 Starting local sshd daemon on port ${SSH_TARGET_PORT}..."
        sshd -p "${SSH_TARGET_PORT}" && echo "  ✅ sshd started successfully" || echo "  ⚠️ sshd start failed"
    fi
fi

# ── [10] SUMMARY ──
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🎉 SSOT Installation Complete!"
echo "═══════════════════════════════════════════════════════════"
if [[ "$SHELL" == *"zsh"* ]]; then
    echo "To activate immediately, run: exec zsh  (or source ~/.zshrc)"
else
    echo "To activate immediately, run: exec bash (or source ~/.bashrc)"
fi
echo "═══════════════════════════════════════════════════════════"
