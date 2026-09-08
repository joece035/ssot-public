# ================================================================
# ~/.zshrc - JOE SSOT ZSH Config (Termux)
# MASTER: WSL | SSOT: ~/ssot/tools/zshrc_termux.zsh
# Deployed by: Fresh_termux_fullsetup_SSOT.sh (links to ~/.zshrc)
# Do NOT edit on Termux -- edit in WSL, Syncthing syncs it.
# ================================================================

# -- Terminal type (SSH sessions inherit no TERM -- micro/TUI needs this)
export TERM="${TERM:-xterm-256color}"
export COLORTERM="truecolor"
export JOE_ENV="MUMU"
export MY_DEVICE="MUMU"

# -- Shell Options (Prevent glob errors & duplicate fpath) ------
setopt NO_NOMATCH 2>/dev/null || true
setopt NULL_GLOB 2>/dev/null || true
typeset -g -U fpath path PATH 2>/dev/null || true

# -- Path Setup ------------------------------------------------
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$HOME/.local/bin:$PATH"
if [[ -d "/data/data/com.termux/files/usr/bin" ]]; then
    export PATH="/data/data/com.termux/files/usr/bin:$PATH"
fi

# -- Ensure ALL Zsh system function directories are in fpath ----
_tz_dir="/data/data/com.termux/files/usr/share/zsh"
if [[ -d "$_tz_dir" ]]; then
    for _d in "$_tz_dir"/site-functions(N) \
              "$_tz_dir"/*(N) \
              "$_tz_dir"/*/functions(N) \
              "$_tz_dir"/*/functions/*(N) \
              "$_tz_dir"/*/functions/*/*(N) \
              "$_tz_dir"/*/functions/*/*/*(N); do
        [[ -d "$_d" ]] && fpath+=("$_d")
    done
fi
unset _tz_dir _d

# -- Oh My Zsh Flags -------------------------------------------
export DISABLE_LS_COLORS="true"
export ZSH_DISABLE_COMPFIX="true"

# -- Clear old shell function conflicts for OMZ spectrum -------
unfunction color 2>/dev/null || true
unset color 2>/dev/null || true

# -- Powerlevel10k instant prompt (quiet output warning) -------
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -- Oh My Zsh (Source ONCE per session to prevent compinit corruption on reload) --
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
    git
    autoupdate
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)

if [[ -z "${_OMZ_SOURCED:-}" ]]; then
    export _OMZ_SOURCED=1
    [[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
fi

# -- ZSH/Bash compat layer (BEFORE joe.sh) ---------------------
[[ -f "$HOME/.env" ]] && source "$HOME/.env"
SSOT="${SSOT:-$HOME/ssot}"
[[ -f "$SSOT/.zsh-bash-compat.sh" ]] && source "$SSOT/.zsh-bash-compat.sh"

# -- JOE SSOT single entry point --------------------------------
# joe.sh: JOE_ENV detection -> 00-env.sh -> 01-colors.sh -> functions
[[ -f "$SSOT/joe.sh" ]] && source "$SSOT/joe.sh"

# -- Powerlevel10k config --------------------------------------
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
# .p10k.zsh (p10k configure) declares POWERLEVEL9K_INSTANT_PROMPT=verbose,
# which would OVERRIDE the quiet above and re-enable the console-output
# warning at finalize. Re-assert quiet AFTER sourcing it.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# -- Safe UP/DOWN keybindings ----------------------------------
if ! autoload +X -U up-line-or-beginning-search 2>/dev/null; then
    up-line-or-beginning-search() { zle up-line-or-history; }
    zle -N up-line-or-beginning-search 2>/dev/null
fi
if ! autoload +X -U down-line-or-beginning-search 2>/dev/null; then
    down-line-or-beginning-search() { zle down-line-or-history; }
    zle -N down-line-or-beginning-search 2>/dev/null
fi

if zle -la 2>/dev/null | grep -q history-substring-search; then
    bindkey '^[[A' history-substring-search-up   2>/dev/null
    bindkey '^[[B' history-substring-search-down 2>/dev/null
    bindkey "$terminfo[kcuu1]" history-substring-search-up   2>/dev/null
    bindkey "$terminfo[kcud1]" history-substring-search-down 2>/dev/null
else
    bindkey '^[[A' up-line-or-history   2>/dev/null
    bindkey '^[[B' down-line-or-history 2>/dev/null
fi

GITSTATUS_LOG_LEVEL=DEBUG

# -- Powerlevel10k finalize ------------------------------------
(( ! ${+functions[p10k]} )) || p10k finalize

# -- Micro editor wrapper (fix TUI/black screen freeze) ----------
# Root cause (2026-08-15):
#   1. TERM unset in SSH session -> micro tcell/TUI cannot init
#   2. /dev/tty missing in non-interactive SSH -> Screen init fails -> hang
# Fix: Set TERM + check for TTY before launching
micro() {
    # Fix 1: Ensure TERM is always set
    if [[ -z "$TERM" || "$TERM" == "dumb" ]]; then
        export TERM="xterm-256color"
        export COLORTERM="truecolor"
    fi

    # Fix 2: Check for TTY -- micro uses tcell which needs /dev/tty
    if ! [ -t 0 ] || ! [ -t 1 ]; then
        if [[ -c /dev/tty ]]; then
            # Redirect to /dev/tty directly (fallback for some SSH configs)
            TERM="${TERM:-xterm-256color}" command micro "$@" </dev/tty >/dev/tty
            return $?
        else
            printf '\033[31mERROR: micro requires an interactive TTY\033[0m\n'
            printf 'Fix: Open Termux on MuMu directly, or use: ssh -t\n'
            return 1
        fi
    fi

    # Normal path: reset terminal state to prevent p10k escape sequence bleed
    command printf '\033[?1049l' 2>/dev/null  # exit alternate screen
    command printf '\033[0m' 2>/dev/null       # reset all colors
    command printf '\033[?25h' 2>/dev/null     # show cursor
    command printf '\033[2J\033[H' 2>/dev/null # clear screen
    TERM="${TERM:-xterm-256color}" command micro "$@"
    local ret=$?
    command printf '\033[?1049l' 2>/dev/null
    command printf '\033[0m' 2>/dev/null
    return $ret
}

# -- pnpm (global bin dir; removed by an accidental WIP edit 2026-08-08) --
export PNPM_HOME="/data/data/com.termux/files/home/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac 
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
#                 Disable gitstatus                  #
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
export POWERLEVEL9K_DISABLE_GITSTATUS=true
export GITSTATUS_ENABLE=0
 
