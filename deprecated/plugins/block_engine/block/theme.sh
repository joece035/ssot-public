#!/bin/bash
# ============================================================
# block/theme.sh — Theme loader & color compiler
# ============================================================
# Globals written : _THEME[]  (associative array)
#                   _BLK_STYLE_LOADED (cache flag)
# Reads from      : block_style.sh  01-colors.sh
# No eval. Styles set globals via set_() then we harvest them.
# ============================================================
# _THEME keys:
#   data_rows     — which status function to call
#   offset        — position offset (number or NONE)
#   border_random — yes/no
#   frame_random  — yes/no
#   border_char   — repeating char for border
#   frame_char    — repeating char for frame random
#   mid_line      — mid-separator char
#   row_frame_l/r — row frame chars L/R
#   mid_frame_l/r — mid frame chars L/R
#   top_border    — top border char
#   bot_border    — bottom border char
#   mid_sep       — label-value separator
#   mid_line_c    — mid line color spec
#   row_frame_c   — row frame color spec
#   mid_frame_c   — mid frame color spec
#   top_border_c  — top border color spec
#   bot_border_c  — bot border color spec
#   label_c       — label color spec
#   value_c       — value color spec
#   mid_sep_c     — mid-separator color spec
#   --- compiled color strings (ready to print) ---
#   cc_ml         — compiled mid line
#   cc_row_fl/fr  — compiled row frame L/R
#   cc_mid_fl/fr  — compiled mid frame L/R
#   cc_bt         — compiled top border (colored char, not repeated)
#   cc_bb         — compiled bottom border
#   cc_brc        — compiled random border char
#   cc_hrc        — compiled random frame char
# ============================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    declare -g -A _THEME 2>/dev/null || true
else
    typeset -g -A _THEME 2>/dev/null || true
fi

# Evaluate root path at sourcing time
# bash: BASH_SOURCE[0] = file where this code was sourced from.
# zsh:  ${funcsourcetrace[1]} = "file:lineno" (exact equivalent).
# Priority: _BLOCK_ROOT > BASH_SOURCE[0] (bash) / funcsourcetrace (zsh) > fallback
if [[ -n "${_BLOCK_ROOT:-}" ]]; then
    # Already set by entry.sh — use as-is
    _THEME_DIR="${_BLOCK_ROOT}/plugins/block_engine/block"
elif [[ -n "${BASH_VERSION:-}" && -n "${BASH_SOURCE[0]:-}" ]]; then
    _THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _BLOCK_ROOT="${_THEME_DIR}/../../.."
elif [[ -n "${ZSH_VERSION:-}" && -n "${funcsourcetrace[1]:-}" ]]; then
    # funcsourcetrace[1] = "file:lineno" — strip :lineno with %%:*
    _THEME_DIR="$(cd "$(dirname "${funcsourcetrace[1]%%:*}")" && pwd)"
    _BLOCK_ROOT="${_THEME_DIR}/../../.."
else
    _THEME_DIR="${JOE_PLUGINS:-$HOME/ssot/plugins}/block_engine/block"
    _BLOCK_ROOT="${JOE_ROOT:-$HOME/ssot}"
fi

# ============================================================
# _load_theme <style> <offset>
#   Populates _THEME[] from block_style.sh style functions.
#   No eval. Harvests globals written by set_() then cleans up.
# ============================================================
_load_theme() {
    local style="${1:-default}"
    local offset="${2:-}"

    # -- Source colors first (needed by _apply_color_to)
    if [[ -z "${RESET:-}" ]]; then
        [[ -f "${JOE_CORE}/01-colors.sh" ]] && source "${JOE_CORE}/01-colors.sh" && shopt -s expand_aliases 2>/dev/null
    fi

    # -- Source function tools (needed by bc_() and tp() used in _style_* OFFSET calc)
    if ! declare -f bc_ &>/dev/null; then
        [[ -f "${JOE_FUNCTIONS}/00.1-function-tools.sh" ]] && source "${JOE_FUNCTIONS}/00.1-function-tools.sh" 2>/dev/null
    fi

    # -- Source block_style.sh (guard against double-source in same invocation)
    [[ -f "${JOE_PLUGINS}/block_engine/styles/block_style.sh" ]] && source "${JOE_PLUGINS}/block_engine/styles/block_style.sh"
    # -- Source custom styles if exist
    [[ -f "${JOE_ROOT}/lessons/custom_style.sh" ]] && source "${JOE_ROOT}/lessons/custom_style.sh"

    # -- Invoke the style function (it uses set_() to write globals)
    # -- Clear OFFSET and random state before calling style to ensure fresh values
    unset OFFSET 2>/dev/null
    unset '_THEME[cc_rand_border]' '_THEME[cc_rand_frame]' '_THEME[cc_rand_frame_l]' '_THEME[cc_rand_frame_r]' 2>/dev/null
    case "$style" in
        a)       _style_a       ;;
        b)       _style_b       ;;
        c)       _style_c       ;;
        d)       _style_random  ;;
        _s[1-6]) _"$style"      ;;   # custom styles
        *)       _style_default ;;
    esac

    # -- Harvest globals into _THEME (isolate from caller scope)
    _THEME[data_rows]="${_data_ROWS:-status_new}"
    # -- OFFSET priority: caller arg > style-set global > default 0
    _THEME[offset]="${offset:-${OFFSET:-0}}"
    _THEME[border_random]="${BORDER_RANDOM_C:-no}"
    _THEME[frame_random]="${FRAME_RANDOM_C:-no}"
    _THEME[mid_random]="${MID_RANDOM_C:-no}"
    _THEME[border_char]="${BORDER_RANDOM:-▨}"
    _THEME[frame_char]="${FRAME_RANDOM:-‖}"
    _THEME[mid_line]="${MID_LINE:-=}"
    _THEME[row_frame_l]="${ROW_FRAME_L:-|}"
    _THEME[row_frame_r]="${ROW_FRAME_R:-|}"
    _THEME[mid_frame_l]="${MID_FRAME_L:-|}"
    _THEME[mid_frame_r]="${MID_FRAME_R:-|}"
    _THEME[top_border]="${TOP_BORDER:-▰}"
    _THEME[bot_border]="${BOT_BORDER:-▰}"
    _THEME[mid_sep]="${MD_SEP_:- : }"
    _THEME[mid_line_c]="${MID_LINE_C:-gr \"\"}"
    _THEME[row_frame_c]="${ROW_FRAME_C:-gr \"\"}"
    _THEME[mid_frame_c]="${MID_FRAME_C:-gr \"\"}"
    _THEME[top_border_c]="${TOP_BORDER_C:-lg b}"
    _THEME[bot_border_c]="${BOT_BORDER_C:-lg b}"
    _THEME[label_c]="${LABEL_C:-gr \"\"}"
    _THEME[value_c]="${VALUE_C:-w bi}"
    _THEME[mid_sep_c]="${MID_SEP_C:-lg b}"

    # -- Store color palette in _THEME for reliable access in all contexts
    _THEME[_pal_1]="${lr:-}"
    _THEME[_pal_2]="${lb:-}"
    _THEME[_pal_3]="${lg:-}"
    _THEME[_pal_4]="${ora:-}"
    _THEME[_pal_5]="${gr:-}"
    _THEME[_pal_6]="${lm:-}"
    _THEME[_pal_7]="${lc:-}"
    _THEME[_pal_8]="${y:-}"

    # -- Compile colored strings (call _apply_colors)
    _compile_theme_colors
}

# ============================================================
# _apply_color_to <config> <text>
#   Safe color helper — no eval.
#   config format: "<colorname> <style>"  e.g. 'gr ""' or 'w bi'
#   NOTE (V3 01-colors.sh compat): block_style.sh authors use
#     `set_ MID_LINE_C 'gr ""'`  to mean "gray, no style".
#     The literal 2-char string `""` must be normalized to empty
#     BEFORE calling color(), otherwise _color_render's
#     `[[ "$2" == "" ]]` check fails and the literal `""` gets
#     rendered as text (extra "" line in output).
# ============================================================
_apply_color_to() {
    local config="${1:-gr}"
    local text="$2"
    local clr sty
    clr="${config%% *}"
    sty="${config#* }"
    [[ "$sty" == "$clr" ]] && sty=''
    sty="${sty//\'/}"
    sty="${sty//\"/}"          # <-- V3 fix: strip literal double-quotes
    [[ -z "$sty" ]] && sty=''  # <-- V3 fix: ensure truly empty (0 chars)
    color "$clr" "$sty" "$text"
}

# ============================================================
# _compile_theme_colors — pre-render colored chars into _THEME
# ============================================================
_compile_theme_colors() {
    # Random border / frame
    _THEME[cc_brc]="$(rc b "${_THEME[border_char]}")"
    _THEME[cc_hrc]="$(rc1 "" "${_THEME[frame_char]}")"

    # Mid line, row frames, mid frames
    _THEME[cc_ml]="$(_apply_color_to "${_THEME[mid_line_c]}"   "${_THEME[mid_line]}")"
    _THEME[cc_row_fl]="$(_apply_color_to "${_THEME[row_frame_c]}" "${_THEME[row_frame_l]}")"
    _THEME[cc_row_fr]="$(_apply_color_to "${_THEME[row_frame_c]}" "${_THEME[row_frame_r]}")"
    _THEME[cc_mid_fl]="$(_apply_color_to "${_THEME[mid_frame_c]}" "${_THEME[mid_frame_l]}")"
    _THEME[cc_mid_fr]="$(_apply_color_to "${_THEME[mid_frame_c]}" "${_THEME[mid_frame_r]}")"

    # Border chars (single, will be repeated by renderer)
    _THEME[cc_bt]="$(_apply_color_to "${_THEME[top_border_c]}" "${_THEME[top_border]}")"
    _THEME[cc_bb]="$(_apply_color_to "${_THEME[bot_border_c]}" "${_THEME[bot_border]}")"
}
