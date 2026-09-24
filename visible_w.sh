#!/usr/bin/env bash
# ------------------------------------------------------------
# File: visible_w.sh
# Purpose: Test script for calculating visible terminal width & dynamic borders
# ------------------------------------------------------------
#set -e

SSOT="${SSOT:-$HOME/ssot}"
source "$HOME/.bashrc" 2>/dev/null || true

a=$(cn 10 b --bg 242 "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ 🌿")
echo "$a"
_w $a
echo ${#a}


 fff(){
    local exit_code=$?
    local last_status_raw='(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧'
    local last_status
    if [ $exit_code -eq 0 ]; then
        last_status="$(mc b "$last_status_raw")"
    else
        last_status="$(c lr b "$last_status_raw")"
    fi
    # -- environment / current shell
    local cur_env="${JOE_ENV:-${MY_DEVICE:-WSL2}}"
    #local cur_shell="${_SHELL:-${SHELL##*/}}"
    local env_tag="< $(c 83 d "$cur_env") : $(c 240 d "$cur_shell") >"

    # -- USER@HOST
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-wsl2}"
    #local user_host="$(c cr b "$cur_user") @ $(c y b "$cur_host")"

    # -- Current Dir & Git
    local current_dir="$(c 242 d "${PWD/#$HOME/\~}")"
    #local git_info="$(_git_prompt)"
    local sep="$(c gr d '|')"

    # -- 1. รวมเนื้อหาของแถวกลางจริงที่จะแสดงผล
    local prompt_content="${sep} ${last_status} ${env_tag} ${user_host} in ${current_dir}${git_info} ${sep}"

    # -- 2. Dynamic border calculation: ยิงวัดความกว้างรอบเดียว (One-Shot)
    local term_w
    term_w=$(tput cols 2>/dev/null || echo 80)
    #( term_w < 37 )) && term_w=37

    local text_len
    text_len=$(_w "$prompt_content")

    local lens=$text_len
    (( lens > (term_w - 2) )) && lens=$(( term_w - 2 ))
    #(( lens < 37 )) && lens=$(( term_w - 2 ))

    local BN_BORDER_CHAR_TOP="${BOT_LINE:-$'\u2581'}"
    local BN_BORDER_CHAR_BOT="${TOP_LINE:-$'\u2594'}"

    local _str_t="" _str_b=""
    for (( _i = 1; _i <= lens; _i++ )); do
        _str_t+="${BN_BORDER_CHAR_TOP}"
        _str_b+="${BN_BORDER_CHAR_BOT}"
    done
    local border_top="$(c gr d "${_str_t}")"
    local border_bot="$(c gr d "${_str_b}")"

    # -- 3. ประกอบร่าง Dynamic PS1 (Prompt)
    local PS1_=""
    PS1_+="${border_top}\n"
    PS1_+="${prompt_content}\n"
    PS1_+="${border_bot}\n"
    PS1_+=" -→ "

    export -n PS1 2>/dev/null || true
    PS="$PS1_"
    printf '%b' "$PS1_"
    printf '%s\n' "$PS1_"
    echo "$PS1_"
    echo -n "$PS1_"
  }
    fff
