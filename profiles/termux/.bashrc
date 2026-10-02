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

# ── Locale (Termux) ─────────────────────────────────────────────
# Termux ships NO locale database and has no `locale` command. C.UTF-8
# is the POSIX-sanctioned spelling that bash here actually honours, so
# set it: it gives correct multibyte handling for the prompt and tools.
export LC_ALL="C.UTF-8"
export LC_CTYPE="C.UTF-8"
export LANG="C.UTF-8"
unset LC_COLLATE LC_MESSAGES LC_MONETARY LC_NUMERIC LC_TIME LC_PAPER LC_MEASUREMENT 2>/dev/null

# ── ble.sh ──────────────────────────────────────────────────────
# ble.sh probed the locale with .test-C-locale:
#   local LC_ALL= LC_CTYPE= LANG=C; local s='あ'; ((${#s}==3))
# Termux's bash always answers 1 there (it decodes UTF-8 whatever LANG
# says) — verified unfixable: plain, --posix, --noediting and -o posix
# all give ${#s}==1. So the probe always failed and every login printed
#   ble.sh: The locale 'C' (LC_CTYPE) seems broken. ...
#   ble.sh: Termux has an issue with its locale "C", ...
# which is a false positive (termux/termux-packages#23010).
#
# Clearing _ble_util_locale_broken after load does NOT help: ble recomputes
# the cache whenever $LC_ALL:$LC_CTYPE:$LANG differs from its saved triple,
# and .update-locale-cache runs from ble/term/attach at the FIRST PROMPT —
# after our rc file has finished. The value is therefore always repopulated.
#
# Override the probe instead. It is defined by ble.sh and called by name, so
# a redefinition after the source sticks and can only ever make the check
# pass — it cannot affect any encoding table or character handling.
if [[ $- == *i* && -f $HOME/.local/share/blesh/ble.sh ]]; then
    if [[ -z "${BLE_VERSION-}" ]]; then
        source "$HOME/.local/share/blesh/ble.sh" --attach=none
        # Termux bash is always multibyte-aware; report the probe as passing
        ble/util/.test-C-locale() { return 0; }
        _ble_util_locale_broken=
        _ble_util_locale_broken_notified=
    fi
fi

# ── 3. NVM & COMPLETIONS (MUST come BEFORE .env) ──
# .env reads NVM_DIR to find node path — needs NVM init first
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use default >/dev/null 2>&1 || true

# ── 4. ENVIRONMENT & PATHS ──
# ~/.local/bin/env handles: PATH, ~/.env, SSOT auto-detect, joe.sh
_check -f "$HOME/.local/bin/env" "source"

# Environment-specific overrides
export JOE_ENV="${JOE_ENV:-TERMUX}"
export MY_DEVICE="${MY_DEVICE:-TERMUX}"

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





# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
export PATH="$HOME/.local/bin:$PATH"


export TERM=xterm-256color
