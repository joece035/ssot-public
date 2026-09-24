#!/usr/bin/env bash
# ============================================================
# Theme C: CYBERPUNK NEON
# Palette: Black bg + hot magenta + electric cyan + lime
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "source-only"; exit 1; }

_sp_cyber() {
    local exit_code=$?

    local _cur_row=0 _max_lines=24
    local _raw=""
    IFS=';' read -t 0.1 -sdR -p $'\033[6n' _raw _max_lines < /dev/tty 2>/dev/null || true
    _cur_row="${_raw#*[}"
    [[ "$_cur_row" =~ ^[0-9]+$ ]] || _cur_row=0
    [[ "$_max_lines" =~ ^[0-9]+$ ]] || _max_lines=24
    _max_lines=$(tput lines 2>/dev/null || echo "$_max_lines")
    [[ "$_max_lines" =~ ^[0-9]+$ ]] || _max_lines=24

    local show_mini=0
    local _prev=${_SSOT_CYBER_PREV_ROW:-0}
    if (( _cur_row <= 2 || (_cur_row < _prev && _prev > 2) )); then
        _SSOT_CYBER_BANNER=1; show_mini=0
    elif (( _cur_row < _max_lines && ${_SSOT_CYBER_BANNER:-0} == 1 )); then
        show_mini=1
    fi
    _SSOT_CYBER_PREV_ROW=$_cur_row

    if (( show_mini == 1 )); then
        if (( exit_code == 0 )); then
            PS1=" \e[38;5;201m▶\e[0m  "
        else
            PS1=" \e[38;5;9m▶\e[0m  "
        fi
        return
    fi

    local C_MAGENTA='\e[38;5;201m'
    local C_CYAN='\e[38;5;51m'
    local C_LIME='\e[38;5;154m'
    local C_ORANGE='\e[38;5;214m'
    local C_RED='\e[38;5;9m'
    local C_DIM='\e[38;5;238m'
    local C_GRAY='\e[38;5;246m'
    local RST='\e[0m'
    local B='\e[1m'

    local status_str
    if (( exit_code == 0 )); then
        status_str="${C_LIME}${B}[OK]${RST}"
    else
        status_str="${C_RED}${B}[ERR:${exit_code}]${RST}"
    fi

    local cur_env="${JOE_ENV:-WSL}"
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-$(hostname -s)}"
    local cwd="${PWD/#$HOME/\~}"

    local git_str=""
    if command -v git &>/dev/null; then
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        if [[ -n "$branch" ]]; then
            local dirty=""
            [[ -n "$(git status --porcelain 2>/dev/null)" ]] && dirty="${C_ORANGE}!${RST}"
            git_str=" ${C_DIM}::${RST}${C_MAGENTA}${branch}${RST}${dirty}"
        fi
    fi

    local term_w; term_w=$(tput cols 2>/dev/null || echo 80)
    [[ "$term_w" =~ ^[0-9]+$ ]] || term_w=80
    local line1=""; for ((i=0;i<term_w;i++)); do line1+="═"; done
    local half=$(( term_w / 2 ))
    local line2=""; for ((i=0;i<half;i++)); do line2+="─"; done
    local border_top="${C_MAGENTA}${line1}${RST}"
    local border_mid="${C_DIM}${line2}${RST}"

    local label_env="${C_DIM}ENV:${RST}${C_CYAN}${B}${cur_env}${RST}"
    local label_user="${C_DIM}SYS:${RST}${C_LIME}${B}${cur_user}${RST}${C_DIM}@${RST}${C_ORANGE}${B}${cur_host}${RST}"
    local label_path="${C_DIM}DIR:${RST}${C_GRAY}${cwd}${RST}"

    local PS1_=""
    PS1_+="${border_top}\n"
    PS1_+=" ${status_str}  ${label_env}  ${label_user}  ${label_path}${git_str}\n"
    PS1_+="${border_mid}\n"
    PS1_+=" ${C_MAGENTA}${B}▶${RST}  "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_sp_cyber