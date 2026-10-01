# bash: #!/bin/bash
#!/usr/bin/env pwsh
# ============================================================
# 02-aliases.sh — All Aliases (CANONICAL)
# ============================================================
# This is the SINGLE SOURCE OF TRUTH for all aliases.
# Organized by category for easy maintenance.
#
# Stage: 5 (after all env vars and functions loaded)
# Dependencies: 00-env.sh (for $oppc, $dbp, etc.)
# ============================================================

# ============================================================
# NAVIGATION & SHORTCUTS
# ============================================================


# bash: alias ls='ls --color=auto'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias ls='ls --color=auto'
# bash: alias la='ls -A'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias la='ls -A'
# bash: alias l='ls -CF'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias l='ls -CF'





# bash: alias dir='dir --color=auto'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias dir='dir --color=auto'
# bash: alias vdir='vdir --color=auto'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias vdir='vdir --color=auto'
# bash: alias grep='grep --color=auto'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias grep='grep --color=auto'
# bash: alias fgrep='fgrep --color=auto'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias fgrep='fgrep --color=auto'
# bash: alias egrep='egrep --color=auto'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias egrep='egrep --color=auto'
# bash: alias diff='diff --color=auto'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias diff='diff --color=auto'
# bash: alias ip='ip --color=auto'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias ip='ip --color=auto'





# bash: case "$_SHELL" in
switch -Wildcard ($_SHELL) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
    # bash: zsh) unbinding -a g >/dev/null 2>&1 || true ;;
    'zsh' {  # pattern) -> "..." {
        unbinding -a g >/dev/null 2>&1 || true  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
        break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
    }
    # bash: bash) unbinding -a ll >/dev/null 2>&1 || true ;;
    'bash' {  # pattern) -> "..." {
        unbinding -a ll >/dev/null 2>&1 || true  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
        break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
    }
# bash: esac
# -> จบ case — pwsh ปิด switch ด้วย } แทน esac
}


#alias spy='source $PYTHON_VENV'

# Directory shortcuts (using env vars from 00-env.sh)

# bash: alias htm='cd $htm'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias htm='cd $htm'
# bash: alias hwsl='cd $HWSL'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias hwsl='cd $HWSL'
# bash: alias hpc='cd $hpc'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias hpc='cd $hpc'
# bash: alias hmp='cd $hmp'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias hmp='cd $hmp'
# bash: alias cdbsc='cd $SSOT && pwd'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias cdbsc='cd $SSOT && pwd'
# bash: alias dbp='cd $DASHBOARD_DIR'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias dbp='cd $DASHBOARD_DIR'
# bash: alias sdc='cd $SDCARD_PATH && pwd'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias sdc='cd $SDCARD_PATH && pwd'
# bash: alias cdboom='cd $boom'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias cdboom='cd $boom'
# bash: alias bkboom='cd $bk_boom'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias bkboom='cd $bk_boom'
# ============================================================
# CONFIGURATION & RELOADING
# ============================================================

# Shell-aware reload (zsh uses .zshrc, bash uses .bashrc)


# ============================================================
# SYSTEM & PROCESS MANAGEMENT
# ============================================================

# bash: alias ktmux="tmux kill-server"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias ktmux="tmux kill-server"

# bash: ll() {
function ll {  # ฟังก์ชัน bash -> function name {
    # bash: fm ls "$@"
    fm ls "$@"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}



# Syncthing (WSL)
# bash: alias s-start="(syncthing serve --gui-address=0.0.0.0:${NODE_WSL_ST_PORT:-8385} &)"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias s-start="(syncthing serve --gui-address=0.0.0.0:${NODE_WSL_ST_PORT:-8385} &)"
# bash: alias s-stop="pkill -f 'syncthing serve' && echo 'WSL Syncthing stopped'"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias s-stop="pkill -f 'syncthing serve' && echo 'WSL Syncthing stopped'"
# bash: alias s-status="ss -tlnp | grep ${NODE_WSL_ST_PORT:-8385} && echo 'WSL Syncthing: RUNNING' || echo 'WSL Syncthing: STOPPED'"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias s-status="ss -tlnp | grep ${NODE_WSL_ST_PORT:-8385} && echo 'WSL Syncthing: RUNNING' || echo 'WSL Syncthing: STOPPED'"
# bash: alias s-log="tail -20 \"$HOME/.local/state/syncthing/syncthing.log\" 2>/dev/null || echo 'No log found'"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias s-log="tail -20 \"$HOME/.local/state/syncthing/syncthing.log\" 2>/dev/null || echo 'No log found'"



# ============================================================
# BUILD & COMPILATION
# ============================================================

# bash: alias fbrun="full_pipe"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias fbrun="full_pipe"
# bash: alias rbdb='rbfe && opdb'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias rbdb='rbfe && opdb'

# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
#                       alias                        #
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
# bash: alias cdrp="cd $SSOT && cn 45 b "$PWD""
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias cdrp="cd $SSOT && cn 45 b "$PWD""
# bash: alias jenv="cn lg b $JOE_ENV"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias jenv="cn lg b $JOE_ENV"
# bash: alias repos="cn lg b $SSOT"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias repos="cn lg b $SSOT"
# bash: alias envm='bash "$SSOT/tools/env-manager.sh"'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias envm='bash "$SSOT/tools/env-manager.sh"'
# bash: alias envmgr='bash "$SSOT/tools/env-manager.sh"'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias envmgr='bash "$SSOT/tools/env-manager.sh"'
# bash: alias b2p='bash "$SSOT/tools/b2p.sh"'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias b2p='bash "$SSOT/tools/b2p.sh"'



# statscal — uncomment if tools/statscal/statscal.py exists
# alias statscal='python3 "$SSOT/tools/statscal/statscal.py"'
# alias wr='python3 "$SSOT/tools/statscal/statscal.py"'

# ============================================================
# SSOT SECRET VAULT
# ============================================================
# vault lock    — encrypt ~/.env → core/.env.enc
# vault unlock  — decrypt core/.env.enc → ~/.env
# vault status  — health + audit (exit 1 if incomplete)
# vault init    — interactive wizard
# vault export  — encrypted backup
# vault lock_pubkey   — encrypt pubkeys → core/pubkeys.enc
# vault unlock_pubkey — decrypt + install to authorized_keys
# vault pubkey-status — show key status
# vault pubkey-audit  — read-only authorized_keys check (corrector)
# vault pubkey-fix    — repair this node (corrector fix-local)
# vault pubkey-collect [--add <key>] [--scan-mesh] — merge keys into vault
# vault pubkey-sync   — install vault keys (corrector install)
# bash: alias vault='${SSOT:-$HOME/ssot}/bootstrap/vault/ssot-vault.sh'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias vault='${SSOT:-$HOME/ssot}/bootstrap/vault/ssot-vault.sh'
# bash: alias ssot-vault='${SSOT:-$HOME/ssot}/bootstrap/vault/ssot-vault.sh'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias ssot-vault='${SSOT:-$HOME/ssot}/bootstrap/vault/ssot-vault.sh'
# bash: alias secret-setup='${SSOT:-$HOME/ssot}/bootstrap/vault/secret-setup.sh'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias secret-setup='${SSOT:-$HOME/ssot}/bootstrap/vault/secret-setup.sh'
# bash: alias node-register='${SSOT:-$HOME/ssot}/bootstrap/nodes/node-register.sh'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias node-register='${SSOT:-$HOME/ssot}/bootstrap/nodes/node-register.sh'
# bash: alias node-status='${SSOT:-$HOME/ssot}/bootstrap/nodes/node-status.sh'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias node-status='${SSOT:-$HOME/ssot}/bootstrap/nodes/node-status.sh'
# bash: alias nodestatus='${SSOT:-$HOME/ssot}/bootstrap/nodes/node-status.sh'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias nodestatus='${SSOT:-$HOME/ssot}/bootstrap/nodes/node-status.sh'
# bash: alias ns='${SSOT:-$HOME/ssot}/bootstrap/nodes/node-status.sh'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias ns='${SSOT:-$HOME/ssot}/bootstrap/nodes/node-status.sh'

# ============================================================
# SYSTEM DASHBOARD
# ============================================================
# dashboard          — full dashboard (all sections)
# dashboard --ssh    — include live SSH tests
# dashboard --compact — minimal view
# dashboard --json   — JSON output
# db                 — shorthand for dashboard
# bash: alias ssotdb='${SSOT:-$HOME/ssot}/tools/dashboard.sh'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias ssotdb='${SSOT:-$HOME/ssot}/tools/dashboard.sh'
# bash: alias db='${SSOT:-$HOME/ssot}/tools/dashboard.sh'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias db='${SSOT:-$HOME/ssot}/tools/dashboard.sh'

#ssh audit
# bash: alias ssh-audit='bash $SSOT/bootstrap/script/ssh_audit.sh'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias ssh-audit='bash $SSOT/bootstrap/script/ssh_audit.sh'

# bash: alias py="python3"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias py="python3"
# --codetrans
# bash: export b2p_path="$SSOT/bash_to_python/codetrans.py"
$env:b2p_path = "$SSOT/bash_to_python/codetrans.py"  # export -> $env:VAR
# bash: alias 2py='python3 $b2p_path'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias 2py='python3 $b2p_path'

# -- dice simulator

# bash: alias dice="bash $SSOT/roll.sh"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias dice="bash $SSOT/roll.sh"
# bash: alias dicepy="python3 $SSOT/roll.py"
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias dicepy="python3 $SSOT/roll.py"
