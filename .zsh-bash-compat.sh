# ============================================================
# .zsh-bash-compat.sh — Zsh -> Bash Compatibility Layer
# ============================================================
# Sourced by .zshrc BEFORE joe.sh to make ssot work in zsh.
# SSOT: ~/ssot/.zsh-bash-compat.sh
# ============================================================

# ── 1. Bash-compatible shell options (safe for interactive Zsh) ──
setopt GLOB_SUBST 2>/dev/null       # Glob expansion like bash
setopt NULL_GLOB 2>/dev/null        # No error on empty globs
setopt NO_NOMATCH 2>/dev/null       # Don't error on unmatched globs
unsetopt KSH_ARRAYS 2>/dev/null     # Keep native 1-indexed zsh arrays (crucial for path & OMZ)
unsetopt SH_WORD_SPLIT 2>/dev/null  # Keep native zsh word splitting (prevents PATH corruption)

# ── 2. BASH_SOURCE array shim for ZSH ──
# bash: BASH_SOURCE[0] inside a function = file where the function was defined.
# zsh:  equivalent is funcsourcetrace[1] = "file:lineno" of the function's
#       definition site. We initialize BASH_SOURCE[0] to the current file
#       as a fallback for top-level code (where funcsourcetrace is unset).
#       Functions should use ${funcsourcetrace[1]%%:*} (see entry.sh).
if [[ -n "${ZSH_VERSION:-}" ]]; then
    typeset -g -a BASH_SOURCE 2>/dev/null
    BASH_SOURCE=("${(%):-%x}")
fi

# ── 3. Guard compdump function for compinit ──
# Prevents "compinit:484: compdump: function definition file not found"
if ! autoload +X -U compdump 2>/dev/null && ! typeset -f compdump &>/dev/null; then
    compdump() { return 0; }
fi

# ── 4. Bash completion compatibility ──
# Only load bashcompinit if available; do NOT re-run compinit (OMZ already runs it)
if typeset -f compinit &>/dev/null || autoload +X -U compinit 2>/dev/null; then
    autoload -Uz bashcompinit 2>/dev/null && bashcompinit 2>/dev/null || true
fi

# ── 5. complete() & compgen() shims ──
if ! command -v complete &>/dev/null && ! typeset -f complete &>/dev/null; then
    complete() { :; }
fi
if ! command -v compgen &>/dev/null && ! typeset -f compgen &>/dev/null; then
    compgen() { :; }
fi

# ── 6. Unalias conflicts BEFORE ssot load ──
unalias sudo 2>/dev/null
unalias sd 2>/dev/null
unalias rc 2>/dev/null
unalias stc 2>/dev/null
unalias _ 2>/dev/null
unalias ls 2>/dev/null
unalias ll 2>/dev/null
unalias la 2>/dev/null

# ── 7. Zsh-specific PATH helper ──
[[ -d /usr/local/bin ]] && export PATH="/usr/local/bin:$PATH"

# ── 8. mapfile / readarray shim (bash 4+ builtin → zsh function) ──
# BUG FIXED 2026-10-03: old body was eval "${_var}=(\"\${(@f)}\")".
#   ${(@f)} has NO parameter name → zsh parse error
#   "(eval):1: unmatched \"" → array stayed empty → callers (find_stuff.sh
#   find_unsource_func) reported "function not found". Now reads stdin
#   line-by-line and assigns by name.
if ! command -v mapfile &>/dev/null && ! typeset -f mapfile &>/dev/null; then
    mapfile() {
        local _var="" _line
        local -a _mf_lines=()          # ALL locals before the read loop (zsh 5.9 leak)
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -t) shift ;;
                -d|-n|-O|-s|-u|-C) shift 2 ;;
                -c) shift ;;
                --) shift; break ;;
                -*) shift ;;
                *)  _var="$1"; shift; break ;;
            esac
        done
        if [[ -z "$_var" ]]; then
            echo "mapfile: variable name required" >&2
            return 2
        fi
        # No stdin redirect (interactive/TTY) → empty array, never block
        if [[ -t 0 ]]; then
            eval "$_var=()"
            return 0
        fi
        while IFS= read -r _line; do
            _mf_lines+=("$_line")
        done
        eval "$_var=(\"\${_mf_lines[@]}\")"
    }
fi
if ! command -v readarray &>/dev/null && ! typeset -f readarray &>/dev/null; then
    # Multiline body: bash requires `;` or a newline before the closing `}`
    # (zsh accepts the one-liner, bash -n rejects it).
    readarray() {
        mapfile "$@"
    }
fi