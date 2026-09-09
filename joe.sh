#!/bin/bash
# ============================================================
# 🚀 JOE'S PERSONAL COMMAND CENTER — Main Entry Point
# ============================================================
# Works on WSL, Termux (incl. MuMu), and Git Bash via single source.
# Detection order: Termux → WSL → Git Bash → MUMU
# ============================================================

# ── Step 0: JOE_ENV detection (fallback — ปกติ set จาก ~/.env หรือ .bashrc) ──
# ค่าที่ใช้ได้: TERMUX | WSL | GIT-BASH | MUMU

[[ -n "${MY_DEVICE:-}" ]] && export JOE_ENV=${MY_DEVICE:-$JOE_ENV}
if [[ -z "${JOE_ENV:-}" ]]; then
    if [[ -d "/data/data/com.termux" ]]; then
        if [[ -n "${MUMU_DEVICE:-}" ]] || [[ "$(getprop ro.product.model 2>/dev/null)" =~ (MuMu|vphone) ]]; then
            export JOE_ENV="MUMU"
        else
            export JOE_ENV="TERMUX"
        fi
    elif command -v apk >/dev/null 2>&1; then
        # ACODEX: must check before WSL — ACODEX runs on WSL filesystem
        export JOE_ENV="ACODEX"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        export JOE_ENV="WSL"
    elif [[ -n "${MSYSTEM:-}" ]] || [[ "$OSTYPE" == "msys" ]]; then
        export JOE_ENV="GIT-BASH"
    fi
fi


#--- Global constants (machine-independent)



# ── Step 2: Set derived paths based on JOE_ENV ──
# SSOT: respect existing value (set by repo() or ~/.env), only set default if empty
if [[ -z "${SSOT:-}" ]]; then
    case "$JOE_ENV" in
        TERMUX)
            export SSOT="/data/data/com.termux/files/home/ssot"
            ;;
        MUMU)
            export SSOT="/data/data/com.termux/files/home/ssot"
            ;;
        WSL)
            export SSOT="$HOME/ssot"
            ;;
        GIT-BASH)
            export SSOT="$HOME/ssot"
            ;;
        *)
            export SSOT="$HOME/ssot"
            ;;
    esac
fi

# Derived paths (use $SSOT, not hardcoded)
case "$JOE_ENV" in
    TERMUX)
        export DASHBOARD_DIR="$HOME/dashboard"
        export OBSIDIAN_VAULT="/storage/emulated/0/syncthing/hermes_vault"
        export home="$HOME"
        export nexus_vault="$HOME/nexus_vault"
        export MAIN_SYNC_DIR="$HOME/main_sync"
        export SSH_PORT=8022
        ;;
    MUMU)
        export DASHBOARD_DIR="$HOME/dashboard"
        export OBSIDIAN_VAULT="/storage/emulated/0/syncthing/hermes_vault"
        export home="$HOME"
        export nexus_vault="$HOME/nexus_vault"
        export MAIN_SYNC_DIR="$HOME/main_sync"
        export SSH_PORT=8020
        ;;
    WSL)
	    export hpc="/mnt/c/Users/User"
        export hwsl="${hwsl:-$HOME}"
        export DASHBOARD_DIR="$HOME/dashboard"
        export PYTHON_VENV="${PYTHON_VENV:-$HOME/.venv/bin/activate}"
        export OBSIDIAN_VAULT="$hpc/DESKTOP/obsidian/alphadev_vaults"
        export home="$HOME"
        export nexus_vault="$HOME/nexus_vault"
        export MAIN_SYNC_DIR="$HOME/main_sync"
        export SSH_PORT=22
        
        ;;
    GIT-BASH)
        export hpc="$HOME"
        export hwsl="${hwsl:-//wsl.localhost/Ubuntu/home/usercivenz}"
        export DASHBOARD_DIR="$HWSL/dashboard"
        export OBSIDIAN_VAULT="$hpc/DESKTOP/obsidian/alphadev_vaults"
        export home="$HWSL"
        export nexus_vault="$hpc/DESKTOP/nexus_vault"
        export MAIN_SYNC_DIR="$HOME/DESKTOP/main_sync"
        export SSH_PORT=2222
        
        ;;
esac

# -- Global varialble defined after done env detection process
        export SCRIPTS_PATH=$SSOT
        export COLOR_PATH="$SSOT"
        export msync="$MAIN_SYNC_DIR"
        export htm="/data/data/com.termux/files/home"
        export OP_DIR="${HOME}"
        export SSH_MUMU_PORT=8020
        export SSH_TERMUX_PORT=8022
        export SSH_WSL_PORT=22
        export SSH_WIN_PORT=22




# ── Step 1.5: CRLF SELF-HEAL (กันไฟล์ CRLF ทำ bash พัง) ──
# Syncthing sync ข้ามเครื่อง (WSL ↔ Termux/Acode-X ↔ Win ↔ MuMu)
# ถ้าเครื่องไหนแก้ไฟล์แล้วบันทึกเป็น CRLF (Windows/Acode-X) bash จะ
# syntax error ทันที — ตรงนี้แปลงกลับเป็น LF ให้อัตโนมัติก่อน source
# หมายเหตุ: ถ้า joe.sh ตัวเองเป็น CRLF จะ parse ไม่ผ่านมาถึงตรงนี้
# → ต้องมี guard ใน .bashrc ด้วย (ดู .bashrc section 6)
crlf(){

 if [[ "$JOE_ENV" != "GIT-BASH" ]] && command -v grep >/dev/null 2>&1 && command -v sed >/dev/null 2>&1; then
    _crlf_files="$(grep -rlU $'\r' "$SSOT" --include="*.sh" 2>/dev/null)"
    if [[ -n "$_crlf_files" ]]; then
        _crlf_count=0
        while IFS= read -r _f; do
            sed -i 's/\r$//' "$_f"
            _crlf_count=$((_crlf_count+1))
        done <<< "$_crlf_files"
        # Send to STDERR (not STDOUT) so Powerlevel10k instant prompt
        # is not disturbed — p10k flags ANY stdout during init as a
        # problem and prints a multi-line warning to the user.
        echo "⚠️  CRLF auto-fixed: ${_crlf_count} file(s) → LF (มาจากเครื่องอื่น/Windows)" >&2
    fi
 fi
}

# ── Auto start sshd & ssh-agent ──


# Auto-start sshd if not running (guarded for git-bash which lacks pgrep)
# Auto-start ssh-agent if not running (needed for tm/tw key auth)
# Auto-start ssh-agent if not running (needed for tm/tw key auth)

auto_start_ssh(){
  # Auto-start sshd guarded by JOE_ENV
 if [[ "$JOE_ENV" == "WSL" ]]; then
    # WSL: ใช้ service ssh
    if ! service ssh status >/dev/null 2>&1; then
        sudo service ssh start >/dev/null 2>&1 && { command -v cn &>/dev/null && cn 10 b "SSH Service (WSL) started successfully." >&2; } || { command -v cn &>/dev/null && cn 9 b "Failed to start SSH Service." >&2; }
    else
        command -v cn &>/dev/null && cn 10 bi "ssh activated port : ${SSH_PORT}" >&2
    fi
 elif [[ "$JOE_ENV" == "TERMUX" || "$JOE_ENV" == "MUMU" ]]; then
    # Termux / MuMu: ใช้ sshd binary ตรงๆ
    # NOTE: Termux ใหม่ rename process เป็น "sshd-session" ไม่ใช่ "sshd"
    # → pgrep -x sshd ใช้ไม่ได้ ต้อง check จาก port ที่ bind อยู่จริงแทน
    if ! pgrep -f "sshd.*-p.*${SSH_PORT}" >/dev/null 2>&1; then
        sshd -p "$SSH_PORT" >/dev/null 2>&1 && { command -v cn &>/dev/null && cn 10 b "SSH Daemon started on port ${SSH_PORT}." >&2; } || { command -v cn &>/dev/null && cn 9 b "Failed to start sshd on port ${SSH_PORT}." >&2; }
    else
        command -v cn &>/dev/null && cn 10 bi "ssh activated port : ${SSH_PORT}" >&2
    fi
 fi
}



ssot_load(){
    # -- Load all scripts in SSOT folders with priority order --
    if ! typeset -f _check &>/dev/null && [ -f "$SSOT/.bash_helper" ]; then
        source "$SSOT/.bash_helper"
    fi

    local SHOW_LOAD="${1:-""}"
    local source_files=(
        "$SSOT/bootstrap/00-env.sh"
        "$SSOT/core/ssh-config.sh"
        "$SSOT/core/3worlds.sh"
        "$SSOT/core/aliases.sh"
        "$SSOT/core/profiles.sh"
        "$SSOT/core/theme.sh"
        "$SSOT/functions"/*.sh
        "$SSOT/personal/joe_scripts.sh"
    )
    #-- run main cmd
    _check -f "source_files" "source" 2>/dev/null
    #-- เรียกดูไฟล์ท่ถูก source ตามลำดับ
    if [[ -n "${SHOW_LOAD}" && "${SHOW_LOAD}" =~ ^(true|1|yes)$ ]]; then
        local basen_files=() 
        local max_len=0 
        local sf=""

        for sf in "${source_files[@]}"; do
            if [[ -f "$sf" ]]; then
                local f_name=""
                f_name="${sf##*/}"            
                basen_files+=("$f_name")
            fi
        done
        # -- Calculate max length --
        local file_name=""
        local len=0
        local padding=0

        for file_name in "${basen_files[@]}"; do
            len=${#file_name}
            if (( len > max_len )); then
                max_len=$len
            fi
        done
        # -- Print with alignment --
        for file_name in "${basen_files[@]}"; do
            padding=$((max_len - ${#file_name} + 5))
            printf "%s   %s%*s %s\n" \
                "$(c 202 b "source")" \
                "$(c 246 b "$file_name")" \
                "${padding}" "" \
                "$(c 46 b "done")"
        done        
    fi
}

#-- Global shell refresh
pp() {
    clear &&
    LOAD_LIST="${1:-""}"
    AI_PROFILE="${2:-"mom"}"
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        source "$HOME/.zshrc"
        
    else
        source "$HOME/.bashrc"
    fi
    #cn 46 b "✓ Config reloaded!"
}
alias re="pp"

# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
#                      START UP                      #
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
# m a 50  # offset=50 cols from left (was 0=full-center, looked like 'hang' on slow shells)

# Init-time startup tasks — wrapped in { ... } >&2 so any console
# output from syncthing_auto / rc_del goes to STDERR only.
# Required by Powerlevel10k instant prompt (sourced first in .zshrc):
# p10k is strict — ANY stdout during zsh init invalidates the
# instant prompt and prints a multi-line warning to the user.
 {
    unbinding -a g    
    ssot_load ${LOAD_LIST:-}
    pf ${AI_PROFILE:-mom}
    case "$JOE_ENV" in 
        TERMUX|MUMU) rc_delete ;;
    esac
    unset LOAD_LIST
    unset AI_PROFILE

 } >/dev/null 2>&1


{
    if [[ "$JOE_ENV" != "GIT-BASH" ]]; then
        if ! command -v pgrep >/dev/null 2>&1; then
            cn 9 b "pgrep not found, skipping syncthing check"
        elif ! pgrep -f syncthing >/dev/null 2>&1; then
            cn 202 b "syncthing not running, starting..."
                ( syncthing_auto > /dev/null 2>&1 ) &
        else
            cn 202 b "Syncthing is already running"
        fi
    fi
} >/dev/null 2>&1




# Disable nounset after everything is loaded — ble.sh restores set -u
# after each command, but joe.sh uses unset variables (dbp, $2, etc.)
set +u

