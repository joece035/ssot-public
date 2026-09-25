#!/usr/bin/env bash
# ============================================================
# Theme C: CYBERPUNK NEON
# Palette: Black bg + hot magenta + electric cyan + lime
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

_sp_cyber() {
    local exit_code=$?

    # ── full banner หรือ mini prompt? ────────────────────────
    _joe_ctx _SSOT_CYBER
    if (( _JOE_MINI == 1 )); then
        if (( exit_code == 0 )); then
            PS1=" $(psc 201 b '▶')  "
        else
            PS1=" $(psc 9 b '▶')  "
        fi
        return
    fi

    # ── status ────────────────────────────────────────────────
    local status_str
    if (( exit_code == 0 )); then
        status_str="$(psc 154 b '[OK]')"
    else
        status_str="$(psc 9 b "[ERR:${exit_code}]")"
    fi

    # ── env / user / host / path ──────────────────────────────
    local cur_env="${JOE_ENV:-WSL}"
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-$(hostname -s)}"
    local cwd="${PWD/#$HOME/\~}"

    local label_env="$(psc 238 d 'ENV:')$(psc 51 b "$cur_env")"
    local label_user="$(psc 238 d 'SYS:')$(psc 154 b "$cur_user")$(psc 238 d '@')$(psc 214 b "$cur_host")"
    local label_path="$(psc 238 d 'DIR:')$(psc 246 b "$cwd")"

    # ── git ───────────────────────────────────────────────────
    local git_str
    git_str="$(_joe_git ' ::' 201 b 214 '!')"

    # ── content (ยังไม่มี \n) → วัดความกว้าง → ค่อยต่อ border ──
    local content=" ${status_str}  ${label_env}  ${label_user}  ${label_path}${git_str}"
    local lens
    lens="$(_joe_fit "$content")"

    local border_top border_bot
    border_top="$(_joe_border "$lens" '▁' 201 d)"
    border_bot="$(_joe_border "$lens" '▔' 238 d)"

    # ── assemble ──────────────────────────────────────────────
    local PS1_=""
    PS1_+="${border_top}\n"
    PS1_+="${content}\n"
    PS1_+="${border_bot}\n"
    PS1_+=" $(psc 201 b '▶')  "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_sp_cyber
