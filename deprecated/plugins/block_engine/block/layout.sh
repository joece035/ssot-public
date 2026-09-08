#!/bin/bash
# ============================================================
# block/layout.sh — Layout Scanner & Width Calculator
# ============================================================
# Globals written : _LAYOUT[]  (associative array)
# Reads from      : utils.sh constants  TERM_WIDTH (via _blk_init)
# No eval, no scattered globals
# ============================================================
# _LAYOUT keys:
#   label_w   — max label display width across all rows
#   value_w   — max value display width across all rows
#   block_w   — total block inner width
#   indent    — left padding spaces (for centering / offset)
#   sep       — label-value separator string (from theme MD_SEP_)
# ============================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    declare -g -A _LAYOUT 2>/dev/null || true
else
    typeset -g -A _LAYOUT 2>/dev/null || true
fi

# ============================================================
# _blk_parse_row <row_string>
#   Parses row string into 4 components: _parsed_eml, _parsed_label, _parsed_value, _parsed_emr
#   Supports:
#     - 4 fields: EMOJI_L|LABEL|VALUE|EMOJI_R  or  |LABEL|VALUE|
#     - 3 fields: EMOJI_L|LABEL|VALUE  or  |LABEL|VALUE  or  LABEL|VALUE|
#     - 2 fields: LABEL|VALUE
# ============================================================
_blk_parse_row() {
    local row="$1"
    # Cross-shell split on '|' via _split_pipe() helper (utils.sh).
    # Keeps the rest of the engine shell-agnostic.
    _split_pipe parts "$row"
    local n=${#parts[@]}

    case $n in
        4)
            _parsed_eml="${parts[0]}"
            _parsed_label="${parts[1]}"
            _parsed_value="${parts[2]}"
            _parsed_emr="${parts[3]}"
            ;;
        3)
            if [[ -z "${parts[0]}" ]]; then
                _parsed_eml=""
                _parsed_label="${parts[1]}"
                _parsed_value="${parts[2]}"
                _parsed_emr=""
            elif [[ -z "${parts[2]}" ]]; then
                _parsed_eml=""
                _parsed_label="${parts[0]}"
                _parsed_value="${parts[1]}"
                _parsed_emr=""
            else
                _parsed_eml="${parts[0]}"
                _parsed_label="${parts[1]}"
                _parsed_value="${parts[2]}"
                _parsed_emr=""
            fi
            ;;
        2)
            _parsed_eml=""
            _parsed_label="${parts[0]}"
            _parsed_value="${parts[1]}"
            _parsed_emr=""
            ;;
        *)
            _parsed_eml=""
            _parsed_label="$row"
            _parsed_value=""
            _parsed_emr=""
            ;;
    esac
}

# ============================================================
# _blk_scan <row1> <row2> ...
#   Scans rows for max label/value widths.
#   Writes: _LAYOUT[label_w]  _LAYOUT[value_w]
# ============================================================
_blk_scan() {
    local rows=("$@")
    local max_l=0 max_v=0
    local row w
    local _parsed_eml _parsed_label _parsed_value _parsed_emr
    local -a labels=() values=()

    for row in "${rows[@]}"; do
        _blk_parse_row "$row"
        labels+=("$_parsed_label")
        values+=("$_parsed_value")
    done

    # Batch visual-width (emoji-aware) — python3 เรียกครั้งเดียวแทนทุกเซลล์
    while IFS= read -r w; do
        (( w > max_l )) && max_l=$w
    done < <(_blk_str_widths "${labels[@]}")
    while IFS= read -r w; do
        (( w > max_v )) && max_v=$w
    done < <(_blk_str_widths "${values[@]}")

    _LAYOUT[label_w]=$max_l
    _LAYOUT[value_w]=$max_v
}

# ============================================================
# _blk_build_layout [offset]
#   Computes block_w and indent from scan results + TERM_WIDTH.
#   Reads  : _LAYOUT[label_w]  _LAYOUT[value_w]  TERM_WIDTH
#            MD_SEP_ (from theme)
#   Writes : _LAYOUT[block_w]  _LAYOUT[indent]  _LAYOUT[sep]
# ============================================================
_blk_build_layout() {
    local offset="${1:-0}"

    _blk_init   # ensure TERM_WIDTH is cached

    # -- Handle NONE → left-align (indent=1), empty → center (offset=0)
    local is_none=0
    [[ "$offset" == "NONE" ]] && is_none=1 && offset=0
    [[ -z "$offset" ]] && offset=0

    local sep="${MD_SEP_:-${_THEME[mid_sep]:- : }}"
    local sep_len; sep_len="$(_blk_str_width "$sep")"
    local label_w="${_LAYOUT[label_w]:-0}"
    local value_w="${_LAYOUT[value_w]:-0}"

    # Actual frame visual width (replaces the old PAD_X=2 assumption).
    # Using the real frame width keeps block_w == rendered row width for EVERY row,
    # including the max-width value row (the old PAD_X + extra_frame hack overflowed
    # by extra_frame-V2E_GAP when value_pad clamped to 0).
    local fl="${_THEME[row_frame_l]:-|}"
    local fr="${_THEME[row_frame_r]:-|}"
    local frame_w; frame_w=$(( $(_blk_str_width "$fl") + $(_blk_str_width "$fr") ))

    local block_w=$(( EMO_L + label_w + sep_len + value_w + V2E_GAP + EMO_R + frame_w ))

    # -- Auto-shrink: if block wider than terminal, cap at tput cols - 2
    local max_w=$(( TERM_WIDTH - 2 ))
    if (( block_w > max_w )); then
        block_w=$max_w
        local used=$(( EMO_L + sep_len + V2E_GAP + EMO_R + frame_w ))
        value_w=$(( block_w - used - label_w ))
        (( value_w < 1 )) && value_w=1
        _LAYOUT[value_w]=$value_w
    fi

    # -- Compute indent (centering + offset)
    #    offset -1 = left, 0 = center, +1 = right
    local range=$(( TERM_WIDTH - block_w - 2 ))
    (( range < 0 )) && range=0
    local half=$(( range / 2 ))
    local off_pct=$(awk -v o="$offset" 'BEGIN{printf "%d", o*100}' 2>/dev/null || echo 0)
    local indent=$(( 1 + half + off_pct * half / 100 ))

    # -- NONE → force left-align (indent=1)
    (( is_none == 1 )) && indent=1

    _LAYOUT[block_w]=$block_w
    _LAYOUT[indent]=$indent
    _LAYOUT[sep]="$sep"
}
