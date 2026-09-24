#!/usr/bin/env bash
# ============================================================
# Theme A: NORD ARCTIC
# Palette: Polar night + frost blue + aurora accents
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "source-only"; exit 1; }

_sp_nord() {
    local exit_code=$?

    # ── cursor position (safe: default 0 if terminal not support) ──
    local _cur_row=0 _max_lines=24
    local _raw=""
    IFS=';' read -t 0.1 -sdR -p $'\033[6n' _raw _max_lines < /dev/tty 2>/dev/null || true
    _cur_row="${_raw#*[}"
    # Guard: must be integer
    [[ "$_cur_row" =~ ^[0-9]+$ ]] || _cur_row=0
    [[ "$_max_lines" =~ ^[0-9]+$ ]] || _max_lines=24
    _max_lines=$(tput lines 2>/dev/null || echo "$_max_lines")
    [[ "$_max_lines" =~ ^[0-9]+$ ]] || _max_lines=24

    local show_mini=0
    local _prev=${_SSOT_NORD_PREV_ROW:-0}
    if (( _cur_row <= 2 || (_cur_row < _prev && _prev > 2) )); then
        _SSOT_NORD_BANNER=1; show_mini=0
    elif (( _cur_row < _max_lines && ${_SSOT_NORD_BANNER:-0} == 1 )); then
        show_mini=1
    fi
    _SSOT_NORD_PREV_ROW=$_cur_row

    if (( show_mini == 1 )); then
        if (( exit_code == 0 )); then
            PS1=" \e[38;5;81m-→\e[0m  "
        else
            PS1=" \e[38;5;203m-→\e[0m  "
        fi
        return
    fi

    # ── colours (Nord palette) ─────────────────────────────────
    local C_FROST='\e[38;5;81m'
    local C_POLAR='\e[38;5;240m'
    local C_AURORA='\e[38;5;114m'
    local C_SNOW='\e[38;5;189m'
    local C_ERR='\e[38;5;203m'
    local C_GOLD='\e[38;5;221m'
    local C_DIM='\e[38;5;243m'
    local RST='\e[0m'
    local B='\e[1m'
    local D='\e[2m'

    # ── status ────────────────────────────────────────────────
    local status_str
    if (( exit_code == 0 )); then
        status_str="${C_AURORA}${B}❄ ${RST}"
    else
        status_str="${C_ERR}${B}✖ ${RST}"
    fi

    # ── env / user / host / path ──────────────────────────────
    local cur_env="${JOE_ENV:-WSL}"
    local cur_shell="${BASH_VERSION:+bash}${ZSH_VERSION:+zsh}"
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-$(hostname -s)}"
    local cwd="${PWD/#$HOME/\~}"

    local env_tag="${C_DIM}${D}‹ ${cur_env}:${cur_shell} ›${RST}"
    local user_host="${C_FROST}${B}${cur_user}${RST}${C_DIM}@${RST}${C_GOLD}${B}${cur_host}${RST}"
    local dir_str="${C_SNOW}${D}${cwd}${RST}"

    # ── git ───────────────────────────────────────────────────
    local git_str=""
    if command -v git &>/dev/null; then
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        if [[ -n "$branch" ]]; then
            local dirty=""
            [[ -n "$(git status --porcelain 2>/dev/null)" ]] && dirty="${C_GOLD}*${RST}"
            git_str=" ${C_DIM}on${RST} ${C_FROST}${B} ${branch}${RST}${dirty}"
        fi
    fi

    # ── border ────────────────────────────────────────────────
    local term_w; term_w=$(tput cols 2>/dev/null || echo 80)
    [[ "$term_w" =~ ^[0-9]+$ ]] || term_w=80
    local line="" line2=""
    for ((i=0;i<term_w;i++)); do line+="▁"; line2+="▔"; done
    local border_top="${C_POLAR}${D}${line}${RST}"
    local border_bot="${C_POLAR}${D}${line2}${RST}"

    # ── assemble ──────────────────────────────────────────────
    local PS1_=""
    PS1_+="${border_top}\n"
    PS1_+=" ${status_str}  ${env_tag}  ${user_host}  in ${dir_str}${git_str} \n"
    PS1_+="${border_bot}\n"
    PS1_+=" ${C_FROST}${B}-→${RST}  "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_sp_nord