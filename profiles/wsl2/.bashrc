# $HOME/.bashrc: executed by bash(1) for non-login shells.
# Load helper functions early so core functions (like _color_render)
# are available during the .env loading phase
if [[ -f "$HOME/ssot/.bash_helper" ]]; then
    source "$HOME/ssot/.bash_helper" 2>/dev/null
fi
    
# ── 1. CORE BASH CONFIG ──
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ── 2. BASH LINE EDITOR (Source only, no attach yet) ──
if [[ $- == *i* && -f $HOME/.local/share/blesh/ble.sh ]]; then
    [[ ${BLE_VERSION-} ]] || source $HOME/.local/share/blesh/ble.sh --attach=none
fi
_check -f "$HOME/.local/share/blesh/ble.sh" "source"
# ── 3. NVM & COMPLETIONS (MUST come BEFORE .env) ──
# .env reads NVM_DIR to find node path — needs NVM init first
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use default >/dev/null 2>&1 || true

# ── 4. ENVIRONMENT & PATHS ──
# ~/.local/bin/env handles: PATH, ~/.env, SSOT auto-detect, joe.sh
. "$HOME/.local/bin/env"

# Environment-specific overrides (set by ~/.local/bin/env via ~/.env)
export JOE_ENV="${JOE_ENV:-WSL2}"
export MY_DEVICE="${MY_DEVICE:-WSL2}"

# Extra PATH entries (not managed by env)
export PATH="$HOME/.local/lib/openclaw/bin:$PATH"

# ── 5. ALIASES & COMPLETIONS ──
[ -f $HOME/.bash_aliases ] && source $HOME/.bash_aliases

# ── 6. PERSONAL COMMAND CENTER (JOE) ──
# joe.sh is auto-sourced by ~/.local/bin/env via SSOT
# CRLF guard: convert CRLF→LF if needed (Windows/Acode-X issue)
if [[ -f "${SSOT:-$HOME/ssot}/joe.sh" ]] && grep -qU $'\r' "${SSOT:-$HOME/ssot}/joe.sh" 2>/dev/null; then
    sed -i 's/\r$//' "${SSOT:-$HOME/ssot}/joe.sh"
    echo "⚠️  CRLF→LF: joe.sh (auto-fixed)"
fi

# ── 6. STARSHIP ──
# if [[ $- == *i* && -z "$STARSHIP_LOADED" ]]; then
#     eval "$(starship init bash)"
#     STARSHIP_LOADED=1
# fi

# ── 8. ATTACH BLE.SH ──
if [[ $- == *i* && ${BLE_VERSION-} && -z "$BLE_ATTACHED" ]]; then
    export BLE_ATTACHED=1
    ble-attach
fi

# ── 9. FINAL SETTINGS ──


# OpenClaw Completion
[ -f "$HOME/.openclaw-2/completions/openclaw.bash" ] && source "$HOME/.openclaw-2/completions/openclaw.bash"

# opencode
export PATH=$HOME/.opencode/bin:$PATH


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
export PATH="$HOME/.local/bin:$PATH"


export TERM=xterm-256color

source -- $HOME/.local/share/blesh/ble.sh
[ -t 0 ] && stty sane 2>/dev/null || true
