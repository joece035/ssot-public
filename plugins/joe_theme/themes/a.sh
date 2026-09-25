#!/usr/bin/env bash
# ============================================================
# Theme A: NORD ARCTIC
# Palette: Polar night + frost blue + aurora accents
# สีทุกจุดมาจาก core/01-colors.sh ผ่าน psc (PS1-safe)
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "source-only"; exit 1; }

# shared lib: cursor lifecycle / width / border / git
_joe_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib.sh"
source "$_joe_lib" 2>/dev/null
if ! command -v psc >/dev/null 2>&1 || ! command -v _joe_ctx >/dev/null 2>&1; then
    printf '[joe_theme] cannot load %s\n' "$_joe_lib" >&2
    return 1
fi

_sp_nord() {
    local exit_code=$?

    # ── full banner หรือ mini prompt? ────────────────────────
    _joe_ctx _SSOT_NORD
    if (( _JOE_MINI == 1 )); then
        if (( exit_code == 0 )); then
            PS1=" $(psc 81 b '-→')  "
        else
            PS1=" $(psc 203 b '-→')  "
        fi
        return
    fi

    # ── status ────────────────────────────────────────────────
    local status_str
    if (( exit_code == 0 )); then
        status_str="$(psc 114 b '❄ ')"
    else
        status_str="$(psc 203 b '✖ ')"
    fi

    # ── env / user / host / path ──────────────────────────────
    local cur_env="${JOE_ENV:-WSL}"
    local cur_shell="${BASH_VERSION:+bash}${ZSH_VERSION:+zsh}"
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-$(hostname -s)}"
    local cwd="${PWD/#$HOME/\~}"

    local env_tag="$(psc 243 d "‹ ${cur_env}:${cur_shell} ›")"
    local user_host="$(psc 81 b "$cur_user")$(psc 243 d '@')$(psc 221 b "$cur_host")"
    local dir_str="$(psc 189 d "$cwd")"

    # ── git ───────────────────────────────────────────────────
    local git_str
    git_str="$(_joe_git ' on ' 81 b 221)"

    # ── content (ยังไม่มี \n) → วัดความกว้าง → ค่อยต่อ border ──
    local content=" ${status_str}  ${env_tag}  ${user_host}  in ${dir_str}${git_str}"
    local lens
    lens="$(_joe_fit "$content")"

    local border_top border_bot
    border_top="$(_joe_border "$lens" '▁' 240 d)"
    border_bot="$(_joe_border "$lens" '▔' 240 d)"

    # ── assemble ──────────────────────────────────────────────
    local PS1_=""
    PS1_+="${border_top}\n"
    PS1_+="${content}\n"
    PS1_+="${border_bot}\n"
    PS1_+=" $(psc 81 b '-→')  "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_sp_nord
