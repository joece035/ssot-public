#!/bin/bash
# ============================================================
# entry.sh — JOE Block Engine (Public API)
# ============================================================
# Architecture: Rows → Layout → Theme → Renderer → Dashboard
#
# Modules sourced from joe-block/block/:
#   utils.sh    — constants, _blk_init, _blk_repeat_char, _blk_str_width
#   layout.sh   — _blk_scan, _blk_build_layout  (_LAYOUT[])
#   theme.sh    — _load_theme, _apply_color_to   (_THEME[])
#   renderer.sh — render_row, render_mid, render_border_top/bot
#   status.sh   — status_new, op_profile
#
# Public API (backward compatible):
#   dashboard           — reads stdin, renders block
#   dashboard_array     — dashboard_array row1 row2 ...
#   m [style] [offset]  — main entry point
#   m_random [pure|s]   — random style selector
#   m_animate [spd] [cycles] [step]
# ============================================================

# ── Source all modules (idempotent) ──────────────────────────
_blk_source_modules() {
    local _D _self=""
    # Cross-shell detection of the file where THIS function was defined:
    #   bash : BASH_SOURCE[0] is the definition file (native bash).
    #   zsh  : ${funcsourcetrace[1]} is "file:lineno" of the definition
    #          site — exact zsh equivalent of bash's BASH_SOURCE[0].
    #          Strip the ":lineno" suffix with %%:* to get the path.
    #   both : fallback to SCRIPTS_PATH (SSOT).
    if [[ -n "${BASH_VERSION:-}" && -n "${BASH_SOURCE[0]:-}" ]]; then
        _self="${BASH_SOURCE[0]}"
    elif [[ -n "${ZSH_VERSION:-}" && -n "${funcsourcetrace[1]:-}" ]]; then
        _self="${funcsourcetrace[1]%%:*}"
    fi
    if [[ -n "$_self" ]]; then
        _D="$(cd "$(dirname "$_self")" && pwd)/block"
    else
        # Last resort: assume plugins/block_engine/block/ relative to JOE_ROOT
        _D="${JOE_PLUGINS:-$HOME/ssot/plugins}/block_engine/block"
    fi
    # Export _BLOCK_ROOT so theme.sh can use it (avoids BASH_SOURCE issue in zsh)
    # _BLOCK_ROOT must point to ssot/ root (two levels up from block_engine/)
    _BLOCK_ROOT="$(cd "${_D}/../../.." && pwd)"   # ssot/ root (block → block_engine → plugins → ssot)
    export _BLOCK_ROOT
    [[ -f "${_D}/utils.sh"    ]] && source "${_D}/utils.sh"
    [[ -f "${_D}/layout.sh"   ]] && source "${_D}/layout.sh"
    [[ -f "${_D}/theme.sh"    ]] && source "${_D}/theme.sh"
    [[ -f "${_D}/renderer.sh" ]] && source "${_D}/renderer.sh"
    [[ -f "${_D}/status.sh"   ]] && source "${_D}/status.sh"
}
_blk_source_modules

# ============================================================
# dashboard — PUBLIC API
#   Reads rows from stdin (pipe or heredoc), renders full block.
#   Pipeline: scan → layout → theme (already loaded) → render
# ============================================================
dashboard() {
    local ROWS=()
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        ROWS+=("$line")
    done
    [[ ${#ROWS[@]} -eq 0 ]] && return 0

    # Layout pass
    _blk_scan "${ROWS[@]}"
    _blk_build_layout "${_THEME[offset]:-0}"

    # Sync MD_SEP_ from theme into _LAYOUT (renderer uses _LAYOUT[sep])
    _LAYOUT[sep]="${_THEME[mid_sep]:- : }"

    # -- Debug: show offset flow ( uncomment to debug )
    # echo "DEBUG: _THEME[offset]='${_THEME[offset]:-UNSET}'" >&2

    # -- Guard: จอเล็กเกินไป ไม่ render
    (( ${_LAYOUT[block_w]:-0} == 0 )) && return 0

    # Render
    render_border_top

    local i=0
    local _parsed_eml _parsed_label _parsed_value _parsed_emr
    for row in "${ROWS[@]}"; do
        _blk_parse_row "$row"
        render_row "$_parsed_eml" "$_parsed_label" "$_parsed_value" "$_parsed_emr"
        if (( i < ${#ROWS[@]} - 1 )); then
            render_mid
        fi
        (( i++ ))
    done

    render_border_bot
}

# ============================================================
# dashboard_array — PUBLIC API
#   Pass rows as arguments instead of stdin.
#   Usage: dashboard_array row1 row2 ...
# ============================================================
dashboard_array() {
    printf '%s\n' "$@" | dashboard
}

# ============================================================
# m — PUBLIC API  (main entry point)
#   Usage: m [style_or_offset] [offset]
#     m              → default style, centered
#     m a            → style_a
#     m -500         → default style, shifted right
#     m a -500       → style_a, shifted right
# ============================================================
m() {
    local arg1="${1:-}" arg2="${2:-}"
    local style="default" offset=""

    if [[ "$arg1" =~ ^-?[0-9]+$ ]]; then
        offset="$arg1"
    else
        [[ -n "$arg1" ]] && style="$arg1"
        [[ "$arg2" =~ ^-?[0-9]+$ ]] && offset="$arg2"
    fi

    # Capture TERM_WIDTH HERE (interactive shell, before any pipe subshell)
    unset TERM_WIDTH 2>/dev/null
    _blk_init

    # Load theme (sources block_style.sh + 01-colors.sh internally)
    _load_theme "$style" "$offset"

    # Dispatch data provider — no eval, safe case statement (Priority 1)
    case "${_THEME[data_rows]:-status_new}" in
        status_new) status_new ;;
        op_profile)  op_  ;;
        t)  joe_test ;;
        *)           status_new ;;
    esac
}

# ============================================================
# m_random — PUBLIC API
#   Usage: m_random [pure|s]
#     pure (default) — random, repeats allowed
#     s|shuffle      — Fisher-Yates deck, no repeat until full loop
# ============================================================
m_random() {
    local mode="${1:-pure}"
    local styles=("a" "b" "c" "default")

    case "$mode" in
        s|shuffle)
            if [[ -z "${_MR_DECK[*]:-}" ]] || (( ${#_MR_DECK[@]} == 0 )); then
                _MR_DECK=("${styles[@]}")
                local i j tmp
                for (( i=${#_MR_DECK[@]}-1; i>0; i-- )); do
                    j=$(( RANDOM % (i+1) ))
                    tmp="${_MR_DECK[$i]}"
                    _MR_DECK[$i]="${_MR_DECK[$j]}"
                    _MR_DECK[$j]="$tmp"
                done
            fi
            local pick="${_MR_DECK[-1]}"
            unset '_MR_DECK[-1]'
            m "$pick"
            ;;
        *)
            m "${styles[$(( RANDOM % ${#styles[@]} ))]}"
            ;;
    esac
}

# ============================================================
# m_animate — PUBLIC API
#   Ping-pong animation: block slides left ↔ right
#   Usage: m_animate [speed] [cycles] [step]
#     speed  = delay per frame seconds (default 0.05)
#     cycles = back-forth cycles       (default 3)
#     step   = columns per frame       (default 3)
# ============================================================
m_animate() {
    local speed="${1:-0.05}"
    local cycles="${2:-3}"
    local step="${3:-3}"

    _blk_init
    local term_w="${TERM_WIDTH:-80}"

    local -a blk_lines=()
    mapfile -t blk_lines < <(m 2>/dev/null)

    while (( ${#blk_lines[@]} > 0 )) && [[ -z "${blk_lines[-1]}" ]]; do
        unset 'blk_lines[-1]'
    done
    local n=${#blk_lines[@]}
    if (( n == 0 )); then
        echo "m_animate: m ไม่ได้ผลิต output — ลอง m ดูก่อน"
        return 1
    fi

    local blk_width
    blk_width=$(printf '%s' "${blk_lines[0]}" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | wc -c)
    blk_width=$(( blk_width - 1 ))

    local max_pos=$(( term_w - blk_width - 5 ))
    (( max_pos < 5 )) && { echo "m_animate: block กว้างเกินไป (${blk_width}px)"; return 1; }

    trap 'printf "\033[?25h"; tput cnorm 2>/dev/null; return 1' INT TERM
    printf '\033[?25l'

    local p c
    for (( c=0; c<cycles; c++ )); do
        for (( p=0; p<=max_pos; p+=step )); do
            _m_anim_draw blk_lines "$n" "$p"
            sleep "$speed"
        done
        for (( p=max_pos; p>=0; p-=step )); do
            _m_anim_draw blk_lines "$n" "$p"
            sleep "$speed"
        done
    done

    printf '\033[?25h'
    tput cnorm 2>/dev/null
    trap - INT TERM
}

# ── Internal: draw one animation frame ──────────────────────
_m_anim_draw() {
    local -n _la=$1 2>/dev/null || eval "local _la=(\"\${$1[@]}\")"
    local n=$2 pos=$3
    printf '\033[2J\033[H'
    local pad; _pvar pad '%*s' "$pos" ''
    local i
    for (( i=0; i<n; i++ )); do
        printf '%s%s\n' "$pad" "${_la[$i]}"
    done
}

m_test_offsets() {
    # offset -1→+1: -1=left, 0=center, +1=right
    local offsets=(-1 -0.75 -0.5 -0.25 0 0.25 0.5 0.75 1)
    local labels=("ซ้ายสุด" "3/4ซ้าย" "กลางซ้าย" "1/4ซ้าย" "กลาง" "1/4ขวา" "กลางขวา" "3/4ขวา" "ขวาสุด")
    local i=0
    for off in "${offsets[@]}"; do
        cn lg b "─── OFFSET = $off (${labels[$i]}) ───"
        _THEME[offset]="$off"
        local ROWS=(
            "🌟|OFFSET|${off}|⭐"
            "📏|TERM|$(tput cols 2>/dev/null || echo 80)|📐"
        )
        dashboard_array "${ROWS[@]}"
        echo ""
        (( i++ ))
    done
}