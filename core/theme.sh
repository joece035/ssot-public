#!/bin/bash
# ======================================================
# 🎨 JOE'S TERMINAL THEME & PROMPT (WSL Ubuntu Edition)
# ======================================================

# 1. Colors & escape helpers (PS1-safe: ทุก escape sequence ต้องหุ้มด้วย \[ ... \])
# รองรับ psc <color> [style] <text...> ตามมาตรฐาน SSOT Color Engine V3 (core/01-colors.sh)
if ! command -v psc >/dev/null 2>&1; then
    _color_src="${SSOT:-${SCRIPTS_PATH:-$HOME/ssot}}/core/01-colors.sh"
    [[ -f "$_color_src" ]] && source "$_color_src" 2>/dev/null
fi

# Fallback escape helper กรณีรันแยกเดี่ยวและยังไม่ได้ source 01-colors.sh
if ! command -v psc >/dev/null 2>&1; then
    psc() {
        local c="${1:-}" s="${2:-}" t="${3:-}"
        local num="$c"
        case "$c" in
            r) num=196;; lr) num=203;; g) num=82;; lg) num=46;; y) num=226;;
            cr) num=51;; b) num=33;; ora) num=208;; gr) num=244;;
        esac
        local st=""
        [[ "$s" =~ b ]] && st+="\e[1m"
        [[ "$s" =~ d ]] && st+="\e[2m"
        printf '\[\e[38;5;%sm%b\]%s\[\e[0m\]' "$num" "$st" "$t"
    }
fi

# 2. ฟังก์ชันตรวจสอบ Git Branch แบบไม่หน่วงเครื่อง (Lightweight Git Status)
_git_prompt() {
    if command -v git >/dev/null 2>&1; then
        local branch
        branch=$(git branch --show-current 2>/dev/null)
        if [ -n "$branch" ]; then
            if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
                psc y b " 🌿 ${branch}*"
            else
                psc 82 b " 🌿 ${branch}"
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
  smart_prompt(){
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
            PS1=" $(psc lg b "  -→  ") "
        else
            PS1=" $(psc lr b "  -→  ") "
        fi
        return
    fi
    # ─────────────────────────────────────────────────────────────
	}	
	smart_prompt
    local last_status_raw='(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧'
    local last_status
    if [ $exit_code -eq 0 ]; then
        last_status="$(psc lg b "$last_status_raw")"
    else
        last_status="$(psc lr b "$last_status_raw")"
    fi

    # -- environment / current shell
    local cur_env="${JOE_ENV:-${MY_DEVICE:-WSL2}}"
    local cur_shell="${_SHELL:-${SHELL##*/}}"
    local env_tag="< $(psc 198 b "$cur_env") : $(psc ora b "$cur_shell") >"

    # -- USER@HOST
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-wsl2}"
    local user_host="$(psc cr b "$cur_user") @ $(psc y b "$cur_host")"

    # -- Current Dir & Git
    local current_dir="$(psc 242 "\w")"
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

    local text_len=$(( 9 + (${#cur_env} + ${#cur_shell} + 7) + 1 + (${#cur_user} + 3 + ${#cur_host}) + 4 + ${#raw_pwd} + git_branch_len + 9 ))

    local lens=$text_len
    (( lens > (term_w - 2) )) && lens=$(( term_w - 2 ))
    (( lens < 20 )) && lens=40

    local BN_BORDER_CHAR_TOP="${BOT_LINE:-$'\u2581'}"
    local BN_BORDER_CHAR_BOT="${TOP_LINE:-$'\u2594'}"

    local _str_t=""
    local _str_b=""
    for (( _i = 1; _i <= lens; _i++ )); do
        _str_t+="${BN_BORDER_CHAR_TOP}"
        _str_b+="${BN_BORDER_CHAR_BOT}"
    done
    local border_top="$(psc 54 d "${_str_t}")"
    local border_bot="$(psc 54 d "${_str_b}")"
		local sep=$(psc 54 b '|')
    # -- ประกอบร่าง Dynamic PS1 (Prompt)
    local PS1_=""
    PS1_+="${border_top}\n"
    PS1_+="${sep} ${last_status} ${env_tag} ${user_host} in ${current_dir}${git_info} ${sep}\n"
    PS1_+="${border_bot}\n"
    PS1_+=" -→ "

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
