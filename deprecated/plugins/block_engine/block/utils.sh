#!/bin/bash
# ============================================================
# block/utils.sh — Shared utilities for JOE_BLOCK engine
# ============================================================
# Constants : EMO_W  EMO_L  EMO_R  V2E_GAP  PAD_X
# Functions : _blk_init  _blk_repeat_char  _blk_str_width
# ============================================================

# -- Emoji visual-width constant (all envs = 2 cols)
EMO_W=2

# -- Layout constants (Single Source of Truth)
EMO_L=4      # cells for left emoji column
EMO_R=5      # cells for right emoji column
V2E_GAP=2    # spaces after value before right icon
PAD_X=2      # inner horizontal padding

# ============================================================
# _blk_init — capture TERM_WIDTH
#   Call from interactive shell BEFORE any pipe (pipe subshell
#   makes tput cols return 80). Once TERM_WIDTH is set, skip.
# ============================================================
_blk_init() {
    [[ -n "${TERM_WIDTH:-}" ]] && return 0
    TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
}

# ============================================================
# _blk_repeat_char <char> <count>
#   Prints <char> repeated <count> times (no newline)
# ============================================================
# ============================================================
# _pvar <varname> <format> [args...] — Cross-shell printf -v
#   bash: printf -v (fast, no subshell)
#   zsh:  eval + printf (compatible fallback)
# ============================================================
_pvar() {
    local _var="$1"; shift
    # Both bash and zsh support printf -v
    printf -v "$_var" "$@"
}

# ============================================================
# _split_pipe <input_var_name> <string>
#   Splits <string> on '|' into the array named <input_var_name>.
#   Cross-shell — bash 4+ and zsh 5+.
#   Usage:
#     _split_pipe parts "$row"
#     echo "${#parts[@]}"   # array length
#     echo "${parts[2]}"    # 3rd field
#   Why a function (not inline): bash's `read -ra` errors in zsh
#   (`bad option: -a`); zsh's `${(@s:|:)}` is a syntax error in bash.
#   Centralizing the shell detect keeps the rest of the engine clean.
# ============================================================
_split_pipe() {
    local _arr_name="$1"
    local _str="$2"
    # Resolve the array name in the caller's scope.
    # bash 4.2+: namerefs ; zsh 5+: typeset -g
    if [[ -n "${BASH_VERSION:-}" ]]; then
        # bash: IFS + read -ra into the named array via nameref
        local -n _out="$_arr_name"
        IFS='|' read -ra _out <<< "$_str"
    else
        # zsh: split with (s:|:) and assign to the global array
        # (zsh arrays are auto-global unless declared `local -a` in fn)
        eval "${_arr_name}=(\"\${(@s:|:)_str}\")"
    fi
}

# ============================================================
# _blk_repeat_char <char> <count>
#   Prints <char> repeated <count> times (no newline)
# ============================================================
_blk_repeat_char() {
    local char="$1"
    local count="$2"
    (( count <= 0 )) && return 0
    _pvar _rpt_spaces '%*s' "$count" ''
    printf '%s' "${_rpt_spaces// /$char}"
}

# ============================================================
# _blk_repeat_pattern <pattern> <target_w>
#   Repeats <pattern> until visual width reaches <target_w>.
#   Truncates any overflow so total output visual width is EXACTLY <target_w>.
#   Supports single-char and multi-char patterns (e.g., "▫▭▫", "▮▭", "━").
# ============================================================
_blk_repeat_pattern() {
    local pat="$1"
    local target_w="$2"
    (( target_w <= 0 )) && return 0
    [[ -z "$pat" ]] && { _blk_repeat_char " " "$target_w"; return 0; }

    local pat_len=${#pat}
    if (( pat_len <= 1 )); then
        _blk_repeat_char "$pat" "$target_w"
        return 0
    fi

    local reps=$(( target_w / pat_len ))
    local rem=$(( target_w % pat_len ))

    local result=""
    local i
    for (( i=0; i<reps; i++ )); do
        result+="$pat"
    done

    if (( rem > 0 )); then
        result+="${pat:0:$rem}"
    fi

    printf '%s' "$result"
}

# ============================================================
# _blk_str_width <string>
#   Returns visual column-width of <string> (ANSI escapes ignored).
#   Accuracy tiers (no hard external dependency):
#     1. wcwidth.wcswidth  — if the `wcwidth` package is installed
#        (handles flags, ZWJ sequences, variation selectors, combining marks)
#     2. emoji-aware east_asian_width fallback — built-in unicodedata only:
#        - regional-indicator pairs (flags) → 2 cols per pair
#        - variation selectors / ZWJ / combining marks (Mn) → 0 cols
#        - emoji pictograph ranges → 2 cols (fixes ea 'N' emoji like 🖥 ⏱)
#        - CJK W/F → 2 cols, else 1
#     3. ${#str} — only if python3 itself is unavailable
# ============================================================
_blk_str_width() {
    local str="$1"
    [[ -z "$str" ]] && { echo 0; return 0; }

    if command -v python3 &>/dev/null; then
        python3 - "$str" 2>/dev/null <<'PYEOF' || printf '%s' "${#str}"
import sys, re, unicodedata
s = sys.argv[1]
# strip ANSI CSI escape sequences — both real ESC (\x1b) and literal "\e"
# (theme color codes are stored as literal \e[...m and resolved by echo -e)
s = re.sub(r'(?:\x1b|\\e)\[[0-?]*[ -/]*[@-~]', '', s)

# --- tier 1: wcwidth (most accurate) ---
try:
    from wcwidth import wcswidth
    w = wcswidth(s)
    if w >= 0:
        print(w)
        sys.exit(0)
except ImportError:
    pass

# --- tier 2: emoji-aware east_asian_width fallback ---
def is_pictograph(cp):
    return (0x1F300 <= cp <= 0x1FAFF or   # emoticons / pictographs / supplemental
            0x2600 <= cp <= 0x26FF or      # misc symbols
            0x2700 <= cp <= 0x27BF or      # dingbats
            0x2B00 <= cp <= 0x2BFF)        # misc symbols & arrows

chars = list(s)
n = len(chars)
i = 0
w = 0
while i < n:
    c = chars[i]
    cp = ord(c)
    cat = unicodedata.category(c)
    # zero-width: combining marks, ZWJ, variation selectors
    if cat == 'Mn' or cp == 0x200D or 0xFE00 <= cp <= 0xFE0F or 0xE0100 <= cp <= 0xE01EF:
        i += 1
        continue
    # regional indicator pair → flag glyph (2 cols per pair)
    if 0x1F1E6 <= cp <= 0x1F1FF:
        j = i
        while j < n and 0x1F1E6 <= ord(chars[j]) <= 0x1F1FF:
            j += 1
        w += ((j - i + 1) // 2) * 2
        i = j
        continue
    # VS16 (U+FE0F) right after this char → forces emoji presentation → 2 cols
    has_vs16 = (i + 1 < n) and (ord(chars[i + 1]) == 0xFE0F)
    if is_pictograph(cp) or has_vs16:
        w += 2
        i += 1
        continue
    ea = unicodedata.east_asian_width(c)
    w += 2 if ea in ('W', 'F') else 1
    i += 1
print(max(w, 0))
PYEOF
    else
        # --- tier 3: no python3 — rough codepoint count ---
        local plain
        plain=$(printf '%s' "$str" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
        printf '%s' "${#plain}"
    fi
}

# ============================================================
# _blk_str_widths — batch visual-width (reads lines from stdin)
#   Same accuracy tiers as _blk_str_width, but ONE python3 call
#   for many strings (fast path for _blk_scan).
#   Usage: printf '%s\n' "str1" "str2" | _blk_str_widths
# ============================================================
_blk_str_widths() {
    if command -v python3 &>/dev/null; then
        python3 - "$@" 2>/dev/null <<'PYEOF'
import sys, re, unicodedata

def wc(s):
    s = re.sub(r'(?:\x1b|\\e)\[[0-?]*[ -/]*[@-~]', '', s)
    try:
        from wcwidth import wcswidth
        w = wcswidth(s)
        if w >= 0:
            return w
    except ImportError:
        pass
    def is_pictograph(cp):
        return (0x1F300 <= cp <= 0x1FAFF or
                0x2600 <= cp <= 0x26FF or
                0x2700 <= cp <= 0x27BF or
                0x2B00 <= cp <= 0x2BFF)
    chars = list(s)
    n = len(chars)
    i = 0
    w = 0
    while i < n:
        c = chars[i]
        cp = ord(c)
        cat = unicodedata.category(c)
        if cat == 'Mn' or cp == 0x200D or 0xFE00 <= cp <= 0xFE0F or 0xE0100 <= cp <= 0xE01EF:
            i += 1
            continue
        if 0x1F1E6 <= cp <= 0x1F1FF:
            j = i
            while j < n and 0x1F1E6 <= ord(chars[j]) <= 0x1F1FF:
                j += 1
            w += ((j - i + 1) // 2) * 2
            i = j
            continue
        has_vs16 = (i + 1 < n) and (ord(chars[i + 1]) == 0xFE0F)
        if is_pictograph(cp) or has_vs16:
            w += 2
            i += 1
            continue
        ea = unicodedata.east_asian_width(c)
        w += 2 if ea in ('W', 'F') else 1
        i += 1
    return max(w, 0)

for a in sys.argv[1:]:
    print(wc(a))
PYEOF
        return 0
    fi

    # fallback: ไม่มี python3 — นับ codepoint คร่าว ๆ
    local s
    for s in "$@"; do
        printf '%s\n' "${#s}"
    done
}

# ============================================================
# _blk_truncate <str> <max_w> — ตัด string ตาม visual width
#   (กันตัดกลาง emoji / กวาดเกินช่อง) — ใช้ตอน value ยาวเกิน
# ============================================================
_blk_truncate() {
    local str="$1" max_w="$2"
    local w cut
    w="$(_blk_str_width "$str")"
    cut=${#str}
    while (( w > max_w && cut > 1 )); do
        cut=$(( cut - 1 ))
        str="${str:0:cut}"
        w="$(_blk_str_width "$str")"
    done
    printf '%s' "$str"
}

# ============================================================
# _mask_token <value> — mask secret (โชว์ 4 ตัวแรก/4 ตัวท้าย)
# ============================================================
_mask_token() {
    local v="$1"
    if [[ -z "$v" ]]; then
        printf '%s' "(unset)"
    elif (( ${#v} <= 8 )); then
        printf '%s' "****"
    else
        printf '%s' "${v:0:4}****${v: -4}"
    fi
}
