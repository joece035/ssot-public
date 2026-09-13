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
                   cn r b "❌ -l ต้องตามด้วยตัวเลข เช่น: wtf -g -l 10 pattern"
                   return 1
               fi
               limit="$OPTARG" ;;
            :) cn r b "❌ -$OPTARG ต้องมีค่าตาม เช่น: -l 10"; return 1 ;;
            \?) cn r b "❌ flag ไม่รู้จัก: -$OPTARG  (ใช้ได้: -g -v -l N)"; return 1 ;;
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
            cn r b "❌ ต้องระบุ pattern: wtf -g [-v] [-l N] <pattern>"
            return 1
        fi

        # helper: พิมพ์รายการด้วยสีจาก SSOT พร้อมตัดตาม limit
        #   $1 = label (หัวข้อหมวด), $2 = cn code (r/g/c/m/gr/...), $3.. = items
        _wtf_limit() {
            local label="$1"; local item_color="$2"; shift 2
            local -a items=("$@")
            local total=${#items[@]}
            local -a shown=("${items[@]}")
            if (( opt_l && limit > 0 && total > limit )); then
                shown=("${items[@]:0:$limit}")
                local remaining=$(( total - limit ))
                cn gr "" "   ...และอีก $remaining รายการ (เพิ่ม -l N เพื่อดูเพิ่ม)"
            fi
            if (( ${#shown[@]} > 0 )); then
                cn y b "$label"
                local item
                for item in "${shown[@]}"; do
                    cn "$item_color" "" "   $item"
                done
            fi
        }

        cn c "" "▬▬▬▬▬▬▬▬▬▬▬▬ wtf -g '$pattern' ▬▬▬▬▬▬▬▬▬▬▬▬"

        # ── Functions ──
        local -a fn_results=()
        if [[ "${_SHELL}" == "zsh" ]]; then
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
        if [[ "${_SHELL}" == "zsh" ]]; then
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
            if [[ "${_SHELL}" == "zsh" ]]; then
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
        if [[ "${_SHELL}" == "zsh" ]]; then
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

        cn c "" "▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬"

        # ── Learn Mode footer (-v) ──
        if (( opt_v )); then
            cn gr "" "━━━━━━━━━━━━━━ 📖 Learn Mode ━━━━━━━━━━━━━━"
            if [[ "${_SHELL}" == "zsh" ]]; then
                cn gr "" "# Functions : print -l \${(ok)functions} | grep -i '$pattern'"
                cn gr "" "# Aliases   : alias | grep -i '$pattern'"
                cn gr "" "# Variables : env | grep -i '$pattern'"
                cn gr "" "# Commands  : whence -pm '*${pattern}*'"
            else
                cn gr "" "# Functions : compgen -A function | grep -i '$pattern'"
                cn gr "" "# Aliases   : compgen -A alias | grep -i '$pattern'"
                cn gr "" "# Variables : env | grep -i '$pattern'"
                cn gr "" "# Commands  : compgen -c | grep -i '$pattern' | sort -u"
            fi
            cn gr "" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
            cn r b "❌ '$varname' ไม่ใช่ชื่อตัวแปรที่ถูกต้อง"
            return 1
        fi

        if [[ ! -v "$varname" ]]; then
            cn r b "❌ ตัวแปร '$varname' ยังไม่ถูก set"
            return 1
        fi

        local value
        if [[ "${_SHELL}" == "zsh" ]]; then
            value="${(P)varname}"   # zsh indirect expansion
        else
            # eval+single-quote: ซ่อน ${!varname} จาก zsh history expansion
            eval 'value="${!varname}"'   # bash indirect expansion
        fi

        if (( want_len )); then
            cn lg b "\${#$varname} = ${#value}"
        else
            cn lg b "$varname = $value"
            cn lg n "length: ${#value}"
        fi
        return 0
    fi

    # ─────────────────────────────────────────────────────────────
    # MODE 2: Command / alias / function inspection
    # ─────────────────────────────────────────────────────────────
    if [[ -z "$1" ]]; then
        cn r b "❌ กรุณาระบุคำสั่ง, alias หรือตัวแปร เช่น: wtf test_wtf หรือ wtf '\$VAR'"
        return 1
    fi

    local target="$1"
    local alias_def

    if [[ "${_SHELL}" == "zsh" ]]; then
        # ฝั่ง Zsh (Termux)
        if [ "$(whence -w "$1" 2>/dev/null)" = "$1: alias" ]; then
            alias_def=$(alias "$1" 2>/dev/null)
            target=$(echo "$alias_def" | cut -d'=' -f2- | tr -d "'" | awk '{print $1}')
        fi
        type -a "$1" 2>/dev/null | grep -E '^[^[:space:]]+ is '
    else
        # ฝั่ง Bash (WSL / Git-Bash)
        if [ "$(type -t "$1" 2>/dev/null)" = "alias" ]; then
            alias_def=$(alias "$1" 2>/dev/null)
            target=$(echo "$alias_def" | cut -d'=' -f2- | tr -d "'" | awk '{print $1}')
        fi

        local type_info
        type_info="$(type -a "$1" 2>/dev/null | grep -E '^[^[:space:]]+ is ')"
        if [[ -z "$type_info" ]]; then
            cn r b "❌ '$1' ไม่พบในระบบ (not found)"
            return 1
        fi

        # ถ้า target เป็นฟังก์ชัน ให้ค้นหาตำแหน่งไฟล์ต้นทางเหมือน Zsh
        if [ "$(type -t "$target" 2>/dev/null)" = "function" ]; then
            local fn_file="" fn_line="" ext_info=""
            shopt -s extdebug 2>/dev/null
            ext_info="$(declare -F "$target" 2>/dev/null)"
            shopt -u extdebug 2>/dev/null

            if [[ -n "$ext_info" ]]; then
                read -r _fn fn_line fn_file <<< "$ext_info"
            fi

            if [[ -z "$fn_file" ]]; then
                local search_dir="${BASH_SOURCE[0]%/*}"
                if [[ -z "$search_dir" || "$search_dir" == "." ]]; then
                    search_dir="${HOME}/ssot"
                fi
                local grep_res
                grep_res="$(grep -rnE "^\s*(function\s+)?${target}\s*\(\)" "$search_dir" 2>/dev/null | head -n 1)"
                if [[ -n "$grep_res" ]]; then
                    fn_file="${grep_res%%:*}"
                fi
            fi

            if [[ -n "$fn_file" ]]; then
                echo "$target is a shell function from $fn_file"
            else
                echo "$type_info"
            fi
        else
            echo "$type_info"
        fi
    fi

    local func_def
    func_def="$(declare -f "$target" 2>/dev/null)"
    if [[ -n "$func_def" ]]; then
        cn lg b "$func_def"
    fi
}

test_wtf() {

  cn 10 b "Test wtf"

}
alias t_wtf='test_wtf'
  



