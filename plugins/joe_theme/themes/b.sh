#!/usr/bin/env bash
# ============================================================
# Theme B: TOKYO NIGHT
# Palette: Deep navy + violet + rose + cyan
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "source-only"; exit 1; }

_sp_tokyo() {
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
    local _prev=${_SSOT_TOKYO_PREV_ROW:-0}
    if (( _cur_row <= 2 || (_cur_row < _prev && _prev > 2) )); then
        _SSOT_TOKYO_BANNER=1; show_mini=0
    elif (( _cur_row < _max_lines && ${_SSOT_TOKYO_BANNER:-0} == 1 )); then
        show_mini=1
    fi
    _SSOT_TOKYO_PREV_ROW=$_cur_row

    if (( show_mini == 1 )); then
        if (( exit_code == 0 )); then
            PS1=" \e[38;5;141m ❯\e[0m  "
        else
            PS1=" \e[38;5;203m ❯\e[0m  "
        fi
        return
    fi

    local C_VIOLET='\e[38;5;141m'
    local C_CYAN='\e[38;5;117m'
    local C_ROSE='\e[38;5;211m'
    local C_GREEN='\e[38;5;120m'
    local C_BLUE='\e[38;5;75m'
    local C_DIM='\e[38;5;243m'
    local C_FG='\e[38;5;253m'
    local RST='\e[0m'
    local B='\e[1m'
    local D='\e[2m'

    local status_str
    if (( exit_code == 0 )); then
        status_str="${C_GREEN}${B}✓${RST}"
    else
        status_str="${C_ROSE}${B}✗ ${exit_code}${RST}"
    fi

    local cur_env="${JOE_ENV:-WSL}"
    local cur_shell="${BASH_VERSION:+bash}${ZSH_VERSION:+zsh}"
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-$(hostname -s)}"
    local cwd="${PWD/#$HOME/\~}"

    local git_str=""
    if command -v git &>/dev/null; then
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        if [[ -n "$branch" ]]; then
            local dirty=""
            [[ -n "$(git status --porcelain 2>/dev/null)" ]] && dirty="${C_ROSE}*${RST}"
            git_str=" ${C_DIM}⎇${RST} ${C_VIOLET}${branch}${RST}${dirty}"
        fi
    fi

    local term_w; term_w=$(tput cols 2>/dev/null || echo 80)
    [[ "$term_w" =~ ^[0-9]+$ ]] || term_w=80
    local line=""; for ((i=0;i<term_w;i++)); do line+="─"; done
    local border="${C_DIM}${line}${RST}"

    local seg_env="${C_DIM}[${RST}${C_BLUE}${D}${cur_env}${RST}${C_DIM}]${RST}"
    local seg_user="${C_DIM}[${RST}${C_CYAN}${B}${cur_user}${RST}${C_DIM}@${RST}${C_VIOLET}${B}${cur_host}${RST}${C_DIM}]${RST}"
    local seg_dir="${C_DIM}[${RST}${C_FG}${cwd}${RST}${C_DIM}]${RST}"

    local PS1_=""
    PS1_+="${border}\n"
    PS1_+=" ${status_str}  ${seg_env} ${seg_user} ${seg_dir}${git_str}\n"
    PS1_+="${border}\n"
    PS1_+=" ${C_VIOLET}${B}❯${RST}  "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_sp_tokyo