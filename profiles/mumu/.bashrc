# $HOME/.bashrc: executed by bash(1) for non-login shells.

[[ -f "$HOME/ssot/.bash_helper" ]] && source "$HOME/ssot/.bash_helper"
# ── 1. CORE BASH CONFIG ──
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ── 2. BASH LINE EDITOR (Source only, no attach yet) ──



# ── 3. NVM & COMPLETIONS (MUST come BEFORE .env) ──
# .env reads NVM_DIR to find node path — needs NVM init first
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use default >/dev/null 2>&1 || true

# ── 4. ENVIRONMENT & PATHS ──
# ~/.local/bin/env handles: PATH, ~/.env, SSOT auto-detect, joe.sh
_check -f "$HOME/.local/bin/env" "source"

# Environment-specific overrides
export JOE_ENV="${JOE_ENV:-MUMU}"
export MY_DEVICE="${MY_DEVICE:-MUMU}"

# Extra PATH entries
export PATH="$HOME/.local/lib/openclaw/bin:$PATH"

# ── 5. ALIASES & COMPLETIONS ──
[ -f $HOME/.bash_aliases ] && source $HOME/.bash_aliases

# ── 6. PERSONAL COMMAND CENTER (JOE) ──
# Source joe.sh; suppress all errors so any function-level bugs
# don't kill the shell (defensive — not a fix, just safety net)
# CRLF guard: ถ้า joe.sh ถูกบันทึกเป็น CRLF (จาก Windows/Acode-X) bash จะ
# parse ไม่ผ่าน → แปลงกลับเป็น LF ก่อน source (joe.sh มี self-heal ข้างในด้วย)
if [ -f $HOME/ssot/joe.sh ] && grep -qU $'\r' $HOME/ssot/joe.sh 2>/dev/null; then
    sed -i 's/\r$//' $HOME/ssot/joe.sh
    echo "⚠️  CRLF→LF: joe.sh (auto-fixed)"
fi
[ -f $HOME/ssot/joe.sh ] && . $HOME/ssot/joe.sh 2>/dev/null






# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
export PATH="$HOME/.local/bin:$PATH"


export TERM=xterm-256color
