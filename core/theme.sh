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
    local _cur_row=0

    # 1. อ่านตำแหน่ง Cursor ปัจจุบัน
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        local _old_stty
        _old_stty=$(stty -g 2>/dev/null)
        stty -echo 2>/dev/null
        printf '\033[6n' >/dev/tty 2>/dev/null
        IFS='[;R' read -r -d 'R' _ _cur_row _ </dev/tty 2>/dev/null
        stty "$_old_stty" 2>/dev/null
    fi

    [[ "$_cur_row" =~ ^[0-9]+$ ]] || _cur_row=0

    local _prev_row=${_SSOT_LAST_ROW:-0}
    _SSOT_LAST_ROW=$_cur_row

    # ดึงจำนวนบรรทัดทั้งหมดของหน้าจอ Terminal ปัจจุบัน
    local _max_lines=${LINES:-$(tput lines 2>/dev/null || echo 24)}

    # 2. คำนวณ Delta
    local _delta=$(( _cur_row - _prev_row ))
    (( _delta < 0 )) && _delta=$(( -_delta ))

    # -------------------------------------------------------------
    # 🎯 SMART PROMPT LIFECYCLE (v2):
    # 1. Clear screen หรือ cursor กระโดดขึ้นบนสุด (_cur_row <= 2 หรือ _cur_row < _prev_row)
    #    -> แสดง Full Banner ทันที
    # 2. เลื่อนลงมาระหว่างกลางจอ (_cur_row < _max_lines) และเคยแสดง Banner ไปแล้ว
    #    -> แสดง Mini Prompt (-→ ) เสมอ เพราะ Banner บนสุดยังอยู่บนหน้าจอแน่นอน
    # 3. Output ก้อนใหญ่ดัน Cursor จากกลางจอลงมามิดขอบล่าง (_delta กระโดด)
    #    -> เช่น คำสั่ง seq, ls, cat, for-loop ที่ดันจอลงมาจนชนขอบล่าง -> แสดง Full Banner
    # 4. Cursor ติดขอบล่างจออยู่แล้ว (_cur_row >= _max_lines)
    #    -> ถ้าเป็นคำสั่งเงียบ (cd, export, enter ว่าง) ให้คง Mini Prompt ไว้
    #    -> ถ้าเป็นคำสั่งที่มี output รันติดต่อกันจนพ้นจอ ให้แสดง Full Banner
    # -------------------------------------------------------------
    local show_mini=0

    # CASE 1: Clear screen หรือ cursor กระโดดขึ้นบนสุด
    if (( _cur_row <= 2 || (_cur_row < _prev_row && _prev_row > 2) )); then
        _SSOT_BANNER_SHOWN=1
        _SSOT_SCROLL_COUNT=0
        show_mini=0

    # CASE 2: อยู่ระหว่างกลางจอ (_cur_row < _max_lines) และเคยแสดง Banner แล้ว
    elif (( _cur_row < _max_lines && ${_SSOT_BANNER_SHOWN:-0} == 1 )); then
        show_mini=1

    # CASE 3: Output ก้อนใหญ่ดันลงมาจากกลางจอจนชนขอบล่าง (_prev_row อยู่ห่างจากขอบล่างเกิน 4 บรรทัด)
    elif (( _cur_row >= _max_lines && _prev_row > 0 && _prev_row < (_max_lines - 4) )); then
        _SSOT_BANNER_SHOWN=1
        _SSOT_SCROLL_COUNT=0
        show_mini=0

    # CASE 4: ติดขอบล่างจออยู่แล้ว (_cur_row >= _max_lines)
    else
        # เช็คคำสั่งล่าสุดจาก history (ถ้ามี)
        local last_cmd=""
        if [[ $- == *i* ]]; then
            last_cmd=$(history 1 2>/dev/null | sed -E 's/^[ ]*[0-9]+[ ]*//')
        fi

        # ถ้าเป็นคำสั่งที่ไม่มี output (cd, pushd, popd, export, unset หรือเคาะ Enter เปล่า)
        if [[ -z "$last_cmd" || "$last_cmd" =~ ^(cd|pushd|popd|export|unset)([[:space:]]|$) ]]; then
            show_mini=1
        else
            # ถ้าเป็นคำสั่งที่มี output (เช่น seq, ls, git, cat, for ... done)
            _SSOT_SCROLL_COUNT=$(( ${_SSOT_SCROLL_COUNT:-0} + 1 ))
            if (( _SSOT_SCROLL_COUNT < 2 )); then
                show_mini=1
            else
                _SSOT_SCROLL_COUNT=0
                _SSOT_BANNER_SHOWN=1
                show_mini=0
            fi
        fi
    fi

    # ถ้าเข้าเงื่อนไข Mini Prompt: พิมพ์แค่ -→ แล้วจบฟังก์ชันทันที
    if (( show_mini == 1 )); then
        if [ $exit_code -eq 0 ]; then
            PS1=" $(psc lg b "  -→  ") "
        else
            PS1=" $(psc lr b "  -→  ") "
        fi
        return
    fi

    local last_status_raw='(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧'
    local last_status
    if [ $exit_code -eq 0 ]; then
        last_status="$(mc b "$last_status_raw")"
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
    local current_dir="$(psc 242 "${PWD/#$HOME/\~}")"
    local git_info="$(_git_prompt)"
    local sep="$(psc 54 b '|')"

    # -- 1. รวมเนื้อหาของแถวกลางจริงที่จะแสดงผล
    local prompt_content="${sep} ${last_status} ${env_tag} ${user_host} in ${current_dir}${git_info} ${sep}"

    # -- 2. Dynamic border calculation: ยิงวัดความกว้างรอบเดียว (One-Shot)
    local term_w
    term_w=$(tput cols 2>/dev/null || echo 80)
    (( term_w < 40 )) && term_w=80

    local text_len
    text_len=$(_w "$prompt_content")

    local lens=$text_len
    (( lens > (term_w - 2) )) && lens=$(( term_w - 2 ))
    (( lens < 20 )) && lens=40

    local BN_BORDER_CHAR_TOP="${BOT_LINE:-$'\u2581'}"
    local BN_BORDER_CHAR_BOT="${TOP_LINE:-$'\u2594'}"

    local _str_t="" _str_b=""
    for (( _i = 1; _i <= lens; _i++ )); do
        _str_t+="${BN_BORDER_CHAR_TOP}"
        _str_b+="${BN_BORDER_CHAR_BOT}"
    done
    local border_top="$(psc 54 b "${_str_t}")"
    local border_bot="$(psc 54 b "${_str_b}")"

    # -- 3. ประกอบร่าง Dynamic PS1 (Prompt)
    local PS1_=""
    PS1_+="${border_top}\n"
    PS1_+="${prompt_content}\n"
    PS1_+="${border_bot}\n"
    PS1_+=" -→ "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

# ✅ FIX 4: ลบ duplicate — เหลือแค่ชุดเดียว
_SSOT_LAST_ROW=0
_SSOT_BANNER_SHOWN=0
_SSOT_SCROLL_COUNT=0
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

echo

