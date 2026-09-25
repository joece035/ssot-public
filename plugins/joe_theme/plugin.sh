#!/usr/bin/env bash
# ============================================================
# plugin: joe_theme  -- Entry Point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "source-only"; exit 1; }

_JOE_THEME_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_JOE_THEME_DIR="$_JOE_THEME_ROOT/themes"

# shared lib (โหลด Color Engine จาก core/01-colors.sh ให้ด้วย)
source "$_JOE_THEME_ROOT/_lib.sh" 2>/dev/null

# ข้อความเตือน — สีจาก Color Engine เท่านั้น (plain ถ้า engine ยังไม่มา)
_joe_paint() {
    if command -v psc >/dev/null 2>&1; then psc "$1" b "$2"; else printf '%s' "$2"; fi
}

theme_switch() {
    local t="${1:-a}"
    local file="$_JOE_THEME_DIR/${t}.sh"
    if [[ ! -f "$file" ]]; then
        printf '%s theme not found: %s\n' "$(_joe_paint 203 '[joe_theme]')" "$t" >&2
        printf '%s %s\n' "$(_joe_paint 221 'Available:')" \
            "$(ls "$_JOE_THEME_DIR" 2>/dev/null | sed 's/\.sh$//' | tr '\n' ' ')" >&2
        return 1
    fi
    unset PS1; clear; source "$file"
}


alias ta='theme_switch a'
alias tb='theme_switch b'
alias tc='theme_switch c'
alias td='theme_switch default'
alias te='theme_switch e'
alias tf='theme_switch f'
theme_switch default
