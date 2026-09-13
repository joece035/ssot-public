#!/bin/bash
# ============================================================
# 00-env.sh — Environment Variables & Paths (CANONICAL)
# ============================================================
# This is the SINGLE SOURCE OF TRUTH for all environment
# variables. Set by boot.sh Stage 2, after JOE_ENV detected.
#
# NOTE: Core paths (SCRIPTS_PATH, JOE_ENV, hpc, htm, hwsl,
# NODE_BIN, dbp, OPENCLAW_BIN) are set by boot.sh Stage 0.
# This file ONLY sets derived/secondary variables.
#
# All paths use variables from boot.sh (no hardcoded paths).
# This ensures it works across all environments: WSL, Termux,
# Linux, and Git Bash on Windows.
#
# Stage: 2 (after boot.sh Stage 0 and 00-bootstrap.sh)
# Dependencies: JOE_ENV, hpc, htm, hwsl, dbp, HOME, SCRIPTS_PATH
# ============================================================

# ============================================================
# ── 0. LOCAL SECRETS & OVERRIDES (SSOT) ──
# Loads private credentials and machine overrides.
# 1. Machine Config (local only, never in git/vault): ~/.env
if [[ -f "$HOME/.env" ]]; then
    source "$HOME/.env"
elif [[ -f "${SSOT:-$HOME/ssot}/.env" ]]; then
    source "${SSOT:-$HOME/ssot}/.env"
elif [[ -f "${SCRIPTS_PATH:-$HOME/ssot}/.env" ]]; then
    source "${SCRIPTS_PATH:-$HOME/ssot}/.env"
fi

# 2. Shared Secrets (decrypted from vault): ~/.env.secret
if [[ -f "$HOME/.env.secret" ]]; then
    source "$HOME/.env.secret"
elif [[ -f "${SSOT:-$HOME/ssot}/.env.secret" ]]; then
    source "${SSOT:-$HOME/ssot}/.env.secret"
fi

# ============================================================
# 1. WORKSPACE PATHS (Derived from JOE_ENV basics)
# ============================================================


case "$JOE_ENV" in
    TERMUX)
         export HERMES_DIR="/data/data/com.termux/files/home/.hermes"
         export PYTHON_VENV="$HOME/.dash_venv/bin/activate"
         export SDCARD_PATH="/storage/emulated/0/"
         export NODE_HOST="termux"
         ;;
    MUMU)
         export HERMES_DIR="/data/data/com.termux/files/home/.hermes"
         export PYTHON_VENV="$HOME/.dash_venv/bin/activate"
         export SDCARD_PATH="/storage/emulated/0/"
         export NODE_HOST="mumu"
         ;;
    WSL)
         export HERMES_DIR="$HOME/.hermes"
         export PYTHON_VENV="$HOME/.venv/bin/activate"
         export NODE_HOST="wsl"
         export WIN_PATH="/mnt/"
         

         ;;
    GIT-BASH)
         export HERMES_DIR="/mnt/c/Users/User/AppData/Local/hermes"
         export PYTHON_VENV="$HWSL/.venv/bin/activate"
         export NODE_HOST="window"
         export WIN_PATH='/'

         ;;
    *)
         export PYTHON_VENV="$htm/.dash_venv/bin/activate"
         export NODE_HOST="linux"
         ;;
esac

# ============================================================
# 2. GLOBAL VARIABLE
# ============================================================
export bsc="$HOME/bashscripts"
export ssot="$HOME/ssot"
export profile=mom
export oppc="$hpc/openclaw"
export dpc="$hpc/Desktop"
export dtpc="$hpc/Desktop"          # compat alias ของ dpc
export hmp="${HERMES_DIR:-$HOME/.hermes}"   # AGENT.md: hmp = $HOME/.hermes
export HERMES_LOG_DIR="${HERMES_DIR}/logs"  # log dir สำหรับ tools/hermes.sh
export BRAVE_SEARCH_API_KEY="${BRAVE_SEARCH_API_KEY:-}"
export BRAVE_API_KEY="${BRAVE_API_KEY:-$BRAVE_SEARCH_API_KEY}"
export ALPHA_DIR="$msync/alpha-workspace"
export alpha=${ALPHA_DIR}
export storage="/storage/emulated/0/" # sdcrd
export ais_fiber="880-563-6522"
export ais_phone="0814764210"
export space="\u2003\u2003\u2003\u2003"
export bin="$HOME/.local/bin"

if [[ -n "${ZSH_VERSION:-}" ]]; then
    export _SHELL="zsh"
elif [[ -n "${BASH_VERSION:-}" ]]; then
    export _SHELL="bash"
else
    export _SHELL="${_SHELL:-${SHELL##*/}}"
fi
export _USER="${USER:-${USERNAME:-$(whoami 2>/dev/null)}}"
export pftermux="${SSOT}/profiles/termux"
export ptwsl="${SSOT}/profiles/wsl"
export pfmumu="${SSOT}/profiles/mumu"
export pfwin="${SSOT}/profiles/git-bash"
# ============================================================
# SupperBoom env
# ============================================================

export ssboom="${WIN_PATH}c/Users/User/Documents/mumusharedfolder/Screenshots"
export vdoboom="${WIN_PATH}c/Users/User/Documents/MuMuSharedFolder/VideoRecords"
export bk_vdoboom="${WIN_PATH}h/boom/VideoRecords"
export bk_ssboom="${WIN_PATH}h/boom/Screenshots"
# ============================================================
# Dynamic env switching
# ============================================================
ai_bin() {
    if command -v openclaw >/dev/null 2>&1; then
        export OPENCLAW_BIN="openclaw"
    else
        unset OPENCLAW_BIN
    fi
    if command -v hermes >/dev/null 2>&1; then
        export HERMES_BIN="hermes"
    else
        unset HERMES_BIN
    fi
}
ai_bin
# ============================================================
# 2. SERVICE PATHS & DIRECTORIES
# ============================================================

# Use dbp from boot.sh (already set correctly for environment

export ENGINES_DIR="$DASHBOARD_DIR/api/engines"

# ============================================================
# 3. PYTHON & VIRTUAL ENVIRONMENT
# ============================================================


# Python activation script
export DASHBOARD_PYTHON="$PYTHON_VENV"

# Python I/O encoding
export PYTHONIOENCODING="utf-8"

# ============================================================
# 3.5 MATH HELPER DEFAULTS (used by m() in 00.1-function-tools.sh)
# ============================================================
# Excel-style: default 2 decimals, round-half-up
export MATH_DEFAULT_SCALE="${MATH_DEFAULT_SCALE:-0}"
export MATH_DEFAULT_MODE="${MATH_DEFAULT_MODE:-round}"   # round | up | down

# ============================================================
# 4. NODE & BUILD SETTINGS
# ============================================================

export NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache

# ============================================================
# 5. OPENCLAW CONFIGURATION
# ============================================================

export OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1
export OPENCLAW_NO_RESPAWN=1
export CURRENT_OC_PROFILE="${CURRENT_OC_PROFILE:-None (Default)}"

# ============================================================
# 6. NODE REGISTRY (Tailscale MagicDNS — SSOT for all nodes)
# ============================================================
# Primary identity = Tailscale hostname (MagicDNS).
# IPs are no longer hardcoded — Tailscale resolves them.
# To add a new node: add a NODE_<NAME>_* block below.
#
# Schema per node:
#   HOST      — Tailscale MagicDNS hostname
#   USER      — SSH login user
#   PORT      — SSH port (SSH service port on the node)
#   ST_PORT   — Syncthing GUI port
#   ST_KEY    — Syncthing API key
#   ST_URL    — Syncthing base URL (no trailing slash)
# ============================================================
# -- TAILSCALING: Tailscale environment detection
if command -v tailscale >/dev/null 2>&1; then
    export TAILSCALE_BIN="tailscale"
    if [[ "$JOE_ENV" != "GIT-BASH" ]]; then
        export TAILSCALE_STATUS="$(tailscale status 2>/dev/null || echo "tailscale not running")"
        export TAILSCALE_IP="$(tailscale ip -4 2>/dev/null || echo "tailscale not running")"
    else
        export TAILSCALE_STATUS="available"
        export TAILSCALE_IP="100.69.181.45"
    fi
else
    export TAILSCALE_STATUS="tailscale not running"
    export TAILSCALE_IP="tailscale not running"
fi
export TAILSCALE_IP_TERMUX=100.110.26.16
export TAILSCALE_IP_WINDOW=100.69.181.45
export TAILSCALE_IP_WSL=100.80.195.120
export TAILSCALE_IP_MUMU=100.100.176.94

# ── Dynamic Node Registry Loader (drop-in profiles from $SSOT/bootstrap/nodes/*.node.env) ──
if [[ -f "${SSOT:-$HOME/ssot}/bootstrap/nodes/loader.sh" ]]; then
    source "${SSOT:-$HOME/ssot}/bootstrap/nodes/loader.sh"
fi

# ============================================================
# COMPATIBILITY LAYER — Phase 1
# All legacy variable names re-exported from Node Registry.
# DO NOT remove these until all consumers migrate to NODE_* vars.
# ============================================================

# Termux compat
export TERMUX_IP="${NODE_TERMUX_HOST:-$NODE_TERMUX_IP}"
export TERMUX_USER="$NODE_TERMUX_USER"
export TERMUX_PORT="$NODE_TERMUX_PORT"
export TERMUX_TELSCAIL_IP="$NODE_TERMUX_HOST"
export ST_KEY_TERMUX="$NODE_TERMUX_ST_KEY"
export ST_PORT_TERMUX="$NODE_TERMUX_ST_PORT"
export URL_TERMUX="${NODE_TERMUX_ST_URL}/"

# WSL compat
export WSL_IP="${NODE_WSL_HOST:-$NODE_WSL_IP}"
export WSL_USER="$NODE_WSL_USER"
export WSL_TELSCAIL_IP="$NODE_WSL_HOST"
export ST_KEY_WSL="$NODE_WSL_ST_KEY"
export ST_PORT_WSL="$NODE_WSL_ST_PORT"
export URL_WSL="${NODE_WSL_ST_URL}/"

# --- Windows compat
# WIN_GIT_BASH: path ของ Git Bash บน Windows (ใช้โดย tw() ใน 3worlds.sh)
# Windows OpenSSH default shell = PowerShell — tw() ต้องเรียกผ่าน PS call operator
#export WIN_GIT_BASH="C:\PROGRA~1\Git\bin\bash.exe"
export WINDOWS_IP="${NODE_WIN_HOST:-$NODE_WIN_IP}"
export WINDOWS_USER="$NODE_WIN_USER"
export ST_KEY_WIN="$NODE_WIN_ST_KEY"
export ST_PORT_WIN="$NODE_WIN_ST_PORT"
export URL_WIN="${NODE_WIN_ST_URL}/"
export WIN_GIT_BASH="C:/Program Files/Git/bin/bash.exe"

# MUMUPlayer compat (Android emulator peer)
export MUMU_IP="${NODE_MUMU_HOST:-$NODE_MUMU_IP}"
export MUMU_USER="$NODE_MUMU_USER"
export MUMU_PORT="$NODE_MUMU_PORT"
export MUMU_TELSCAIL_IP="$NODE_MUMU_HOST"
export ST_KEY_MUMU="$NODE_MUMU_ST_KEY"
export ST_PORT_MUMU="$NODE_MUMU_ST_PORT"
export URL_MUMU="${NODE_MUMU_ST_URL}/"

# ACODEX compat
export ACODEX_IP="${NODE_ACODEX_HOST:-$NODE_ACODEX_IP}"
export ACODEX_USER="$NODE_ACODEX_USER"
export ACODEX_PORT="$NODE_ACODEX_PORT"

# ============================================================
# EXPORTS COMPLETE — Ready for use in aliases and functions
# All paths are environment-aware and work across WSL, Termux, Linux, Git Bash
# ============================================================

# --- SHORT CUT FOR JOE-- #
export nx="$nexus_vault"
export USDT_BEP20_BITKUB="${USDT_BEP20_BITKUB:-}"
export SOL_BITKUB="${SOL_BITKUB:-}"
export SOL_METAMAS="${SOL_METAMAS:-}"
export BTC_BITKUB="${BTC_BITKUB:-}"
export HOME_ADDRESS="${HOME_ADDRESS:-}"


# ============================================================
#--FB PAGE
# ============================================================

# - lookforward
export FACEBOOK_PAGE_TOKEN="${FACEBOOK_PAGE_TOKEN:-}"

export FACEBOOK_PAGE_ID="${FACEBOOK_PAGE_ID:-}"

# -- Shpee page คัดแต่สิ่งที่คุณคู้ควร
export SHOPEE_PAGE_TOKEN="${SHOPEE_PAGE_TOKEN:-}"

export SHOPEE_PAGE_ID="${SHOPEE_PAGE_ID:-}"

# ── OpenCode Go zen (Joe's preferred AI provider) ──
# Key pool: แยกตาม profile เพื่อกันปนกันและ track อายุการใช้งาน
# Schema: $OC_KEY_<PROFILE>    — secret (per-profile)
#         $OC_BASE_URL         — OpenCode Go API endpoint (shared)

# ของแม่ (mom) — key ใหม่ต่อวันที่ 2026-07-25
export OC_KEY_MOM="${OC_KEY_MOM:-}"

# ของพี่โจ (joe) — key เก่า ใช้ได้ปกติ
export OC_KEY_JOE="${OC_KEY_JOE:-}"

# OpenCode Zen (joe เท่านั้น — ใช้ Claude Sonnet)
export OC_KEY_ZEN="${OC_KEY_ZEN:-}"

# Shared endpoint
export OC_BASE_URL="https://opencode.ai/zen/go/v1"

# Aliases กลาง — backward compat (alias เก่าที่หลายไฟล์เรียกใช้)
# Default follows $profile (mom). Override with:  pf joe  |  pf mom
# ai_profile() ใน joe.sh จะ overwrite ตอนสลับ profile
export OPENCODE_GO_API_KEY="$OC_KEY_MOM"
export OPENCODE_API_KEY="$OC_KEY_MOM"
export OPENCODE_ZEN_API_KEY="$OC_KEY_ZEN"
export OPENCODE_GO_BASE_URL="$OC_BASE_URL"

# ============================================================
# BACKUP — Single Source of Truth for backup paths
# ============================================================
# Override per-env by exporting BACKUP_DIR before sourcing.
# Default: ~/backups (cross-platform: works on WSL, Termux, Git Bash)
# Used by: bkp / bkpi / bkpl / bkls in functions/00.1-function-tools.sh
# ============================================================
export BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
mkdir -p "$BACKUP_DIR" 2>/dev/null

# ============================================================
# 7. DEFAULT EDITOR (JOE_ENV-aware)
# ============================================================
# SSOT rule: ตั้ง EDITOR/VISUAL ตาม environment เพื่อให้ทุก tool
# (git commit, crontab -e, sudoedit, npm config edit) เรียก editor
# ที่ถูกต้องอัตโนมัติ
#
# Joe's typical flow:
#   Windows Git Bash → ssh WSL (tw) → joe.sh loads → EDITOR=micro
#   WSL/TERMUX  → micro    (GUI-feel terminal editor)
#   GIT-BASH    → code     (VS Code ที่มีอยู่บน Windows) — fallback
#   fallback    → nano
# ============================================================

case "$JOE_ENV" in
    WSL|TERMUX|MUMU)
        if command -v micro >/dev/null 2>&1; then
            export EDITOR="micro"
            export VISUAL="micro"
        else
            export EDITOR="nano"
            export VISUAL="nano"
        fi
        ;;
    GIT-BASH)
        # micro.exe ติดตั้งยากบน Git Bash → fallback เป็น VS Code
        if command -v code >/dev/null 2>&1; then
            export EDITOR="code --wait"
            export VISUAL="code --wait"
        elif command -v nano >/dev/null 2>&1; then
            export EDITOR="nano"
            export VISUAL="nano"
        else
            export EDITOR="notepad"
            export VISUAL="notepad"
        fi
        ;;
    *)
        export EDITOR="nano"
        export VISUAL="nano"
        ;;
esac
#-- Zshshell-setup
zsh_setup(){
    local device=${1:-$MY_DEVICE} #-- TERMUX || MUMU
    local zsh_path="${SSOT:-$HOME/ssot}/profiles/${device}/.zshrc"
        case "$device" in
            TERMUX|termux)
                    if  [[ -f "$HOME/.zshrc" ]]; then
                        mv "$HOME/.zshrc" "$HOME/.zshrcbk_by_setup" &&
                        cn 10 bi "done backup .zshrc" &&
                        #rm -f "$HOME/.zshrc" && cn 10 bi "deleted .zshrc" &&
                        ln -s "${zsh_path}" "$HOME/.zshrc" &&
                        [[ -f "$HOME/.zshrc" ]]&&
                        c 10 bi "Done Symlink "${zsh_path}"";c 45 b "-->>";cn 198 b " ~/.zshrc"
                    else
                        ln -s ""${zsh_path}"" "$HOME/.zshrc" &&
                        [[ -f "$HOME/.zshrc" ]]&&
                        c 10 bi "Done Symlink "${zsh_path}"";c 45 b "-->>";cn 198 b " ~/.zshrc"
                    fi
                    ;;
            MUMU|mumu)
                    if  [[ -f "$HOME/.zshrc" ]]; then
                        mv "$HOME/.zshrc" "$HOME/.zshrcbk_by_setup" &&
                        cn 10 bi "done backup .zshrc" &&
                        #rm -f "$HOME/.zshrc" && cn 10 bi "deleted .zshrc" &&
                        ln -s "${zsh_path}" "$HOME/.zshrc" &&
                        [[ -f "$HOME/.zshrc" ]]&&
                        c 10 bi "Done Symlink "${zsh_path}"";c 45 b "-->>";cn 198 b " ~/.zshrc"
                    else
                        ln -s ""${zsh_path}"" "$HOME/.zshrc" &&
                        [[ -f "$HOME/.zshrc" ]]&&
                        c 10 bi "Done Symlink "${zsh_path}"";c 45 b "-->>";cn 198 b " ~/.zshrc"
                    fi
                    ;;
            *)
                    cn y b "้run zsh_setup <TERMUX or MUMU>"
                    return 0
                    ;;
        esac


}








