#!/usr/bin/env bash
# ============================================================
# plugin: joe_theme  -- Entry Point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "source-only"; exit 1; }

_JOE_THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/themes"

theme_switch() {
    local t="${1:-a}"
    local file="$_JOE_THEME_DIR/${t}.sh"
    if [[ ! -f "$file" ]]; then
        printf "\033[31m[joe_theme]\033[0m theme not found: %s\n" "$t" >&2
        printf "\033[33mAvailable:\033[0m %s\n" "$(ls "$_JOE_THEME_DIR" 2>/dev/null | sed 's/\.sh$//' | tr '\n' ' ')" >&2
        return 1
    fi
    unset PS1; clear; source "$file"
}



alias ta='theme_switch a'
alias tb='theme_switch b'
alias tc='theme_switch c'
alias td='theme_switch default'
theme_switch default