#!/usr/bin/env python3


import os
import shutil
import subprocess


def _run(cmd):
    """รันคำสั่ง shell ตรงๆ แล้วคืน exit status (ใช้กับคำสั่งที่ไม่ได้แปลงเป็น python) """
    return subprocess.run(cmd, shell=True).returncode


def _sh(cmd):
    """รันคำสั่ง shell แล้วคืนผลลัพธ์ stdout (เทียบเท่า $(...) ใน bash) """
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.rstrip("\n")


def _ok(cmd):
    """คืน True เมื่อคำสั่ง exit status = 0 (เทียบเท่าการเช็ค condition ใน if) """
    return subprocess.run(cmd, shell=True).returncode == 0



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
# bash: if [[ -f "$HOME/.env" ]]; then
if os.path.exists(f"{HOME}/.env"):  # ใส่ : แทน then
    # bash: source "$HOME/.env"
    exec(open(f"{HOME}/.env").read())  # source -> exec(open().read()); $VAR -> f-string {VAR}
# bash: elif [[ -f "${SSOT:-$HOME/ssot}/.env" ]]; then
elif os.path.exists("${SSOT:-" + str(HOME) + "/ssot}/.env"):  # ใส่ : แทน then
    # bash: source "${SSOT:-$HOME/ssot}/.env"
    exec(open("${SSOT:-" + str(HOME) + "/ssot}/.env").read())  # source -> exec(open().read())
# bash: elif [[ -f "${SCRIPTS_PATH:-$HOME/ssot}/.env" ]]; then
elif os.path.exists("${SCRIPTS_PATH:-" + str(HOME) + "/ssot}/.env"):  # ใส่ : แทน then
    # bash: source "${SCRIPTS_PATH:-$HOME/ssot}/.env"
    exec(open("${SCRIPTS_PATH:-" + str(HOME) + "/ssot}/.env").read())  # source -> exec(open().read())
# bash: fi
# -> จบ if — python เยื้องกลับ (dedent) แทน fi

# 2. Shared Secrets (decrypted from vault): ~/.env.secret
# bash: if [[ -f "$HOME/.env.secret" ]]; then
if os.path.exists(f"{HOME}/.env.secret"):  # ใส่ : แทน then
    # bash: source "$HOME/.env.secret"
    exec(open(f"{HOME}/.env.secret").read())  # source -> exec(open().read()); $VAR -> f-string {VAR}
# bash: elif [[ -f "${SSOT:-$HOME/ssot}/.env.secret" ]]; then
elif os.path.exists("${SSOT:-" + str(HOME) + "/ssot}/.env.secret"):  # ใส่ : แทน then
    # bash: source "${SSOT:-$HOME/ssot}/.env.secret"
    exec(open("${SSOT:-" + str(HOME) + "/ssot}/.env.secret").read())  # source -> exec(open().read())
# bash: fi
# -> จบ if — python เยื้องกลับ (dedent) แทน fi

# ============================================================
# 1. WORKSPACE PATHS (Derived from JOE_ENV basics)
# ============================================================


# bash: case "$JOE_ENV" in
match JOE_ENV:  # case -> match/case (python 3.10+)
    # bash: TERMUX)
    case _ if str(JOE_ENV) == "TERMUX":  # แยกเงื่อนไข case -> case:
        # bash: export HERMES_DIR="/data/data/com.termux/files/home/.hermes"
        HERMES_DIR = "/data/data/com.termux/files/home/.hermes"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export PYTHON_VENV="$HOME/.dash_venv/bin/activate"
        PYTHON_VENV = f"{HOME}/.dash_venv/bin/activate"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
        # bash: export SDCARD_PATH="/storage/emulated/0/"
        SDCARD_PATH = "/storage/emulated/0/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export NODE_HOST="termux"
        NODE_HOST = "termux"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: MUMU)
    case _ if str(JOE_ENV) == "MUMU":  # แยกเงื่อนไข case -> case:
        # bash: export HERMES_DIR="/data/data/com.termux/files/home/.hermes"
        HERMES_DIR = "/data/data/com.termux/files/home/.hermes"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export PYTHON_VENV="$HOME/.dash_venv/bin/activate"
        PYTHON_VENV = f"{HOME}/.dash_venv/bin/activate"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
        # bash: export SDCARD_PATH="/storage/emulated/0/"
        SDCARD_PATH = "/storage/emulated/0/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export NODE_HOST="mumu"
        NODE_HOST = "mumu"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: OPPO)
    case _ if str(JOE_ENV) == "OPPO":  # แยกเงื่อนไข case -> case:
        # bash: export HERMES_DIR="/data/data/com.termux/files/home/.hermes"
        HERMES_DIR = "/data/data/com.termux/files/home/.hermes"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export PYTHON_VENV="$HOME/.dash_venv/bin/activate"
        PYTHON_VENV = f"{HOME}/.dash_venv/bin/activate"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
        # bash: export SDCARD_PATH="/storage/emulated/0/"
        SDCARD_PATH = "/storage/emulated/0/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export NODE_HOST="oppo"
        NODE_HOST = "oppo"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: ACODEX)
    case _ if str(JOE_ENV) == "ACODEX":  # แยกเงื่อนไข case -> case:
        # bash: export NODE_HOST="acodex"
        NODE_HOST = "acodex"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: WSL)
    case _ if str(JOE_ENV) == "WSL":  # แยกเงื่อนไข case -> case:
        # bash: export HERMES_DIR="$HOME/.hermes"
        HERMES_DIR = f"{HOME}/.hermes"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
        # bash: export PYTHON_VENV="$HOME/.venv/bin/activate"
        PYTHON_VENV = f"{HOME}/.venv/bin/activate"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
        # bash: export NODE_HOST="wsl"
        NODE_HOST = "wsl"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export WIN_PATH="/mnt/"
        WIN_PATH = "/mnt/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export HWSL="$HOME"
        HWSL = HOME  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export HWSL2="unseen"
        HWSL2 = "unseen"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: WSL2)
    case _ if str(JOE_ENV) == "WSL2":  # แยกเงื่อนไข case -> case:
        # bash: export HERMES_DIR="$HOME/.hermes"
        HERMES_DIR = f"{HOME}/.hermes"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
        # bash: export PYTHON_VENV="$HOME/.venv/bin/activate"
        PYTHON_VENV = f"{HOME}/.venv/bin/activate"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
        # bash: export NODE_HOST="wsl2"
        NODE_HOST = "wsl2"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export WIN_PATH="/mnt/"
        WIN_PATH = "/mnt/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export HWSL="unseen"
        HWSL = "unseen"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export HWSL2="$HOME"
        HWSL2 = HOME  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: GIT-BASH)
    case _ if str(JOE_ENV) == "GIT-BASH":  # แยกเงื่อนไข case -> case:
        # bash: export HERMES_DIR="/mnt/c/Users/User/AppData/Local/hermes"
        HERMES_DIR = "/mnt/c/Users/User/AppData/Local/hermes"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export PYTHON_VENV="$HWSL/.venv/bin/activate"
        PYTHON_VENV = f"{HWSL}/.venv/bin/activate"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
        # bash: export NODE_HOST="window"
        NODE_HOST = "window"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export WIN_PATH='/'
        WIN_PATH = "/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export HWSL="//wsl.localhost/Ubuntu/home/usercivenz"
        HWSL = "//wsl.localhost/Ubuntu/home/usercivenz"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export HWSL2="//wsl.localhost/Ubuntu-22.04/home/joez"
        HWSL2 = "//wsl.localhost/Ubuntu-22.04/home/joez"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

    # bash: *)
    case _:  # แยกเงื่อนไข case -> case:
        # bash: export PYTHON_VENV="$htm/.dash_venv/bin/activate"
        PYTHON_VENV = f"{htm}/.dash_venv/bin/activate"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
        # bash: export NODE_HOST="linux"
        NODE_HOST = "linux"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: esac
# -> จบ case — python เยื้องกลับแทน esac

# ============================================================
# 2. GLOBAL VARIABLE
# ============================================================
# bash: export hwsl=${HWSL}
hwsl = HWSL  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export hwsl2=${HWSL2}
hwsl2 = HWSL2  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export bsc="$HOME/bashscripts"
bsc = f"{HOME}/bashscripts"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export ssot="$HOME/ssot"
ssot = f"{HOME}/ssot"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export profile=mom
profile = "mom"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export oppc="$hpc/openclaw"
oppc = f"{hpc}/openclaw"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export dpc="$hpc/Desktop"
dpc = f"{hpc}/Desktop"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export dtpc="$hpc/Desktop"          # compat alias ของ dpc
dtpc = f"{hpc}/Desktop"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export hmp="${HERMES_DIR:-$HOME/.hermes}"   # AGENT.md: hmp = $HOME/.hermes
hmp = "${HERMES_DIR:-" + str(HOME) + "/.hermes}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export HERMES_LOG_DIR="${HERMES_DIR}/logs"  # log dir สำหรับ tools/hermes.sh
HERMES_LOG_DIR = f"{HERMES_DIR}/logs"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export BRAVE_SEARCH_API_KEY="${BRAVE_SEARCH_API_KEY:-}"
BRAVE_SEARCH_API_KEY = "${BRAVE_SEARCH_API_KEY:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export BRAVE_API_KEY="${BRAVE_API_KEY:-$BRAVE_SEARCH_API_KEY}"
BRAVE_API_KEY = "${BRAVE_API_KEY:-" + str(BRAVE_SEARCH_API_KEY) + "}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ALPHA_DIR="$msync/alpha-workspace"
ALPHA_DIR = f"{msync}/alpha-workspace"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export alpha=${ALPHA_DIR}
alpha = ALPHA_DIR  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export storage="/storage/emulated/0/" # sdcrd
storage = "/storage/emulated/0/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ais_fiber="880-563-6522"
ais_fiber = "880-563-6522"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ais_phone="0814764210"
ais_phone = "0814764210"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export space="\u2003\u2003\u2003\u2003"
space = "\\u2003\\u2003\\u2003\\u2003"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export bin="$HOME/.local/bin"
bin = f"{HOME}/.local/bin"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}

# bash: if [[ -n "${ZSH_VERSION:-}" ]]; then
if "${ZSH_VERSION:-}":  # ใส่ : แทน then
    # bash: export _SHELL="zsh"
    _SHELL = "zsh"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: elif [[ -n "${BASH_VERSION:-}" ]]; then
elif "${BASH_VERSION:-}":  # ใส่ : แทน then
    # bash: export _SHELL="bash"
    _SHELL = "bash"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: else
else:  # else: (ไม่ต้องมี then)
    # bash: export _SHELL="${_SHELL:-${SHELL##*/}}"
    _SHELL = "${_SHELL:-${SHELL##*/}}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: fi
# -> จบ if — python เยื้องกลับ (dedent) แทน fi
# bash: export _USER="${USER:-${USERNAME:-$(whoami 2>/dev/null)}}"
_USER = "${USER:-${USERNAME:-" + (_sh("whoami 2>/dev/null")) + "}}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $(cmd) -> _sh() (subprocess)
# bash: export pftermux="${SSOT}/profiles/termux"
pftermux = f"{SSOT}/profiles/termux"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export ptwsl="${SSOT}/profiles/wsl"
ptwsl = f"{SSOT}/profiles/wsl"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export pfmumu="${SSOT}/profiles/mumu"
pfmumu = f"{SSOT}/profiles/mumu"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export pfwin="${SSOT}/profiles/git-bash"
pfwin = f"{SSOT}/profiles/git-bash"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# ============================================================
# SupperBoom env
# ============================================================

# bash: export ssboom="${WIN_PATH}c/Users/User/Documents/mumusharedfolder/Screenshots"
ssboom = f"{WIN_PATH}c/Users/User/Documents/mumusharedfolder/Screenshots"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export vdoboom="${WIN_PATH}c/Users/User/Documents/MuMuSharedFolder/VideoRecords"
vdoboom = f"{WIN_PATH}c/Users/User/Documents/MuMuSharedFolder/VideoRecords"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export bk_vdoboom="${WIN_PATH}h/boom/VideoRecords"
bk_vdoboom = f"{WIN_PATH}h/boom/VideoRecords"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export bk_ssboom="${WIN_PATH}h/boom/Screenshots"
bk_ssboom = f"{WIN_PATH}h/boom/Screenshots"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# ============================================================
# Dynamic env switching
# ============================================================
# bash: ai_bin() {
def ai_bin():  # ฟังก์ชัน bash -> def name():
    # bash: if command -v openclaw >/dev/null 2>&1; then
    if _ok("command -v openclaw >/dev/null 2>&1"):  # ใส่ : แทน then
        # bash: export OPENCLAW_BIN="openclaw"
        OPENCLAW_BIN = "openclaw"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: else
    else:  # else: (ไม่ต้องมี then)
        # bash: unset OPENCLAW_BIN
        # TODO: 'unset' ไม่มีใน python ตรงตัว: unset OPENCLAW_BIN
    # bash: fi
    # -> จบ if — python เยื้องกลับ (dedent) แทน fi
    # bash: if command -v hermes >/dev/null 2>&1; then
    if _ok("command -v hermes >/dev/null 2>&1"):  # ใส่ : แทน then
        # bash: export HERMES_BIN="hermes"
        HERMES_BIN = "hermes"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: else
    else:  # else: (ไม่ต้องมี then)
        # bash: unset HERMES_BIN
        # TODO: 'unset' ไม่มีใน python ตรงตัว: unset HERMES_BIN
    # bash: fi
    # -> จบ if — python เยื้องกลับ (dedent) แทน fi
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }
# bash: ai_bin
_run("ai_bin")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
# ============================================================
# 2. SERVICE PATHS & DIRECTORIES
# ============================================================

# Use dbp from boot.sh (already set correctly for environment

# bash: export ENGINES_DIR="$DASHBOARD_DIR/api/engines"
ENGINES_DIR = f"{DASHBOARD_DIR}/api/engines"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}

# ============================================================
# 3. PYTHON & VIRTUAL ENVIRONMENT
# ============================================================


# Python activation script
# bash: export DASHBOARD_PYTHON="$PYTHON_VENV"
DASHBOARD_PYTHON = PYTHON_VENV  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# Python I/O encoding
# bash: export PYTHONIOENCODING="utf-8"
PYTHONIOENCODING = "utf-8"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# ============================================================
# 3.5 MATH HELPER DEFAULTS (used by m() in 00.1-function-tools.sh)
# ============================================================
# Excel-style: default 2 decimals, round-half-up
# bash: export MATH_DEFAULT_SCALE="${MATH_DEFAULT_SCALE:-0}"
MATH_DEFAULT_SCALE = "${MATH_DEFAULT_SCALE:-0}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export MATH_DEFAULT_MODE="${MATH_DEFAULT_MODE:-round}"   # round | up | down
MATH_DEFAULT_MODE = "${MATH_DEFAULT_MODE:-round}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# ============================================================
# 4. NODE & BUILD SETTINGS
# ============================================================

# bash: export NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
NODE_COMPILE_CACHE = "/var/tmp/openclaw-compile-cache"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# ============================================================
# 5. OPENCLAW CONFIGURATION
# ============================================================

# bash: export OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1
OPENCLAW_ALLOW_INSECURE_PRIVATE_WS = 1  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export OPENCLAW_NO_RESPAWN=1
OPENCLAW_NO_RESPAWN = 1  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export CURRENT_OC_PROFILE="${CURRENT_OC_PROFILE:-None (Default)}"
CURRENT_OC_PROFILE = "${CURRENT_OC_PROFILE:-None (Default)}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

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
# bash: if command -v tailscale >/dev/null 2>&1; then
if _ok("command -v tailscale >/dev/null 2>&1"):  # ใส่ : แทน then
    # bash: export TAILSCALE_BIN="tailscale"
    TAILSCALE_BIN = "tailscale"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: if [[ "$JOE_ENV" != "GIT-BASH" ]]; then
    if str(JOE_ENV) != "GIT-BASH":  # ใส่ : แทน then
        # bash: export TAILSCALE_STATUS="$(tailscale status 2>/dev/null || echo "tailscale not running")"
        TAILSCALE_STATUS = _sh("tailscale status 2>/dev/null || echo \"tailscale not running\"")  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $(cmd) -> _sh() (subprocess)
        # bash: export TAILSCALE_IP="$(tailscale ip -4 2>/dev/null || echo "tailscale not running")"
        TAILSCALE_IP = _sh("tailscale ip -4 2>/dev/null || echo \"tailscale not running\"")  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $(cmd) -> _sh() (subprocess)
    # bash: else
    else:  # else: (ไม่ต้องมี then)
        # bash: export TAILSCALE_STATUS="available"
        TAILSCALE_STATUS = "available"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export TAILSCALE_IP="100.69.181.45"
        TAILSCALE_IP = "100.69.181.45"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: fi
    # -> จบ if — python เยื้องกลับ (dedent) แทน fi
# bash: else
else:  # else: (ไม่ต้องมี then)
    # bash: export TAILSCALE_STATUS="tailscale not running"
    TAILSCALE_STATUS = "tailscale not running"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: export TAILSCALE_IP="tailscale not running"
    TAILSCALE_IP = "tailscale not running"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: fi
# -> จบ if — python เยื้องกลับ (dedent) แทน fi
# bash: export TAILSCALE_IP_TERMUX=100.110.26.16
TAILSCALE_IP_TERMUX = "100.110.26.16"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export TAILSCALE_IP_WINDOW=100.69.181.45
TAILSCALE_IP_WINDOW = "100.69.181.45"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export TAILSCALE_IP_WSL=100.80.195.120
TAILSCALE_IP_WSL = "100.80.195.120"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export TAILSCALE_IP_MUMU=100.100.176.94
TAILSCALE_IP_MUMU = "100.100.176.94"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export TAILSCALE_IP_OPPO=100.82.29.18
TAILSCALE_IP_OPPO = "100.82.29.18"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export TAILSCALE_IP_WSL2=100.93.45.16
TAILSCALE_IP_WSL2 = "100.93.45.16"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# ── Dynamic Node Registry Loader (drop-in profiles from $SSOT/bootstrap/nodes/*.node.env) ──
# bash: if [[ -f "${SSOT:-$HOME/ssot}/bootstrap/nodes/loader.sh" ]]; then
if os.path.exists("${SSOT:-" + str(HOME) + "/ssot}/bootstrap/nodes/loader.sh"):  # ใส่ : แทน then
    # bash: source "${SSOT:-$HOME/ssot}/bootstrap/nodes/loader.sh"
    exec(open("${SSOT:-" + str(HOME) + "/ssot}/bootstrap/nodes/loader.sh").read())  # source -> exec(open().read())
# bash: fi
# -> จบ if — python เยื้องกลับ (dedent) แทน fi

# ============================================================
# COMPATIBILITY LAYER — Phase 1
# All legacy variable names re-exported from Node Registry.
# DO NOT remove these until all consumers migrate to NODE_* vars.
# ============================================================

# Termux compat
# bash: export TERMUX_IP="${NODE_TERMUX_HOST:-$NODE_TERMUX_IP}"
TERMUX_IP = "${NODE_TERMUX_HOST:-" + str(NODE_TERMUX_IP) + "}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export TERMUX_USER="$NODE_TERMUX_USER"
TERMUX_USER = NODE_TERMUX_USER  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export TERMUX_PORT="$NODE_TERMUX_PORT"
TERMUX_PORT = NODE_TERMUX_PORT  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export TERMUX_TELSCAIL_IP="$NODE_TERMUX_HOST"
TERMUX_TELSCAIL_IP = NODE_TERMUX_HOST  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ST_KEY_TERMUX="$NODE_TERMUX_ST_KEY"
ST_KEY_TERMUX = NODE_TERMUX_ST_KEY  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ST_PORT_TERMUX="$NODE_TERMUX_ST_PORT"
ST_PORT_TERMUX = NODE_TERMUX_ST_PORT  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export URL_TERMUX="${NODE_TERMUX_ST_URL}/"
URL_TERMUX = f"{NODE_TERMUX_ST_URL}/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}

# WSL compat
# bash: export WSL_IP="${NODE_WSL_HOST:-$NODE_WSL_IP}"
WSL_IP = "${NODE_WSL_HOST:-" + str(NODE_WSL_IP) + "}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export WSL_USER="$NODE_WSL_USER"
WSL_USER = NODE_WSL_USER  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export WSL_TELSCAIL_IP="$NODE_WSL_HOST"
WSL_TELSCAIL_IP = NODE_WSL_HOST  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ST_KEY_WSL="$NODE_WSL_ST_KEY"
ST_KEY_WSL = NODE_WSL_ST_KEY  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ST_PORT_WSL="$NODE_WSL_ST_PORT"
ST_PORT_WSL = NODE_WSL_ST_PORT  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export URL_WSL="${NODE_WSL_ST_URL}/"
URL_WSL = f"{NODE_WSL_ST_URL}/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}

# WSL2 compat
# bash: export WSL2_IP="${NODE_WSL2_HOST:-$NODE_WSL2_IP}"
WSL2_IP = "${NODE_WSL2_HOST:-" + str(NODE_WSL2_IP) + "}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export WSL2_USER="$NODE_WSL2_USER"
WSL2_USER = NODE_WSL2_USER  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export WSL2_TELSCAIL_IP="$NODE_WSL2_HOST"
WSL2_TELSCAIL_IP = NODE_WSL2_HOST  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ST_KEY_WSL2="$NODE_WSL2_ST_KEY"
ST_KEY_WSL2 = NODE_WSL2_ST_KEY  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ST_PORT_WSL2="$NODE_WSL2_ST_PORT"
ST_PORT_WSL2 = NODE_WSL2_ST_PORT  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export URL_WSL2="${NODE_WSL2_ST_URL}/"
URL_WSL2 = f"{NODE_WSL2_ST_URL}/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}

# --- Windows compat
# WIN_GIT_BASH: path ของ Git Bash บน Windows (ใช้โดย tw() ใน 3worlds.sh)
# Windows OpenSSH default shell = PowerShell — tw() ต้องเรียกผ่าน PS call operator
#export WIN_GIT_BASH="C:\PROGRA~1\Git\bin\bash.exe"
# bash: export WINDOWS_IP="${NODE_WIN_HOST:-$NODE_WIN_IP}"
WINDOWS_IP = "${NODE_WIN_HOST:-" + str(NODE_WIN_IP) + "}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export WINDOWS_USER="$NODE_WIN_USER"
WINDOWS_USER = NODE_WIN_USER  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ST_KEY_WIN="$NODE_WIN_ST_KEY"
ST_KEY_WIN = NODE_WIN_ST_KEY  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ST_PORT_WIN="$NODE_WIN_ST_PORT"
ST_PORT_WIN = NODE_WIN_ST_PORT  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export URL_WIN="${NODE_WIN_ST_URL}/"
URL_WIN = f"{NODE_WIN_ST_URL}/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}
# bash: export WIN_GIT_BASH="C:/Program Files/Git/bin/bash.exe"
WIN_GIT_BASH = "C:/Program Files/Git/bin/bash.exe"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# MUMUPlayer compat (Android emulator peer)
# bash: export MUMU_IP="${NODE_MUMU_HOST:-$NODE_MUMU_IP}"
MUMU_IP = "${NODE_MUMU_HOST:-" + str(NODE_MUMU_IP) + "}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export MUMU_USER="$NODE_MUMU_USER"
MUMU_USER = NODE_MUMU_USER  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export MUMU_PORT="$NODE_MUMU_PORT"
MUMU_PORT = NODE_MUMU_PORT  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export MUMU_TELSCAIL_IP="$NODE_MUMU_HOST"
MUMU_TELSCAIL_IP = NODE_MUMU_HOST  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ST_KEY_MUMU="$NODE_MUMU_ST_KEY"
ST_KEY_MUMU = NODE_MUMU_ST_KEY  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ST_PORT_MUMU="$NODE_MUMU_ST_PORT"
ST_PORT_MUMU = NODE_MUMU_ST_PORT  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export URL_MUMU="${NODE_MUMU_ST_URL}/"
URL_MUMU = f"{NODE_MUMU_ST_URL}/"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export; $VAR -> f-string {VAR}

# ACODEX compat
# bash: export ACODEX_IP="${NODE_ACODEX_HOST:-$NODE_ACODEX_IP}"
ACODEX_IP = "${NODE_ACODEX_HOST:-" + str(NODE_ACODEX_IP) + "}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ACODEX_USER="${NODE_ACODEX_USER:-root}"
ACODEX_USER = "${NODE_ACODEX_USER:-root}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export ACODEX_PORT="${NODE_ACODEX_PORT:-8021}"
ACODEX_PORT = "${NODE_ACODEX_PORT:-8021}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# ============================================================
# EXPORTS COMPLETE — Ready for use in aliases and functions
# All paths are environment-aware and work across WSL, Termux, Linux, Git Bash
# ============================================================

# --- SHORT CUT FOR JOE-- #
# bash: export nx="$nexus_vault"
nx = nexus_vault  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export USDT_BEP20_BITKUB="${USDT_BEP20_BITKUB:-}"
USDT_BEP20_BITKUB = "${USDT_BEP20_BITKUB:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export SOL_BITKUB="${SOL_BITKUB:-}"
SOL_BITKUB = "${SOL_BITKUB:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export SOL_METAMAS="${SOL_METAMAS:-}"
SOL_METAMAS = "${SOL_METAMAS:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export BTC_BITKUB="${BTC_BITKUB:-}"
BTC_BITKUB = "${BTC_BITKUB:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export HOME_ADDRESS="${HOME_ADDRESS:-}"
HOME_ADDRESS = "${HOME_ADDRESS:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export


# ============================================================
#--FB PAGE
# ============================================================

# - lookforward
# bash: export FACEBOOK_PAGE_TOKEN="${FACEBOOK_PAGE_TOKEN:-}"
FACEBOOK_PAGE_TOKEN = "${FACEBOOK_PAGE_TOKEN:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# bash: export FACEBOOK_PAGE_ID="${FACEBOOK_PAGE_ID:-}"
FACEBOOK_PAGE_ID = "${FACEBOOK_PAGE_ID:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# -- Shpee page คัดแต่สิ่งที่คุณคู้ควร
# bash: export SHOPEE_PAGE_TOKEN="${SHOPEE_PAGE_TOKEN:-}"
SHOPEE_PAGE_TOKEN = "${SHOPEE_PAGE_TOKEN:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# bash: export SHOPEE_PAGE_ID="${SHOPEE_PAGE_ID:-}"
SHOPEE_PAGE_ID = "${SHOPEE_PAGE_ID:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# ── OpenCode Go zen (Joe's preferred AI provider) ──
# Key pool: แยกตาม profile เพื่อกันปนกันและ track อายุการใช้งาน
# Schema: $OC_KEY_<PROFILE>    — secret (per-profile)
#         $OC_BASE_URL         — OpenCode Go API endpoint (shared)

# ของแม่ (mom) — key ใหม่ต่อวันที่ 2026-07-25
# bash: export OC_KEY_MOM="${OC_KEY_MOM:-}"
OC_KEY_MOM = "${OC_KEY_MOM:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# ของพี่โจ (joe) — key เก่า ใช้ได้ปกติ
# bash: export OC_KEY_JOE="${OC_KEY_JOE:-}"
OC_KEY_JOE = "${OC_KEY_JOE:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# OpenCode Zen (joe เท่านั้น — ใช้ Claude Sonnet)
# bash: export OC_KEY_ZEN="${OC_KEY_ZEN:-}"
OC_KEY_ZEN = "${OC_KEY_ZEN:-}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# Shared endpoint
# bash: export OC_BASE_URL="https://opencode.ai/zen/go/v1"
OC_BASE_URL = "https://opencode.ai/zen/go/v1"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# Aliases กลาง — backward compat (alias เก่าที่หลายไฟล์เรียกใช้)
# Default follows $profile (mom). Override with:  pf joe  |  pf mom
# ai_profile() ใน joe.sh จะ overwrite ตอนสลับ profile
# bash: export OPENCODE_GO_API_KEY="$OC_KEY_MOM"
OPENCODE_GO_API_KEY = OC_KEY_MOM  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export OPENCODE_API_KEY="$OC_KEY_MOM"
OPENCODE_API_KEY = OC_KEY_MOM  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export OPENCODE_ZEN_API_KEY="$OC_KEY_ZEN"
OPENCODE_ZEN_API_KEY = OC_KEY_ZEN  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: export OPENCODE_GO_BASE_URL="$OC_BASE_URL"
OPENCODE_GO_BASE_URL = OC_BASE_URL  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# ============================================================
# BACKUP — Single Source of Truth for backup paths
# ============================================================
# Override per-env by exporting BACKUP_DIR before sourcing.
# Default: ~/backups (cross-platform: works on WSL, Termux, Git Bash)
# Used by: bkp / bkpi / bkpl / bkls in functions/00.1-function-tools.sh
# ============================================================
# bash: export BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
BACKUP_DIR = "${BACKUP_DIR:-" + str(HOME) + "/backups}"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: mkdir -p "$BACKUP_DIR" 2>/dev/null
_run("mkdir -p \"" + str(BACKUP_DIR) + "\" 2>/dev/null")  # mkdir -> os.makedirs(); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

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

# bash: case "$JOE_ENV" in
match JOE_ENV:  # case -> match/case (python 3.10+)
    # bash: WSL|TERMUX|MUMU|WSL2)
    case _ if any(str(JOE_ENV) == "WSL", str(JOE_ENV) == "TERMUX", str(JOE_ENV) == "MUMU", str(JOE_ENV) == "WSL2"):  # แยกเงื่อนไข case -> case:
        # bash: if command -v micro >/dev/null 2>&1; then
        if _ok("command -v micro >/dev/null 2>&1"):  # ใส่ : แทน then
            # bash: export EDITOR="micro"
            EDITOR = "micro"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
            # bash: export VISUAL="micro"
            VISUAL = "micro"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: else
        else:  # else: (ไม่ต้องมี then)
            # bash: export EDITOR="nano"
            EDITOR = "nano"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
            # bash: export VISUAL="nano"
            VISUAL = "nano"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: fi
        # -> จบ if — python เยื้องกลับ (dedent) แทน fi
    # bash: GIT-BASH)
    case _ if str(JOE_ENV) == "GIT-BASH":  # แยกเงื่อนไข case -> case:
        # micro.exe ติดตั้งยากบน Git Bash → fallback เป็น VS Code
        # bash: if command -v code >/dev/null 2>&1; then
        if _ok("command -v code >/dev/null 2>&1"):  # ใส่ : แทน then
            # bash: export EDITOR="code --wait"
            EDITOR = "code --wait"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
            # bash: export VISUAL="code --wait"
            VISUAL = "code --wait"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: elif command -v nano >/dev/null 2>&1; then
    elif _ok("command -v nano >/dev/null 2>&1"):  # ใส่ : แทน then
        # bash: export EDITOR="nano"
        EDITOR = "nano"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export VISUAL="nano"
        VISUAL = "nano"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: else
    else:  # else: (ไม่ต้องมี then)
        # bash: export EDITOR="notepad"
        EDITOR = "notepad"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export VISUAL="notepad"
        VISUAL = "notepad"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
    # bash: fi
    # -> จบ if — python เยื้องกลับ (dedent) แทน fi
    # bash: *)
    case _:  # แยกเงื่อนไข case -> case:
        # bash: export EDITOR="nano"
        EDITOR = "nano"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
        # bash: export VISUAL="nano"
        VISUAL = "nano"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: esac
# -> จบ case — python เยื้องกลับแทน esac
#-- Zshshell-setup
# bash: zsh_setup(){
def zsh_setup():  # ฟังก์ชัน bash -> def name():
    # bash: local JOE_ENV=${1:-$JOE_ENV} #-- TERMUX || MUMU
    JOE_ENV = "${1:-" + str(JOE_ENV) + "}"  # python ไม่มี local
    # bash: local zsh_path="${SSOT:-$HOME/ssot}/profiles/${device}/.zshrc"
    zsh_path = "${SSOT:-" + str(HOME) + "/ssot}/profiles/" + str(device) + "/.zshrc"  # python ไม่มี local
    # bash: case "$JOE_ENV" in
    match JOE_ENV:  # case -> match/case (python 3.10+)
        # bash: TERMUX|termux)
        case _ if any(str(JOE_ENV) == "TERMUX", str(JOE_ENV) == "termux"):  # แยกเงื่อนไข case -> case:
            # bash: if  [[ -f "$HOME/.zshrc" ]]; then
            if os.path.exists(f"{HOME}/.zshrc"):  # ใส่ : แทน then
                # bash: mv "$HOME/.zshrc" "$HOME/.zshrcbk_by_setup" &&
                _run("mv \"" + str(HOME) + "/.zshrc\" \"" + str(HOME) + "/.zshrcbk_by_setup\"")  # mv -> shutil.move(); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                # bash: cn 10 bi "done backup .zshrc" &&
                _run("cn 10 bi \"done backup .zshrc\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                #rm -f "$HOME/.zshrc" && cn 10 bi "deleted .zshrc" &&
                # bash: ln -s "${zsh_path}" "$HOME/.zshrc" &&
                _run("ln -s \"" + str(zsh_path) + "\" \"" + str(HOME) + "/.zshrc\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                # bash: [[ -f "$HOME/.zshrc" ]]&&
                _run("[[ -f \"" + str(HOME) + "/.zshrc\" ]]")  # [ ] condition -> นิพจน์ python (and/or/not); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                # bash: c 10 bi "Done Symlink "${zsh_path}"";c 45 b "-->>";cn 198 b " ~/.zshrc"
                _run("c 10 bi \"Done Symlink \"" + str(zsh_path) + "\"\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                _run("c 45 b \"-->>\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                _run("cn 198 b \" ~/.zshrc\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
            # bash: else
            else:  # else: (ไม่ต้องมี then)
                # bash: ln -s ""${zsh_path}"" "$HOME/.zshrc" &&
                _run("ln -s \"\"" + str(zsh_path) + "\"\" \"" + str(HOME) + "/.zshrc\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                # bash: [[ -f "$HOME/.zshrc" ]]&&
                _run("[[ -f \"" + str(HOME) + "/.zshrc\" ]]")  # [ ] condition -> นิพจน์ python (and/or/not); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                # bash: c 10 bi "Done Symlink "${zsh_path}"";c 45 b "-->>";cn 198 b " ~/.zshrc"
                _run("c 10 bi \"Done Symlink \"" + str(zsh_path) + "\"\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                _run("c 45 b \"-->>\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                _run("cn 198 b \" ~/.zshrc\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
            # bash: fi
            # -> จบ if — python เยื้องกลับ (dedent) แทน fi
        # bash: MUMU|mumu)
        case _ if any(str(JOE_ENV) == "MUMU", str(JOE_ENV) == "mumu"):  # แยกเงื่อนไข case -> case:
            # bash: if  [[ -f "$HOME/.zshrc" ]]; then
            if os.path.exists(f"{HOME}/.zshrc"):  # ใส่ : แทน then
                # bash: mv "$HOME/.zshrc" "$HOME/.zshrcbk_by_setup" &&
                _run("mv \"" + str(HOME) + "/.zshrc\" \"" + str(HOME) + "/.zshrcbk_by_setup\"")  # mv -> shutil.move(); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                # bash: cn 10 bi "done backup .zshrc" &&
                _run("cn 10 bi \"done backup .zshrc\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                #rm -f "$HOME/.zshrc" && cn 10 bi "deleted .zshrc" &&
                # bash: ln -s "${zsh_path}" "$HOME/.zshrc" &&
                _run("ln -s \"" + str(zsh_path) + "\" \"" + str(HOME) + "/.zshrc\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                # bash: [[ -f "$HOME/.zshrc" ]]&&
                _run("[[ -f \"" + str(HOME) + "/.zshrc\" ]]")  # [ ] condition -> นิพจน์ python (and/or/not); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                # bash: c 10 bi "Done Symlink "${zsh_path}"";c 45 b "-->>";cn 198 b " ~/.zshrc"
                _run("c 10 bi \"Done Symlink \"" + str(zsh_path) + "\"\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                _run("c 45 b \"-->>\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                _run("cn 198 b \" ~/.zshrc\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
            # bash: else
            else:  # else: (ไม่ต้องมี then)
                # bash: ln -s ""${zsh_path}"" "$HOME/.zshrc" &&
                _run("ln -s \"\"" + str(zsh_path) + "\"\" \"" + str(HOME) + "/.zshrc\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                # bash: [[ -f "$HOME/.zshrc" ]]&&
                _run("[[ -f \"" + str(HOME) + "/.zshrc\" ]]")  # [ ] condition -> นิพจน์ python (and/or/not); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                # bash: c 10 bi "Done Symlink "${zsh_path}"";c 45 b "-->>";cn 198 b " ~/.zshrc"
                _run("c 10 bi \"Done Symlink \"" + str(zsh_path) + "\"\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                _run("c 45 b \"-->>\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
                _run("cn 198 b \" ~/.zshrc\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
            # bash: fi
            # -> จบ if — python เยื้องกลับ (dedent) แทน fi
        # bash: *)
        case _:  # แยกเงื่อนไข case -> case:
            # bash: cn y b "้run zsh_setup <TERMUX or MUMU>"
            _run("cn y b \"\u0e49run zsh_setup <TERMUX or MUMU>\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
            # bash: return 0
            return 0  # return เหมือนกันใน python
    # bash: esac
    # -> จบ case — python เยื้องกลับแทน esac


# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }


# bash: export gh_token=-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-
gh_token = "-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-"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export




