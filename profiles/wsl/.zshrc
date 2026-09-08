# ================================================================
# $HOME/.zshrc - JOE SSOT ZSH Config (WSL)
# SSOT: $HOME/ssot/profiles/wsl/.zshrc
# Linked to: $HOME/.zshrc
# ================================================================

# -- Reset any bash-emulation options if re-sourcing in the same session --
unsetopt KSH_ARRAYS SH_WORD_SPLIT 2>/dev/null || true

# -- Path Setup (Must be BEFORE any tools/helpers run) ----------
export PATH="$HOME/.local/bin:$HOME/.local/lib/openclaw/bin:$HOME/.opencode/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export SSOT="$HOME/ssot"
export JOE_ENV="WSL"
export MY_DEVICE="WSL"

# -- Initialize color engine (must come before any tools that use it) --
# Check if .bash_helper is executable and source it
if [[ -x "$HOME/ssot/.bash_helper" ]]; then
    source "$HOME/ssot/.bash_helper"
elif [[ -f "$HOME/ssot/.bash_helper" ]]; then
    chmod +x "$HOME/ssot/.bash_helper"
    source "$HOME/ssot/.bash_helper"
fi

# -- Terminal type (micro/TUI needs this) -----------------------
export TERM="${TERM:-xterm-256color}"
export COLORTERM="truecolor"

# -- Shell Options (Prevent glob errors & duplicate fpath) ------
setopt NO_NOMATCH 2>/dev/null || true
setopt NULL_GLOB 2>/dev/null || true
typeset -g -U fpath path PATH 2>/dev/null || true

# -- Powerlevel10k instant prompt (quiet output warning) -------
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -- NVM (Node Version Manager - MUST come BEFORE .env) --------
export NVM_DIR="$HOME/.nvm"
_check -f "$NVM_DIR/nvm.sh" "source" 
nvm use default >/dev/null 2>&1 || true

# -- Local Env -------------------------------------------------
_check -f "$HOME/.local/bin/env" "source"

# -- Oh My Zsh Flags -------------------------------------------
export DISABLE_LS_COLORS="true"
export ZSH_DISABLE_COMPFIX="true"

# -- Clear old shell function conflicts for OMZ spectrum -------
unfunction color 2>/dev/null || true
unset color 2>/dev/null || true

# -- Oh My Zsh (Source ONCE per session) -----------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)

if [[ -z "${_OMZ_SOURCED:-}" ]]; then
    export _OMZ_SOURCED=1
    [[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
fi

# -- ZSH/Bash compat layer & SSOT entry point ------------------
SSOT="${SSOT:-$HOME/ssot}"
source_files=(
    "$HOME/.env"
    "$SSOT/.zsh-bash-compat.sh"
    "$HOME/.bash_aliases"
    "$SSOT/joe.sh"
    "$HOME/.p10k.zsh"
)
_check -f "source_files" "source" 2>/dev/null



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
    bindkey "^[[A" history-substring-search-up   2>/dev/null
    bindkey "^[[B" history-substring-search-down 2>/dev/null
    bindkey "$terminfo[kcuu1]" history-substring-search-up   2>/dev/null
    bindkey "$terminfo[kcud1]" history-substring-search-down 2>/dev/null
else
    bindkey "^[[A" up-line-or-history   2>/dev/null
    bindkey "^[[B" down-line-or-history 2>/dev/null
fi

GITSTATUS_LOG_LEVEL=DEBUG

# -- Powerlevel10k finalize ------------------------------------
(( ! ${+functions[p10k]} )) || p10k finalize

# -- Aliases & Integrations ------------------------------------
alias ktmux="tmux kill-server"

# OpenClaw Completion
export openclaw_bash_path="$HOME/.openclaw-2/completions/openclaw.bash"
_check -f "$openclaw_bash_path" "source" 2>/dev/null

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

# Micro editor wrapper
micro() {
    if [[ -z "$TERM" || "$TERM" == "dumb" ]]; then
        export TERM="xterm-256color"
        export COLORTERM="truecolor"
    fi
    if ! [ -t 0 ] || ! [ -t 1 ]; then
        if [[ -c /dev/tty ]]; then
            TERM="${TERM:-xterm-256color}" command micro "$@" </dev/tty >/dev/tty
            return $?
        else
            printf "\033[31mERROR: micro requires an interactive TTY\033[0m\n"
            return 1
        fi
    fi
    command printf "\033[?1049l" 2>/dev/null
    command printf "\033[0m" 2>/dev/null
    command printf "\033[?25h" 2>/dev/null
    command printf "\033[2J\033[H" 2>/dev/null
    TERM="${TERM:-xterm-256color}" command micro "$@"
    local ret=$?
    command printf "\033[?1049l" 2>/dev/null
    command printf "\033[0m" 2>/dev/null
    return $ret
}

# To customize prompt, run `p10k configure` or edit $HOME/.p10k.zsh.
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
