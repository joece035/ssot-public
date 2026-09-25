#!/usr/bin/env bash
# ============================================================
# joe_theme / _lib.sh — shared prompt library (PS1-safe)
# ------------------------------------------------------------
# กฎ AGENTS.md: สีทุกจุดต้องมาจาก core/01-colors.sh (Color Engine V3)
#   psc <เลขสี> [style] <text>  -> fragment สำหรับ PS1 (หุ้ม \[ ... \] ให้เอง)
#   _w  <text>                  -> ความกว้างที่แสดงจริง
#   c / cn                      -> print สี (ใช้ตอนอยู่นอก PS1)
# ห้ามเขียน ANSI escape literal ในไฟล์ plugin แม้แต่บรรทัดเดียว
# (รวมถึงใน comment ด้วย)
#
# ทำไมใช้ psc ไม่ใช่ c/cn : ทั้ง 3 ตัวอยู่ใน 01-colors.sh แต่ c/cn คืน escape
#   เปล่า ๆ ถ้าใส่ใน PS1 readline จะนับความกว้างบรรทัดผิด (พิมพ์แล้ว cursor
#   เพี้ยน/ตัดบรรทัดมั่ว) psc หุ้มทุกตัวด้วย \[ ... \] ให้แล้ว
#
# หมายเหตุ: ถ้า terminal ไม่ตอบ cursor-position report (_joe_ctx) จะ fallback
#   เป็น full banner เสมอ — ไม่ใช่ error
# ------------------------------------------------------------
# API:
#   _joe_ctx    <state_prefix>                       -> ตั้ง _JOE_MINI (0/1)
#   _joe_w      <text>                               -> คอลัมน์ที่แสดงจริง
#   _joe_fit    <text>                               -> ความกว้าง border ที่พอดีจอ
#   _joe_border <width> <char> <color> [style]       -> border 1 บรรทัด (PS1-safe)
#   _joe_git    <prefix> <color> [style] [dirty_color] [dirty_char]
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "source-only"; exit 1; }

_JOE_THEME_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# 1. COLOR ENGINE — โหลด core/01-colors.sh ถ้ายังไม่มีใน session
# ============================================================
if ! command -v psc >/dev/null 2>&1; then
    for _joe_color_src in \
        "${SSOT:-${SCRIPTS_PATH:-$HOME/ssot}}/core/01-colors.sh" \
        "$_JOE_THEME_ROOT/../../core/01-colors.sh"
    do
        if [[ -f "$_joe_color_src" ]]; then
            source "$_joe_color_src" 2>/dev/null
            break
        fi
    done
    unset _joe_color_src
fi

# degrade: engine มาไม่ถึง -> คืน text เปล่า ๆ ไม่ hardcode escape
if ! command -v psc >/dev/null 2>&1; then
    psc() {
        local -a _a=("$@")
        local _n=${#_a[@]}
        (( _n >= 3 )) && { printf '%s' "${_a[*]:2}"; return 0; }
        if (( _n == 2 )); then
            [[ "$2" =~ ^[bdiu]{1,4}$ ]] || printf '%s' "$2"
        fi
        return 0
    }
fi
if ! command -v _w >/dev/null 2>&1; then
    _w() { printf '%s' "${#1}"; }
fi

# ============================================================
# 2. WIDTH — วัด "ก่อน" ประกอบ border เสมอ (หัวใจของ dynamic border)
# ============================================================
# _joe_w <text> — ความกว้างที่แสดงจริง
#   ตัด marker \n ของ PS1 ทิ้งก่อน เพราะมันคือ "ขึ้นบรรทัดใหม่"
#   ไม่ใช่คอลัมน์  (ถ้าไม่ตัด border จะยาวเกิน 2 ช่องเสมอ)
_joe_w() {
    local _t="$1"
    _t="${_t//\\n/}"
    _w "$_t"
}

# _joe_fit <text> — ความกว้าง border = ความกว้าง content แต่ไม่ชนขอบจอ
_joe_fit() {
    local _w_cur _w_term
    _w_cur=$(_joe_w "$1")
    [[ "$_w_cur" =~ ^[0-9]+$ ]] || _w_cur=0
    _w_term=$(tput cols 2>/dev/null)
    [[ "$_w_term" =~ ^[0-9]+$ ]] || _w_term=${COLUMNS:-80}
    (( _w_term < 12 )) && _w_term=12
    (( _w_cur > _w_term - 2 )) && _w_cur=$((_w_term - 2))
    (( _w_cur < 4 )) && _w_cur=4
    printf '%s' "$_w_cur"
}

# _joe_border <width> <char> <color> [style] — border หนึ่งบรรทัด
_joe_border() {
    local _bw="$1" _ch="$2" _bc="${3:-240}" _bs="${4:-d}" _s="" _i
    [[ "$_bw" =~ ^[0-9]+$ ]] || _bw=0
    (( _bw < 1 )) && _bw=1
    for ((_i = 0; _i < _bw; _i++)); do _s+="$_ch"; done
    psc "$_bc" "$_bs" "$_s"
}

# ============================================================
# 3. GIT SEGMENT — branch + dirty flag (PS1-safe)
#    _joe_git <prefix> <color> [style] [dirty_color] [dirty_char]
#    prefix ถูกพิมพ์แบบ dim สี 243 (เช่น " on ", " ⎇ ", " ::")
# ============================================================
_joe_git() {
    local _pre="$1" _col="$2" _st="${3:-b}" _dc="${4:-221}" _dc_char="${5:-*}"
    local _branch _dirty=""
    command -v git >/dev/null 2>&1 || return 0
    _branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    [[ -n "$_branch" ]] || return 0
    [[ -n "$(git status --porcelain 2>/dev/null)" ]] && _dirty="$(psc "$_dc" "" "$_dc_char")"
    printf '%s%s%s' "$(psc 243 d "$_pre")" "$(psc "$_col" "$_st" "$_branch")" "$_dirty"
}

# ============================================================
# 4. PROMPT LIFECYCLE — full banner vs mini prompt
#    _joe_ctx <state_prefix>
#      เก็บ state ใน ${prefix}_PREV_ROW / ${prefix}_BANNER (แยกกันตาม theme)
#      ผลลัพธ์: _JOE_MINI (0 = full banner, 1 = mini prompt)
# ============================================================
_joe_ctx() {
    local _pfx="${1:-_SSOT}"
    local _prev_var="${_pfx}_PREV_ROW" _banner_var="${_pfx}_BANNER"
    local _cur=0 _raw="" _col="" _max=0 _q=""

    # ถามตำแหน่ง cursor ผ่าน terminfo (u7) — ไม่เขียน escape ตรง ๆ
    if [[ -t 0 && -t 1 && -e /dev/tty ]]; then
        _q="$(tput u7 2>/dev/null)"
        if [[ -n "$_q" ]]; then
            printf '%s' "$_q" >/dev/tty 2>/dev/null
            # ต้องใช้ 2 ตัวแปร (row/col) — ถ้ามี variable เดียว คำตอบจะถูก
            # รวมกันเป็นบรรทัดเดียว แล้ว parse ตำแหน่ง cursor พัง
            IFS=';' read -t 0.1 -s -d R _raw _col </dev/tty 2>/dev/null || true
        fi
    fi
    _raw="${_raw#*[}"
    [[ "$_raw" =~ ^([0-9]+) ]] && _cur="${BASH_REMATCH[1]}"

    _max="$(tput lines 2>/dev/null)"
    [[ "$_max" =~ ^[0-9]+$ ]] || _max=${LINES:-24}
    [[ "$_max" =~ ^[0-9]+$ ]] || _max=24

    local _prev="${!_prev_var:-0}" _banner="${!_banner_var:-0}"
    [[ "$_prev" =~ ^[0-9]+$ ]] || _prev=0
    [[ "$_banner" =~ ^[0-9]+$ ]] || _banner=0

    # CASE 1: จอถูก clear หรือ cursor กระโดดขึ้นบน -> full banner
    # CASE 2: cursor อยู่กลางจอ และเคยแสดง banner แล้ว -> mini
    local _mini=0
    if (( _cur <= 2 || (_cur < _prev && _prev > 2) )); then
        _banner=1
    elif (( _cur < _max && _banner == 1 )); then
        _mini=1
    fi

    printf -v "$_prev_var" '%d' "$_cur"
    printf -v "$_banner_var" '%d' "$_banner"
    _JOE_MINI=$_mini
    return 0
}
