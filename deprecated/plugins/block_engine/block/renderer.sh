#!/bin/bash
# ============================================================
# block/renderer.sh — Pure rendering functions
# ============================================================
# All functions receive _LAYOUT[] and _THEME[] as context.
# ZERO global side-effects. No eval.
# ============================================================
# Public API:
#   render_border_top  — print top border line
#   render_border_bot  — print bottom border line
#   render_row         — print one data row with frame
#   render_mid         — print mid-separator line between rows
# ============================================================

# ============================================================
# _get_frame_chars
#   Sets local vars: hr_l hr_r hm_l hm_r  based on FRAME_RANDOM
# ============================================================
_get_frame_chars() {
    # Outputs 4 vars: hr_l hr_r hm_l hm_r  based on FRAME_RANDOM
    if [[ "${_THEME[frame_random]:-no}" == "yes" ]]; then
        hr_l="${_THEME[cc_hrc]}"
        hr_r="${_THEME[cc_hrc]}"
        hm_l="${_THEME[cc_hrc]}"
        hm_r="${_THEME[cc_hrc]}"
    elif [[ "${_THEME[frame_random]:-no}" == "random" ]]; then
        # Pick ONE random color for all frame chars (reuse if already set)
        if [[ -z "${_THEME[cc_rand_frame_l]:-}" ]]; then
            local -a _pal=("${_THEME[_pal_1]}" "${_THEME[_pal_2]}" "${_THEME[_pal_3]}" "${_THEME[_pal_4]}" "${_THEME[_pal_5]}" "${_THEME[_pal_6]}" "${_THEME[_pal_7]}" "${_THEME[_pal_8]}")
            local _rc="${_pal[$(( RANDOM % ${#_pal[@]} ))]}"
            local _fl="${_THEME[row_frame_l]:-|}"
            local _fr="${_THEME[row_frame_r]:-|}"
            _THEME[cc_rand_frame_l]="$(_c_apply "$_rc" "$_fl")"
            _THEME[cc_rand_frame_r]="$(_c_apply "$_rc" "$_fr")"
        fi
        hr_l="${_THEME[cc_rand_frame_l]}"
        hr_r="${_THEME[cc_rand_frame_r]}"
        hm_l="${_THEME[cc_rand_frame_l]}"
        hm_r="${_THEME[cc_rand_frame_r]}"
    else
        hr_l="${_THEME[cc_row_fl]}"
        hr_r="${_THEME[cc_row_fr]}"
        hm_l="${_THEME[cc_mid_fl]}"
        hm_r="${_THEME[cc_mid_fr]}"
    fi
}

# ============================================================
# render_border_top
#   Prints top border. Uses _LAYOUT[block_w], _LAYOUT[indent], _THEME
# ============================================================
render_border_top() {
    local w="${_LAYOUT[block_w]}"
    local indent="${_LAYOUT[indent]}"
    local pad; _pvar pad '%*s' "$indent" ''
    local border=""
    local ch="${_THEME[border_char]}"

    if [[ "${_THEME[border_random]:-no}" == "yes" ]]; then
        # Random color per character (rainbow)
        local plain_pattern="$(_blk_repeat_pattern "$ch" "$w")"
        local i ch_sub
        for (( i=0; i<w; i++ )); do
            ch_sub="${plain_pattern:$i:1}"
            border+="$(rc1 "" "$ch_sub")"
        done
    elif [[ "${_THEME[border_random]:-no}" == "random" ]]; then
        # Pick ONE random color from palette, use for entire border (same top & bottom)
        local -a _pal=("${_THEME[_pal_1]}" "${_THEME[_pal_2]}" "${_THEME[_pal_3]}" "${_THEME[_pal_4]}" "${_THEME[_pal_5]}" "${_THEME[_pal_6]}" "${_THEME[_pal_7]}" "${_THEME[_pal_8]}")
        local _rc="${_pal[$(( RANDOM % ${#_pal[@]} ))]}"
        local plain; plain="$(_blk_repeat_pattern "$ch" "$w")"
        border="$(_c_apply "$_rc" "$plain")"
        # Store for bottom border to reuse same color
        _THEME[cc_rand_border]="$border"
    else
        local plain; plain="$(_blk_repeat_pattern "$ch" "$w")"
        border="$(_apply_color_to "${_THEME[top_border_c]}" "$plain")"
    fi
    echo -e "${pad}${border}"
}
# ============================================================
# render_border_bot
# ============================================================
render_border_bot() {
    local w="${_LAYOUT[block_w]}"
    local indent="${_LAYOUT[indent]}"
    local pad; _pvar pad '%*s' "$indent" ''
    local border=""
    local ch="${_THEME[border_char]}"

    if [[ "${_THEME[border_random]:-no}" == "yes" ]]; then
        # Random color per character (rainbow)
        local plain_pattern="$(_blk_repeat_pattern "$ch" "$w")"
        local i ch_sub
        for (( i=0; i<w; i++ )); do
            ch_sub="${plain_pattern:$i:1}"
            border+="$(rc1 "" "$ch_sub")"
        done
    elif [[ "${_THEME[border_random]:-no}" == "random" ]]; then
        # Reuse same random color from top border
        border="${_THEME[cc_rand_border]:-}"
        # If not stored (edge case), generate fresh
        if [[ -z "$border" ]]; then
            local -a _pal=("${_THEME[_pal_1]}" "${_THEME[_pal_2]}" "${_THEME[_pal_3]}" "${_THEME[_pal_4]}" "${_THEME[_pal_5]}" "${_THEME[_pal_6]}" "${_THEME[_pal_7]}" "${_THEME[_pal_8]}")
            local _rc="${_pal[$(( RANDOM % ${#_pal[@]} ))]}"
            local plain; plain="$(_blk_repeat_pattern "$ch" "$w")"
            border="$(_c_apply "$_rc" "$plain")"
        fi
    else
        local plain; plain="$(_blk_repeat_pattern "$ch" "$w")"
        border="$(_apply_color_to "${_THEME[bot_border_c]}" "$plain")"
    fi
    echo -e "${pad}${border}"
}

# ============================================================
# render_mid
#   Prints mid-separator line (between rows)
# ============================================================
render_mid() {
    local indent="${_LAYOUT[indent]}"
    local w="${_LAYOUT[block_w]}"
    local pad; _pvar pad '%*s' "$indent" ''

    # -- Get frame chars first to measure their actual visual width
    local hr_l hr_r hm_l hm_r
    _get_frame_chars

    # -- Measure visual width of (possibly colored) mid frame chars.
    #    _blk_str_width strips both real ESC and literal "\e" color codes,
    #    so the colored compiled strings measure the same as their plain chars.
    local hm_l_w hm_r_w
    hm_l_w="$(_blk_str_width "$hm_l")"
    hm_r_w="$(_blk_str_width "$hm_r")"
    local inner_w=$(( w - hm_l_w - hm_r_w ))
    (( inner_w < 0 )) && inner_w=0

    local ml_ch="${_THEME[mid_line]:-=}"
    local mid_str; mid_str="$(_blk_repeat_pattern "$ml_ch" "$inner_w")"

    # -- Apply color to mid line (random=single random color from palette)
    if [[ "${_THEME[mid_random]:-no}" == "random" ]]; then
        local -a _pal=("${_THEME[_pal_1]}" "${_THEME[_pal_2]}" "${_THEME[_pal_3]}" "${_THEME[_pal_4]}" "${_THEME[_pal_5]}" "${_THEME[_pal_6]}" "${_THEME[_pal_7]}" "${_THEME[_pal_8]}")
        local _rc="${_pal[$(( RANDOM % ${#_pal[@]} ))]}"
        mid_str="$(_c_apply "$_rc" "$mid_str")"
    else
        mid_str="$(_apply_color_to "${_THEME[mid_line_c]}" "$mid_str")"
    fi

    echo -e "${pad}${hm_l}${mid_str}${hm_r}"
}

# ============================================================
# render_row <eml> <label> <value> <emr>
#   Prints one data row with frame chars and padding.
#   Assembles string incrementally — no long format string.
# ============================================================
render_row() {
    local eml="$1" label="$2" value="$3" emr="$4"
    local label_w="${_LAYOUT[label_w]}"
    local value_w="${_LAYOUT[value_w]}"
    local sep="${_LAYOUT[sep]}"
    local indent="${_LAYOUT[indent]}"
    local pad; _pvar pad '%*s' "$indent" ''

    # -- Get frame chars (visual width already accounted for in block_w via frame_w)
    local hr_l hr_r hm_l hm_r
    _get_frame_chars

    # -- Measure visual widths of left and right emoji/icons
    local w_eml=0 w_emr=0
    [[ -n "$eml" ]] && w_eml="$(_blk_str_width "$eml")"
    [[ -n "$emr" ]] && w_emr="$(_blk_str_width "$emr")"

    # -- Emoji padding: left column total cells must equal EMO_L (4), right column total cells must equal EMO_R (5)
    local left_pad=$(( (EMO_L - w_eml) / 2 ))
    local left_rem=$(( EMO_L - w_eml - left_pad ))
    (( left_pad < 0 )) && left_pad=0
    (( left_rem < 0 )) && left_rem=0

    local r_left=$(( (EMO_R - w_emr) / 2 ))
    local r_right=$(( EMO_R - w_emr - r_left ))
    (( r_left < 0 )) && r_left=0
    (( r_right < 0 )) && r_right=0

    # -- Truncate value if its VISUAL width exceeds value_w (prevent wrap)
    local vlen; vlen="$(_blk_str_width "$value")"
    if (( vlen > value_w )); then
        value="$(_blk_truncate "$value" $((value_w - 1)))…"
    fi

    # -- Text padding using VISUAL width (emoji-aware), not codepoint count ${#...}
    #    block_w already includes the real frame width, so value_pad needs no
    #    extra_frame compensation (value section = value_w + V2E_GAP + EMO_R).
    local label_vw; label_vw="$(_blk_str_width "$label")"
    local value_vw; value_vw="$(_blk_str_width "$value")"
    local label_pad=$(( label_w - label_vw ))
    (( label_pad < 0 )) && label_pad=0
    local value_pad=$(( value_w - value_vw + V2E_GAP ))
    (( value_pad < 0 )) && value_pad=0

    # -- Apply colors
    local color_label color_value
    color_label="$(_apply_color_to "${_THEME[label_c]}" "$label")"
    color_value="$(_apply_color_to "${_THEME[value_c]}" "$value")"

    # -- Assemble row string incrementally (Priority 4: no long printf)
    local row=""
    local _tmp=""

    _pvar _tmp '%*s%s%*s' "$left_pad" '' "$eml" "$left_rem" ''
    row+="$_tmp"

    row+="$color_label"

    _pvar _tmp '%*s' "$label_pad" ''
    row+="$_tmp"

    row+="$sep"
    row+="$color_value"

    _pvar _tmp '%*s%*s%s%*s' "$value_pad" '' "$r_left" '' "$emr" "$r_right" ''
    row+="$_tmp"

    echo -e "${pad}${hr_l}${row}${hr_r}"
    
}

# ============================================================
# render_title
#   Prints environment-specific title centered in terminal
# ============================================================
render_title() {
    [[ $- != *i* ]] && return 0   # only in interactive shell
    local title
    case "${JOE_ENV:-}" in
        TERMUX)   title="$(rc b "🔴🟠🟡🟢🔵🟢🟡🟠🔴🔹🚀 Joe's TERMUX📲↘🔹")" ;;
        WSL)      title="$(rc b "🟥🟧🟨🟩🟦🟩🟨🟧🟥🔹🚀  Joe's WSL▫️💻↘🔹")" ;;
        GIT-BASH) title="$(rc b "🟥🟠🟨🟢🔷🟢🟨🟠🟥🔹🚀 Joe's GIT-BASH▫️🖥️↘")" ;;
        *)        title="$(rc "🔴🟧🟡🟩🔷🟩🟡🟧🔴🔹🚀 Joe's Android▫️💻↘🔹")" ;;
    esac
    local title_w; title_w="$(_blk_str_width "$title")"
    local sp_title=$(( (TERM_WIDTH - title_w) / 2 ))
    (( sp_title < 0 )) && sp_title=0
    local _pad; _pvar _pad '%*s' "$sp_title" ''
    printf '%s%s\n' "$_pad" "$title"
}
