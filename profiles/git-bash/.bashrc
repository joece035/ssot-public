# ~/.bashrc: executed by bash(1) for non-login shells.

[[ -f "$HOME/ssot/.bash_helper" ]] && source "$HOME/ssot/.bash_helper"
# ── 1. CORE BASH CONFIG ──
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ── 2. BASH LINE EDITOR (Disabled on Windows Git Bash for high performance) ──
# ble.sh causes significant fork/subshell latency on MSYS2. Enable only on Linux/WSL.

# ── 3. LAZY LOAD NVM & NODE (Instant shell startup) ──
export NVM_DIR="$HOME/.nvm"
if [ -d "$NVM_DIR" ]; then
    _load_nvm() {
        unset -f nvm node npm npx _load_nvm 2>/dev/null
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    }
    nvm()  { _load_nvm && nvm "$@"; }
    node() { _load_nvm && node "$@"; }
    npm()  { _load_nvm && npm "$@"; }
    npx()  { _load_nvm && npx "$@"; }
fi

# ── 4. ENVIRONMENT & PATHS ──
# ~/.local/bin/env handles: PATH, ~/.env, SSOT auto-detect, joe.sh
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Environment-specific overrides
export JOE_ENV="${JOE_ENV:-GIT-BASH}"
export MY_DEVICE="${MY_DEVICE:-GIT-BASH}"

# Extra PATH entries
export PATH="$HOME/.local/lib/openclaw/bin:$PATH"

# ── 5. ALIASES & COMPLETIONS ──
[ -f ~/.bash_aliases ] && source ~/.bash_aliases

# ── 6. PERSONAL COMMAND CENTER (JOE) ──
# CRLF guard: ถ้า joe.sh ถูกบันทึกเป็น CRLF (จาก Windows/Acode-X) แปลงกลับเป็น LF ก่อน source
if [ -f "$SSOT/joe.sh" ] && grep -qU $'\r' "$SSOT/joe.sh" 2>/dev/null; then
    sed -i 's/\r$//' "$SSOT/joe.sh"
    echo "⚠️  CRLF→LF: joe.sh (auto-fixed)"
fi
[ -f "$SSOT/joe.sh" ] && . "$SSOT/joe.sh" 2>/dev/null

# ── 7. FINAL SETTINGS ──
alias ktmux="tmux kill-server"

# OpenClaw Completion
[ -f "$HOME/.openclaw-2/completions/openclaw.bash" ] && source "$HOME/.openclaw-2/completions/openclaw.bash"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"


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

