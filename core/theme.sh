#!/bin/bash
# ======================================================
# 🎨 JOE'S TERMINAL THEME & PROMPT (WSL Ubuntu Edition)
# ======================================================

# 1. Colors & escape helpers (PS1-safe: ทุก escape sequence ต้องหุ้มด้วย \[ ... \])
_ps_c() { echo -n "\[\e[38;5;${1}m\]"; }
_ps_r() { echo -n "\[\e[0m\]"; }
_ps_b() { echo -n "\[\e[1m\]"; }
_ps_d() { echo -n "\[\e[2m\]"; }

# 2. ฟังก์ชันตรวจสอบ Git Branch แบบไม่หน่วงเครื่อง (Lightweight Git Status)
_git_prompt() {
    if command -v git >/dev/null 2>&1; then
        local branch
        branch=$(git branch --show-current 2>/dev/null)
        if [ -n "$branch" ]; then
            if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
                echo -n "$(_ps_b)$(_ps_c 226) 🌿 ${branch}*$(_ps_r)"
            else
                echo -n "$(_ps_b)$(_ps_c 82) 🌿 ${branch}$(_ps_r)"
            fi
        fi
    fi
}

# 3. ฟังก์ชันสร้างเส้นแบ่ง (Border line)
_draw_border() {
    local char="${1:-┈}"
    local count="${2:-40}"
    (( count < 1 )) && count=1
    printf '%.0s'"$char" $(seq 1 "$count")
}

# 4. ประกอบร่างเป็น Dynamic PS1 (Prompt) — BASH ONLY
if [[ -n "${BASH_VERSION:-}" ]]; then

_set_prompt() {
    local exit_code=$?

    # ─── SMART PROMPT GUARD ───────────────────────────────────────
    local _cur_row=0
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        local _old_stty
        _old_stty=$(stty -g 2>/dev/null)
        stty -echo 2>/dev/null
        printf '\033[6n' >/dev/tty 2>/dev/null
        IFS='[;R' read -r -d 'R' _ _cur_row _ </dev/tty 2>/dev/null
        stty "$_old_stty" 2>/dev/null
    fi
    # ✅ FIX 1: sanitize — ป้องกัน arithmetic crash เมื่ออ่านไม่ได้
    [[ "$_cur_row" =~ ^[0-9]+$ ]] || _cur_row=0

    # ✅ FIX 2: บันทึก prev ก่อน update _SSOT_LAST_ROW
    local _prev_row=${_SSOT_LAST_ROW:-0}
    _SSOT_LAST_ROW=$_cur_row

    local _delta=$(( _cur_row - _prev_row ))
    (( _delta < 0 )) && _delta=$(( -_delta ))

    # ✅ FIX 3: เช็ค _prev_row (ไม่ใช่ _SSOT_LAST_ROW ที่ update แล้ว)
    if (( _delta < 5 && _prev_row > 5 )); then
        if [ $exit_code -eq 0 ]; then
            PS1=" $(_ps_b)$(_ps_c 198)❯$(_ps_c 208)─$(_ps_c 196)♥$(_ps_c 208)─$(_ps_c 198)❯$(_ps_r) "
        else
            PS1=" $(_ps_b)$(_ps_c 196)❯─♥─❯$(_ps_r) "
        fi
        return
    fi
    # ─────────────────────────────────────────────────────────────

    local last_status_raw="▏▎▍▌▋▊▉█"
    local last_status
    if [ $exit_code -eq 0 ]; then
        last_status="$(_ps_b)$(_ps_c 46)${last_status_raw}$(_ps_r)"
    else
        last_status="$(_ps_b)$(_ps_c 196)${last_status_raw}$(_ps_r)"
    fi

    # -- environment / current shell
    local cur_env="${JOE_ENV:-${MY_DEVICE:-WSL2}}"
    local cur_shell="${_SHELL:-${SHELL##*/}}"
    local env_tag="< $(_ps_b)$(_ps_c 198)${cur_env}$(_ps_r) : $(_ps_b)$(_ps_c 208)${cur_shell}$(_ps_r) >"

    # -- USER@HOST
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-wsl2}"
    local user_host="$(_ps_b)$(_ps_c 51)${cur_user}$(_ps_r) @ $(_ps_b)$(_ps_c 226)${cur_host}$(_ps_r)"

    # -- Current Dir & Git
    local current_dir="$(_ps_c 242)\w$(_ps_r)"
    local git_info="$(_git_prompt)"

    # -- Dynamic border calculation
    local term_w
    term_w=$(tput cols 2>/dev/null || echo 80)
    (( term_w < 40 )) && term_w=80

    local raw_pwd="${PWD/#$HOME/\~}"
    local git_branch_len=0
    if command -v git >/dev/null 2>&1; then
        local b
        b=$(git branch --show-current 2>/dev/null)
        [[ -n "$b" ]] && git_branch_len=$(( ${#b} + 5 ))
    fi

    local text_len=$(( 8 + 1 + (${#cur_env} + ${#cur_shell} + 7) + 1 + (${#cur_user} + 3 + ${#cur_host}) + 4 + ${#raw_pwd} + git_branch_len ))

    local lens=$text_len
    (( lens > (term_w - 2) )) && lens=$(( term_w - 2 ))
    (( lens < 20 )) && lens=40

    local BN_BORDER_CHAR="┈"
    local borde="$(_ps_d)$(_ps_c 235)$(_draw_border "$BN_BORDER_CHAR" "$lens")$(_ps_r)"

    # -- ประกอบร่าง Dynamic PS1 (Prompt)
    local PS1_=""
    PS1_+="${borde}\n"
    PS1_+="${last_status} ${env_tag} ${user_host} in ${current_dir}${git_info}\n"
    PS1_+="${borde}\n"
    PS1_+=" $(_ps_b)$(_ps_c 198)❯$(_ps_c 208)─$(_ps_c 196)♥$(_ps_c 208)─$(_ps_c 198)❯$(_ps_r) "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

# ✅ FIX 4: ลบ duplicate — เหลือแค่ชุดเดียว
_SSOT_LAST_ROW=0
export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_set_prompt

elif [[ -n "${ZSH_VERSION:-}" ]]; then
    unset PROMPT_COMMAND
    export -n PROMPT_COMMAND 2>/dev/null || true
fi

# 5. Show Fastfetch (only in interactive WSL shells with logo)
if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
    if [ "$JOE_ENV" = "WSL" ]; then
        clear
        fastfetch --logo ubuntu
    fi
fi
