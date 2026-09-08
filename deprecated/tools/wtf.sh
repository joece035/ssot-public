#!/bin/bash

 wtf () {
    # ══════════════════════════════════════════════════════════════
    # wtf — Multi-mode CLI inspector (SSOT: bash/zsh via $JOE_ENV)
    # Usage:
    #   wtf <cmd>            Mode 2: inspect command/alias/function
    #   wtf '$VAR'           Mode 1: inspect variable value + length
    #   wtf '${#VAR}'        Mode 1: inspect variable length only
    #   wtf -g <pat>         Mode 3: search functions/aliases/vars/cmds
    #   wtf -g -v <pat>      Mode 3 + Learn Mode (show raw commands)
    #   wtf -g -l N <pat>    Mode 3 + limit N results per category
    #   wtf -g -v -l N <pat> Mode 3 + both (flags MUST come before pattern)
    # ══════════════════════════════════════════════════════════════

    local opt_g=0 opt_v=0 opt_l=0 limit=0
    local OPTIND=1

    # ── Parse flags (POSIX getopts: ทุก flag ต้องมาก่อน pattern) ──
    while getopts ":gvl:" opt; do
        case "$opt" in
            g) opt_g=1 ;;
            v) opt_v=1 ;;
            l) opt_l=1
               if ! [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
                   color r b "❌ -l ต้องตามด้วยตัวเลข เช่น: wtf -g -l 10 pattern"
                   return 1
               fi
               limit="$OPTARG" ;;
            :) color r b "❌ -$OPTARG ต้องมีค่าตาม เช่น: -l 10"; return 1 ;;
            \?) color r b "❌ flag ไม่รู้จัก: -$OPTARG  (ใช้ได้: -g -v -l N)"; return 1 ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    # ─────────────────────────────────────────────────────────────
    # MODE 3: Search — wtf -g [-v] [-l N] <pattern>
    # Colors via `color` from 01-colors.sh (no hardcoded escapes)
    # ─────────────────────────────────────────────────────────────
    if (( opt_g )); then
        local pattern="${1:-}"
        if [[ -z "$pattern" ]]; then
            color r b "❌ ต้องระบุ pattern: wtf -g [-v] [-l N] <pattern>"
            return 1
        fi

        # helper: พิมพ์รายการด้วยสีจาก SSOT พร้อมตัดตาม limit
        #   $1 = label (หัวข้อหมวด), $2 = color code (r/g/c/m/gr/...), $3.. = items
        _wtf_limit() {
            local label="$1"; local item_color="$2"; shift 2
            local -a items=("$@")
            local total=${#items[@]}
            local -a shown=("${items[@]}")
            if (( opt_l && limit > 0 && total > limit )); then
                shown=("${items[@]:0:$limit}")
                local remaining=$(( total - limit ))
                color gr "" "   ...และอีก $remaining รายการ (เพิ่ม -l N เพื่อดูเพิ่ม)"
            fi
            if (( ${#shown[@]} > 0 )); then
                color y b "$label"
                local item
                for item in "${shown[@]}"; do
                    color "$item_color" "" "   $item"
                done
            fi
        }

        color c "" "▬▬▬▬▬▬▬▬▬▬▬▬ wtf -g '$pattern' ▬▬▬▬▬▬▬▬▬▬▬▬"

        # ── Functions ──
        local -a fn_results=()
        if [[ "$JOE_ENV" == "TERMUX" ]]; then
            # zsh: ${(ok)functions} ให้ชื่อฟังก์ชันทั้งหมด
            while IFS= read -r fn; do
                fn_results+=( "$fn" )
            done < <( print -l ${(ok)functions} 2>/dev/null | grep -i "$pattern" )
        else
            # bash
            while IFS= read -r fn; do
                fn_results+=( "$fn" )
            done < <( compgen -A function 2>/dev/null | grep -i "$pattern" )
        fi
        _wtf_limit "⚡ Functions" g "${fn_results[@]}"

        # ── Aliases ──
        local -a alias_results=()
        if [[ "$JOE_ENV" == "TERMUX" ]]; then
            while IFS= read -r al; do
                alias_results+=( "$al" )
            done < <( alias 2>/dev/null | grep -i "$pattern" | cut -d'=' -f1 | sed 's/alias //' )
        else
            while IFS= read -r al; do
                alias_results+=( "$al" )
            done < <( compgen -A alias 2>/dev/null | grep -i "$pattern" )
        fi
        _wtf_limit "📎 Aliases" c "${alias_results[@]}"

        # ── Environment Variables ──
        local -a var_results=()
        local vval
        while IFS= read -r vname; do
            if [[ "$JOE_ENV" == "TERMUX" ]]; then
                vval="${(P)vname}"      # zsh indirect expansion
            else
                eval 'vval="${!vname}"'  # bash indirect (eval hides from zsh)
            fi
            # ตัดค่าที่ยาวเกิน 60 ตัว
            if (( ${#vval} > 60 )); then vval="${vval:0:60}..."; fi
            var_results+=( "${vname}=${vval}" )
        done < <( env 2>/dev/null | grep -i "$pattern" | cut -d'=' -f1 | sort -u )
        _wtf_limit "🌍 Variables" m "${var_results[@]}"

        # ── Commands (PATH) ──
        local -a cmd_results=()
        if [[ "$JOE_ENV" == "TERMUX" ]]; then
            # zsh: whence -pm ดีกว่า compgen
            while IFS= read -r cmd; do
                cmd_results+=( "$cmd" )
            done < <( whence -pm "*${pattern}*" 2>/dev/null | grep -i "$pattern" | head -50 )
        else
            while IFS= read -r cmd; do
                cmd_results+=( "$cmd" )
            done < <( compgen -c 2>/dev/null | grep -i "$pattern" | sort -u )
        fi
        _wtf_limit "📦 Commands" gr "${cmd_results[@]}"

        color c "" "▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬"

        # ── Learn Mode footer (-v) ──
        if (( opt_v )); then
            color gr "" "━━━━━━━━━━━━━━ 📖 Learn Mode ━━━━━━━━━━━━━━"
            if [[ "$JOE_ENV" == "TERMUX" ]]; then
                color gr "" "# Functions : print -l \${(ok)functions} | grep -i '$pattern'"
                color gr "" "# Aliases   : alias | grep -i '$pattern'"
                color gr "" "# Variables : env | grep -i '$pattern'"
                color gr "" "# Commands  : whence -pm '*${pattern}*'"
            else
                color gr "" "# Functions : compgen -A function | grep -i '$pattern'"
                color gr "" "# Aliases   : compgen -A alias | grep -i '$pattern'"
                color gr "" "# Variables : env | grep -i '$pattern'"
                color gr "" "# Commands  : compgen -c | grep -i '$pattern' | sort -u"
            fi
            color gr "" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
        return 0
    fi

    # ─────────────────────────────────────────────────────────────
    # MODE 1: Variable inspection — wtf '$VAR' / wtf '${#VAR}'
    # ─────────────────────────────────────────────────────────────
    local input="${1:-}"
    if [[ "$input" == \$* || "$input" == \#* ]]; then
        local varname="$input"
        varname="${varname#\$}"
        varname="${varname#\{}"
        varname="${varname%\}}"

        local want_len=0
        if [[ "$varname" == \#* ]]; then
            want_len=1
            varname="${varname#\#}"
        fi

        if [[ ! "$varname" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            color r b "❌ '$varname' ไม่ใช่ชื่อตัวแปรที่ถูกต้อง"
            return 1
        fi

        if [[ ! -v "$varname" ]]; then
            color r b "❌ ตัวแปร '$varname' ยังไม่ถูก set"
            return 1
        fi

        local value
        if [[ "$JOE_ENV" == "TERMUX" ]]; then
            value="${(P)varname}"   # zsh indirect expansion
        else
            # eval+single-quote: ซ่อน ${!varname} จาก zsh history expansion
            eval 'value="${!varname}"'   # bash indirect expansion
        fi

        if (( want_len )); then
            color lg b "\${#$varname} = ${#value}"
        else
            color lg b "$varname = $value"
            color lg n "length: ${#value}"
        fi
        return 0
    fi

    # ─────────────────────────────────────────────────────────────
    # MODE 2: Command / alias / function inspection (ของเดิม ไม่แตะ)
    # ─────────────────────────────────────────────────────────────
    type -a "$1"
    local target="$1"
    local alias_def

    if [[ "$JOE_ENV" == "TERMUX" ]]; then
        # ฝั่ง Zsh (Termux)
        if [ "$(whence -w "$1")" = "$1: alias" ]; then
            alias_def=$(alias "$1")
            target=$(echo "$alias_def" | cut -d'=' -f2- | tr -d "'" | awk '{print $1}')
        fi
    else
        # ฝั่ง Bash (WSL / Git-Bash)
        if [ "$(type -t "$1")" = "alias" ]; then
            alias_def=$(alias "$1")
            target=$(echo "$alias_def" | cut -d'=' -f2- | tr -d "'" | awk '{print $1}')
        fi
    fi

    color lg b "$(declare -f "$target" 2>/dev/null)"
}
wth   () {
    local target="$1"
    local alias_def
    
   case "$1" in
      \$*) 
            local var="${1#\$}"   # ตัด $ ออก
            echo "${!var}"        # indirect expansion
            ;;
      *)
            type -a "$target" 2>/dev/null
            if [[ "$JOE_ENV" == "TERMUX" ]]; then
  # ฝั่ง Zsh (Termux)
               if [ "$(whence -w "$1")" = "$1: alias" ]; then
                alias_def=$(alias "$1")
                target=$(echo "$alias_def" | cut -d'=' -f2- | tr -d "'" | awk '{print $1}')
               fi  
            else
  # ฝั่ง Bash (WSL / Git-Bash)
               if [ "$(type -t "$1")" = "alias" ]; then
                alias_def=$(alias "$1")
                target=$(echo "$alias_def" | cut -d'=' -f2- | tr -d "'" | awk '{print $1}')
               fi  
            fi
            ;;
   esac         
        color lg b "$(declare -f "$target" 2>/dev/null)"
}



