#!/usr/bin/env bash
# =============================================================================
#  ███████╗██╗██╗     ███████╗███╗   ███╗ ██████╗ ██████╗
#  ██╔════╝██║██║     ██╔════╝████╗ ████║██╔════╝ ██╔══██╗
#  █████╗  ██║██║     █████╗  ██╔████╔██║██║  ███╗██████╔╝
#  ██╔══╝  ██║██║     ██╔══╝  ██║╚██╔╝██║██║   ██║██╔══██╗
#  ██║     ██║███████╗███████╗██║ ╚═╝ ██║╚██████╔╝██║  ██║
#  ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝
#  File Manager CLI — v3.1 | # ============================================================================= #Everyone + Learn Mode
# =============================================================================
# Usage: source bash-manager.sh      (load all functions)
#        fm help                      (show help menu)
#        fm learn on                  (เปิด Learn Mode — ดูคำสั่งจริง)
#        fm learn off                 (ปิด Learn Mode)
# =============================================================================
#bash-manager.sh switch checking

# ─────────────────────────────────────────────────────────────────
# SINGLE SOURCE OF TRUTH — Guard
# ─────────────────────────────────────────────────────────────────
# This file relies on variables set by joe.sh → 00-env.sh → 01-colors.sh
# If sourced standalone (without joe.sh), we load the minimum needed.


# Ensure SCRIPTS_PATH is set (needed for sourcing other modules)
export SCRIPTS_PATH="${SCRIPTS_PATH:-$HOME/ssot}"

# Source colors from SSOT (core/01-colors.sh) if not already loaded
if ! command -v c >/dev/null 2>&1; then
  _colors_file="$SCRIPTS_PATH/core/01-colors.sh"
  [[ -f "$_colors_file" ]] && source "$_colors_file"
  unset _colors_file
fi

# Source env vars from SSOT (bootstrap/00-env.sh) if not already loaded
if [[ -z "$TERMUX_IP" ]]; then
  _env_file="$SCRIPTS_PATH/bootstrap/00-env.sh"
  [[ -f "$_env_file" ]] && source "$_env_file"
  unset _env_file
fi

# ─────────────────────────────────────────────────────────────────
# DYNAMIC BLOCK HELPERS (Visual width & padding)
# ─────────────────────────────────────────────────────────────────
_dblock_strip_ansi() {
  printf '%s' "$1" | sed -E $'s/\x1b\\[[0-9;]*[a-zA-Z]//g'
}

_dblock_vis_len() {
  local clean
  clean=$(_dblock_strip_ansi "$1")
  # Strip combining marks for accurate terminal cell width
  local clean_no_combining
  clean_no_combining=$(printf '%s' "$clean" | tr -d "ัิีึืฺุู็่้๊๋์ํ๎" 2>/dev/null || echo "$clean")
  echo "${#clean_no_combining}"
}

_dblock_repeat() {
  local count=$1 char=$2 out="" c
  (( count < 0 )) && count=0
  for (( c=0; c<count; c++ )); do out+="$char"; done
  printf '%s' "$out"
}

# ─────────────────────────────────────────────────────────────────
# LEARN MODE TOGGLE
# ─────────────────────────────────────────────────────────────────
FM_LEARN=${FM_LEARN:-0}

# _learn_box <title> <cmd_line> [flag|desc] [flag|desc] ...
# แสดง box อธิบายคำสั่งจริงที่กำลังรัน — ปรับความกว้าง Dynamic ตามเนื้อหาจริง (title, cmd, flags, descriptions)
_learn_box() {
  [[ "$FM_LEARN" != "1" ]] && return
  local title="$1"; shift
  local cmd="$1";   shift
  local -a annotations=("$@")

  # 1. Measure dimensions
  local max_flag=0 max_desc=0
  local -a p_flags=() p_descs=()

  for item in "${annotations[@]}"; do
    local flag="${item%%|*}"
    local desc="${item##*|}"
    p_flags+=("$flag")
    p_descs+=("$desc")

    local l_f; l_f=$(_dblock_vis_len "$flag")
    local l_d; l_d=$(_dblock_vis_len "$desc")
    (( l_f > max_flag )) && max_flag=$l_f
    (( l_d > max_desc )) && max_desc=$l_d
  done

  local l_title; l_title=$(_dblock_vis_len "$title")
  local l_cmd; l_cmd=$(_dblock_vis_len "$cmd")
  local cmd_display="\$ ${cmd}"
  local l_cmd_disp=$(( l_cmd + 2 ))

  # Minimum default width
  local inner_w=65

  # Content width from flags + descriptions
  local flag_section_w=$(( max_flag + 4 + max_desc ))

  # Find max needed inner width
  (( l_title + 4 > inner_w )) && inner_w=$(( l_title + 4 ))
  (( l_cmd_disp + 4 > inner_w )) && inner_w=$(( l_cmd_disp + 4 ))
  (( flag_section_w + 4 > inner_w )) && inner_w=$(( flag_section_w + 4 ))

  # Cap at terminal width - 6
  local term_cols=$(tput cols 2>/dev/null || echo 80)
  local max_term=$(( term_cols - 6 ))
  (( max_term < 40 )) && max_term=40
  (( inner_w > max_term )) && inner_w=$max_term

  # Style colors
  local c_box="$(_c 208)"
  local c_rst="$(_r)"
  local c_cmd="$(_c 46)"
  local c_flag="$(_c 51)$(_b)"
  local c_desc="$(_c 244)"
  local c_dim="$(_c 244)$(_d)"
  local c_title="$(_c 255)$(_b)"

  local top_fill=$(( inner_w - 16 ))
  (( top_fill < 1 )) && top_fill=1
  local hz_top; hz_top=$(_dblock_repeat "$top_fill" "─")
  local hz_mid; hz_mid=$(_dblock_repeat "$inner_w" "─")
  local hz_bot; hz_bot=$(_dblock_repeat "$inner_w" "─")

  echo ""
  # Top Header
  printf "  %s┌─ 📚 LEARN MODE %s┐%s\n" "$c_box" "$hz_top" "$c_rst"

  # Title Line
  local pad_t=$(( inner_w - l_title - 2 ))
  (( pad_t < 0 )) && pad_t=0
  local s_pad_t; s_pad_t=$(_dblock_repeat "$pad_t" " ")
  printf "  %s│%s  %s%s%s%s%s│%s\n" "$c_box" "$c_rst" "$c_title" "$title" "$c_rst" "$s_pad_t" "$c_box" "$c_rst"

  # Mid Separator
  printf "  %s├%s┤%s\n" "$c_box" "$hz_mid" "$c_rst"

  # Raw Command Header
  local pad_raw_hdr=$(( inner_w - 14 ))
  (( pad_raw_hdr < 0 )) && pad_raw_hdr=0
  local s_pad_raw_hdr; s_pad_raw_hdr=$(_dblock_repeat "$pad_raw_hdr" " ")
  printf "  %s│%s  %sRaw command:%s%s%s│%s\n" "$c_box" "$c_rst" "$c_dim" "$c_rst" "$s_pad_raw_hdr" "$c_box" "$c_rst"

  # Raw Command Line
  local pad_cmd=$(( inner_w - l_cmd_disp - 2 ))
  (( pad_cmd < 0 )) && pad_cmd=0
  local s_pad_cmd; s_pad_cmd=$(_dblock_repeat "$pad_cmd" " ")
  printf "  %s│%s  %s%s%s%s%s│%s\n" "$c_box" "$c_rst" "$c_cmd" "$cmd_display" "$c_rst" "$s_pad_cmd" "$c_box" "$c_rst"

  # Annotations (Flags & options)
  if [[ ${#p_flags[@]} -gt 0 ]]; then
    # Blank row inside box
    local s_blank; s_blank=$(_dblock_repeat "$inner_w" " ")
    printf "  %s│%s%s%s│%s\n" "$c_box" "$c_rst" "$s_blank" "$c_box" "$c_rst"

    # Flags Header
    local pad_flags_hdr=$(( inner_w - 25 ))
    (( pad_flags_hdr < 0 )) && pad_flags_hdr=0
    local s_pad_flags_hdr; s_pad_flags_hdr=$(_dblock_repeat "$pad_flags_hdr" " ")
    printf "  %s│%s  %sFlags & options อธิบาย:%s%s%s│%s\n" "$c_box" "$c_rst" "$c_dim" "$c_rst" "$s_pad_flags_hdr" "$c_box" "$c_rst"

    local i
    for (( i=0; i<${#p_flags[@]}; i++ )); do
      local f="${p_flags[$i]}"
      local d="${p_descs[$i]}"
      local lf; lf=$(_dblock_vis_len "$f")
      local ld; ld=$(_dblock_vis_len "$d")

      local f_pad=$(( max_flag - lf + 2 ))
      (( f_pad < 1 )) && f_pad=1
      local s_f_pad; s_f_pad=$(_dblock_repeat "$f_pad" " ")

      local row_len=$(( 2 + lf + f_pad + ld ))
      local right_pad=$(( inner_w - row_len - 2 ))
      (( right_pad < 0 )) && right_pad=0
      local s_right_pad; s_right_pad=$(_dblock_repeat "$right_pad" " ")

      printf "  %s│%s  %s%s%s%s%s%s%s%s%s│%s\n" \
        "$c_box" "$c_rst" \
        "$c_flag" "$f" "$c_rst" \
        "$s_f_pad" \
        "$c_desc" "$d" "$c_rst" \
        "$s_right_pad" \
        "$c_box" "$c_rst"
    done
  fi

  # Bottom Border
  printf "  %s└%s┘%s\n" "$c_box" "$hz_bot" "$c_rst"
  echo ""
}

fm_learn() {
  local mode="${1:-toggle}"
  case "$mode" in
    on|1)
      export FM_LEARN=1
      echo ""
      printf '%s\n' "$(c 208 b '📚 Learn Mode ')$(c 46 b 'ON')  — ทุก command จะแสดงคำสั่งจริงก่อนรัน"
      printf '%s\n' "$(c 244 d '  ปิดด้วย: ')$(c 51 b 'fm learn off')"
      echo ""
      ;;
    off|0)
      export FM_LEARN=0
      echo ""
      printf '%s\n' "$(c 208 b '📚 Learn Mode ')$(c 203 b 'OFF')"
      echo ""
      ;;
    toggle|*)
      if [[ "$FM_LEARN" == "1" ]]; then fm_learn off; else fm_learn on; fi
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────
# INTERNAL HELPERS
# ─────────────────────────────────────────────────────────────────
_ok()    { printf '%s\n' "$(c 46 '' '  ✔  ')$(c 82 b "$*")"; }
_warn()  { cn 226 "  ⚠  $*"; }
_err()   { printf '%s\n' "$(c 203 '' '  ✘  ')$(c 196 b "$*")" >&2; }
_info()  { printf '%s\n' "$(c 87 '' '  ℹ  ')$(c 51 b "$*")"; }
_step()  { printf '%s\n' "$(c 75 '' '  →  ')$(c w b "$*")"; }
_sep()   { cn 244 "" "─────────────────────────────────────────────────────"; }

_confirm() {
  local msg="${1:-Are you sure?}"
  printf '%s' "$(c 226 b '  ❓  ')$(c w b "${msg}")$(c 244 '' ' [y/N] ')"
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

_human_size() {
  local bytes=${1:-0}
  if ! command -v bc_ >/dev/null 2>&1 && [[ -f "${SCRIPTS_PATH:-$HOME/ssot}/functions/00.1-function-tools.sh" ]]; then
    source "${SCRIPTS_PATH:-$HOME/ssot}/functions/00.1-function-tools.sh" 2>/dev/null
  fi
  if   (( bytes >= 1073741824 )); then printf "%s GB" "$(bc_ 1 "$bytes/1073741824")"
  elif (( bytes >= 1048576    )); then printf "%s MB" "$(bc_ 1 "$bytes/1048576")"
  elif (( bytes >= 1024       )); then printf "%s KB" "$(bc_ 1 "$bytes/1024")"
  else printf "%d B" "$bytes"; fi
}

# ─────────────────────────────────────────────────────────────────
# DYNAMIC BLOCK ENGINE — Auto-calculates width from max_label & max_value
# ─────────────────────────────────────────────────────────────────
dynamic_block() {
  local title="" border_style="round" border_color="51" label_color="226" val_color="255" sep_str=" : "
  local -a raw_rows=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--title)  title="$2"; shift 2 ;;
      -s|--style)  border_style="$2"; shift 2 ;;
      -c|--color)  border_color="$2"; shift 2 ;;
      -lc)         label_color="$2"; shift 2 ;;
      -vc)         val_color="$2"; shift 2 ;;
      -sep)        sep_str="$2"; shift 2 ;;
      *)           raw_rows+=("$1"); shift ;;
    esac
  done

  # Read from stdin if no positional row args
  if [[ ${#raw_rows[@]} -eq 0 ]]; then
    local line
    while IFS= read -r line; do
      [[ -n "$line" ]] && raw_rows+=("$line")
    done
  fi

  [[ ${#raw_rows[@]} -eq 0 ]] && return 0

  # Border glyphs
  local tl tr bl br hz vt
  case "$border_style" in
    double) tl="╔"; tr="╗"; bl="╚"; br="╝"; hz="═"; vt="║" ;;
    single) tl="┌"; tr="┐"; bl="└"; br="┘"; hz="─"; vt="│" ;;
    heavy)  tl="┏"; tr="┓"; bl="┗"; br="┛"; hz="━"; vt="┃" ;;
    *)      tl="╭"; tr="╮"; bl="╰"; br="╯"; hz="─"; vt="│" ;; # round
  esac

  # 1. Parse rows & Calculate max_label / max_value
  local -a p_eml=() p_lbl=() p_val=() p_emr=()
  local max_eml=0 max_lbl=0 max_val=0 max_emr=0

  for row in "${raw_rows[@]}"; do
    local eml="" lbl="" val="" emr=""
    IFS='|' read -r -a parts <<< "$row"
    local n=${#parts[@]}

    case $n in
      4) eml="${parts[0]}"; lbl="${parts[1]}"; val="${parts[2]}"; emr="${parts[3]}" ;;
      3)
        if [[ -z "${parts[0]}" ]]; then
          lbl="${parts[1]}"; val="${parts[2]}"
        elif [[ -z "${parts[2]}" ]]; then
          lbl="${parts[0]}"; val="${parts[1]}"
        else
          eml="${parts[0]}"; lbl="${parts[1]}"; val="${parts[2]}"
        fi
        ;;
      2) lbl="${parts[0]}"; val="${parts[1]}" ;;
      *) lbl="$row"; val="" ;;
    esac

    p_eml+=("$eml"); p_lbl+=("$lbl"); p_val+=("$val"); p_emr+=("$emr")

    local l_eml; l_eml=$(_dblock_vis_len "$eml")
    local l_lbl; l_lbl=$(_dblock_vis_len "$lbl")
    local l_val; l_val=$(_dblock_vis_len "$val")
    local l_emr; l_emr=$(_dblock_vis_len "$emr")

    (( l_eml > max_eml )) && max_eml=$l_eml
    (( l_lbl > max_lbl )) && max_lbl=$l_lbl
    (( l_val > max_val )) && max_val=$l_val
    (( l_emr > max_emr )) && max_emr=$l_emr
  done

  local sep_len; sep_len=$(_dblock_vis_len "$sep_str")
  local eml_slot=0 emr_slot=0
  (( max_eml > 0 )) && eml_slot=$(( max_eml + 1 ))
  (( max_emr > 0 )) && emr_slot=$(( max_emr + 1 ))

  # Calculate inner content width
  local content_w=$(( eml_slot + max_lbl + sep_len + max_val + emr_slot ))
  local inner_w=$(( content_w + 2 ))

  # Adjust width for title if present
  local title_len=0
  if [[ -n "$title" ]]; then
    title_len=$(_dblock_vis_len "$title")
    if (( title_len + 4 > inner_w )); then
      inner_w=$(( title_len + 4 ))
      max_val=$(( inner_w - 2 - eml_slot - max_lbl - sep_len - emr_slot ))
    fi
  fi

  # Style colors
  local c_border="$(_c "$border_color")"
  local c_lbl="$(_c "$label_color")$(_b)"
  local c_val="$(_c "$val_color")"
  local c_sep="$(_c 244)"
  local c_rst="$(_r)"

  _dblock_repeat() {
    local count=$1 char=$2 out="" c
    for (( c=0; c<count; c++ )); do out+="$char"; done
    printf '%s' "$out"
  }

  # Render Top Border
  if [[ -n "$title" ]]; then
    local fill_w=$(( inner_w - title_len - 3 ))
    (( fill_w < 1 )) && fill_w=1
    local hz_fill; hz_fill=$(_dblock_repeat "$fill_w" "$hz")
    printf "  %s%s%s %s%s%s %s%s%s%s\n" \
      "$c_border" "$tl" "$hz" \
      "$(_c 255)$(_b)" "$title" "$c_rst" \
      "$c_border" "$hz_fill" "$tr" "$c_rst"
  else
    local hz_fill; hz_fill=$(_dblock_repeat "$inner_w" "$hz")
    printf "  %s%s%s%s%s\n" "$c_border" "$tl" "$hz_fill" "$tr" "$c_rst"
  fi

  # Render Rows
  local total_rows=${#p_lbl[@]}
  local i
  for (( i=0; i<total_rows; i++ )); do
    local cur_eml="${p_eml[$i]}"
    local cur_lbl="${p_lbl[$i]}"
    local cur_val="${p_val[$i]}"
    local cur_emr="${p_emr[$i]}"

    local l_eml; l_eml=$(_dblock_vis_len "$cur_eml")
    local l_lbl; l_lbl=$(_dblock_vis_len "$cur_lbl")
    local l_val; l_val=$(_dblock_vis_len "$cur_val")
    local l_emr; l_emr=$(_dblock_vis_len "$cur_emr")

    local s_eml=""
    if (( max_eml > 0 )); then
      if (( l_eml > 0 )); then s_eml="${cur_eml} "
      else s_eml="$(_dblock_repeat "$eml_slot" ' ')"
      fi
    fi

    local lbl_pad=$(( max_lbl - l_lbl ))
    local s_lbl="${cur_lbl}$(_dblock_repeat "$lbl_pad" ' ')"

    local val_pad=$(( max_val - l_val ))
    (( val_pad < 0 )) && val_pad=0
    local s_val="${cur_val}$(_dblock_repeat "$val_pad" ' ')"

    local s_emr=""
    if (( max_emr > 0 )); then
      if (( l_emr > 0 )); then s_emr=" ${cur_emr}"
      else s_emr="$(_dblock_repeat "$emr_slot" ' ')"
      fi
    fi

    local line_vis_len=$(( max_eml > 0 ? eml_slot : 0 ))
    line_vis_len=$(( line_vis_len + max_lbl + sep_len + l_val + val_pad + (max_emr > 0 ? emr_slot : 0) ))
    local right_slack=$(( inner_w - 2 - line_vis_len ))
    (( right_slack < 0 )) && right_slack=0
    local s_slack; s_slack=$(_dblock_repeat "$right_slack" ' ')

    local row_content="${s_eml}${c_lbl}${s_lbl}${c_rst}${c_sep}${sep_str}${c_rst}${c_val}${s_val}${c_rst}${s_emr}${s_slack}"
    printf "  %s%s%s %s %s%s%s\n" \
      "$c_border" "$vt" "$c_rst" \
      "$row_content" \
      "$c_border" "$vt" "$c_rst"
  done

  # Render Bottom Border
  local hz_bot; hz_bot=$(_dblock_repeat "$inner_w" "$hz")
  printf "  %s%s%s%s%s\n" "$c_border" "$bl" "$hz_bot" "$br" "$c_rst"
}
dblock() { dynamic_block "$@"; }
alias dblock="dynamic_block"

# _fm_list_dir <target> <show_hidden:yes|no>
# Internal helper — does the actual listing (used by fm_ls and fm_lsa)
#   show_hidden=yes → ls -1ap   (รวม dotfiles .bashrc .env .git)
#   show_hidden=no  → ls -1p    (default — ไม่รวม dotfiles)
_fm_list_dir() {
  local target="$1"
  local show_hidden="${2:-no}"
  local ls_opts=(-1p)
  [[ "$show_hidden" == "yes" ]] && ls_opts=(-1ap)

  echo ""
  cn 87 "  📂  $(realpath "$target")"
  _sep
  ctab "bu:6 bu:10 bu:8 bu:20 0:0" "PERM" "SIZE" "TYPE" "MODIFIED" "NAME"
  _sep

  local count=0
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    local name perm size type mdate icon color
    name=$(basename "$item")
    perm=$(stat -c "%A" "$item" 2>/dev/null || stat -f "%Sp" "$item" 2>/dev/null || echo "?")
    mdate=$(stat -c "%y" "$item" 2>/dev/null | cut -c1-16 || stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$item" 2>/dev/null || echo "?")
    size="—"

    local link_target=""
    local color_code=""
    if   [[ -L "$item" ]]; then
      icon="🔗"; type="symlink"; color_code=51
      link_target=$(readlink "$item" 2>/dev/null)
    elif [[ -d "$item" ]]; then icon="📁"; type="dir";     color_code=75
    elif [[ -x "$item" ]]; then icon="⚙️ "; type="exec";    color_code=46
    else                        icon="📄"; type="file";    color_code=255; fi

    if [[ -f "$item" ]]; then
      local raw_size
      raw_size=$(stat -c "%s" "$item" 2>/dev/null || stat -f "%z" "$item" 2>/dev/null || echo 0)
      size=$(_human_size "$raw_size")
    fi

    if [[ -n "$link_target" ]]; then
      ctab "2:6 244:10 2:8 2:20 x:0" "$perm" "$size" "$type" "$mdate" "$(c $color_code b "${icon} ${name}") → $(c 46 b "${link_target}")"
    else
      ctab "2:6 244:10 2:8 2:20 x:0" "$perm" "$size" "$type" "$mdate" "$(c $color_code b "${icon} ${name}")"
    fi
    (( count++ ))
  done < <(ls "${ls_opts[@]}" "$target" 2>/dev/null | sed "s|^|$target/|" | sort -t/ -k2)

  _sep
  printf '%s\n' "$(c 244 d '  Total: ') $(c w b "${count} items")"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
#  HELP MENU
# ═════════════════════════════════════════════════════════════════
fm_help() {
  local cat="${1:-all}"
  echo ""
  c 87 b "╔══════════════════════════════════════════════════════════════════╗"
  printf '%s\n' "$(c 87 b '║')  $(c 255 b '📁  FILE MANAGER CLI  v3.0  —  Quick Reference Guide')            $(c 87 b '║')"
  printf '%s\n' "$(c 87 b '║')  $(c 244 d 'source filemanager.sh  →  fm help  →  fm learn on')              $(c 87 b '║')"
  c 87 b "╚══════════════════════════════════════════════════════════════════╝"

  if [[ "$cat" == "all" || "$cat" == "nav" ]]; then
    echo ""
    cn 141 "  🧭  NAVIGATION & LISTING"
    hline 66
    ctab "1:22 51:28 0:0" "COMMAND" "SYNTAX" "DESCRIPTION"
    hline 66
    ctab "46:22 244:28 0:0" "fm ls"     "fm ls [path]"           "แสดงไฟล์ทั้งหมดแบบสวยงาม"
    ctab "46:22 244:28 0:0" "fm lsa"    "fm lsa [path]"          "แสดงรวมไฟล์ซ่อน (.dotfiles)"
    ctab "46:22 244:28 0:0" "fm tree"   "fm tree [path] [depth]" "แสดงโครงสร้างโฟลเดอร์แบบ tree"
    ctab "46:22 244:28 0:0" "fm goto"   "fm goto <path>"         "เปลี่ยน directory พร้อม bookmark"
    ctab "46:22 244:28 0:0" "fm back"   "fm back"                "กลับ directory ก่อนหน้า"
    ctab "46:22 244:28 0:0" "fm home"   "fm home"                "กลับ Home directory"
    ctab "46:22 244:28 0:0" "fm pwd"    "fm pwd"                 "บอกว่าอยู่ที่ไหนตอนนี้"
    hline 66
  fi

  if [[ "$cat" == "all" || "$cat" == "file" ]]; then
    echo ""
    cn 226 "  📄  FILE OPERATIONS"
    hline 66
    ctab "1:22 51:28 0:0" "COMMAND" "SYNTAX" "DESCRIPTION"
    hline 66
    ctab "46:22 244:28 0:0" "fm cp"     "fm cp <src> <dst>"      "คัดลอกไฟล์/โฟลเดอร์ (มี progress)"
    ctab "46:22 244:28 0:0" "fm mv"     "fm mv <src> <dst>"      "ย้ายไฟล์/โฟลเดอร์ (ยืนยันก่อน)"
    ctab "46:22 244:28 0:0" "fm rm"     "fm rm <file/dir>"       "ลบไฟล์ (ถามยืนยัน + ส่ง trash)"
    ctab "46:22 244:28 0:0" "fm rn"     "fm rn <old> <new>"      "เปลี่ยนชื่อไฟล์"
    ctab "46:22 244:28 0:0" "fm mk"     "fm mk <name>"           "สร้างไฟล์เปล่าใหม่"
    ctab "46:22 244:28 0:0" "fm mkdir"  "fm mkdir <name>"        "สร้างโฟลเดอร์ (รวม parent)"
    ctab "46:22 244:28 0:0" "fm touch"  "fm touch <file>"        "สร้าง/อัปเดต timestamp ไฟล์"
    ctab "46:22 244:28 0:0" "fm link"   "fm link <src> <dst>"    "สร้าง symlink"
    hline 66
  fi

  if [[ "$cat" == "all" || "$cat" == "search" ]]; then
    echo ""
    cn 75 "  🔍  SEARCH & INFORMATION"
    hline 66
    ctab "1:22 51:28 0:0" "COMMAND" "SYNTAX" "DESCRIPTION"
    hline 66
    ctab "46:22 244:28 0:0" "fm find"     "fm find <name> [path]"    "ค้นหาไฟล์ตามชื่อ"
    ctab "46:22 244:28 0:0" "fm grep"     "fm grep <text> [path]"    "ค้นหาข้อความในไฟล์"
    ctab "46:22 244:28 0:0" "fm findext"  "fm findext <.ext> [path]" "ค้นหาตามนามสกุลไฟล์"
    ctab "46:22 244:28 0:0" "fm findsize" "fm findsize <+/-N> [MB]"  "ค้นหาตามขนาดไฟล์"
    ctab "46:22 244:28 0:0" "fm info"     "fm info <file>"           "แสดงรายละเอียดไฟล์ครบถ้วน"
    ctab "46:22 244:28 0:0" "fm size"     "fm size [path]"           "ขนาดรวมของไฟล์/โฟลเดอร์"
    ctab "46:22 244:28 0:0" "fm recent"   "fm recent [N] [path]"     "ไฟล์ที่แก้ไขล่าสุด N รายการ"
    ctab "46:22 244:28 0:0" "fm big"      "fm big [N] [path]"        "ไฟล์ขนาดใหญ่สุด N อันดับ"
    ctab "46:22 244:28 0:0" "fm dup"      "fm dup [path]"            "หาไฟล์ที่ซ้ำกัน (by checksum)"
    hline 66
  fi

  if [[ "$cat" == "all" || "$cat" == "zip" ]]; then
    echo ""
    cn 203 "  🗜️   COMPRESS & ARCHIVE"
    hline 66
    ctab "1:22 51:28 0:0" "COMMAND" "SYNTAX" "DESCRIPTION"
    hline 66
    ctab "46:22 244:28 0:0" "fm zip"     "fm zip <out.zip> <src>"     "บีบอัดเป็น ZIP"
    ctab "46:22 244:28 0:0" "fm unzip"   "fm unzip <file.zip> [dst]"  "แตก ZIP ไปยัง path"
    ctab "46:22 244:28 0:0" "fm tar"     "fm tar <out.tar.gz> <src>"  "บีบอัดเป็น tar.gz"
    ctab "46:22 244:28 0:0" "fm untar"   "fm untar <file.tar.gz>"     "แตก tar.gz"
    ctab "46:22 244:28 0:0" "fm ziplist" "fm ziplist <file.zip>"      "ดูรายการในไฟล์ ZIP"
    hline 66
  fi

  if [[ "$cat" == "all" || "$cat" == "perm" ]]; then
    echo ""
    cn 141 "  🔐  PERMISSIONS & OWNERSHIP"
    hline 66
    ctab "1:22 51:28 0:0" "COMMAND" "SYNTAX" "DESCRIPTION"
    hline 66
    ctab "46:22 244:28 0:0" "fm perm"   "fm perm <file>"         "ดู permission ปัจจุบัน"
    ctab "46:22 244:28 0:0" "fm chmod"  "fm chmod <mode> <file>" "เปลี่ยน permission (ex: 755)"
    ctab "46:22 244:28 0:0" "fm chown"  "fm chown <user> <file>" "เปลี่ยนเจ้าของไฟล์"
    ctab "46:22 244:28 0:0" "fm mkexec" "fm mkexec <file>"       "ทำให้ไฟล์รันได้ (+x)"
    ctab "46:22 244:28 0:0" "fm rmexec" "fm rmexec <file>"       "ถอด permission รัน (-x)"
    hline 66
  fi

  if [[ "$cat" == "all" || "$cat" == "disk" ]]; then
    echo ""
    cn 87 "  💾  DISK & STORAGE"
    hline 66
    ctab "1:22 51:28 0:0" "COMMAND" "SYNTAX" "DESCRIPTION"
    hline 66
    ctab "46:22 244:28 0:0" "fm df"         "fm df"             "ดู disk usage ทุก drive"
    ctab "46:22 244:28 0:0" "fm du"         "fm du [path]"      "ดูขนาดแต่ละโฟลเดอร์ย่อย"
    ctab "46:22 244:28 0:0" "fm clean"      "fm clean [path]"   "ลบไฟล์ tmp/cache ชั่วคราว"
    ctab "46:22 244:28 0:0" "fm trash"      "fm trash"          "ดูสิ่งที่ถูกลบ (trash bin)"
    ctab "46:22 244:28 0:0" "fm emptytrash" "fm emptytrash"     "ล้าง trash bin (ถามยืนยัน)"
    hline 66
  fi

  if [[ "$cat" == "all" || "$cat" == "batch" ]]; then
    echo ""
    cn 226 "  ⚡  BATCH OPERATIONS"
    hline 66
    ctab "1:22 51:28 0:0" "COMMAND" "SYNTAX" "DESCRIPTION"
    hline 66
    ctab "46:22 244:28 0:0" "fm bren"    "fm bren <pattern> <rep>"  "เปลี่ยนชื่อหลายไฟล์พร้อมกัน"
    ctab "46:22 244:28 0:0" "fm bcp"     "fm bcp <dst> <files...>"  "คัดลอกหลายไฟล์ไปปลายทาง"
    ctab "46:22 244:28 0:0" "fm bmv"     "fm bmv <dst> <files...>"  "ย้ายหลายไฟล์ไปปลายทาง"
    ctab "46:22 244:28 0:0" "fm brm"     "fm brm <pattern> [path]"  "ลบหลายไฟล์ตาม pattern"
    ctab "46:22 244:28 0:0" "fm sortdir" "fm sortdir <src> <dst>"   "จัดเรียงไฟล์ตามนามสกุลอัตโนมัติ"
    ctab "46:22 244:28 0:0" "fm datedir" "fm datedir <src> <dst>"   "จัดเรียงไฟล์ตามวันที่แก้ไข"
    hline 66
  fi

  if [[ "$cat" == "all" || "$cat" == "sync" ]]; then
    echo ""
    cn 87 "  🌍  SYNC & REMOTE (3-WORLDS)"
    hline 66
    ctab "1:22 51:28 0:0" "COMMAND" "SYNTAX" "DESCRIPTION"
    hline 66
    ctab "46:22 244:28 0:0" "fm world"  "fm world"             "ตรวจสอบ IP และสถานะเครื่องอื่น"
    ctab "46:22 244:28 0:0" "fm ssh"    "fm ssh <tm|tw|wsl>"   "เชื่อมต่อ SSH ไปยังเครื่องอื่น"
    ctab "46:22 244:28 0:0" "fm push"   "fm push <src> [dst]"  "ส่งไฟล์ไป Termux (Update only)"
    ctab "46:22 244:28 0:0" "fm pull"   "fm pull <src> [dst]"  "ดึงไฟล์จาก Termux (Update only)"
    ctab "46:22 244:28 0:0" "fm rls"    "fm rls [path]"        "ดูรายการไฟล์บน Termux"
    ctab "46:22 244:28 0:0" "fm rrun"   "fm rrun <cmd>"        "รันคำสั่งบน Termux โดยตรง"
    hline 66
  fi

  local learn_status
  if [[ "$FM_LEARN" == "1" ]]; then learn_status="$(c 46 b 'ON')"; else learn_status="$(c 203 b 'OFF')"; fi
  echo ""
  cn 244 d "  ┌──────────────────────────────────────────────────────────────────┐"
  echo -e "  \e[2m│\e[0m  \e[1mfm help\e[0m \e[2m<category>\e[0m  \e[38;5;51mnav│file│search│zip│perm│disk│batch│sync\e[0m  \e[2m│\e[0m"
  echo -e "  \e[2m│\e[0m  \e[38;5;208m📚 Learn Mode:\e[0m ${learn_status}    พิมพ์ \e[38;5;51mfm learn on/off\e[0m เพื่อสลับ         \e[2m│\e[0m"
  cn 244 d "  └──────────────────────────────────────────────────────────────────┘"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
#  NAVIGATION
# ═════════════════════════════════════════════════════════════════

fm_ls() {
  local target="${1:-.}"
  [[ ! -e "$target" ]] && { _err "ไม่พบ: $target"; return 1; }

  _learn_box "fm ls — แสดงรายการไฟล์แบบ formatted" \
    "ls -1p \"$target\" 2>/dev/null | sed 's|^|$target/|' | sort -t/ -k2 | while read item; do stat... done" \
    "ls -1p         |แสดงทีละบรรทัด (1 file per line ไม่ใช่แบบ grid)" \
    "sed            |เติม path เต็มเข้าไปข้างหน้าชื่อไฟล์แต่ละอัน" \
    "sort           |เรียงลำดับรายการไฟล์" \
    "while read     |วนลูปเพื่ออ่าน stat ของแต่ละไฟล์ทีละบรรทัด" \
    "stat -c \"%A\"  |อ่าน permission string เช่น -rwxr-xr-x" \
    "stat -c \"%s\"  |อ่านขนาดไฟล์เป็น bytes แล้ว fm แปลงเป็น KB/MB" \
    "stat -c \"%y\"  |อ่านวันที่ modified ล่าสุด" \
    "file -b        |ตรวจ file type จาก magic bytes (ไม่ใช่แค่นามสกุล)"

  _fm_list_dir "$target" "no"
}

fm_lsa() {
  local target="${1:-.}"
  [[ ! -e "$target" ]] && { _err "ไม่พบ: $target"; return 1; }

  _learn_box "fm lsa — แสดงไฟล์ทั้งหมดรวมไฟล์ซ่อน" \
    "ls -1ap \"$target\" 2>/dev/null | sed 's|^|$target/|' | sort -t/ -k2 | while read item; do stat... done" \
    "ls -1ap        |แสดงทีละบรรทัด รวม dotfiles (.bashrc .env .git)" \
    "-a             |all — แสดงไฟล์ซ่อน" \
    "-p             |ใส่ / ต่อท้ายโฟลเดอร์" \
    "stat -c \"%A\"  |อ่าน permission string" \
    "(ต่างจาก ls)   |fm lsa ใช้ -a ส่วน fm ls ไม่ใช้"

  _fm_list_dir "$target" "yes"
}

fm_tree() {
  local target="${1:-.}"
  local depth="${2:-3}"
  _learn_box "fm tree — แสดงโครงสร้างโฟลเดอร์แบบ tree" \
    "tree -L $depth --dirsfirst -C \"$target\"" \
    "-L $depth      |แสดงลึกสุด $depth ระดับ" \
    "--dirsfirst    |แสดงโฟลเดอร์ก่อนไฟล์เสมอ" \
    "-C             |เปิดสี ANSI color" \
    "(fallback)     |ถ้าไม่มี tree ใช้ find -maxdepth $depth แทน"
  echo ""
  if command -v tree &>/dev/null; then
    tree -L "$depth" --dirsfirst -C "$target"
  else
    _warn "tree ไม่ได้ติดตั้ง — ใช้ find แทน (sudo apt install tree)"
    find "$target" -maxdepth "$depth" | sort | while IFS= read -r f; do
      local lvl; lvl="${f//[^\/]/}"; local d=${#lvl}
      printf '%*s├── %s\n' "$((d*2))" '' "$(basename "$f")"
    done
  fi
  echo ""
}

FM_PREV_DIR=""

fm_goto() {
  [[ -z "$1" ]] && { _err "Usage: fm goto <path>"; return 1; }
  [[ ! -d "$1" ]] && { _err "ไม่พบโฟลเดอร์: $1"; return 1; }
  _learn_box "fm goto — เปลี่hยน directory" \
    "cd \"$1\"" \
    "cd             |change directory — เปลี่ยน working directory ของ shell ปัจจุบัน" \
    "(bookmark)     |fm เก็บ path เดิมไว้ใน \$FM_PREV_DIR เพื่อให้ fm back ใช้ได้"
  FM_PREV_DIR="$PWD"
  cd "$1" && _ok "ย้ายมาที่: $(pwd)"
}

fm_back() {
  [[ -z "$FM_PREV_DIR" ]] && { _warn "ไม่มี history — ลอง fm home"; return 1; }
  _learn_box "fm back — กลับ directory ก่อนหน้า" \
    "cd \"$FM_PREV_DIR\"" \
    "cd <path>      |fm เก็บ path ก่อนหน้าไว้ใน \$FM_PREV_DIR แล้วสลับกลับ" \
    "(swap)         |แล้ว swap ค่า ทำให้ back/forth ไปมาได้"
  local tmp="$PWD"
  cd "$FM_PREV_DIR" && _ok "กลับมาที่: $(pwd)"
  FM_PREV_DIR="$tmp"
}

fm_home() {
  _learn_box "fm home — กลับ Home directory" \
    "cd ~" \
    "~              |tilde (~) = shortcut ของ \$HOME เช่น /home/joe หรือ /root" \
    "\$HOME          |environment variable ที่ shell ตั้งให้อัตโนมัติตอน login"
  cd ~ && _ok "กลับ Home: $(pwd)"
}

fm_pwd() {
  _learn_box "fm pwd — แสดง path ปัจจุบัน" \
    "pwd" \
    "pwd            |print working directory — บอกว่าตอนนี้อยู่ที่ path ไหน" \
    "realpath       |fm ใช้ realpath เพิ่มเติมเพื่อ resolve symlink ให้เป็น path จริง"
  echo ""
  cn 87 "  📍  Current Location"
  cn 255 b "  $(pwd)"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
#  FILE OPERATIONS
# ═════════════════════════════════════════════════════════════════

fm_cp() {
  [[ -z "$1" || -z "$2" ]] && { _err "Usage: fm cp <src> <dst>"; return 1; }
  [[ ! -e "$1" ]] && { _err "ไม่พบต้นทาง: $1"; return 1; }
  if command -v rsync &>/dev/null; then
    _learn_box "fm cp — คัดลอกไฟล์ด้วย rsync (มี progress)" \
      "rsync -ah --progress \"$1\" \"$2\"" \
      "-a             |archive mode = รวม -r(recursive) -l(symlinks) -p(permissions) -t(timestamps)" \
      "-h             |human-readable ขนาดไฟล์ แสดงเป็น KB/MB แทน bytes" \
      "--progress     |แสดง progress bar ขณะคัดลอก" \
      "(ต่างจาก cp)   |rsync เร็วกว่า cp สำหรับไฟล์ใหญ่ และ copy ได้แม่นยำกว่า"
    _step "คัดลอก: $1  →  $2"
    rsync -ah --progress "$1" "$2" && _ok "คัดลอกสำเร็จ"
  else
    _learn_box "fm cp — คัดลอกไฟล์ด้วย cp" \
      "cp -rv \"$1\" \"$2\"" \
      "-r             |recursive — คัดลอกโฟลเดอร์ทั้งหมดรวมโฟลเดอร์ย่อย" \
      "-v             |verbose — แสดงชื่อทุกไฟล์ที่กำลังคัดลอก" \
      "(rsync)        |ถ้าติดตั้ง rsync จะใช้แทน cp เพราะมี progress bar"
    _step "คัดลอก: $1  →  $2"
    cp -rv "$1" "$2" && _ok "คัดลอกสำเร็จ"
  fi
}

fm_mv() {
  [[ -z "$1" || -z "$2" ]] && { _err "Usage: fm mv <src> <dst>"; return 1; }
  [[ ! -e "$1" ]] && { _err "ไม่พบต้นทาง: $1"; return 1; }
  _learn_box "fm mv — ย้ายไฟล์/โฟลเดอร์" \
    "mv -v \"$1\" \"$2\"" \
    "mv             |move — ถ้า src/dst อยู่ใน disk เดียวกัน = แค่เปลี่ยน pointer (เร็วมาก)" \
    "-v             |verbose — แสดงชื่อที่ถูกย้าย" \
    "(ยืนยัน)       |fm เพิ่มขั้นตอนถามยืนยันก่อน เพราะ mv ย้อนกลับไม่ได้ง่ายๆ"
  _confirm "ย้าย '$1' → '$2'?" || { _info "ยกเลิก"; return 0; }
  mv -v "$1" "$2" && _ok "ย้ายสำเร็จ"
}

fm_rm() {
  [[ -z "$1" ]] && { _err "Usage: fm rm <file>"; return 1; }
  [[ ! -e "$1" ]] && { _err "ไม่พบ: $1"; return 1; }
  if command -v trash &>/dev/null; then
    _learn_box "fm rm — ลบไฟล์ (ผ่าน trash-cli)" \
      "trash \"$1\"" \
      "trash          |ส่งไฟล์ไปที่ Trash แทนการลบตาย (สามารถ restore ได้)" \
      "(fallback)     |ถ้าไม่มี trash หรือ gio → ใช้ rm -rv แทน (ลบถาวร)" \
      "(tip)          |sudo apt install trash-cli เพื่อใช้ trash command"
  elif command -v gio &>/dev/null; then
    _learn_box "fm rm — ลบไฟล์ (ผ่าน gio trash)" \
      "gio trash \"$1\"" \
      "gio trash      |GNOME I/O — ส่งไฟล์ไป Trash แบบ freedesktop standard" \
      "(gio)          |ใช้ได้บน Linux desktop เช่น Ubuntu, Fedora, Arch"
  else
    _learn_box "fm rm — ลบไฟล์ถาวร (permanent)" \
      "rm -rv \"$1\"" \
      "rm             |remove — ลบไฟล์ถาวร ย้อนกลับไม่ได้!" \
      "-r             |recursive — ลบโฟลเดอร์พร้อมทุกอย่างข้างใน" \
      "-v             |verbose — แสดงทุกไฟล์ที่ถูกลบ" \
      "(tip)          |ติดตั้ง trash-cli เพื่อความปลอดภัย: sudo apt install trash-cli"
  fi
  _warn "กำลังจะลบ: $1"
  _confirm "ยืนยันการลบ?" || { _info "ยกเลิก — ไฟล์ปลอดภัย"; return 0; }
  if   command -v trash &>/dev/null; then trash "$1" && _ok "ส่งไป Trash สำเร็จ"
  elif command -v gio   &>/dev/null; then gio trash "$1" && _ok "ส่งไป Trash สำเร็จ"
  else rm -rv "$1" && _ok "ลบสำเร็จ (permanent)"; fi
}

fm_rn() {
  [[ -z "$1" || -z "$2" ]] && { _err "Usage: fm rn <old> <new>"; return 1; }
  [[ ! -e "$1" ]] && { _err "ไม่พบ: $1"; return 1; }
  _learn_box "fm rn — เปลี่ยนชื่อไฟล์" \
    "mv -v \"$1\" \"$2\"" \
    "mv             |การเปลี่ยนชื่อใน Unix = mv ในโฟลเดอร์เดิม ไม่มี rename command แยก" \
    "-v             |แสดงชื่อเดิม → ชื่อใหม่"
  mv -v "$1" "$2" && _ok "เปลี่ยนชื่อ: $1 → $2"
}

fm_mk() {
  [[ -z "$1" ]] && { _err "Usage: fm mk <filename>"; return 1; }
  _learn_box "fm mk — สร้างไฟล์เปล่า" \
    "touch \"$1\"" \
    "touch          |สร้างไฟล์เปล่าถ้ายังไม่มี หรือ อัปเดต timestamp ถ้ามีอยู่แล้ว" \
    "(size=0)       |ไฟล์ที่สร้างมีขนาด 0 bytes พร้อมให้เขียนข้อมูลทีหลัง"
  touch "$1" && _ok "สร้างไฟล์: $1"
}

fm_mkdir() {
  [[ -z "$1" ]] && { _err "Usage: fm mkdir <dirname>"; return 1; }
  _learn_box "fm mkdir — สร้างโฟลเดอร์" \
    "mkdir -pv \"$1\"" \
    "-p             |parents — สร้างโฟลเดอร์ parent อัตโนมัติถ้ายังไม่มี เช่น a/b/c สร้างทีเดียว" \
    "-v             |verbose — แสดงแต่ละโฟลเดอร์ที่สร้าง" \
    "(ไม่มี -p)     |mkdir ปกติ error ถ้า parent ไม่มี แต่ -p จะข้ามไปเงียบๆ"
  mkdir -pv "$1" && _ok "สร้างโฟลเดอร์: $1"
}

fm_touch() {
  [[ -z "$1" ]] && { _err "Usage: fm touch <file>"; return 1; }
  _learn_box "fm touch — อัปเดต timestamp ไฟล์" \
    "touch \"$1\"" \
    "touch          |ถ้าไฟล์มีอยู่แล้ว: อัปเดต mtime (modified time) เป็นตอนนี้" \
    "               |ถ้าไฟล์ยังไม่มี: สร้างไฟล์เปล่าขนาด 0 bytes" \
    "(use case)     |ใช้บ่อยใน Makefile เพื่อ trigger rebuild โดยไม่ต้องแก้เนื้อหา"
  touch "$1" && _ok "อัปเดต timestamp: $1"
}

fm_link() {
  [[ -z "$1" || -z "$2" ]] && { _err "Usage: fm link <src> <dst>"; return 1; }
  _learn_box "fm link — สร้าง symbolic link" \
    "ln -sv \"$1\" \"$2\"" \
    "ln             |link — สร้าง link ระหว่างไฟล์" \
    "-s             |symbolic — สร้าง symlink (shortcut) ไม่ใช่ hard link" \
    "-v             |verbose — แสดง link ที่สร้าง" \
    "(symlink)      |ไฟล์ dst จะชี้ไปที่ src เหมือน shortcut, ถ้าลบ src link จะ broken" \
    "(hardlink)     |ถ้าไม่ใส่ -s = hard link ชี้ inode เดียวกัน ลบ src ไฟล์ยังอยู่"
  ln -sv "$1" "$2" && _ok "สร้าง symlink: $2 → $1"
}

# ═════════════════════════════════════════════════════════════════
#  SEARCH & INFORMATION
# ═════════════════════════════════════════════════════════════════

fm_find() {
  local name="${1:?Usage: fm find <name> [path]}"
  local path="${2:-.}"
  _learn_box "fm find — ค้นหาไฟล์ตามชื่อ" \
    "find \"\$path\" -iname \"*\${name}*\" -not -path '*/\.*' 2>/dev/null | while IFS= read -r f; do ... done" \
    "find           |เครื่องมือค้นหาไฟล์ใน filesystem แบบ recursive" \
    "-iname         |case-insensitive name match, * = wildcard ใดๆ ก็ได้" \
    "-not -path     |ข้ามโฟลเดอร์ซ่อน (dotfiles) เช่น .git .cache" \
    "while read     |วนลูปเพื่อเช็คชนิดไฟล์ (folder/exec/file) เพื่อใส่ไอคอนสี" \
    "(ต่างจาก ls)   |find ลงลึกทุก subdirectory, ls แค่ชั้นเดียว"
  echo ""
  find "$path" -iname "*${name}*" -not -path '*/\.*' 2>/dev/null | while IFS= read -r f; do
    if   [[ -d "$f" ]]; then printf '%s\n' "$(c 75 b "  📁 $f")"
    elif [[ -x "$f" ]]; then printf '%s\n' "$(c 46 b "  ⚙️  $f")"
    else printf '%s\n' "$(c 255 b "  📄 $f")"; fi
  done
  echo ""
}

fm_grep() {
  local text="${1:?Usage: fm grep <text> [path]}"
  local path="${2:-.}"
  _learn_box "fm grep — ค้นหาข้อความในไฟล์" \
    "grep -rl --color=always \"\$text\" \"\$path\" 2>/dev/null | while IFS= read -r f; do grep -c ... done" \
    "grep           |global regular expression print — ค้นหา pattern ในไฟล์" \
    "-r             |recursive — ค้นทุกไฟล์ใน subdirectory" \
    "-l             |list only — แสดงแค่ชื่อไฟล์ที่เจอ ไม่แสดงทุก line" \
    "--color        |highlight คำที่เจอด้วยสี" \
    "(grep -n)      |อยากดู line number ด้วย ใช้ grep -rn แทน"
  echo ""
  grep -rl --color=always "$text" "$path" 2>/dev/null | while IFS= read -r f; do
    local hits; hits=$(grep -c "$text" "$f" 2>/dev/null)
    printf '%s\n' "$(c 46 b "  $f") $(c 244 d "($hits matches)")"
  done
  echo ""
}

fm_findext() {
  local ext="${1:?Usage: fm findext <.ext> [path]}"
  local path="${2:-.}"
  [[ "$ext" != .* ]] && ext=".$ext"
  _learn_box "fm findext — ค้นหาตามนามสกุล" \
    "find \"\$path\" -iname \"*\${ext}\" 2>/dev/null | while IFS= read -r f; do stat ... done" \
    "find           |ค้นหาแบบ recursive ทุก subdirectory" \
    "-iname \"*\$ext\" |* = ชื่อใดก็ได้, ลงท้ายด้วย \$ext (case-insensitive)" \
    "while read     |วนลูปใช้ stat อ่านขนาดไฟล์ทีละอันเพื่อแสดงผล" \
    "(นามสกุล)      |Unix ไม่ได้ใช้นามสกุลตัดสิน type จริงๆ แต่ find ใช้ชื่อล้วน"
  echo ""
  find "$path" -iname "*${ext}" 2>/dev/null | while IFS= read -r f; do
    local raw; raw=$(stat -c "%s" "$f" 2>/dev/null || stat -f "%z" "$f" 2>/dev/null || echo 0)
    printf "  %s  %s\n" "$(c 255 b "$(_human_size "$raw")")" "$f"
  done
  echo ""
}

fm_findsize() {
  local spec="${1:?Usage: fm findsize <+/-NMB> [path]  ex: fm findsize +10 /home}"
  local path="${2:-.}"
  _learn_box "fm findsize — ค้นหาตามขนาดไฟล์" \
    "find \"\$path\" -type f -size \"\${spec}M\" 2>/dev/null | while IFS= read -r f; do stat ... done" \
    "-type f        |f = regular file เท่านั้น (ไม่รวมโฟลเดอร์)" \
    "-size \${spec}M  |+ = ใหญ่กว่า, - = เล็กกว่า, ไม่มี prefix = เท่ากับ (หน่วย M=MB)" \
    "(หน่วยอื่น)    |c=bytes k=KB M=MB G=GB เช่น -size +1G หาไฟล์ใหญ่กว่า 1GB"
  echo ""
  find "$path" -type f -size "${spec}M" 2>/dev/null | while IFS= read -r f; do
    local raw; raw=$(stat -c "%s" "$f" 2>/dev/null || stat -f "%z" "$f" 2>/dev/null || echo 0)
    printf "  %s  %s\n" "$(c 226 b "$(_human_size "$raw")")" "$f"
  done
  echo ""
}

fm_info() {
  local f="${1:?Usage: fm info <file>}"
  [[ ! -e "$f" ]] && { _err "ไม่พบ: $f"; return 1; }
  _learn_box "fm info — รายละเอียดไฟล์ครบถ้วน" \
    "stat \"$f\"  +  file -b \"$f\"  +  wc -lw \"$f\"" \
    "stat           |อ่าน metadata ของไฟล์จาก inode (ไม่ต้องเปิดไฟล์จริง)" \
    "stat -c '%A %a'|%A = symbolic perm (-rwxr-xr-x), %a = numeric (755)" \
    "stat -c '%U:%G'|%U = owner username, %G = group name" \
    "stat -c '%y'   |%y = mtime (last modified), %w = birth time (ถ้า fs รองรับ)" \
    "file -b        |อ่าน magic bytes ของไฟล์จริง เช่น 'PNG image data, 1920x1080'" \
    "wc -l / -w     |word count — นับ lines / words ในไฟล์"
  local raw size
  raw=$(stat -c "%s" "$f" 2>/dev/null || stat -f "%z" "$f" 2>/dev/null || echo 0)
  size=$(_human_size "$raw")
  echo ""
  cn 87 "  ╔══════════════════════════════════════════╗"
  printf '%s\n' "$(c 87 b '  ║')  $(c w b 'File Information')                         $(c 87 b '║')"
  cn 87 "  ╚══════════════════════════════════════════╝"
  printf "  \e[2m%-18s\e[0m  %s\n" "Name:"        "$(basename "$f")"
  printf "  \e[2m%-18s\e[0m  %s\n" "Full Path:"   "$(realpath "$f")"
  printf "  \e[2m%-18s\e[0m  %s\n" "Size:"        "$size ($raw bytes)"
  printf "  \e[2m%-18s\e[0m  %s\n" "Type:"        "$(file -b "$f" 2>/dev/null || echo 'unknown')"
  printf "  \e[2m%-18s\e[0m  %s\n" "Permissions:" "$(stat -c '%A (%a)' "$f" 2>/dev/null || stat -f '%Sp' "$f")"
  printf "  \e[2m%-18s\e[0m  %s\n" "Owner:"       "$(stat -c '%U:%G' "$f" 2>/dev/null || stat -f '%Su:%Sg' "$f")"
  printf "  \e[2m%-18s\e[0m  %s\n" "Modified:"    "$(stat -c '%y' "$f" 2>/dev/null | cut -c1-19 || stat -f '%Sm' "$f")"
  printf "  \e[2m%-18s\e[0m  %s\n" "Created:"     "$(stat -c '%w' "$f" 2>/dev/null | cut -c1-19 || stat -f '%SB' "$f")"
  if [[ -f "$f" ]]; then
    printf "  %s  %s\n" "$(c 244 d "$(printf '%-18s' 'Lines/Words:')")" "$(wc -l < "$f" 2>/dev/null) / $(wc -w < "$f" 2>/dev/null)"
  fi
  echo ""
}

fm_size() {
  local target="${1:-.}"
  _learn_box "fm size — ขนาดรวมของไฟล์/โฟลเดอร์" \
    "du -sh \"$target\"" \
    "du             |disk usage — คำนวณขนาดที่ใช้จริงบน disk (รวม subdirectory)" \
    "-s             |summarize — แสดงแค่ยอดรวม ไม่แสดงทีละไฟล์" \
    "-h             |human-readable แสดงเป็น KB/MB/GB"
  _info "คำนวณขนาด: $target"
  du -sh "$target" 2>/dev/null | awk '{print "  Size: " $1 "  →  " $2}'
  echo ""
}

fm_recent() {
  local n="${1:-10}"
  local path="${2:-.}"
  _learn_box "fm recent — ไฟล์ที่แก้ไขล่าสุด" \
    "find \"$path\" -type f -printf '%T@ %p\n' | sort -rn | head -$n" \
    "-printf '%T@'  |T@ = mtime เป็น Unix timestamp (seconds since 1970-01-01)" \
    "sort -rn       |r = reverse (ใหม่สุดก่อน), n = numeric sort" \
    "head -$n        |แสดงแค่ $n บรรทัดแรก" \
    "date -d @ts    |แปลง Unix timestamp กลับเป็นวันที่อ่านได้"
  _info "ไฟล์ที่แก้ไขล่าสุด $n รายการใน $path"
  echo ""
  find "$path" -type f -not -path '*/\.*' -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -"$n" \
    | while read -r ts f; do
        local date raw
        date=$(date -d "@${ts%.*}" "+%Y-%m-%d %H:%M" 2>/dev/null || date -r "${ts%.*}" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "?")
        raw=$(stat -c "%s" "$f" 2>/dev/null || stat -f "%z" "$f" 2>/dev/null || echo 0)
        printf "  %s  %s  %s\n" "$(c 244 d "$date")" "$(c 244 b "$(_human_size "$raw")")" "$f"
      done
  echo ""
}

fm_big() {
  local n="${1:-10}"
  local path="${2:-.}"
  _learn_box "fm big — ไฟล์ขนาดใหญ่ที่สุด" \
    "find \"$path\" -type f -printf '%s %p\n' | sort -rn | head -$n" \
    "-printf '%s'   |s = file size เป็น bytes" \
    "sort -rn       |เรียงจากมากไปน้อย (ใหญ่สุดก่อน)" \
    "head -$n        |เอาแค่ top $n" \
    "(tip)          |fm big 20 / เพื่อหาไฟล์ขนาดใหญ่ที่กิน disk"
  _info "ไฟล์ขนาดใหญ่ที่สุด $n อันดับใน $path"
  echo ""
  find "$path" -type f -not -path '*/\.*' -printf '%s %p\n' 2>/dev/null \
    | sort -rn | head -"$n" \
    | while read -r bytes f; do
        printf "  %s  %s\n" "$(c 226 b "$(_human_size "$bytes")")" "$f"
      done
  echo ""
}

fm_dup() {
  local path="${1:-.}"
  _learn_box "fm dup — หาไฟล์ที่ซ้ำกัน (by MD5 checksum)" \
    "find \"$path\" -type f -exec md5sum {} + | sort | awk 'seen[\$1]++'" \
    "-exec md5sum {}+|คำนวณ MD5 checksum ทุกไฟล์ (fingerprint ของเนื้อหา)" \
    "sort           |เรียงตาม checksum เพื่อให้ไฟล์เหมือนกันอยู่ติดกัน" \
    "awk seen[]     |ถ้า checksum ซ้ำ = ไฟล์เนื้อหาเหมือนกัน 100%" \
    "(md5 vs sha)   |md5 เร็วกว่า sha256 เหมาะกับการหา dup ไม่ใช่ security"
  _info "กำลังหาไฟล์ซ้ำใน $path (อาจใช้เวลาสักครู่)..."
  echo ""
  find "$path" -type f -not -path '*/\.*' -exec md5sum {} + 2>/dev/null \
    | sort | awk 'seen[$1]++ { print $0 }' \
    | while IFS= read -r line; do
        printf '%s\n' "$(c 203 b '  ⚠ DUP:') $line"
      done
  echo ""
}

# ═════════════════════════════════════════════════════════════════
#  ARCHIVE
# ═════════════════════════════════════════════════════════════════

fm_zip() {
  [[ -z "$1" || -z "$2" ]] && { _err "Usage: fm zip <output.zip> <source>"; return 1; }
  command -v zip &>/dev/null || { _err "zip ไม่ได้ติดตั้ง: sudo apt install zip"; return 1; }
  _learn_box "fm zip — บีบอัดเป็น ZIP" \
    "zip -r \"$1\" \"$2\"" \
    "zip            |สร้างไฟล์ .zip แบบ DEFLATE compression" \
    "-r             |recursive — รวมทุกไฟล์ใน subdirectory ด้วย" \
    "(zip vs tar)   |zip = เข้ากันได้ทุก OS (Windows เปิดได้), tar.gz compression ดีกว่า"
  _step "บีบอัด: $2 → $1"
  zip -r "$1" "$2" && _ok "สร้าง ZIP สำเร็จ: $1"
}

fm_unzip() {
  [[ -z "$1" ]] && { _err "Usage: fm unzip <file.zip> [destination]"; return 1; }
  [[ ! -f "$1" ]] && { _err "ไม่พบ: $1"; return 1; }
  local dst="${2:-.}"
  _learn_box "fm unzip — แตกไฟล์ ZIP" \
    "unzip -o \"$1\" -d \"$dst\"" \
    "unzip          |แตกไฟล์ .zip" \
    "-o             |overwrite — เขียนทับไฟล์เดิมโดยไม่ถาม" \
    "-d \"$dst\"      |destination — แตกไปยัง folder ที่ระบุ (สร้างให้อัตโนมัติ)" \
    "(tip)          |fm ziplist ก่อนแตก เพื่อดูว่ามีอะไรในไฟล์"
  _step "แตกไฟล์: $1 → $dst"
  unzip -o "$1" -d "$dst" && _ok "แตกไฟล์สำเร็จ"
}

fm_tar() {
  [[ -z "$1" || -z "$2" ]] && { _err "Usage: fm tar <output.tar.gz> <source>"; return 1; }
  _learn_box "fm tar — บีบอัดเป็น tar.gz" \
    "tar -czvf \"$1\" \"$2\"" \
    "-c             |create — สร้าง archive ใหม่" \
    "-z             |gzip — บีบอัดด้วย gzip (.gz) หลังจาก tar รวมไฟล์" \
    "-v             |verbose — แสดงทุกไฟล์ที่เพิ่ม" \
    "-f \"$1\"        |file — ระบุชื่อ output file" \
    "(tar vs zip)   |tar.gz compression ratio ดีกว่า zip แต่ Windows ต้องใช้ 7-zip"
  _step "บีบอัด tar.gz: $2 → $1"
  tar -czvf "$1" "$2" && _ok "สร้าง tar.gz สำเร็จ: $1"
}

fm_untar() {
  [[ -z "$1" ]] && { _err "Usage: fm untar <file.tar.gz>"; return 1; }
  [[ ! -f "$1" ]] && { _err "ไม่พบ: $1"; return 1; }
  _learn_box "fm untar — แตกไฟล์ tar.gz" \
    "tar -xzvf \"$1\"" \
    "-x             |extract — แตกไฟล์ (ตรงข้ามกับ -c create)" \
    "-z             |gzip — บอกให้ tar รู้ว่าต้อง decompress gzip ก่อน" \
    "-v             |verbose — แสดงทุกไฟล์ที่แตก" \
    "-f \"$1\"        |file — ระบุชื่อ input file" \
    "(ดูก่อนแตก)   |tar -tzvf file.tar.gz เพื่อดูรายการก่อนแตก"
  _step "แตกไฟล์: $1"
  tar -xzvf "$1" && _ok "แตกสำเร็จ"
}

fm_ziplist() {
  [[ -z "$1" ]] && { _err "Usage: fm ziplist <file.zip>"; return 1; }
  [[ ! -f "$1" ]] && { _err "ไม่พบ: $1"; return 1; }
  _learn_box "fm ziplist — ดูรายการในไฟล์ ZIP" \
    "unzip -l \"$1\"" \
    "unzip -l       |list — แสดงรายการไฟล์ใน ZIP โดยไม่แตกออกมา" \
    "(tar)          |ดูรายการใน tar.gz: tar -tzvf file.tar.gz"
  _info "รายการใน $1:"
  echo ""
  unzip -l "$1"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
#  PERMISSIONS
# ═════════════════════════════════════════════════════════════════

fm_perm() {
  [[ -z "$1" ]] && { _err "Usage: fm perm <file>"; return 1; }
  [[ ! -e "$1" ]] && { _err "ไม่พบ: $1"; return 1; }
  _learn_box "fm perm — ดู permission ของไฟล์" \
    "stat -c '%A %a %U' \"$1\"" \
    "stat -c '%A'   |symbolic: -rwxr-xr-x (อ่านง่าย)" \
    "stat -c '%a'   |numeric/octal: 755 (ใช้กับ chmod ได้โดยตรง)" \
    "stat -c '%U'   |owner username" \
    "(อ่าน perm)    |r=read w=write x=execute, กลุ่ม 1=owner 2=group 3=others"
  local p n
  p=$(stat -c '%A' "$1" 2>/dev/null || stat -f '%Sp' "$1" 2>/dev/null)
  n=$(stat -c '%a' "$1" 2>/dev/null || stat -f '%OLp' "$1" 2>/dev/null)
  echo ""
  printf '%s\n' "$(c w b '  File:')       $1"
  printf '%s\n' "$(c w b '  Symbolic:')   $(c 87 b "$p")"
  printf '%s\n' "$(c w b '  Numeric:')    $(c 226 b "$n")"
  printf '%s\n' "$(c w b '  Owner:')      $(stat -c '%U' "$1" 2>/dev/null)"
  echo ""
}

fm_chmod() {
  [[ -z "$1" || -z "$2" ]] && { _err "Usage: fm chmod <mode> <file>  ex: fm chmod 755 script.sh"; return 1; }
  [[ ! -e "$2" ]] && { _err "ไม่พบ: $2"; return 1; }
  _learn_box "fm chmod — เปลี่ยน permission" \
    "chmod $1 \"$2\"" \
    "chmod          |change mode — เปลี่ยน permission bits ของไฟล์" \
    "$1             |octal: 7=rwx 6=rw- 5=r-x 4=r-- 0=---" \
    "755            |owner rwx, group r-x, others r-x (ปกติสำหรับ script)" \
    "644            |owner rw-, group r--, others r-- (ปกติสำหรับไฟล์ทั่วไป)" \
    "600            |owner rw- เท่านั้น (สำหรับไฟล์ secret เช่น private key)"
  chmod "$1" "$2" && _ok "เปลี่ยน permission: $2 → $1"
}

fm_chown() {
  [[ -z "$1" || -z "$2" ]] && { _err "Usage: fm chown <user> <file>"; return 1; }
  [[ ! -e "$2" ]] && { _err "ไม่พบ: $2"; return 1; }
  _learn_box "fm chown — เปลี่ยนเจ้าของไฟล์" \
    "chown $1 \"$2\"" \
    "chown          |change owner — เปลี่ยนเจ้าของไฟล์" \
    "$1             |ระบุเป็น user หรือ user:group เช่น joe:developers" \
    "(sudo)         |ส่วนใหญ่ต้องใช้ sudo เพราะการ chown ต้องสิทธิ์ root"
  chown "$1" "$2" && _ok "เปลี่ยนเจ้าของ: $2 → $1"
}

fm_mkexec() {
  [[ -z "$1" ]] && { _err "Usage: fm mkexec <file>"; return 1; }
  _learn_box "fm mkexec — ทำให้ไฟล์รันได้" \
    "chmod +x \"$1\"" \
    "chmod +x       |เพิ่ม execute bit ให้ทุก role (owner, group, others)" \
    "(+x vs 755)    |+x เพิ่มบน permission เดิม, 755 ตั้งค่าใหม่ตรงๆ" \
    "(จำเป็น)       |ไฟล์ .sh ต้อง chmod +x ก่อนถึงจะ ./script.sh ได้"
  chmod +x "$1" && _ok "ตั้งค่า +x: $1 สามารถรันได้แล้ว"
}

fm_rmexec() {
  [[ -z "$1" ]] && { _err "Usage: fm rmexec <file>"; return 1; }
  _learn_box "fm rmexec — ถอด execute permission" \
    "chmod -x \"$1\"" \
    "chmod -x       |ลบ execute bit ออกจากทุก role" \
    "(security)     |ใช้เพื่อป้องกัน script ถูกรันโดยไม่ตั้งใจ"
  chmod -x "$1" && _ok "ถอด -x: $1 ไม่สามารถรันได้แล้ว"
}

# ═════════════════════════════════════════════════════════════════
#  DISK & STORAGE
# ═════════════════════════════════════════════════════════════════

fm_df() {
  _learn_box "fm df — ดู disk usage ทุก drive" \
    "df -h" \
    "df             |disk free — แสดง space ที่ใช้/เหลือในแต่ละ filesystem ที่ mount" \
    "-h             |human-readable แสดงเป็น GB/MB แทน 512-byte blocks" \
    "(Mounted on)   |filesystem mount ณ ตำแหน่งใด เช่น / = root, /home = home dir" \
    "(Use%)         |fm color-code: เขียว <70%, เหลือง <90%, แดง >=90%"
  echo ""
  cn 87 "  💾  Disk Usage Summary"
  _sep
  df -h | awk -v CH="$(_c 255)$(_b)" -v CG="$(_c 82)" \
                -v CY="$(_c 226)$(_b)" -v CR="$(_c 196)$(_b)" -v R="$(_r)" \
    'NR==1 { printf "  " CH "%-20s  %-6s  %-6s  %-6s  %-5s  %s" R "\n",$1,$2,$3,$4,$5,$6; next }
     NR >1 {
       used=$5+0
       color=CG
       if (used>=90) color=CR
       else if (used>=70) color=CY
       printf "  %-20s  %-6s  %-6s  %-6s  " color "%-5s" R "  %s\n",$1,$2,$3,$4,$5,$6
     }'
  echo ""
}

fm_du() {
  local path="${1:-.}"
  _learn_box "fm du — ขนาดแต่ละโฟลเดอร์ย่อย" \
    "du -sh \"$path\"/*/  | sort -rh | head -20" \
    "du             |disk usage — คำนวณขนาดจริงบน disk รวม subdirectory" \
    "-s             |summarize — ยอดรวมต่อโฟลเดอร์ ไม่แตกย่อยทีละไฟล์" \
    "-h             |human-readable" \
    "sort -rh       |r=reverse h=human-numeric (เรียง 1G > 500M > 10K ถูกต้อง)" \
    "head -20       |แสดงแค่ 20 โฟลเดอร์ใหญ่สุด"
  _info "ขนาดโฟลเดอร์ย่อยใน $path :"
  echo ""
  du -sh "$path"/*/ 2>/dev/null | sort -rh | head -20 \
    | awk -v CY="$(printf '\e[1;38;5;226m')" -v R="$(printf '\e[0m')" '{printf "  " CY "%-10s" R "  %s\n", $1, $2}'
  echo ""
}

fm_clean() {
  local path="${1:-.}"
  _learn_box "fm clean — ลบไฟล์ temporary/cache" \
    "find \"$path\" -type f \\( -name '*.tmp' -o -name '*.log' -o -name '.DS_Store' -o -name 'Thumbs.db' -o -name '*.cache' \\) -print -delete" \
    "-type f        |ไฟล์เท่านั้น (ไม่ลบโฟลเดอร์)" \
    "\\( ... \\)      |grouping conditions ด้วย parentheses" \
    "-o             |OR — ตรงกับ pattern ใดก็ได้ใน group" \
    "-name '*.tmp'  |wildcard match ชื่อไฟล์ที่ลงท้ายด้วย .tmp" \
    "-print         |แสดงชื่อก่อนลบ (เพื่อ audit ว่าลบอะไรไปบ้าง)" \
    "-delete        |ลบทันที ไม่ผ่าน trash (permanent)"
  _warn "กำลังจะลบไฟล์ tmp/cache ใน: $path"
  _confirm "ยืนยัน?" || { _info "ยกเลิก"; return 0; }
  find "$path" -type f \( -name "*.tmp" -o -name "*.log" -o -name ".DS_Store" \
    -o -name "Thumbs.db" -o -name "*.cache" \) -print -delete 2>/dev/null
  _ok "ล้างไฟล์ชั่วคราวสำเร็จ"
}

FM_TRASH="${HOME}/.fm_trash"

fm_trash() {
  mkdir -p "$FM_TRASH"
  _learn_box "fm trash — ดูไฟล์ใน Trash" \
    "ls -lh \"$FM_TRASH\"" \
    "FM_TRASH       |fm เก็บไฟล์ที่ 'ลบ' ไว้ที่ ~/.fm_trash แทนการลบตาย" \
    "ls -lh         |l=long format, h=human-readable size" \
    "(restore)      |ถ้าอยากคืนไฟล์: fm cp ~/.fm_trash/ชื่อไฟล์ ~/ปลายทาง"
  if [[ -z "$(ls -A "$FM_TRASH")" ]]; then
    _info "Trash ว่างเปล่า 🎉"
  else
    _info "ไฟล์ใน Trash (${FM_TRASH}):"
    echo ""
    ls -lh "$FM_TRASH" | awk -v CW="$(_c 255)" -v R="$(_r)" 'NR>1 {printf "  " CW "%-10s" R "  %s\n", $5, $9}'
    echo ""
  fi
}

fm_emptytrash() {
  mkdir -p "$FM_TRASH"
  _learn_box "fm emptytrash — ล้าง Trash ถาวร" \
    "rm -rf \"${FM_TRASH}\"/*" \
    "rm             |remove" \
    "-r             |recursive — ลบโฟลเดอร์และทุกอย่างข้างใน" \
    "-f             |force — ไม่ถาม ไม่ error ถ้าไฟล์ไม่มี" \
    "/*             |glob: ทุกสิ่งใน FM_TRASH แต่ไม่ลบ folder Trash ตัวเอง" \
    "(ถาวร)         |ย้อนกลับไม่ได้ — fm จึงถามยืนยันก่อนเสมอ"
  if [[ -z "$(ls -A "$FM_TRASH")" ]]; then _info "Trash ว่างอยู่แล้ว"; return 0; fi
  _confirm "ล้าง Trash ถาวร (ย้อนกลับไม่ได้)?" || { _info "ยกเลิก"; return 0; }
  rm -rf "${FM_TRASH:?}"/* && _ok "ล้าง Trash สำเร็จ"
}

# ═════════════════════════════════════════════════════════════════
#  BATCH OPERATIONS
# ═════════════════════════════════════════════════════════════════

fm_bren() {
  local pattern="${1:?Usage: fm bren <old_pattern> <replacement>}"
  local replace="${2:?Usage: fm bren <old_pattern> <replacement>}"
  _learn_box "fm bren — เปลี่ยนชื่อหลายไฟล์พร้อมกัน" \
    "for f in *\"$pattern\"*; do mv \"\$f\" \"\${f//$pattern/$replace}\"; done" \
    "for f in *pat* |glob expansion: shell หา filename ที่มี pattern ก่อน loop" \
    "\${f//pat/rep} |bash string substitution: แทนทุก occurrence ของ pat ด้วย rep" \
    "(preview)      |fm แสดง before→after ก่อนถามยืนยัน ไม่ได้เปลี่ยนทันที"
  _info "Preview การเปลี่ยนชื่อ (pattern='$pattern' → '$replace'):"
  echo ""
  local count=0
  for f in *"$pattern"*; do
    [[ -e "$f" ]] || continue
    local newname="${f//$pattern/$replace}"
    printf "  %s  →  %s\n" "$(c 203 b "$f")" "$(c 46 b "$newname")"
    (( count++ ))
  done
  [[ $count -eq 0 ]] && { _warn "ไม่พบไฟล์ที่ตรงกัน"; return 0; }
  echo ""
  _confirm "ยืนยันเปลี่ยนชื่อ $count ไฟล์?" || { _info "ยกเลิก"; return 0; }
  for f in *"$pattern"*; do
    [[ -e "$f" ]] || continue
    mv "$f" "${f//$pattern/$replace}"
  done
  _ok "เปลี่ยนชื่อ $count ไฟล์สำเร็จ"
}

fm_bcp() {
  local dst="${1:?Usage: fm bcp <destination> <file1> <file2> ...}"
  shift
  [[ $# -eq 0 ]] && { _err "ระบุไฟล์ที่จะคัดลอก"; return 1; }
  _learn_box "fm bcp — คัดลอกหลายไฟล์พร้อมกัน" \
    "mkdir -p \"$dst\" && cp -v <files...> \"$dst/\"" \
    "cp             |copy" \
    "-v             |verbose — แสดงทุกไฟล์ที่คัดลอก" \
    "\$@ (args)      |bash รับ argument หลายตัว แล้วส่งต่อให้ cp ทีเดียว" \
    "mkdir -p       |fm สร้าง destination อัตโนมัติถ้ายังไม่มี"
  mkdir -p "$dst"
  _step "คัดลอก $# ไฟล์ → $dst"
  cp -v "$@" "$dst/" && _ok "คัดลอก $# ไฟล์สำเร็จ"
}

fm_bmv() {
  local dst="${1:?Usage: fm bmv <destination> <file1> <file2> ...}"
  shift
  [[ $# -eq 0 ]] && { _err "ระบุไฟล์ที่จะย้าย"; return 1; }
  _learn_box "fm bmv — ย้ายหลายไฟล์พร้อมกัน" \
    "mkdir -p \"$dst\" && mv -v <files...> \"$dst/\"" \
    "mv             |move" \
    "-v             |verbose" \
    "\$@ (args)      |bash ส่ง argument ทุกตัวให้ mv ทีเดียว" \
    "(ยืนยัน)       |fm ถามก่อนย้าย เพราะ mv ย้อนกลับยาก"
  mkdir -p "$dst"
  _confirm "ย้าย $# ไฟล์ → $dst?" || { _info "ยกเลิก"; return 0; }
  mv -v "$@" "$dst/" && _ok "ย้าย $# ไฟล์สำเร็จ"
}

fm_brm() {
  local pattern="${1:?Usage: fm brm <pattern> [path]}"
  local path="${2:-.}"
  _learn_box "fm brm — ลบหลายไฟล์ตาม pattern" \
    "find \"$path\" -maxdepth 1 -name \"*${pattern}*\"  →  rm -v <each>" \
    "find -maxdepth 1|ค้นแค่ชั้นเดียว ไม่ recursive (ปลอดภัยกว่า)" \
    "-name \"*pat*\"  |wildcard match ชื่อไฟล์ที่มี pattern อยู่" \
    "(preview)      |fm แสดงรายการก่อน แล้วถามยืนยัน ไม่ลบทันที" \
    "rm -v          |verbose ลบทีละไฟล์พร้อมแสดงชื่อ"
  _warn "ไฟล์ที่จะถูกลบ (pattern: $pattern):"
  echo ""
  local files=()
  while IFS= read -r f; do
    files+=("$f")
    printf '%s\n' "$(c 203 b "  🗑  $f")"
  done < <(find "$path" -maxdepth 1 -name "*${pattern}*" 2>/dev/null)
  [[ ${#files[@]} -eq 0 ]] && { _warn "ไม่พบไฟล์ที่ตรงกัน"; return 0; }
  echo ""
  _confirm "ลบ ${#files[@]} ไฟล์?" || { _info "ยกเลิก"; return 0; }
  for f in "${files[@]}"; do rm -v "$f"; done
  _ok "ลบ ${#files[@]} ไฟล์สำเร็จ"
}

fm_sortdir() {
  local src="${1:?Usage: fm sortdir <source_dir> <dest_dir>}"
  local dst="${2:?Usage: fm sortdir <source_dir> <dest_dir>}"
  [[ ! -d "$src" ]] && { _err "ไม่พบโฟลเดอร์ต้นทาง: $src"; return 1; }
  _learn_box "fm sortdir — จัดเรียงไฟล์ตามนามสกุล" \
    "find \"$src\" -maxdepth 1 -type f | while read f; do ext=\${f##*.}; mv \"\$f\" \"$dst/\${ext^^}/\"; done" \
    "\${f##*.}       |bash string op: ตัดทุกอย่างจนถึง . สุดท้าย เหลือแค่ extension" \
    "\${ext^^}       |bash uppercase: แปลง extension เป็นตัวพิมพ์ใหญ่ เช่น jpg→JPG" \
    "mkdir -p       |สร้างโฟลเดอร์ ext อัตโนมัติถ้ายังไม่มี" \
    "(ตัวอย่าง)     |photo.jpg → dst/JPG/photo.jpg, script.sh → dst/SH/script.sh"
  _info "จัดเรียงไฟล์ใน $src ตามนามสกุล → $dst"
  _confirm "ยืนยัน?" || { _info "ยกเลิก"; return 0; }
  find "$src" -maxdepth 1 -type f | while IFS= read -r f; do
    local ext name ext_dir
    name=$(basename "$f")
    ext="${name##*.}"; [[ "$ext" == "$name" ]] && ext="no_ext"
    ext_dir="${dst}/${ext^^}"
    mkdir -p "$ext_dir"
    mv "$f" "$ext_dir/"
    printf '%s\n' "$(c 46 b "  $name") → $(c 75 b "${ext^^}/")"
  done
  _ok "จัดเรียงไฟล์เสร็จสิ้น"
}

fm_datedir() {
  local src="${1:?Usage: fm datedir <source_dir> <dest_dir>}"
  local dst="${2:?Usage: fm datedir <source_dir> <dest_dir>}"
  [[ ! -d "$src" ]] && { _err "ไม่พบ: $src"; return 1; }
  _learn_box "fm datedir — จัดเรียงไฟล์ตามวันที่แก้ไข" \
    "find \"$src\" -maxdepth 1 -type f | while read f; do d=\$(date -r \"\$f\" '+%Y/%m-%b'); mv \"\$f\" \"$dst/\$d/\"; done" \
    "date -r \$f     |อ่าน mtime ของไฟล์แล้วแปลงเป็น format ที่กำหนด" \
    "+%Y/%m-%b      |format: ปี/เดือนตัวเลข-เดือนตัวอักษร เช่น 2025/05-May" \
    "mkdir -p       |สร้างโครงสร้างโฟลเดอร์ปี/เดือน อัตโนมัติ" \
    "(ตัวอย่าง)     |photo.jpg (แก้ไข 1 พ.ค. 2025) → dst/2025/05-May/photo.jpg"
  _info "จัดเรียงไฟล์ใน $src ตามวันที่ → $dst"
  _confirm "ยืนยัน?" || { _info "ยกเลิก"; return 0; }
  find "$src" -maxdepth 1 -type f | while IFS= read -r f; do
    local name date_folder
    name=$(basename "$f")
    date_folder=$(date -r "$f" "+%Y/%m-%b" 2>/dev/null || stat -f '%Sm' -t '%Y/%m-%b' "$f" 2>/dev/null || echo "unknown")
    mkdir -p "${dst}/${date_folder}"
    mv "$f" "${dst}/${date_folder}/"
    printf '%s\n' "$(c 46 b "  $name") → $(c 75 b "${date_folder}/")"
  done
  _ok "จัดเรียงตามวันที่สำเร็จ"
}

# ═════════════════════════════════════════════════════════════════
#  SYNC & REMOTE (3-WORLDS)
# ═════════════════════════════════════════════════════════════════

fm_world() {
  _learn_box "fm world — ตรวจสอบสถานะการเชื่อมต่อระหว่างเครื่อง" \
    "JOE_ENV  +  ping -c 1 \$IP" \
    "JOE_ENV       |ตัวแปร SSOT จาก joe.sh → 00-env.sh (TERMUX/WSL/GIT-BASH/MUMU)" \
    "ping          |ทดสอบว่าเครื่องอื่นออนไลน์อยู่หรือไม่ (Latency)" \
    "env vars      |ใช้ค่า IP/USER จาก 00-env.sh (SSOT)"

  local world
  case "$JOE_ENV" in
    TERMUX)   world="termux" ;;
    WSL)      world="wsl" ;;
    GIT-BASH) world="git-bash" ;;
    MUMU)     world="mumu" ;;
    *)        world="unknown" ;;
  esac

  echo ""
  printf '%s\n' "$(c 87 b '  🌏 Current World:') $(c 226 b "${world}") $(c 244 d "(JOE_ENV=$JOE_ENV)")"
  _sep
  printf "  %s  %s\n" "$(c 244 d "$(printf '%-12s' 'WSL:')")"    "${NODE_WSL_USER:-user}@${NODE_WSL_HOST:-wsl}"
  printf "  %s  %s\n" "$(c 244 d "$(printf '%-12s' 'Termux:')")" "${NODE_TERMUX_USER:-user}@${NODE_TERMUX_HOST:-termux}"
  printf "  %s  %s\n" "$(c 244 d "$(printf '%-12s' 'Windows:')")" "${NODE_WIN_USER:-User}@${NODE_WIN_HOST:-window}"
  echo ""
}

fm_ssh() {
  local target="${1:?Usage: fm ssh <tm|tw|wsl>}"
  shift
  _learn_box "fm ssh — เชื่อมต่อผ่าน Secure Shell" \
    "ssh -p <port> <user>@<ip>" \
    "ssh           |Secure Shell — เข้ารหัสข้อมูลทั้งหมดที่ส่งผ่าน network" \
    "-p <port>     |ระบุ port (Termux ใช้ 8022, Default คือ 22)" \
    "(shortcut)    |fm ssh tm = เข้ามือถือ, fm ssh tw = เข้า Windows"

  case "$target" in
    tm)  ssh -p "${NODE_TERMUX_PORT:-8022}" "${NODE_TERMUX_USER:-}@${NODE_TERMUX_HOST:-termux}" "$@" ;;
    tw)  ssh "${NODE_WIN_USER:-User}@${NODE_WIN_HOST:-window}" "$@" ;;
    wsl) ssh -i ~/.ssh/id_ed25519_wsl -p "${NODE_WSL_PORT:-22}" "${NODE_WSL_USER:-usercivenz}@${NODE_WSL_HOST:-wsl}" "$@" ;;
    *)   _err "ไม่รู้จักเป้าหมาย: $target (ใช้: tm, tw, wsl)" ;;
  esac
}

fm_push() {
  local src="${1:?Usage: fm push <local_path> [remote_dest]}"
  local dst="${2:-.}"
  local r_user r_ip r_port r_name

  case "$JOE_ENV" in
    TERMUX|MUMU)
      r_user="${NODE_WSL_USER:-usercivenz}"; r_ip="${NODE_WSL_HOST:-wsl}"; r_port="${NODE_WSL_PORT:-22}"; r_name="WSL"
      ;;
    *)
      r_user="${NODE_TERMUX_USER:-}"; r_ip="${NODE_TERMUX_HOST:-termux}"; r_port="${NODE_TERMUX_PORT:-8022}"; r_name="Termux"
      ;;
  esac

  _learn_box "fm push — ส่งไฟล์ไป $r_name" \
    "rsync -az --info=progress2 -e 'ssh -p $r_port' \"$src\" \"user@ip:$dst\"" \
    "-a/z/update   |Archive, Compress, และ Update ไฟล์ใหม่กว่า" \
    "-e 'ssh -p'   |ระบุ port ของเครื่องปลายทาง ($r_port)"

  _step "Pushing: $src → $r_name:$dst"
  rsync -az --update --info=progress2 -e "ssh -p $r_port" "$src" "${r_user}@${r_ip}:$dst" && _ok "Push สำเร็จ"
}

fm_pull() {
  local src="${1:?Usage: fm pull <remote_path> [local_dest]}"
  local dst="${2:-.}"
  local r_user r_ip r_port r_name

  case "$JOE_ENV" in
    TERMUX|MUMU)
      r_user="${NODE_WSL_USER:-usercivenz}"; r_ip="${NODE_WSL_HOST:-wsl}"; r_port="${NODE_WSL_PORT:-22}"; r_name="WSL"
      ;;
    *)
      r_user="${NODE_TERMUX_USER:-}"; r_ip="${NODE_TERMUX_HOST:-termux}"; r_port="${NODE_TERMUX_PORT:-8022}"; r_name="Termux"
      ;;
  esac

  _learn_box "fm pull — ดึงไฟล์จาก $r_name" \
    "rsync -az --info=progress2 -e 'ssh -p $r_port' \"user@ip:$src\" \"$dst\"" \
    "Pull          |ดึง code ที่แก้ใน $r_name กลับมาที่เครื่องปัจจุบัน"

  _step "Pulling: $r_name:$src → $dst"
  rsync -az --update --info=progress2 -e "ssh -p $r_port" "${r_user}@${r_ip}:$src" "$dst" && _ok "Pull สำเร็จ"
}

fm_rls() {
  local path="${1:-~}"
  local r_user r_ip r_port r_name

  case "$JOE_ENV" in
    TERMUX|MUMU)
      r_user="${NODE_WSL_USER:-usercivenz}"; r_ip="${NODE_WSL_HOST:-wsl}"; r_port="${NODE_WSL_PORT:-22}"; r_name="WSL"
      ;;
    *)
      r_user="${NODE_TERMUX_USER:-}"; r_ip="${NODE_TERMUX_HOST:-termux}"; r_port="${NODE_TERMUX_PORT:-8022}"; r_name="Termux"
      ;;
  esac

  _learn_box "fm rls — ดูไฟล์ใน $r_name" \
    "ssh -p $r_port user@ip 'ls -lah $path'" \
    "ssh <cmd>     |รันคำสั่งบนเครื่องปลายทาง ($r_name)"

  _info "$r_name Files in $path :"
  echo ""
  ssh -p $r_port "${r_user}@${r_ip}" "ls -lah '$path'"
  echo ""
}

fm_rrun() {
  [[ $# -eq 0 ]] && { _err "Usage: fm rrun <command>"; return 1; }
  local r_user r_ip r_port r_name

  case "$JOE_ENV" in
    TERMUX|MUMU)
      r_user="${NODE_WSL_USER:-usercivenz}"; r_ip="${NODE_WSL_HOST:-wsl}"; r_port="${NODE_WSL_PORT:-22}"; r_name="WSL"
      ;;
    *)
      r_user="${NODE_TERMUX_USER:-}"; r_ip="${NODE_TERMUX_HOST:-termux}"; r_port="${NODE_TERMUX_PORT:-8022}"; r_name="Termux"
      ;;
  esac

  _learn_box "fm rrun — รันคำสั่งบน $r_name" \
    "ssh -p $r_port user@ip \"$*\"" \
    "\"\$*\"          |ส่งคำสั่งทั้งหมดไปรันที่ $r_name"

  _step "Remote Run on $r_name: $*"
  ssh -p $r_port "${r_user}@${r_ip}" "$@"
}

# ═════════════════════════════════════════════════════════════════
#  COMPLETION & SHORTHANDS (Integrated from 3-Worlds)
# ═════════════════════════════════════════════════════════════════

_T_CACHE_DIR="${TMPDIR:-/tmp}/.termux_completion_cache"
_T_CACHE_TTL=30

_t_remote_paths() {
  local prefix="$1"
  local cache_key; cache_key=$(echo "$prefix" | sed 's|/[^/]*$||; s|[^a-zA-Z0-9]|_|g')
  [[ -z "$cache_key" ]] && cache_key="root"
  local cache_file="$_T_CACHE_DIR/${cache_key}.cache"
  mkdir -p "$_T_CACHE_DIR"

  if [[ -f "$cache_file" ]]; then
    local age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
    [[ $age -lt $_T_CACHE_TTL ]] && grep "^$prefix" "$cache_file" 2>/dev/null && return
  fi

  local dir; dir=$(dirname "$prefix"); [[ "$dir" == "." ]] && dir="~"
  ssh -p "${NODE_TERMUX_PORT:-8022}" "${NODE_TERMUX_USER:-}@${NODE_TERMUX_HOST:-termux}" "ls -1dp ${prefix}* 2>/dev/null || ls -1dp ${dir}/ 2>/dev/null" 2>/dev/null | tee "$cache_file"
}

_comp_push() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ $COMP_CWORD -eq 2 ]]; then
    mapfile -t COMPREPLY < <(compgen -f -- "$cur")
    [[ ${#COMPREPLY[@]} -eq 1 && -d "${COMPREPLY[0]}" ]] && COMPREPLY[0]+="/"
  elif [[ $COMP_CWORD -eq 3 ]]; then
    mapfile -t COMPREPLY < <(_t_remote_paths "$cur")
  fi
}

_comp_pull() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ $COMP_CWORD -eq 2 ]]; then
    mapfile -t COMPREPLY < <(_t_remote_paths "$cur")
  elif [[ $COMP_CWORD -eq 3 ]]; then
    mapfile -t COMPREPLY < <(compgen -f -- "$cur")
    [[ ${#COMPREPLY[@]} -eq 1 && -d "${COMPREPLY[0]}" ]] && COMPREPLY[0]+="/"
  fi
}

# Apply completion to fm push/pull
# Note: Complex completion for subcommands requires a dispatcher.
# For now, we'll keep the direct aliases for better completion experience.
alias push="fm push"
alias pull="fm pull"
command -v complete >/dev/null 2>&1 && complete -o nospace -F _comp_push push
command -v complete >/dev/null 2>&1 && complete -o nospace -F _comp_pull pull

# SSH Shortcuts
alias tm="fm ssh tm"
alias tw="fm ssh tw"
alias swsl="fm ssh wsl"

# Legacy Shorthands (Restored)
alias cpw2t="push"
alias cpt2w="pull"


# ═════════════════════════════════════════════════════════════════
#  MAIN DISPATCHER
# ═════════════════════════════════════════════════════════════════
fm() {
  local cmd="${1:-help}"
  shift 2>/dev/null
  case "$cmd" in
    ls)          fm_ls "$@"         ;;
    lsa)         fm_lsa "$@"        ;;
    tree)        fm_tree "$@"       ;;
    goto)        fm_goto "$@"       ;;
    back)        fm_back            ;;
    home)        fm_home            ;;
    pwd)         fm_pwd             ;;
    cp)          fm_cp "$@"         ;;
    mv)          fm_mv "$@"         ;;
    rm)          fm_rm "$@"         ;;
    rn)          fm_rn "$@"         ;;
    mk)          fm_mk "$@"         ;;
    mkdir)       fm_mkdir "$@"      ;;
    touch)       fm_touch "$@"      ;;
    link)        fm_link "$@"       ;;
    find)        fm_find "$@"       ;;
    grep)        fm_grep "$@"       ;;
    findext)     fm_findext "$@"    ;;
    findsize)    fm_findsize "$@"   ;;
    info)        fm_info "$@"       ;;
    size)        fm_size "$@"       ;;
    recent)      fm_recent "$@"     ;;
    big)         fm_big "$@"        ;;
    dup)         fm_dup "$@"        ;;
    zip)         fm_zip "$@"        ;;
    unzip)       fm_unzip "$@"      ;;
    tar)         fm_tar "$@"        ;;
    untar)       fm_untar "$@"      ;;
    ziplist)     fm_ziplist "$@"    ;;
    perm)        fm_perm "$@"       ;;
    chmod)       fm_chmod "$@"      ;;
    chown)       fm_chown "$@"      ;;
    mkexec)      fm_mkexec "$@"     ;;
    rmexec)      fm_rmexec "$@"     ;;
    df)          fm_df              ;;
    du)          fm_du "$@"         ;;
    clean)       fm_clean "$@"      ;;
    trash)       fm_trash           ;;
    emptytrash)  fm_emptytrash      ;;
    bren)        fm_bren "$@"       ;;
    bcp)         fm_bcp "$@"        ;;
    bmv)         fm_bmv "$@"        ;;
    brm)         fm_brm "$@"        ;;
    sortdir)     fm_sortdir "$@"    ;;
    datedir)     fm_datedir "$@"    ;;
    world)       fm_world           ;;
    ssh)         fm_ssh "$@"        ;;
    push)        fm_push "$@"       ;;
    pull)        fm_pull "$@"       ;;
    rls)         fm_rls "$@"        ;;
    rrun)        fm_rrun "$@"       ;;
    learn)       fm_learn "$@"      ;;
    block|dblock) dynamic_block "$@" ;;
    help|--help|-h|"") fm_help "$@" ;;
    *)
      _err "ไม่รู้จักคำสั่ง: $cmd"
      printf '%s\n' "$(c 244 d '  พิมพ์ ')$(c 51 b 'fm help')$(c 244 d ' เพื่อดูรายการคำสั่งทั้งหมด')"
      return 1
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────
# AUTO-WELCOME when sourced
# ─────────────────────────────────────────────────────────────────

_fm_banner() {
  echo -e ""
  cn 87 "  ███████╗██╗██╗     ███████╗███╗   ███╗ ██████╗ ██████╗ "
  cn 87 "  ██╔════╝██║██║     ██╔════╝████╗ ████║██╔════╝ ██╔══██╗"
  cn 87 "  █████╗  ██║██║     █████╗  ██╔████╔██║██║  ███╗██████╔╝"
  cn 87 "  ██╔══╝  ██║██║     ██╔══╝  ██║╚██╔╝██║██║   ██║██╔══██╗"
  cn 87 "  ██║     ██║███████╗███████╗██║ ╚═╝ ██║╚██████╔╝██║  ██║"
  cn 87 "  ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝"
  printf '%s\n' "$(c 255 b '  File Manager CLI — v3.0') | $(c 244 d 'Personal Command Center')"
  cn 244 d "  ───────────────────────────────────────────────────────────────────"
  cn 226 "  🚀 Quick Start:"
  echo -e "    \e[38;5;51mfm help\e[0m       \e[38;5;244m→  แสดงคำสั่งทั้งหมด (Category-based help)\e[0m"
  echo -e "    \e[38;5;51mfm learn on\e[0m   \e[38;5;244m→  เปิด Learn Mode (เพื่อดูคำสั่งจริงขณะรัน)\e[0m"
  echo -e "    \e[38;5;51mfm world\e[0m      \e[38;5;244m→  ตรวจสอบ IP และสถานะเครื่องอื่น (3-Worlds)\e[0m"
  cn 244 d "  ───────────────────────────────────────────────────────────────────"
  cn 46 "  ✅ File Manager loaded "
  echo -e ""
}
alias fm_bn="_fm_banner"
# Run the banner
# ─────────────────────────────────────────────────────────────────
# WELCOME MESSAGE (แสดงตอน source)
# ─────────────────────────────────────────────────────────────────
#printf '%s\n' "$(c 87 b '  💻 fm File-Manager loaded!')  พิมพ์ $(c w b 'fm help') หรือ $(c w b 'xfm status')"
#echo -e ""

# ═════════════════════════════════════════════════════════════════
#
#   ██╗  ██╗███████╗███╗   ███╗
#   ╚██╗██╔╝██╔════╝████╗ ████║
#    ╚███╔╝ █████╗  ██╔████╔██║
#    ██╔██╗ ██╔══╝  ██║╚██╔╝██║
#   ██╔╝ ██╗██║     ██║ ╚═╝ ██║
#   ╚═╝  ╚═╝╚═╝     ╚═╝     ╚═╝
#   Cross-Machine File Manager — v1.0
#   วางต่อท้าย bash-manager.sh แล้ว source ไฟล์เดิมตามปกติ
#
#   Usage: xfm help
#          xfm status
#          xfm ls win
#          xfm cp win:/Users/User/doc.txt tx:~/doc.txt
#          xfm sync wsl:~/projects deb:~/projects
#
# ═════════════════════════════════════════════════════════════════

_xfm_banner() {
  echo -e ""
  cn 87 "  ██╗  ██╗███████╗███╗   ███╗"
  cn 87 "  ╚██╗██╔╝██╔════╝████╗ ████║"
  cn 87 "   ╚███╔╝ █████╗  ██╔████╔██║"
  cn 87 "   ██╔██╗ ██╔══╝  ██║╚██╔╝██║"
  cn 87 "  ██╔╝ ██╗██║     ██║ ╚═╝ ██║"
  cn 87 "  ╚═╝  ╚═╝╚═╝     ╚═╝     ╚═╝"

  printf '%s\n' "$(c 255 b '  Cross-Machine File Manager — v1.0')"
  cn 244 d "  Universal File Transport Layer for 3-World Infrastructure"

  cn 244 d "  ───────────────────────────────────────────────────────────────────"

  cn 226 "  🚀 Quick Start:"
printf '%s\n' "    $(c 51 b 'xfm help')         $(c 244 d '→  แสดงคำสั่งทั้งหมด')"
    printf '%s\n' "    $(c 51 b 'xfm status')       $(c 244 d '→  ตรวจสอบสถานะทุกเครื่อง')"
    printf '%s\n' "    $(c 51 b 'xfm ls win')       $(c 244 d '→  ดูไฟล์ฝั่ง Windows')"
    printf '%s\n' "    $(c 51 b 'xfm cp tx:~/a wsl:~/b') $(c 244 d '→  copy ข้ามโลก')"
    printf '%s\n' "    $(c 51 b 'xfm sync wsl:~/p deb:~/p') $(c 244 d '→  sync project ข้ามเครื่อง')"

  cn 244 d "  ───────────────────────────────────────────────────────────────────"

  cn 46 "  ✅ XFM loaded successfully. Cross-world bridge established."
  echo -e ""
}
alias xfm_bn="_xfm_banner"

_xfm_lower() {
  if [ -n "$ZSH_VERSION" ]; then
    eval 'echo "${1:l}"'
  else
    eval 'echo "${1,,}"'
  fi
}


# ─────────────────────────────────────────────────────────────────
# MACHINE CONFIG — อ้างอิงจาก 00-env.sh (SSOT) เท่านั้น
# ห้าม hardcode ค่าที่นี่ — แก้ที่ 00-env.sh แทน
# ─────────────────────────────────────────────────────────────────
xfm_WIN_HOST="${NODE_WIN_HOST:-${NODE_WIN_IP:-${WINDOWS_IP}}}"
xfm_WIN_USER="${NODE_WIN_USER:-${WINDOWS_USER:-User}}"
xfm_WIN_PORT="${NODE_WIN_PORT:-22}"

xfm_WSL_HOST="${NODE_WSL_HOST:-${NODE_WSL_IP:-${WSL_IP}}}"
xfm_WSL_USER="${NODE_WSL_USER:-${WSL_USER:-usercivenz}}"
xfm_WSL_PORT="${NODE_WSL_PORT:-22}"

xfm_TM_HOST="${NODE_TERMUX_HOST:-${NODE_TERMUX_IP:-${TERMUX_IP}}}"
xfm_TM_USER="${NODE_TERMUX_USER:-${TERMUX_USER:-u0_a331}}"
xfm_TM_PORT="${NODE_TERMUX_PORT:-8022}"

xfm_MM_HOST="${NODE_MUMU_HOST:-${NODE_MUMU_IP:-mumu}}"
xfm_MM_USER="${NODE_MUMU_USER:-u0_a62}"
xfm_MM_PORT="${NODE_MUMU_PORT:-8020}"

xfm_DEB_HOST="${NODE_DEBIAN_HOST:-${DEBIAN_IP:-debian}}"
xfm_DEB_USER="${NODE_DEBIAN_USER:-${DEBIAN_USER:-root}}"
xfm_DEB_PORT="${NODE_DEBIAN_PORT:-${DEBIAN_PORT:-22}}"

# SSOT per-machine — ไม่ hardcode, ใช้ remote lookup ตอน translate

# ─────────────────────────────────────────────────────────────────
# MACHINE RESOLVER HELPERS
# ─────────────────────────────────────────────────────────────────

# รับ nickname → คืน Hostname หรือ IP
_xfm_host() {
  case "$(_xfm_lower "$1")" in
    win|windows) echo "$xfm_WIN_HOST" ;;
    wsl)         echo "$xfm_WSL_HOST" ;;
    tm|termux)   echo "$xfm_TM_HOST"  ;;
    mm|mumu)     echo "$xfm_MM_HOST"  ;;
    deb|debian)  echo "$xfm_DEB_HOST" ;;
    local|.)     echo "localhost"     ;;
    *) return 1 ;;
  esac
}

# รับ nickname → คืน username
_xfm_user() {
  case "$(_xfm_lower "$1")" in
    win|windows) echo "$xfm_WIN_USER" ;;
    wsl)         echo "$xfm_WSL_USER" ;;
    tm|termux)   echo "$xfm_TM_USER"  ;;
    mm|mumu)     echo "$xfm_MM_USER"  ;;
    deb|debian)  echo "$xfm_DEB_USER" ;;
    local|.)     echo "${USER:-$USERNAME}" ;;
    *) return 1 ;;
  esac
}

# รับ nickname → คืน SSH port
_xfm_port() {
  case "$(_xfm_lower "$1")" in
    win|windows) echo "$xfm_WIN_PORT" ;;
    wsl)         echo "$xfm_WSL_PORT" ;;
    tm|termux)   echo "$xfm_TM_PORT"  ;;
    mm|mumu)     echo "$xfm_MM_PORT"  ;;
    deb|debian)  echo "$xfm_DEB_PORT" ;;
    local|.)     echo ""              ;;
    *) return 1 ;;
  esac
}

# รับ nickname → คืนชื่อแสดงผลสวยๆ
_xfm_label() {
  case "$(_xfm_lower "$1")" in
    win|windows) cn 75 b "🖥️  win"    ;;
    wsl)         cn 46 b "🐧  wsl"   ;;
    tm|termux)   cn 226 b "📱  tm"    ;;
    mm|mumu)     cn 208 b "🎮  mm"    ;;
    deb|debian)  cn 87 b "🔷  deb"   ;;
    local|.)     cn 255 b "💻  local"  ;;
    *)           cn 244 "" "❓  $1"    ;;
  esac
}

# Validate machine name
_xfm_valid() {
  case "$(_xfm_lower "$1")" in
    win|windows|wsl|tm|termux|mm|mumu|deb|debian|local|.) return 0 ;;
    *) return 1 ;;
  esac
}

# คืน SSOT path ของ remote machine
# ไม่ hardcode — SSH ไปถาม remote ว่า $SSOT ของมันคืออะไร
# Usage: remote_ssot=$(_xfm_ssot "tm")
_xfm_ssot() {
  local machine="$1"
  # local = ใช้ค่าปัจจุบัน
  if [[ "$(_xfm_lower "$machine")" == "local" || "$machine" == "." ]]; then
    echo "${SSOT:-}"
    return
  fi
  # remote = SSH ไปถาม remote ว่า $SSOT คืออะไร
  local result
  result=$(_xfm_ssh "$machine" 'echo "$SSOT"') 2>/dev/null
  if [[ -n "$result" ]]; then
    echo "$result"
  else
    # fallback: ใช้ local SSOT (ไม่ ideal แต่ไม่ crash)
    echo "${SSOT:-}"
  fi
}

# แปลง path ถ้ามันตรงกับ local SSOT → remote SSOT
# ใช้ตอน xfm cp ข้ามเครื่อง เช่น tm:$SSOT/ wsl:$SSOT
# $SSOT expand เป็น local path ต้อง translate เป็น remote path ก่อน
_xfm_translate_path() {
  local path="$1" remote_machine="$2"
  local local_ssot="${SSOT:-}"
  local remote_ssot
  remote_ssot=$(_xfm_ssot "$remote_machine")

  # ถ้า path เริ่มต้นด้วย local SSOT → แทนที่ด้วย remote SSOT
  if [[ -n "$local_ssot" && "$path" == "$local_ssot"* && "$local_ssot" != "$remote_ssot" ]]; then
    echo "${remote_ssot}${path#"$local_ssot"}"
  else
    echo "$path"
  fi
}

# Parse "machine:path" หรือ "path" (ไม่มี machine = local)
# Usage: machine=$(_xfm_mach "$arg")  path=$(_xfm_path "$arg")
_xfm_mach() {
  if [[ "$1" == *":"* && ! "${1%%:*}" == "/"* ]]; then
    echo "${1%%:*}"
  else
    echo "local"
  fi
}
_xfm_path() {
  if [[ "$1" == *":"* && ! "${1%%:*}" == "/"* ]]; then
    echo "${1#*:}"
  else
    echo "$1"
  fi
}

# Build SSH connection string สำหรับ display
_xfm_conn_str() {
  local m="$1"
  local host user port
  host=$(_xfm_host "$m")
  user=$(_xfm_user "$m")
  port=$(_xfm_port "$m")
  [[ -n "$port" ]] && echo "$user@$host:$port" || echo "$user@$host"
}

# ─────────────────────────────────────────────────────────────────
# SSH / SCP / RSYNC WRAPPERS
# ─────────────────────────────────────────────────────────────────

# รัน command บน remote machine
# Usage: _xfm_ssh <machine> <command>
_xfm_ssh() {
  local machine="$1"; shift
  local host user port
  host=$(_xfm_host "$machine") || { _err "ไม่รู้จัก machine: $machine"; return 1; }
  user=$(_xfm_user "$machine")
  port=$(_xfm_port "$machine")
  local -a ssh_opts=(-o ConnectTimeout=5 -o BatchMode=yes)
  local key="${KEY_NODE:-${HOME}/.ssh/id_ed25519_node}"
  [[ -f "$key" ]] && ssh_opts+=(-i "$key")
  [[ -n "$port" ]] && ssh_opts+=(-p "$port")

  ssh "${ssh_opts[@]}" "$user@$host" "$@"
}

# rsync: local → remote
# Usage: _xfm_push <local_src> <machine> <remote_dst>
_xfm_push() {
  local src="$1" machine="$2" dst="$3"
  local host user port
  host=$(_xfm_host "$machine")
  user=$(_xfm_user "$machine")
  port=$(_xfm_port "$machine")
  local key="${KEY_NODE:-${HOME}/.ssh/id_ed25519_node}"
  local ssh_cmd="ssh -o ConnectTimeout=5 -o BatchMode=yes"
  [[ -f "$key" ]] && ssh_cmd="$ssh_cmd -i $key"
  [[ -n "$port" ]] && ssh_cmd="$ssh_cmd -p $port"
  rsync -avz --progress -e "$ssh_cmd" "$src" "$user@$host:$dst"
}

# rsync: remote → local
# Usage: _xfm_pull <machine> <remote_src> <local_dst>
_xfm_pull() {
  local machine="$1" src="$2" dst="$3"
  local host user port
  host=$(_xfm_host "$machine")
  user=$(_xfm_user "$machine")
  port=$(_xfm_port "$machine")
  local key="${KEY_NODE:-${HOME}/.ssh/id_ed25519_node}"
  local ssh_cmd="ssh -o ConnectTimeout=5 -o BatchMode=yes"
  [[ -f "$key" ]] && ssh_cmd="$ssh_cmd -i $key"
  [[ -n "$port" ]] && ssh_cmd="$ssh_cmd -p $port"
  rsync -avz --progress -e "$ssh_cmd" "$user@$host:$src" "$dst"
}

# Check ว่า machine online ไหม คืน latency ms หรือ -1 ถ้า offline
_xfm_ping() {
  local machine="$1"
  local host; host=$(_xfm_host "$machine") || { echo "-1"; return; }
  local t0 t1
  t0=$(date +%s%N 2>/dev/null || echo 0)
  local -a ssh_opts=(-o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no)
  local key="${KEY_NODE:-${HOME}/.ssh/id_ed25519_node}"
  [[ -f "$key" ]] && ssh_opts+=(-i "$key")
  local port; port=$(_xfm_port "$machine")
  [[ -n "$port" ]] && ssh_opts+=(-p "$port")

  if ssh "${ssh_opts[@]}" "$(_xfm_user "$machine")@$host" "echo ok" &>/dev/null; then
    t1=$(date +%s%N 2>/dev/null || echo 0)
    echo $(( (t1 - t0) / 1000000 ))
  else
    echo "-1"
  fi
}

# ─────────────────────────────────────────────────────────────────
# xfm HELP
# ─────────────────────────────────────────────────────────────────
xfm_help() {
  echo ""
  cn 87 "  ╔══════════════════════════════════════════════════════════════════╗"
  printf '%s\n' "$(c 87 b '  ║')  $(c 255 b '🌐  xfm — Cross-Machine File Manager  v2.0')                    $(c 87 b '║')"
  printf '%s\n' "$(c 87 b '  ║')  $(c 244 d 'Multi-World: win │ wsl │ tm (Termux) │ mm (MuMu) │ deb')     $(c 87 b '║')"
  cn 87 "  ╚══════════════════════════════════════════════════════════════════╝"

  echo ""
  cn 141 "  🏷️   MACHINE NICKNAMES"
  hline 66
  ctab "1:10 51:24 2:10 0:0" "ALIAS" "HOST / USER" "PORT" "MACHINE"
  hline 66
  ctab "75:10 244:24 2:10 0:0"  "win"       "$xfm_WIN_USER@$xfm_WIN_HOST" "$xfm_WIN_PORT" "🖥️  Windows"
  ctab "46:10 244:24 2:10 0:0"  "wsl"       "$xfm_WSL_USER@$xfm_WSL_HOST" "$xfm_WSL_PORT" "🐧  WSL"
  ctab "226:10 244:24 2:10 0:0" "tm"        "$xfm_TM_USER@$xfm_TM_HOST"   "$xfm_TM_PORT"  "📱  Termux (Android)"
  ctab "208:10 244:24 2:10 0:0" "mm"        "$xfm_MM_USER@$xfm_MM_HOST"   "$xfm_MM_PORT"  "🎮  MuMu (Android VM)"
  ctab "87:10 244:24 2:10 0:0"  "deb"       "$xfm_DEB_USER@$xfm_DEB_HOST" "$xfm_DEB_PORT" "🔷  Debian (proot)"
  ctab "255:10 244:24 2:10 0:0" "local / ." "${USER:-$USERNAME}@localhost" "-"           "💻  เครื่องนี้"
  hline 66

  echo ""
  cn 226 "  📡  COMMANDS"
  hline 66
  ctab "1:22 51:34 0:0" "COMMAND" "SYNTAX" "DESCRIPTION"
  hline 66
  ctab "46:22 244:34 0:0" "xfm status"  "xfm status"                          "ping ทุกเครื่อง + disk summary"
  ctab "46:22 244:34 0:0" "xfm ls"      "xfm ls <machine> [path]"             "แสดงไฟล์บน remote"
  ctab "46:22 244:34 0:0" "xfm cp"      "xfm cp <src> <dst>"                  "copy ข้ามเครื่อง (any→any)"
  ctab "46:22 244:34 0:0" "xfm mv"      "xfm mv <src> <dst>"                  "ย้ายข้ามเครื่อง (cp + rm src)"
  ctab "46:22 244:34 0:0" "xfm rm"      "xfm rm <machine:path>"               "ลบไฟล์บน remote (ถามยืนยัน)"
  ctab "46:22 244:34 0:0" "xfm mkdir"   "xfm mkdir <machine:path>"            "สร้างโฟลเดอร์บน remote"
  ctab "46:22 244:34 0:0" "xfm info"    "xfm info <machine:path>"             "รายละเอียดไฟล์บน remote"
  ctab "46:22 244:34 0:0" "xfm df"      "xfm df [machine|all]"                "disk usage (ทีละเครื่อง หรือทุกเครื่อง)"
  ctab "46:22 244:34 0:0" "xfm du"      "xfm du <machine:path>"               "ขนาดโฟลเดอร์ย่อยบน remote"
  ctab "46:22 244:34 0:0" "xfm find"    "xfm find <machine> <name> [path]"    "ค้นหาไฟล์บน remote"
  ctab "46:22 244:34 0:0" "xfm sync"    "xfm sync <src> <dst>"                "rsync สองทิศทาง (any→any)"
  ctab "46:22 244:34 0:0" "xfm push"    "xfm push <local_path> <machine:dst>" "local → remote (shorthand)"
  ctab "46:22 244:34 0:0" "xfm pull"    "xfm pull <machine:src> [local_dst]"  "remote → local (shorthand)"
  ctab "46:22 244:34 0:0" "xfm merge"   "xfm merge <A:path> <B:path>"         "Smart merge ข้ามเครื่อง (env/json/sh)"
  hline 66

  echo ""
  cn 244 d "  ┌──────────────────────────────────────────────────────────────────┐"
  echo -e "  \e[2m│\e[0m  \e[1mSyntax:\e[0m \e[38;5;87mmachine:path\e[0m  เช่น \e[38;5;226mtm:~/storage\e[0m  \e[38;5;208mmm:~/sdcard\e[0m  \e[38;5;75mwin:/Users/User/doc.txt\e[0m   \e[2m│\e[0m"
  echo -e "  \e[2m│\e[0m  ไม่ใส่ machine = local  เช่น \e[38;5;255m~/myfile.txt\e[0m                    \e[2m│\e[0m"
  echo -e "  \e[2m│\e[0m  \e[38;5;208m📚 Learn Mode:\e[0m \e[38;5;51mfm learn on\e[0m เพื่อดูคำสั่งจริงทุกครั้ง            \e[2m│\e[0m"
  cn 244 d "  └──────────────────────────────────────────────────────────────────┘"
  echo ""
}

# ─────────────────────────────────────────────────────────────────
# xfm STATUS — ping ทุกเครื่อง พร้อม disk summary
# ─────────────────────────────────────────────────────────────────
xfm_status() {
  _learn_box "xfm status — ตรวจสถานะทุก machine" \
    "ssh -o ConnectTimeout=5 -o BatchMode=yes user@host 'df -h / | tail -1'" \
    "-o ConnectTimeout=5  |timeout 5 วิ ถ้าไม่ตอบ = offline" \
    "-o BatchMode=yes     |ไม่ถาม password (ใช้ SSH key เท่านั้น)" \
    "df -h / | tail -1    |ดู disk usage ที่ / แค่บรรทัดสุดท้าย" \
    "(parallel)           |xfm ping ทุกเครื่องพร้อมกันด้วย background job &"

  echo ""
  cn 87 "  ╔══════════════════════════════════════════════════════════════════╗"
  printf '%s\n' "$(c 87 b '  ║')  $(c w b '🌐  Cross-Machine Status')                                     $(c 87 b '║')"
  cn 87 "  ╚══════════════════════════════════════════════════════════════════╝"
  echo ""
  ctab "1:6 1:22 1:6 1:8 1:10 1:0" "NAME" "CONNECTION" "PORT" "LATENCY" "DISK USE" "STATUS"
  _sep

  local machines=("win" "wsl" "tm" "mm" "deb")
  for m in "${machines[@]}"; do
    local host user port label conn_str
    host=$(_xfm_host "$m")
    user=$(_xfm_user "$m")
    port=$(_xfm_port "$m")
    conn_str="$user@$host"
    [[ -n "$port" ]] && port_disp=":$port" || port_disp=":22"

    # ping via SSH
    local ms; ms=$(_xfm_ping "$m")

    if [[ "$ms" -ge 0 ]] 2>/dev/null; then
      # get disk usage (filter only percentage token to prevent login banner pollution)
      local disk
      disk=$(_xfm_ssh "$m" "df -h / 2>/dev/null" 2>/dev/null | grep -o -E '[0-9]+%' | tail -n 1)
      [[ -z "$disk" ]] && disk="?"
      local disk_num="${disk//%/}"
      local disk_color="46"
      (( disk_num >= 90 )) 2>/dev/null && disk_color="203"
      (( disk_num >= 70 && disk_num < 90 )) 2>/dev/null && disk_color="226"

      ctab "x:0 244:22 2:6 46:8 ${disk_color}:10 46:0" "$(_xfm_label "$m")" "$conn_str" "$port_disp" "${ms}ms" "$disk" "✔ online"
    else
      ctab "x:0 244:22 2:6 2:8 2:10 203:0" "$(_xfm_label "$m")" "$conn_str" "$port_disp" "—" "—" "✘ offline"
    fi
  done

  echo ""
}

# ─────────────────────────────────────────────────────────────────
# xfm LS — แสดงไฟล์บน remote
# ─────────────────────────────────────────────────────────────────
xfm_ls() {
  local machine="${1:?Usage: xfm ls <machine> [path]}"
  local path="${2:-~}"
  _xfm_valid "$machine" || { _err "ไม่รู้จัก machine: $machine  (win|wsl|tm|mm|deb|local)"; return 1; }

  _learn_box "xfm ls — แสดงไฟล์บน remote" \
    "ssh -p <port> user@host 'ls -lAh --color=never \"$path\"'" \
    "ssh            |เชื่อมต่อ remote แล้วรัน command" \
    "-p <port>      |port ที่ตั้งไว้ตาม machine (tm=8022, mm=8020, win/wsl=22)" \
    "ls -lAh        |l=long format A=all incl. dotfiles h=human-readable size" \
    "--color=never  |ปิดสี ls เพราะ xfm จะจัด format เอง"

  echo ""
  printf '%s\n' "  $(_xfm_label "$machine")  $(c 87 b "📂  $path")"
  _sep

  if [[ "$(_xfm_lower "$machine")" == "local" || "$machine" == "." ]]; then
    ls -lAh --color=always "$path" 2>/dev/null || _err "ไม่พบ path: $path"
  else
    local remote_target="$path"
    [[ "$remote_target" == "~"* ]] && remote_target="\${HOME}${remote_target#\~}"
    _xfm_ssh "$machine" \
      "eval ls -lAh --color=never \"$remote_target\" 2>/dev/null || ls -lAh --color=never \"$path\" 2>/dev/null || echo 'ERROR: path not found'" \
      | while IFS= read -r line; do
          if [[ "$line" == total* ]]; then
            echo -e "  \e[2m$line\e[0m"
          elif [[ "$line" == d* ]]; then
            echo -e "  \e[38;5;75m$line\e[0m"
          elif [[ "$line" == l* ]]; then
            echo -e "  \e[38;5;51m$line\e[0m"
          elif [[ "$line" == *x* ]]; then
            echo -e "  \e[38;5;46m$line\e[0m"
          elif [[ "$line" == ERROR* ]]; then
            echo -e "  \e[38;5;203m$line\e[0m"
          else
            echo -e "  \e[38;5;255m$line\e[0m"
          fi
        done
  fi
  echo ""
}

# ─────────────────────────────────────────────────────────────────
# xfm CP — copy ข้ามเครื่อง (any → any)
# ─────────────────────────────────────────────────────────────────
xfm_cp() {
  local src_arg="${1:?Usage: xfm cp <src> <dst>  ex: xfm cp win:/file.txt tx:~/}"
  local dst_arg="${2:?Usage: xfm cp <src> <dst>}"

  local src_m src_p dst_m dst_p
  src_m=$(_xfm_mach "$src_arg"); src_p=$(_xfm_path "$src_arg")
  dst_m=$(_xfm_mach "$dst_arg"); dst_p=$(_xfm_path "$dst_arg")

  # ── SSOT path auto-translate ──────────────────────────────────
  # $SSOT expand เป็น local path ต้อง translate เป็น remote path
  # เช่น จาก Git Bash: tm:/c/Users/User/ssot → tm:/data/data/com.termux/files/home/ssot
  if [[ "$(_xfm_lower "$src_m")" != "local" && "$(_xfm_lower "$src_m")" != "." ]]; then
    src_p=$(_xfm_translate_path "$src_p" "$src_m")
  fi
  if [[ "$(_xfm_lower "$dst_m")" != "local" && "$(_xfm_lower "$dst_m")" != "." ]]; then
    dst_p=$(_xfm_translate_path "$dst_p" "$dst_m")
  fi

  # ── case 1: same machine ──────────────────────────────────────
  if [[ "$(_xfm_lower "$src_m")" == "$(_xfm_lower "$dst_m")" ]]; then
    _learn_box "xfm cp — copy บน machine เดียวกัน ($src_m)" \
      "ssh -p <port> user@host 'cp -rv \"$src_p\" \"$dst_p\"'" \
      "cp -rv         |copy recursive + verbose บน remote via SSH" \
      "(same machine) |src/dst อยู่เครื่องเดียวกัน ไม่ต้องส่งไฟล์ข้าม network"
    _step "copy บน $src_m: $src_p → $dst_p"
    _xfm_ssh "$src_m" "cp -rv \"$src_p\" \"$dst_p\"" && _ok "copy สำเร็จ"
    return
  fi

  # ── case 2: local → remote ────────────────────────────────────
  if [[ "$(_xfm_lower "$src_m")" == "local" || "${src_m,,}" == "." ]]; then
    _learn_box "xfm cp — local → remote ($dst_m)" \
      "rsync -avz --progress -e 'ssh -p <port>' \"$src_p\" user@host:\"$dst_p\"" \
      "rsync -avz     |a=archive z=compress v=verbose" \
      "--progress     |แสดง progress bar ระหว่าง transfer" \
      "-e 'ssh -p N'  |บอก rsync ให้ใช้ ssh port ที่กำหนด" \
      "user@host:dst  |รูปแบบ remote path ของ rsync"
    _step "push: local:$src_p  →  $dst_m:$dst_p"
    _xfm_push "$src_p" "$dst_m" "$dst_p" && _ok "copy สำเร็จ"
    return
  fi

  # ── case 3: remote → local ────────────────────────────────────
  if [[ "$(_xfm_lower "$dst_m")" == "local" || "${dst_m,,}" == "." ]]; then
    _learn_box "xfm cp — remote ($src_m) → local" \
      "rsync -avz --progress -e 'ssh -p <port>' user@host:\"$src_p\" \"$dst_p\"" \
      "rsync          |pull mode: remote host อยู่ฝั่ง source" \
      "(pull)         |rsync ดึงไฟล์จาก remote มาไว้ local"
    _step "pull: $src_m:$src_p  →  local:$dst_p"
    _xfm_pull "$src_m" "$src_p" "$dst_p" && _ok "copy สำเร็จ"
    return
  fi

  # ── case 4: remote → remote (route ผ่าน local) ───────────────
  _learn_box "xfm cp — remote→remote ผ่าน local ($src_m → $dst_m)" \
    "rsync pull $src_m:$src_p → ${TMPDIR:-/tmp}/xfm_relay/  then  rsync push → $dst_m:$dst_p" \
    "step 1: pull    |ดึงจาก $src_m มาไว้ ${TMPDIR:-/tmp}/xfm_relay/ ก่อน" \
    "step 2: push    |ส่งจาก ${TMPDIR:-/tmp}/xfm_relay/ ไปยัง $dst_m" \
    "step 3: cleanup |ลบ temp dir หลัง transfer สำเร็จ" \
    "(rsync limit)   |rsync ไม่รองรับ remote-to-remote โดยตรง จึงต้อง relay ผ่าน local"

  local relay_dir; relay_dir=$(mktemp -d "${TMPDIR:-/tmp}/xfm_relay_XXXXXX")
  trap "rm -rf '$relay_dir'" RETURN

  _step "relay: $src_m:$src_p  →  [local relay]  →  $dst_m:$dst_p"

  _info "Step 1/3 — pull จาก $src_m ..."
  _xfm_pull "$src_m" "$src_p" "$relay_dir/" || { _err "pull จาก $src_m ล้มเหลว"; return 1; }

  _info "Step 2/3 — push ไปยัง $dst_m ..."
  _xfm_push "$relay_dir/" "$dst_m" "$dst_p" || { _err "push ไปยัง $dst_m ล้มเหลว"; return 1; }

  _info "Step 3/3 — cleanup relay dir ..."
  rm -rf "$relay_dir"

  _ok "remote→remote copy สำเร็จ ($src_m → $dst_m)"
}

# ─────────────────────────────────────────────────────────────────
# xfm MV — ย้ายข้ามเครื่อง (cp + rm src)
# ─────────────────────────────────────────────────────────────────
xfm_mv() {
  local src_arg="${1:?Usage: xfm mv <src> <dst>}"
  local dst_arg="${2:?Usage: xfm mv <src> <dst>}"
  local src_m; src_m=$(_xfm_mach "$src_arg")
  local src_p; src_p=$(_xfm_path "$src_arg")

  _learn_box "xfm mv — ย้ายข้ามเครื่อง" \
    "xfm cp <src> <dst>  &&  ssh user@src_host 'rm -rf \"$src_p\"'" \
    "xfm cp         |ทำ copy ก่อน (ทุก case เหมือนกัน)" \
    "rm -rf src     |หลัง copy สำเร็จ ถึงจะลบ source (safe: copy first)" \
    "(ยืนยัน)       |xfm mv ถามยืนยันก่อนเสมอ เพราะลบ source ย้อนกลับไม่ได้"

  _warn "ย้าย: $src_arg → $dst_arg"
  _warn "source จะถูกลบหลัง copy สำเร็จ"
  _confirm "ยืนยัน?" || { _info "ยกเลิก"; return 0; }

  xfm_cp "$src_arg" "$dst_arg" || { _err "copy ล้มเหลว — source ยังอยู่ครบ"; return 1; }

  _info "ลบ source: $src_m:$src_p ..."
  if [[ "$(_xfm_lower "$src_m")" == "local" || "$src_m" == "." ]]; then
    rm -rf "$src_p" && _ok "ลบ source สำเร็จ"
  else
    _xfm_ssh "$src_m" "rm -rf \"$src_p\"" && _ok "ลบ source บน $src_m สำเร็จ"
  fi
}

# ─────────────────────────────────────────────────────────────────
# xfm RM — ลบไฟล์บน remote
# ─────────────────────────────────────────────────────────────────
xfm_rm() {
  local arg="${1:?Usage: xfm rm <machine:path>}"
  local machine path
  machine=$(_xfm_mach "$arg"); path=$(_xfm_path "$arg")
  _xfm_valid "$machine" || { _err "ไม่รู้จัก machine: $machine"; return 1; }

  _learn_box "xfm rm — ลบไฟล์บน remote" \
    "ssh -p <port> user@host 'rm -rv \"$path\"'" \
    "rm -rv         |recursive + verbose ลบ remote via SSH" \
    "(permanent)    |ลบถาวร ไม่มี trash บน remote — ต้องระวัง!" \
    "(ยืนยัน)       |xfm rm ถามยืนยันก่อนเสมอ"

  _warn "กำลังจะลบบน $(_xfm_label "$machine"): $path"
  _confirm "ยืนยันการลบบน remote?" || { _info "ยกเลิก"; return 0; }

  if [[ "$(_xfm_lower "$machine")" == "local" || "$machine" == "." ]]; then
    rm -rv "$path" && _ok "ลบสำเร็จ"
  else
    _xfm_ssh "$machine" "rm -rv \"$path\"" && _ok "ลบสำเร็จบน $machine"
  fi
}

# ─────────────────────────────────────────────────────────────────
# xfm MKDIR — สร้างโฟลเดอร์บน remote
# ─────────────────────────────────────────────────────────────────
xfm_mkdir() {
  local arg="${1:?Usage: xfm mkdir <machine:path>}"
  local machine path
  machine=$(_xfm_mach "$arg"); path=$(_xfm_path "$arg")
  _xfm_valid "$machine" || { _err "ไม่รู้จัก machine: $machine"; return 1; }

  _learn_box "xfm mkdir — สร้างโฟลเดอร์บน remote" \
    "ssh -p <port> user@host 'mkdir -pv \"$path\"'" \
    "mkdir -pv      |p=สร้าง parent อัตโนมัติ v=verbose" \
    "ssh ... cmd    |ส่ง command ไปรันบน remote แล้วดู output กลับมา"

  if [[ "$(_xfm_lower "$machine")" == "local" || "$machine" == "." ]]; then
    mkdir -pv "$path" && _ok "สร้างโฟลเดอร์สำเร็จ"
  else
    _xfm_ssh "$machine" "mkdir -pv \"$path\"" && _ok "สร้างโฟลเดอร์สำเร็จบน $machine"
  fi
}

# ─────────────────────────────────────────────────────────────────
# xfm INFO — รายละเอียดไฟล์บน remote
# ─────────────────────────────────────────────────────────────────
xfm_info() {
  local arg="${1:?Usage: xfm info <machine:path>}"
  local machine path
  machine=$(_xfm_mach "$arg"); path=$(_xfm_path "$arg")
  _xfm_valid "$machine" || { _err "ไม่รู้จัก machine: $machine"; return 1; }

  _learn_box "xfm info — รายละเอียดไฟล์บน remote" \
    "ssh user@host 'stat \"$path\"; file -b \"$path\"; wc -lw \"$path\"'" \
    "stat           |อ่าน metadata จาก inode: size, perm, owner, timestamps" \
    "file -b        |detect file type จาก magic bytes" \
    "wc -lw         |นับ lines และ words (ถ้าเป็น text file)" \
    "(all-in-one)   |รัน 3 commands พร้อมกันใน ssh session เดียว ประหยัด latency"

  echo ""
  printf '%s\n' "  $(_xfm_label "$machine")  $(c 87 b "📄  $path")"
  _sep

  local remote_cmd='
    f="'"$path"'"
    echo "=STAT="
    stat "$f" 2>/dev/null || echo "stat: not found"
    echo "=FILE="
    file -b "$f" 2>/dev/null || echo "unknown"
    echo "=WC="
    wc -lw "$f" 2>/dev/null || echo "n/a"
  '

  if [[ "$(_xfm_lower "$machine")" == "local" || "$machine" == "." ]]; then
    bash -c "$remote_cmd" 2>/dev/null
  else
    _xfm_ssh "$machine" "$remote_cmd" 2>/dev/null \
      | awk -v GR="$(_c 244)" -v CY="$(_c 51)$(_b)" -v R="$(_r)" '
          /^=STAT=/ { section="stat"; next }
          /^=FILE=/ { section="file"; next }
          /^=WC=/   { section="wc";   next }
          section=="stat" { print "  " GR $0 R }
          section=="file" { print "  " CY "Type:" R "  " $0 }
          section=="wc"   { print "  " CY "Lines/Words:" R "  " $0 }
        '
  fi
  echo ""
}

# ─────────────────────────────────────────────────────────────────
# xfm DF — disk usage (ทีละเครื่อง หรือทุกเครื่องพร้อมกัน)
# ─────────────────────────────────────────────────────────────────
xfm_df() {
  local target="${1:-all}"

  _learn_box "xfm df — disk usage บน remote" \
    "ssh user@host 'df -h'" \
    "df -h          |disk free human-readable — แสดง space ทุก filesystem" \
    "(all)          |xfm loop ทุก machine และรัน df พร้อมกัน (background &)" \
    "(parallel)     |ส่ง SSH request ทุกเครื่องพร้อมกัน แล้วรอ output ทีเดียว"

  local machines=("win" "wsl" "tm" "mm" "deb")
  [[ "$target" != "all" ]] && machines=("$target")

  for m in "${machines[@]}"; do
    _xfm_valid "$m" || { _err "ไม่รู้จัก machine: $m"; continue; }
    echo ""
    echo -e "  $(_xfm_label "$m")  \e[2m$(_xfm_conn_str "$m")\e[0m"
    _sep
    if [[ "$(_xfm_lower "$m")" == "local" || "$m" == "." ]]; then
      df -h
    else
      _xfm_ssh "$m" "df -h" 2>/dev/null \
        | awk -v CH="$(_c 255)$(_b)" -v CG="$(_c 82)" \
                -v CY="$(_c 226)$(_b)" -v CR="$(_c 196)$(_b)" -v R="$(_r)" '
              NR==1 { printf "  " CH "%-20s  %-6s  %-6s  %-6s  %-5s  %s" R "\n",$1,$2,$3,$4,$5,$6; next }
              NR >1 {
                used=$5+0
                color=CG
                if (used>=90) color=CR
                else if (used>=70) color=CY
                printf "  %-20s  %-6s  %-6s  %-6s  " color "%-5s" R "  %s\n",$1,$2,$3,$4,$5,$6
              }' \
        || cn 203 b "  offline หรือเชื่อมต่อไม่ได้"
    fi
  done
  echo ""
}

# ─────────────────────────────────────────────────────────────────
# xfm DU — ขนาดโฟลเดอร์ย่อยบน remote
# ─────────────────────────────────────────────────────────────────
xfm_du() {
  local arg="${1:?Usage: xfm du <machine:path>}"
  local machine path
  machine=$(_xfm_mach "$arg"); path=$(_xfm_path "$arg")
  _xfm_valid "$machine" || { _err "ไม่รู้จัก machine: $machine"; return 1; }

  _learn_box "xfm du — ขนาดโฟลเดอร์ย่อยบน remote" \
    "ssh user@host 'du -sh \"$path\"/*/  | sort -rh | head -20'" \
    "du -sh         |summarize human-readable" \
    "sort -rh       |เรียงจากใหญ่สุด (human-numeric sort)" \
    "head -20       |แสดงแค่ top 20"

  echo ""
  printf '%s\n' "  $(_xfm_label "$machine")  $(c 87 b "📊  $path")"
  _sep

  if [[ "$(_xfm_lower "$machine")" == "local" || "$machine" == "." ]]; then
    du -sh "$path"/*/ 2>/dev/null | sort -rh | head -20 \
      | awk -v CY="$(printf '\e[1;38;5;226m')" -v R="$(printf '\e[0m')" '{printf "  " CY "%-10s" R "  %s\n", $1, $2}'
  else
    _xfm_ssh "$machine" \
      "du -sh \"$path\"/*/ 2>/dev/null | sort -rh | head -20" \
      | awk -v CY="$(printf '\e[1;38;5;226m')" -v R="$(printf '\e[0m')" '{printf "  " CY "%-10s" R "  %s\n", $1, $2}' \
      || echo -e "  \e[38;5;203mไม่สามารถดึงข้อมูลได้\e[0m"
  fi
  echo ""
}

# ─────────────────────────────────────────────────────────────────
# xfm FIND — ค้นหาไฟล์บน remote
# ─────────────────────────────────────────────────────────────────
xfm_find() {
  local machine="${1:?Usage: xfm find <machine> <name> [path]}"
  local name="${2:?Usage: xfm find <machine> <name> [path]}"
  local path="${3:-~}"
  _xfm_valid "$machine" || { _err "ไม่รู้จัก machine: $machine"; return 1; }

  _learn_box "xfm find — ค้นหาไฟล์บน remote" \
    "ssh user@host 'find \"$path\" -iname \"*${name}*\" -not -path \"*/\.*\"'" \
    "find           |recursive file search" \
    "-iname         |case-insensitive wildcard match" \
    "-not -path     |ข้ามโฟลเดอร์ซ่อน (.git .cache etc.)" \
    "(ssh)          |รัน find บน remote แล้วส่ง result กลับมาแสดงที่ local"

  _info "ค้นหา '$name' บน $(_xfm_label "$machine") ใน $path ..."
  echo ""

  if [[ "$(_xfm_lower "$machine")" == "local" || "$machine" == "." ]]; then
    find "$path" -iname "*${name}*" -not -path '*/\.*' 2>/dev/null
  else
    _xfm_ssh "$machine" \
      "find \"$path\" -iname \"*${name}*\" -not -path '*/\.*' 2>/dev/null" \
      | while IFS= read -r f; do
          echo -e "  \e[38;5;255m📄 $f\e[0m"
        done \
      || echo -e "  \e[38;5;203mค้นหาไม่ได้ หรือ offline\e[0m"
  fi
  echo ""
}

# ─────────────────────────────────────────────────────────────────
# xfm SYNC — rsync สองทิศทาง (any → any)
# ─────────────────────────────────────────────────────────────────
xfm_sync() {
  local src_arg="${1:?Usage: xfm sync <src> <dst>  ex: xfm sync tx:~/projects wsl:~/projects}"
  local dst_arg="${2:?Usage: xfm sync <src> <dst>}"

  local src_m dst_m src_p dst_p
  src_m=$(_xfm_mach "$src_arg"); src_p=$(_xfm_path "$src_arg")
  dst_m=$(_xfm_mach "$dst_arg"); dst_p=$(_xfm_path "$dst_arg")

  _learn_box "xfm sync — rsync ข้ามเครื่อง" \
    "rsync -avz --progress --delete -e 'ssh -p <port>' src dst" \
    "-a             |archive: recursive + permissions + timestamps" \
    "-v             |verbose แสดงทุกไฟล์" \
    "-z             |compress ระหว่าง transfer ลด bandwidth" \
    "--progress     |progress bar" \
    "--delete       |ลบไฟล์ปลายทางที่ไม่มีใน source (true sync)" \
    "(remote→remote)|route ผ่าน local relay เหมือน xfm cp"

  _warn "--delete จะลบไฟล์ที่ dst แต่ไม่มีใน src"
  _confirm "ยืนยัน sync: $src_arg → $dst_arg?" || { _info "ยกเลิก"; return 0; }

  local key="${KEY_NODE:-${HOME}/.ssh/id_ed25519_node}"

  # local → remote
  if [[ "$(_xfm_lower "$src_m")" == "local" || "$src_m" == "." ]]; then
    _step "sync: local:$src_p  →  $dst_m:$dst_p"
    local host user port
    host=$(_xfm_host "$dst_m"); user=$(_xfm_user "$dst_m"); port=$(_xfm_port "$dst_m")
    local ssh_opt="-o ConnectTimeout=8 -o BatchMode=yes"
    [[ -f "$key" ]] && ssh_opt="$ssh_opt -i $key"
    [[ -n "$port" ]] && ssh_opt="$ssh_opt -p $port"
    rsync -avz --progress --delete -e "ssh $ssh_opt" "$src_p" "$user@$host:$dst_p" \
      && _ok "sync สำเร็จ"
    return
  fi

  # remote → local
  if [[ "$(_xfm_lower "$dst_m")" == "local" || "$dst_m" == "." ]]; then
    _step "sync: $src_m:$src_p  →  local:$dst_p"
    local host user port
    host=$(_xfm_host "$src_m"); user=$(_xfm_user "$src_m"); port=$(_xfm_port "$src_m")
    local ssh_opt="-o ConnectTimeout=8 -o BatchMode=yes"
    [[ -f "$key" ]] && ssh_opt="$ssh_opt -i $key"
    [[ -n "$port" ]] && ssh_opt="$ssh_opt -p $port"
    rsync -avz --progress --delete -e "ssh $ssh_opt" "$user@$host:$src_p" "$dst_p" \
      && _ok "sync สำเร็จ"
    return
  fi

  # remote → remote (relay)
  _step "sync (relay): $src_m:$src_p  →  [local]  →  $dst_m:$dst_p"
  local relay_dir; relay_dir=$(mktemp -d "${TMPDIR:-/tmp}/xfm_sync_XXXXXX")
  trap "rm -rf '$relay_dir'" RETURN

  _info "Step 1/2 — pull จาก $src_m ..."
  _xfm_pull "$src_m" "$src_p" "$relay_dir/" || { _err "pull ล้มเหลว"; return 1; }

  _info "Step 2/2 — push ไปยัง $dst_m ..."
  local host user port
  host=$(_xfm_host "$dst_m"); user=$(_xfm_user "$dst_m"); port=$(_xfm_port "$dst_m")
  local ssh_opt="-o ConnectTimeout=8 -o BatchMode=yes"
  [[ -f "$key" ]] && ssh_opt="$ssh_opt -i $key"
  [[ -n "$port" ]] && ssh_opt="$ssh_opt -p $port"
  rsync -avz --progress --delete -e "ssh $ssh_opt" "$relay_dir/" "$user@$host:$dst_p" \
    && _ok "sync สำเร็จ"
  rm -rf "$relay_dir"
}

# ─────────────────────────────────────────────────────────────────
# xfm PUSH / PULL — shorthand สำหรับ local↔remote
# ─────────────────────────────────────────────────────────────────
xfm_push() {
  local local_src="${1:?Usage: xfm push <local_path> <machine:dst>}"
  local dst_arg="${2:?Usage: xfm push <local_path> <machine:dst>}"

  _learn_box "xfm push — local → remote shorthand" \
    "rsync -avz --progress -e 'ssh -p <port>' \"$local_src\" user@host:\"dst\"" \
    "(shorthand)    |เหมือน xfm cp local:$local_src $dst_arg แต่พิมพ์สั้นกว่า" \
    "(push = ส่งออก)|ส่งจากเครื่องนี้ไปยัง remote"

  xfm_cp "$local_src" "$dst_arg"
}

xfm_pull() {
  local src_arg="${1:?Usage: xfm pull <machine:src> [local_dst]}"
  local local_dst="${2:-.}"

  _learn_box "xfm pull — remote → local shorthand" \
    "rsync -avz --progress -e 'ssh -p <port>' user@host:\"src\" \"$local_dst\"" \
    "(shorthand)    |เหมือน xfm cp $src_arg local:$local_dst แต่พิมพ์สั้นกว่า" \
    "(pull = ดึงเข้า)|ดึงจาก remote มาไว้ที่เครื่องนี้"

  xfm_cp "$src_arg" "$local_dst"
}

# ─────────────────────────────────────────────────────────────────
# xfm DISPATCHER
# ─────────────────────────────────────────────────────────────────
xfm() {
  local cmd="${1:-help}"
  shift 2>/dev/null
  case "$cmd" in
    status)      xfm_status        ;;
    ls)          xfm_ls "$@"       ;;
    cp)          xfm_cp "$@"       ;;
    mv)          xfm_mv "$@"       ;;
    rm)          xfm_rm "$@"       ;;
    mkdir)       xfm_mkdir "$@"    ;;
    info)        xfm_info "$@"     ;;
    df)          xfm_df "$@"       ;;
    du)          xfm_du "$@"       ;;
    find)        xfm_find "$@"     ;;
    sync)        xfm_sync "$@"     ;;
    push)        xfm_push "$@"     ;;
    pull)        xfm_pull "$@"     ;;
    merge)       xfm_merge "$@"    ;;
    help|--help|-h|"") xfm_help   ;;
    *)
      _err "ไม่รู้จักคำสั่ง xfm: $cmd"
      printf '%s\n' "$(c 244 d '  พิมพ์ ')$(c 51 b 'xfm help')$(c 244 d ' เพื่อดูรายการทั้งหมด')"
      return 1
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────
# WELCOME MESSAGE (แสดงตอน source)
# ─────────────────────────────────────────────────────────────────
#printf '%s\n' "$(c 87 b '  🌐  xfm Cross-Machine loaded!')  พิมพ์ $(c w b 'xfm help') หรือ $(c w b 'xfm status')"
#echo -e ""


# ═════════════════════════════════════════════════════════════════
#
#  ███╗   ███╗███████╗██████╗  ██████╗ ███████╗
#  ████╗ ████║██╔════╝██╔══██╗██╔════╝ ██╔════╝
#  ██╔████╔██║█████╗  ██████╔╝██║  ███╗█████╗
#  ██║╚██╔╝██║██╔══╝  ██╔══██╗██║   ██║██╔══╝
#  ██║ ╚═╝ ██║███████╗██║  ██║╚██████╔╝███████╗
#  ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
#  XFM Smart Merge — v1.0
#  วางต่อท้าย xfm_append.sh (หรือ filemanager.sh)
#
#  Usage: xfm merge <machine_a:path> <machine_b:path>
#  Types: .env  .json  .sh  (text ทั่วไป)
#
# ═════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────
# PYTHON ENGINE WRITER
# เขียน engine.py ไปยัง temp dir ตอน xfm_merge เริ่มทำงาน
# ─────────────────────────────────────────────────────────────────
_xfm_write_engine() {
  local path="$1"
  cat > "$path" << 'PYEOF'
#!/usr/bin/env python3
"""
XFM Merge Engine
Usage:
  python3 engine.py analyze <type> <file_a> <file_b> <out_merged> <out_conflicts>
  python3 engine.py resolve <merged> <resolutions_json> <out_final>
  python3 engine.py show    <conflicts_json> <idx>
"""
import json, sys, re, os

# ── ANALYZE ────────────────────────────────────────────────────
def cmd_analyze(ftype, fa, fb, out_m, out_c):
    if ftype == 'env':
        merged, conflicts = merge_env(fa, fb)
    elif ftype == 'json':
        merged, conflicts = merge_json(fa, fb)
    elif ftype == 'sh':
        merged, conflicts = merge_sh(fa, fb)
    else:
        merged, conflicts = merge_lines(fa, fb)

    with open(out_m, 'w') as f:
        f.write('\n'.join(merged))
    with open(out_c, 'w') as f:
        json.dump(conflicts, f, ensure_ascii=False, indent=2)
    print(len(conflicts))

# ── RESOLVE ────────────────────────────────────────────────────
def cmd_resolve(merged_path, res_path, out_final):
    with open(merged_path) as f:
        content = f.read()
    with open(res_path) as f:
        resolutions = json.load(f)
    for r in resolutions:
        placeholder = f"__CONFLICT_{r['idx']}__"
        content = content.replace(placeholder, r['value'])
    with open(out_final, 'w') as f:
        f.write(content)

# ── SHOW (display one conflict for bash UI) ────────────────────
def cmd_show(conflicts_path, idx):
    with open(conflicts_path) as f:
        conflicts = json.load(f)
    c = conflicts[int(idx)]
    print(f"TYPE:{c['type']}")
    print(f"KEY:{c['key']}")
    print(f"TOTAL:{len(conflicts)}")
    print("---VA---")
    print(c['va'])
    print("---VB---")
    print(c['vb'])
    print("---END---")

# ══════════════════════════════════════════════════════════════
# MERGE IMPLEMENTATIONS
# ══════════════════════════════════════════════════════════════

def merge_env(fa, fb):
    """Key=value merge for .env files"""
    def parse(path):
        kvs, order = {}, []
        with open(path) as f:
            for raw in f:
                line = raw.rstrip('\n')
                m = re.match(r'^(export\s+)?(\w[\w]*)\s*=(.*)', line)
                if m and not line.lstrip().startswith('#'):
                    key = m.group(2)
                    kvs[key] = (line, m.group(3).strip())
                    order.append(('kv', key))
                else:
                    order.append(('raw', line))
        return kvs, order

    ka, oa = parse(fa)
    kb, ob = parse(fb)
    merged, conflicts, cidx, seen = [], [], 0, set()

    for typ, val in oa:
        if typ == 'raw':
            merged.append(val)
        else:
            key = val
            seen.add(key)
            if key in kb:
                if ka[key][1] == kb[key][1]:
                    merged.append(ka[key][0])          # same → include once
                else:
                    merged.append(f'__CONFLICT_{cidx}__')
                    conflicts.append({
                        'idx': cidx, 'type': 'env', 'key': key,
                        'va': ka[key][0], 'vb': kb[key][0]
                    })
                    cidx += 1
            else:
                merged.append(ka[key][0])              # only A → auto-add

    b_only = [(t, v) for t, v in ob if t == 'kv' and v not in seen]
    if b_only:
        merged += ['', '# ── keys only in B (auto-added) ──']
        for _, key in b_only:
            merged.append(kb[key][0])

    return merged, conflicts


def merge_json(fa, fb):
    """Deep merge for JSON files"""
    with open(fa) as f: da = json.load(f)
    with open(fb) as f: db = json.load(f)
    conflicts, cidx = [], [0]

    def deep(a, b, path='root'):
        if isinstance(a, dict) and isinstance(b, dict):
            result = dict(a)
            for k, vb in b.items():
                result[k] = deep(a[k], vb, f'{path}.{k}') if k in a else vb
            return result
        if a == b:
            return a
        placeholder = f'__CONFLICT_{cidx[0]}__'
        conflicts.append({
            'idx': cidx[0], 'type': 'json', 'key': path,
            'va': json.dumps(a, ensure_ascii=False),
            'vb': json.dumps(b, ensure_ascii=False)
        })
        cidx[0] += 1
        return placeholder

    merged_obj = deep(da, db)
    return json.dumps(merged_obj, indent=2, ensure_ascii=False).split('\n'), conflicts


def _count_structural_braces(line):
    """Count { and } braces, ignoring ${...} variable references."""
    import re as _re
    clean = _re.sub(r'\$\{[^}]*\}', '', line)
    return clean.count('{') - clean.count('}')


def extract_sh_functions(content):
    """Extract function blocks. Returns (funcs dict, lines with __FUNC_name__ markers)
    Includes preceding comment/blank lines that belong to the function (header block)
    and trailing closing underline (#----#)."""
    SKIP = {'if','for','while','case','until','select','do','then','fi','done','esac'}
    # Closing underline: line starting AND ending with #, middle is only dashes/equals/box-drawing
    # Matches: #--------------------------------------------------#, #═══#, etc.
    # Does NOT match: # ── Section Title ──  (section dividers without trailing #)
    CLOSE_RE = re.compile(r'^#[\s=\-─═]+#$')
    lines, funcs, out, i = content.split('\n'), {}, [], 0

    while i < len(lines):
        s = lines[i].strip()
        # Match: name() or name () or function name  (allow hyphens in names like check-tm)
        m  = re.match(r'^(?:function\s+)?([\w-]+)\s*\(\s*\)\s*(?:\{.*)?$', s)
        m2 = re.match(r'^function\s+([\w-]+)\s*(?:\{.*)?$', s)
        fname = None
        if m  and m.group(1)  not in SKIP and not s.startswith('#'): fname = m.group(1)
        if m2 and m2.group(1) not in SKIP and not s.startswith('#'): fname = m2.group(1)

        if fname:
            # Collect preceding comment/blank lines that belong to this function
            # (header block: #----NAME----#, comments, blank lines, section dividers, etc.)
            # Stop at closing underlines (#----#) of the PREVIOUS function
            header_start = i
            j = i - 1
            while j >= 0:
                lj = lines[j].strip()
                # Stop at non-comment, non-blank lines (function bodies, assignments, etc.)
                if lj and not lj.startswith('#'):
                    break
                # Stop at closing underlines (decorative #----# separators from prev function)
                if CLOSE_RE.match(lines[j]):
                    break
                header_start = j
                j -= 1

            # Remove header lines from out (they were already appended as non-function lines)
            header_count = i - header_start
            if header_count > 0 and len(out) >= header_count:
                # Verify the tail of out matches the header lines we want to remove
                tail_matches = True
                for k in range(header_count):
                    if out[len(out) - header_count + k] != lines[header_start + k]:
                        tail_matches = False
                        break
                if tail_matches:
                    out = out[:-header_count]

            block = lines[header_start:i]  # header lines
            block.append(lines[i])           # function definition line
            depth = _count_structural_braces(lines[i])
            i += 1
            # If opening brace not yet found
            while i < len(lines) and depth == 0:
                block.append(lines[i])
                depth += _count_structural_braces(lines[i])
                i += 1
            # Collect body
            while i < len(lines) and depth > 0:
                block.append(lines[i])
                depth += _count_structural_braces(lines[i])
                i += 1
            # Skip blank lines between body end and closing underline
            while i < len(lines) and lines[i].strip() == '':
                i += 1
            # Collect closing underline that belongs to THIS function
            if i < len(lines) and CLOSE_RE.match(lines[i]):
                block.append(lines[i])
                i += 1
            funcs[fname] = '\n'.join(block)
            out.append(f'__FUNC_{fname}__')
        else:
            out.append(lines[i])
            i += 1
    return funcs, out


def merge_sh(fa, fb):
    """Function-based merge for .sh files"""
    with open(fa) as f: ca = f.read()
    with open(fb) as f: cb = f.read()

    fa_funcs, fa_lines = extract_sh_functions(ca)
    fb_funcs, fb_lines = extract_sh_functions(cb)

    conflicts, cidx = [], 0
    set_a_non = set(l for l in fa_lines if not l.startswith('__FUNC_'))
    merged = []

    # Non-function lines from A
    for line in fa_lines:
        if not line.startswith('__FUNC_'):
            merged.append(line)

    # Non-function lines only in B
    b_only_lines = [l for l in fb_lines
                    if not l.startswith('__FUNC_') and l not in set_a_non and l.strip()]
    if b_only_lines:
        merged += ['', '# ── non-function lines only in B ──']
        merged.extend(b_only_lines)

    merged += ['', '# ' + '═'*50, '# FUNCTIONS', '# ' + '═'*50]

    # Merge functions
    all_funcs = list(fa_funcs) + [k for k in fb_funcs if k not in fa_funcs]
    for fname in all_funcs:
        in_a, in_b = fname in fa_funcs, fname in fb_funcs
        if in_a and in_b:
            if fa_funcs[fname] == fb_funcs[fname]:
                merged += [''] + fa_funcs[fname].split('\n')   # same → once
            else:
                merged += ['', f'__CONFLICT_{cidx}__']
                conflicts.append({
                    'idx': cidx, 'type': 'sh_func', 'key': fname,
                    'va': fa_funcs[fname], 'vb': fb_funcs[fname]
                })
                cidx += 1
        elif in_a:
            merged += [''] + fa_funcs[fname].split('\n')
        else:
            merged += ['', '# (function only in B — auto-added)']
            merged += fb_funcs[fname].split('\n')

    return merged, conflicts


def merge_lines(fa, fb):
    """Generic line-based merge (no conflict detection, union merge)"""
    with open(fa) as f: la = [l.rstrip('\n') for l in f]
    with open(fb) as f: lb = [l.rstrip('\n') for l in f]
    set_a = set(la)
    b_only = [l for l in lb if l not in set_a]
    merged = list(la)
    if b_only:
        merged += ['', '# ── lines only in B (auto-added) ──']
        merged.extend(b_only)
    return merged, []


# ── ENTRY POINT ────────────────────────────────────────────────
if __name__ == '__main__':
    cmd = sys.argv[1]
    if   cmd == 'analyze': cmd_analyze(*sys.argv[2:7])
    elif cmd == 'resolve': cmd_resolve(*sys.argv[2:5])
    elif cmd == 'show':    cmd_show(sys.argv[2], sys.argv[3])
    else: sys.exit(f'Unknown command: {cmd}')
PYEOF
}

# ─────────────────────────────────────────────────────────────────
# CONFLICT UI — แสดง conflict หนึ่งจุด รับ input จาก user
# ─────────────────────────────────────────────────────────────────
_xfm_conflict_ui() {
  local engine="$1" conflicts_json="$2" idx="$3"
  local label_a="$4" label_b="$5"
  local tmp_display; tmp_display=$(mktemp)

  python3 "$engine" show "$conflicts_json" "$idx" > "$tmp_display"

  local ctype ckey total va vb
  ctype=$(grep '^TYPE:' "$tmp_display" | cut -d: -f2-)
  ckey=$(grep '^KEY:'  "$tmp_display" | cut -d: -f2-)
  total=$(grep '^TOTAL:' "$tmp_display" | cut -d: -f2-)

  # Extract VA and VB blocks
  va=$(awk '/^---VA---/{flag=1;next}/^---VB---/{flag=0}flag' "$tmp_display")
  vb=$(awk '/^---VB---/{flag=1;next}/^---END---/{flag=0}flag' "$tmp_display")
  rm -f "$tmp_display"

  local display_idx=$(( idx + 1 ))

  echo ""
  echo -e "  \e[38;5;203m⚔️  CONFLICT ${display_idx}/${total}\e[0m  \e[1m${ckey}\e[0m  \e[2m(${ctype})\e[0m"
  echo -e "  \e[2m──────────────────────────────────────────────────────────────────\e[0m"

  # Show A value
  echo -e "  \e[38;5;75m┌─ [A]  $label_a ─────────────────────────────────────────────┐\e[0m"
  while IFS= read -r line; do
    printf '  %s  %s\n' "$(c 75 b '│')" "$(c 255 b "$line")"
  done <<< "$va"
  echo -e "  \e[38;5;75m└────────────────────────────────────────────────────────────────┘\e[0m"

  echo ""

  # Show B value
  echo -e "  \e[38;5;46m┌─ [B]  $label_b ─────────────────────────────────────────────┐\e[0m"
  while IFS= read -r line; do
    printf '  %s  %s\n' "$(c 46 b '│')" "$(c 255 b "$line")"
  done <<< "$vb"
  echo -e "  \e[38;5;46m└────────────────────────────────────────────────────────────────┘\e[0m"

  echo ""
  echo -e "  \e[1mเลือก:\e[0m"
  echo -e "  \e[38;5;75m[A]\e[0m ใช้ของ $label_a"
  echo -e "  \e[38;5;46m[B]\e[0m ใช้ของ $label_b"
  echo -e "  \e[38;5;226m[E]\e[0m พิมพ์ค่าใหม่เอง"
  echo -e "  \e[38;5;141m[S]\e[0m เก็บทั้งคู่ (comment อันนึง)"
  echo ""
  echo -en "  \e[1m> \e[0m"
  read -r choice

  # Return resolution value
  case "${choice^^}" in
    A)
      XFM_RESOLUTION="$va"
      _ok "ใช้ค่าจาก $label_a"
      ;;
    B)
      XFM_RESOLUTION="$vb"
      _ok "ใช้ค่าจาก $label_b"
      ;;
    E)
      echo -en "  \e[1mพิมพ์ค่าใหม่: \e[0m"
      read -r custom_val
      XFM_RESOLUTION="$custom_val"
      _ok "ใช้ค่าที่พิมพ์เอง"
      ;;
    S)
      # Keep both — comment out B
      XFM_RESOLUTION="${va}"$'\n'"# [B-alt] ${vb}"
      _ok "เก็บทั้งคู่"
      ;;
    *)
      _warn "ไม่รู้จัก '$choice' — ใช้ A เป็น default"
      XFM_RESOLUTION="$va"
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────
# PREVIEW — แสดงไฟล์ merged พร้อม line number
# ─────────────────────────────────────────────────────────────────
_xfm_preview() {
  local merged_file="$1"
  local filename="$2"
  local total_lines; total_lines=$(wc -l < "$merged_file")

  echo ""
  cn 87 "  ╔══════════════════════════════════════════════════════════════════╗"
  echo -e "  \e[38;5;87m║\e[0m  \e[1m📄 Preview: $filename\e[0m  \e[2m($total_lines lines)\e[0m"
  cn 87 "  ╚══════════════════════════════════════════════════════════════════╝"
  echo ""

  local ln=1
  while IFS= read -r line; do
    # Color-code special markers
    if [[ "$line" == "# ──"* || "$line" == "# ══"* || "$line" == "# FUNC"* ]]; then
      printf "  \e[2m%4d  \e[1;38;5;141m%s\e[0m\n" "$ln" "$line"
    elif [[ "$line" == "# (from B)"* || "$line" == "# (function only"* || "$line" == "# ── "* ]]; then
      printf "  \e[2m%4d  \e[38;5;46m%s\e[0m\n" "$ln" "$line"
    elif [[ "$line" == "#"* ]]; then
      printf "  \e[2m%4d  \e[38;5;244m%s\e[0m\n" "$ln" "$line"
    elif [[ -z "$line" ]]; then
      printf "  \e[2m%4d\e[0m\n" "$ln"
    else
      printf "  \e[2m%4d  \e[38;5;255m%s\e[0m\n" "$ln" "$line"
    fi
    (( ln++ ))
  done < "$merged_file"
  echo ""
}

# ─────────────────────────────────────────────────────────────────
# XFM MERGE — main function
# ─────────────────────────────────────────────────────────────────
xfm_merge() {
  local arg_a="${1:?Usage: xfm merge <machine_a:path> <machine_b:path>}"
  local arg_b="${2:?Usage: xfm merge <machine_a:path> <machine_b:path>}"

  local ma mb pa pb
  ma=$(_xfm_mach "$arg_a"); pa=$(_xfm_path "$arg_a")
  mb=$(_xfm_mach "$arg_b"); pb=$(_xfm_path "$arg_b")

  _xfm_valid "$ma" || { _err "ไม่รู้จัก machine: $ma"; return 1; }
  _xfm_valid "$mb" || { _err "ไม่รู้จัก machine: $mb"; return 1; }

  # detect file type
  local filename; filename=$(basename "$pa")
  local ext="${filename##*.}"
  local ftype
  case "$(_xfm_lower "$ext")" in
    env)         ftype="env"  ;;
    json)        ftype="json" ;;
    sh|bash|zsh) ftype="sh"   ;;
    *)           ftype="lines";;
  esac

  _learn_box "xfm merge — smart merge ข้ามเครื่อง" \
    "pull $ma:$pa  +  pull $mb:$pb  →  merge ($ftype)  →  push both" \
    "ftype=$ftype    |ตรวจจากนามสกุล: env=key-based, json=deep, sh=function-based" \
    "auto-merge      |ส่วนที่ไม่ conflict จะ merge อัตโนมัติ ไม่ถาม" \
    "conflicts       |เฉพาะส่วนที่ต่างกันทั้งคู่จะถามทีละจุด" \
    "push both       |หลัง confirm จะ push ผลลัพธ์กลับทั้งสองเครื่อง"

  # ── Setup temp workspace ──────────────────────────────────────
  local tmp; tmp=$(mktemp -d "${TMPDIR:-/tmp}/xfm_merge_XXXXXX")
  trap "rm -rf '$tmp'" RETURN

  local engine="$tmp/engine.py"
  local file_a="$tmp/file_a"
  local file_b="$tmp/file_b"
  local merged="$tmp/merged.txt"
  local conflicts_json="$tmp/conflicts.json"
  local resolutions_json="$tmp/resolutions.json"
  local final="$tmp/final.txt"

  # ── Write Python engine ───────────────────────────────────────
  _xfm_write_engine "$engine"

  # ── Pull both files ───────────────────────────────────────────
  _info "ดึงไฟล์จาก $(_xfm_label "$ma") ..."
  if [[ "$(_xfm_lower "$ma")" == "local" || "$ma" == "." ]]; then
    cp "$pa" "$file_a" || { _err "ไม่พบ: $pa"; return 1; }
  else
    _xfm_pull "$ma" "$pa" "$file_a" 2>/dev/null || { _err "pull จาก $ma ล้มเหลว"; return 1; }
  fi

  _info "ดึงไฟล์จาก $(_xfm_label "$mb") ..."
  if [[ "$(_xfm_lower "$mb")" == "local" || "$mb" == "." ]]; then
    cp "$pb" "$file_b" || { _err "ไม่พบ: $pb"; return 1; }
  else
    _xfm_pull "$mb" "$pb" "$file_b" 2>/dev/null || { _err "pull จาก $mb ล้มเหลว"; return 1; }
  fi

  # ── Run merge engine ──────────────────────────────────────────
  _step "วิเคราะห์และ auto-merge ($ftype) ..."
  local conflict_count
  conflict_count=$(python3 "$engine" analyze "$ftype" "$file_a" "$file_b" "$merged" "$conflicts_json" 2>/dev/null)

  if [[ -z "$conflict_count" ]]; then
    _err "merge engine error — ตรวจสอบว่ามี python3 ติดตั้งอยู่"
    return 1
  fi

  # ── Resolve conflicts interactively ──────────────────────────
  local label_a="$ma"
  local label_b="$mb"
  local resolutions=()

  if [[ "$conflict_count" -eq 0 ]]; then
    _ok "ไม่มี conflict — merge สำเร็จอัตโนมัติ 🎉"
  else
    echo ""
    echo -e "  \e[38;5;226m⚔️  พบ \e[1m$conflict_count conflict\e[0m\e[38;5;226m — จะถามทีละจุด\e[0m"

    for (( i=0; i<conflict_count; i++ )); do
      _xfm_conflict_ui "$engine" "$conflicts_json" "$i" "$label_a" "$label_b"
      # Escape for JSON
      local escaped_val; escaped_val=$(printf '%s' "$XFM_RESOLUTION" \
        | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
        | sed 's/^"//;s/"$//')
      resolutions+=("{\"idx\": $i, \"value\": \"$escaped_val\"}")
    done

    # Write resolutions JSON
    echo "[$(IFS=','; echo "${resolutions[*]}")]" > "$resolutions_json"

    # Apply resolutions
    _step "ใส่ค่าที่เลือกลงในไฟล์ merge ..."
    python3 "$engine" resolve "$merged" "$resolutions_json" "$final" 2>/dev/null \
      || { _err "apply resolutions ล้มเหลว"; return 1; }
    merged="$final"
  fi

  # ── Preview ───────────────────────────────────────────────────
  _xfm_preview "$merged" "$filename"

  # ── Confirm ───────────────────────────────────────────────────
  _confirm "ยืนยัน push กลับทั้งสองเครื่อง ($ma และ $mb)?" || {
    _info "ยกเลิก — ไม่มีอะไรเปลี่ยนแปลงบน remote"
    return 0
  }

  # ── Push to both machines ─────────────────────────────────────
  _step "push → $ma:$pa ..."
  if [[ "$(_xfm_lower "$ma")" == "local" || "$ma" == "." ]]; then
    cp "$merged" "$pa" && _ok "อัปเดต local:$pa"
  else
    _xfm_push "$merged" "$ma" "$pa" && _ok "อัปเดต $ma:$pa"
  fi

  _step "push → $mb:$pb ..."
  if [[ "$(_xfm_lower "$mb")" == "local" || "$mb" == "." ]]; then
    cp "$merged" "$pb" && _ok "อัปเดต local:$pb"
  else
    _xfm_push "$merged" "$mb" "$pb" && _ok "อัปเดต $mb:$pb"
  fi

  echo ""
  echo -e "  \e[38;5;46m✔  merge สำเร็จ!\e[0m  \e[2mทั้งสองเครื่องมีไฟล์เดียวกันแล้ว\e[0m"
  echo ""
}

#printf '%s\n' "$(c 208 b '  🔀  XFM Merge loaded!')  พิมพ์ $(c w b 'xfm merge <A:path> <B:path>')"
#echo ""

