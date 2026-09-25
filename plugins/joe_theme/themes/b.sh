#!/usr/bin/env bash
# ============================================================
# Theme B: TOKYO NIGHT
# Palette: Deep navy + violet + rose + cyan
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

_sp_tokyo() {
    local exit_code=$?

    # ── full banner หรือ mini prompt? ────────────────────────
    _joe_ctx _SSOT_TOKYO
    if (( _JOE_MINI == 1 )); then
        if (( exit_code == 0 )); then
            PS1=" $(psc 141 b ' ❯')  "
        else
            PS1=" $(psc 211 b ' ❯')  "
        fi
        return
    fi

    # ── status ────────────────────────────────────────────────
    local status_str
    if (( exit_code == 0 )); then
        status_str="$(psc 120 b '✓')"
    else
        status_str="$(psc 211 b "✗ ${exit_code}")"
    fi

    # ── env / user / host / path ──────────────────────────────
    local cur_env="${JOE_ENV:-WSL}"
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-$(hostname -s)}"
    local cwd="${PWD/#$HOME/\~}"

    local seg_env="$(psc 243 d '[')$(psc 75 d "$cur_env")$(psc 243 d ']')"
    local seg_user="$(psc 243 d '[')$(psc 117 b "$cur_user")$(psc 243 d '@')$(psc 141 b "$cur_host")$(psc 243 d ']')"
    local seg_dir="$(psc 243 d '[')$(psc 253 b "$cwd")$(psc 243 d ']')"

    # ── git ───────────────────────────────────────────────────
    local git_str
    git_str="$(_joe_git ' ⎇ ' 141 b 211)"

    # ── content (ยังไม่มี \n) → วัดความกว้าง → ค่อยต่อ border ──
    local content=" ${status_str}  ${seg_env} ${seg_user} ${seg_dir}${git_str}"
    local lens
    lens="$(_joe_fit "$content")"

    local border_top border_bot
    border_top="$(_joe_border "$lens" '▁' 243 d)"
    border_bot="$(_joe_border "$lens" '▔' 243 d)"

    # ── assemble ──────────────────────────────────────────────
    local PS1_=""
    PS1_+="${border_top}\n"
    PS1_+="${content}\n"
    PS1_+="${border_bot}\n"
    PS1_+=" $(psc 141 b '❯')  "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_sp_tokyo
