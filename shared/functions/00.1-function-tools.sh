#!/bin/bash
# ============================================================
# 10-function-tools.sh.sh 
# ============================================================

# ============================================================
# curmv — Cursor Movement Tool
# Usage: curmv <command> [count]
# ============================================================

# -- helper: print blank line (renamed from _ to avoid oh-my-zsh alias conflict)
_nl(){ echo -e ""; }


# ============================================================
# maths — Math & Rounding Engine (Excel-style ROUND, ROUNDUP, ROUNDDOWN)
# Usage:
#   maths [decimal] [u|d|r] <expression>
# Modes:
#   u | up | roundup | ceil      — ROUNDUP (ปัดขึ้นเสมอ)
#   d | down | rounddown | floor — ROUNDDOWN (ปัดลง/ตัดทศนิยมทิ้ง)
#   r | round                   — ROUND (ปัดเศษมาตรฐาน >= 0.5)
# ============================================================
bc___() {
    [[ -z "$1" ]] && return
    local decimal=0 mode="default"

    # Step 1: Check for mode keyword in arg1
    case "${1:-}" in
        u|up|roundup|ceil) mode="up"; shift ;;
        d|down|rounddown|floor|trunc) mode="down"; shift ;;
        r|round) mode="round"; shift ;;
    esac

    # Step 2: Check if scale is specified as a standalone number (e.g. 2 10/3 or 2 u 10/3)
    if [[ "$1" =~ ^[0-9]+$ ]] && [[ $# -gt 1 ]]; then
        if [[ "$2" =~ ^(u|up|roundup|ceil|d|down|rounddown|floor|trunc|r|round)$ ]]; then
            decimal="$1"
            shift
            case "$1" in
                u|up|roundup|ceil) mode="up" ;;
                d|down|rounddown|floor|trunc) mode="down" ;;
                r|round) mode="round" ;;
            esac
            shift
        elif ! [[ "$2" =~ ^[+*/%^-] ]]; then
            decimal="$1"
            shift
        fi
    fi

    # Step 3: Check mode again if shifted
    case "${1:-}" in
        u|up|roundup|ceil) mode="up"; shift ;;
        d|down|rounddown|floor|trunc) mode="down"; shift ;;
        r|round) mode="round"; shift ;;
    esac

    local expr="$*"
    [[ -z "$expr" ]] && return

    awk -v d="$decimal" -v m="$mode" 'BEGIN {
        val = ('"$expr"')
        mult = 10^d
        sign = (val >= 0 ? 1 : -1)
        abs_v = (val >= 0 ? val : -val) * mult
        iv = int(abs_v)
        if (m == "up") {
            res = sign * (abs_v > iv ? iv + 1 : iv) / mult
        } else if (m == "down") {
            res = sign * iv / mult
        } else if (m == "round") {
            res = sign * int(abs_v + 0.5) / mult
        } else {
            res = sign * iv / mult
        }
        printf "%.*f\n", d, res
    }'
}




# Standalone Excel-style Rounding Functions



mathsnew() {
    [[ -z "$1" ]] && return
    local decimal=${1:-0}
    case "$decimal" in
        s|scale)  shift ;;
        n|no|" ") decimal=0; shift ;;
        # Accept a leading integer as the bc scale (e.g. mathsnew 4 22/7)
        [0-9]|[0-9][0-9]|[0-9][0-9][0-9]) decimal="$1"; shift ;;
        *) decimal=0 ;;
    esac
    printf '%s\n' "scale=${decimal}; $*" | bc -l
}

mathsbk() {
    local d=${1:-0}

    if [[ $# -gt 1 ]]; then
        shift
    fi

    printf 'scale=%s; %s\n' "${d:-0}" "$@" | bc -l
}






tp(){
    tput cols "$@"
}
replace_w() {
    local old_name=${1:-}
    local new_name=${2:-}
    local target=${3:-$PWD}
    
    if [[ -z "$old_name" || -z "$new_name" ]]; then
        echo "Usage: change_word <old_name> <new_name> [target_folder]"
        return 1
    fi
    
    echo "Replacing '$old_name' with '$new_name' in $target..."
    
    # ครอบเครื่องหมายคำพูดซ้อนสไตล์นี้ปลอดภัยที่สุดครับ
    find "$target" -type f -exec sed -i "s/""$old_name""/""$new_name""/g" {} +

    echo "✨ All done!"
}

mv_pattern() {
    local src="${1:?กรุณาระบุ pattern}"
    local dest="${2:?กรุณาระบุ destination}"
    mkdir -p "$dest"
    mv $src "$dest/"
    echo "✅ ย้ายเสร็จ: $(ls "$dest" | wc -l) ไฟล์"
}



wa() {
    ffmpeg -hide_banner -stats \
        -i "$1" \
        -vf scale=-2:480 \
        -c:v libx264 \
        -preset veryfast \
        -crf 28 \
        -c:a aac -b:a 96k \
        "${1%.*}_wa.mp4"
}

get_process() {
    local mode="$1"
    local target="$2"

    case "$mode" in
        t|tree)
            pstree -p | grep -- "$target"
            ;;

        n|normal)
            ps aux | grep -- "$target"
            ;;

        pk|kill)
            local pid
            pid=$(lsof -t -i:"$target")

            if [[ -n "$pid" ]]; then
                cn ora bi "Found process PID=$pid"

                kill "$pid"

                cn 10 b "PID $pid has been killed"
            else
                cn y bi "Nothing found on port $target"
            fi
            ;;

        *)
            return 1
            ;;
    esac
}



agent_md() {

    local target=${1:-$PWD}
    
    cp "$HOME/AGENT.md" "$target" && cn 10 b "copied AGENT.md to $target done"

}


hm() {
    [[ -z "$1" ]] && { echo "Usage: hm <mode> [args...]"; return 1; }
    # hermes.sh — uncomment if tools/hermes.sh exists
    # [[ -f $SSOT/tools/hermes.sh ]] && source $SSOT/tools/hermes.sh
    
   local mode=${1:-}
   shift
   case "${mode}" in
       p|-p|--p|"")
            hermes_profile "$@" ;;
       *)
            hermes "$@" ;;
   esac
}

# -- delete all .rc_* files in $HOME
rc_delete() {
  if [[ "$JOE_ENV" == "TERMUX" || "$JOE_ENV" == "MUMU" ]]; then
    local rc
    local count=0
    for rc in "$HOME"/.rc_*; do
       if [[ -f "$rc" ]]; then
         rm -f "$rc" && cn 28 "deleted $rc"
         count=$((count+1))
       fi
    done
    if [[ $count -gt 0 ]]; then
      c 10 bi "ALL done"
    fi
  fi
}

 
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
#                 SYNCCTL-short_cut                  #
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #

unalias stc 2>/dev/null
stc(){
   [[ -z "$1" ]] && { cn 220 bi "Usage: stc <option> [args...]"; return 1; }
        case "$1" in
            -s|--status|s)    syncctl status $() ;;
            -h|--help|h)      syncctl help ;;
            -t|--tranfer|t)
                              local device=${2:-wsl} 
                              syncctl transfer "${device}" --reason "edited by this device" ;;
            -w|--who|w)       cn 198 bi "$(syncctl who | cut -d" " -f2)" ;;
            *)                syncctl "$@" ;;
    esac

}

# NOTE: A stray "symlink" line used to live here — it was a function
# definition that got deleted but the bare name remained, which zsh
# then tried to execute as a system command, producing this on Termux:
#   "No command symlink found, did you mean: ..."
# That also broke Powerlevel10k instant prompt (any console output
# during zsh init does). Removed 2026-08-08.

#---syncctl shortcut---#
sc() {
  # Resolve SSOT (ssot repo) — fallback chain because $SSOT
  # may not be set yet on Termux/acodex depending on boot order.
  local _ssot=""
  for p in \
      "${SSOT:-}" \
      "$HOME/ssot" \
      "$SSOT" \
      "/data/data/com.termux/files/home/ssot"; do
    [[ -n "$p" && -d "$p" ]] && { _ssot="$p"; break; }
  done

  if [[ -z "$_ssot" ]]; then
    cn 196 bi "sc: cannot locate ssot repo (SSOT empty)"
    return 1
  fi

  if [[ -f "$_ssot/tools/syncctl/syncctl" ]]; then
    source "$_ssot/tools/syncctl/syncctl" 2>/dev/null
  else
    cn 220 bi "syncctl not available (tools/syncctl/ not found)"
    return 1
  fi

  if [[ $# -eq 0 ]]; then
    syncctl --help
    return 0
  fi
  case "$1" in
     tm) syncctl transfer termux --reason "edit on termux via acodex" ;;
    wsl) syncctl transfer wsl --reason "edit on wsl" ;;
    win) syncctl transfer windows --reason "edit on windows" ;;
      *) stc "$@" ;;
  esac
}

# ==============================================================================
# Helper: ensure <cmd> [package_name]
# ------------------------------------------------------------------------------
# ตรวจสอบว่ามีคำสั่ง <cmd> ในระบบหรือไม่ หากไม่มีจะติดตั้งแพ็กเกจให้อัตโนมัติ
# รองรับทั้ง Termux (pkg) และ WSL/Linux (apt) ตาม SSOT JOE_ENV
# ==============================================================================
ensure() {
    local cmd="$1"
    local pkg="${2:-$1}" # ถ้าไม่ระบุชื่อ pkg ให้ใช้ชื่อ cmd เป็นชื่อ pkg

    # 1. เช็คว่ามี command อยู่แล้วหรือไม่
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi

    cn 220 bi "⚠️ Command '$cmd' not found. Installing package '$pkg'..." >&2

    # 2. ตรวจสอบ Package Manager ตาม JOE_ENV / OS
    if command -v pkg >/dev/null 2>&1; then
        # Termux / MuMu
        pkg install -y "$pkg"
    elif command -v apt-get >/dev/null 2>&1; then
        # WSL / Ubuntu / Debian
        if [[ $EUID -eq 0 ]]; then
            apt-get update -qq && apt-get install -y "$pkg"
        else
            sudo apt-get update -qq && sudo apt-get install -y "$pkg"
        fi
    else
        cn 196 bi "❌ Error: No supported package manager found (pkg/apt) to install '$pkg'." >&2
        return 1
    fi

    # 3. ยืนยันการติดตั้ง
    if command -v "$cmd" >/dev/null 2>&1; then
        cn 10 bi "✅ Successfully installed '$pkg' ($cmd)." >&2
        return 0
    else
        cn 9 bi "❌ Failed to install '$pkg'." >&2
        return 1
    fi
}

cmd_ens() {
    
    local cmd="${1:?SELECT COMMAND}"
    command -v $cmd >/dev/null 2>&1
    
    if [[ $? == 0 ]]; then
        cn 10 bi "✅ '$cmd' is ready"
        return 0
    else
        cn 198 bi "❌ '$cmd' not found"
        return 1
    fi
}
#-------------------------




