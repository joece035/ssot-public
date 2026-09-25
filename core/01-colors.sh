# ============================================================
# 01-colors.sh — Color Engine V3
# ============================================================

#   color 202 "text"         # 256 color number
#   color m bu "magenta bu"  # magenta + bold+underline
# ============================================================
# COLOR RENDER CORE
#   _color_render <newline> <color> [style] [--bg <num>] [--reset-bg] <text...>
#     newline : 1 = ลงท้ายด้วย \n (cn) | 0 = ไม่มี newline (c)
#     --bg <num>   : ใส่สีพื้นหลัง (0-255)
#     --reset-bg   : reset เฉพาะ bg (\e[49m) โดยไม่ reset fg/style (สำหรับ inline layout)
#   c  <color> [style] <text...>   → พิมพ์สี ไม่มี newline (ต่อ layout ได้)
#   cn <color> [style] <text...>   → พิมพ์สี + ขึ้นบรรทัดใหม่ (จบบรรทัด)
# ตัวอย่าง: c 46 b "ON "; c 226 "| "; cn 208 "WARN"
#   →  ON | WARN  (สีละท่อน ในบรรทัดเดียว)
# NOTE: ชื่อ cn (ไม่ใช่ cp) เพราะ cp ชนกับคำสั่งจริงของระบบ
# ============================================================
# foreground
#\033[38;5;82m

# background
#\033[48;5;82m

# reset
#\033[0m



# ============================================================
# PALETTE DEFINITIONS (Single Source of Truth)
# ============================================================
RC_PALETTE_DEFAULT="45 82 190 196 208 201 39 226 129 48 203 141"
RC_PALETTE_PASTEL="167 173 136 71 68 105 132 178 150 139 174 180"
RC_PALETTE_NEON="21 10 196 200 225 27 202 123 229 205"
RC_PALETTE_DIM="53 22 23 17 54 58 236 64 61"
RC_PALETTE_BDRAW="$RC_PALETTE_DIM" # Alias for backward compatibility

_color_render() {
    local nl="$1"; shift
    local input_color="${1:-""}"

    local is_ps=0
    [[ "$nl" == "ps" ]] && is_ps=1

    # 0. Pre-scan: extract --bg <num|rc|rc:slot> and --reset-bg / --rbg from remaining args
    local bg_esc=""
    local reset_bg=0
    local _args_new=()
    local _skip_next=0
    for _a in "$@"; do
        if [[ $_skip_next -eq 1 ]]; then
            if [[ "$_a" =~ ^(rc|rand)$ ]]; then
                _a="$(random_core roll default)"
            elif [[ "$_a" =~ ^(rc|rand): ]]; then
                _a="$(random_core get "${_a#*:}")"
            fi
            if [[ "$_a" =~ ^[0-9]+$ && "$_a" -ge 0 && "$_a" -le 255 ]]; then
                bg_esc="$(_bg "$_a")"
            fi
            _skip_next=0
            continue
        fi
        if [[ "$_a" == "--bg" ]]; then
            _skip_next=1
            continue
        fi
        if [[ "$_a" == "--reset-bg" || "$_a" == "--rbg" ]]; then
            reset_bg=1
            continue
        fi
        _args_new+=("$_a")
    done
    set -- "${_args_new[@]}"

    local eol="\n"
    [[ "$nl" == "0" || $is_ps -eq 1 ]] && eol=""

    # Standalone reset-bg without extra arguments
    if [[ $# -eq 0 ]]; then
        if [[ $reset_bg -eq 1 ]]; then
            if [[ $is_ps -eq 1 ]]; then
                printf '\[%b%b\]%s' "${bg_esc}" "$(_rbg)" "${eol}"
            else
                printf "${bg_esc}$(_rbg)${eol}"
            fi
            return 0
        fi
        input_color=""
    else
        input_color="${1:-""}"
    fi

    # 1. Resolve color (Keywords, Named slots, & Short names)
    local color_=""
    case "$input_color" in
        rc|rand)
            input_color="$(random_core roll default)"
            ;;
        rc1|rand1)
            input_color="$(random_core roll default "$RC_PALETTE_PASTEL")"
            ;;
        rc2|rand2)
            input_color="$(random_core roll default "$RC_PALETTE_NEON")"
            ;;
        rc3|rand3)
            input_color="$(random_core roll default "$RC_PALETTE_DIM")"
            ;;
        rc4|rand4)
            input_color="$(random_core roll default "$RC_PALETTE_DIM")"
            ;;
        rc:*|rand:*)
            local _slot="${input_color#*:}"
            input_color="$(random_core get "$_slot")"
            ;;
        r)   color_="$R"   ;;  lr)  color_="$LR"  ;;
        g)   color_="$G"   ;;  lg)  color_="$LG"  ;;
        y)   color_="$Y"   ;;
        cr)  color_="$CR"  ;;  lcr|lc) color_="$LCR" ;;
        b)   color_="$B"   ;;  lb)  color_="$LB"  ;;
        m)   color_="$M"   ;;  lm)  color_="$LM"  ;;
        w)   color_="$W"   ;;  gr)  color_="$GR"  ;;
        ora) color_="$ORA" ;;
        *)   color_=""     ;;
    esac

    # 2. Build style prefix — เฉพาะเมื่อ arg ที่ 2 เป็น style จริงๆ
    #    (ว่าง หรือ b/d/i/u ต่อกัน) — กัน text ธรรมดาตกหล่นเป็น style
    local style=""
    if [[ $# -ge 2 && ("$2" == "" || "$2" =~ ^[bdiu]{1,4}$) ]]; then
        local s="$2"
        for (( i=0; i<${#s}; i++ )); do
            local char="${s:$i:1}"
            case "$char" in
                b) style+="$(_b)" ;;
                d) style+="$(_d)" ;;
                i) style+="$(_i)" ;;
                u) style+="$(_u)" ;;
            esac
        done
        shift 2
    else
        shift 1
    fi

    local targets=()
    if [[ $# -gt 0 ]]; then
        targets=("${@}")
    elif [[ $is_ps -eq 1 ]]; then
        local _active_esc="${bg_esc}${color_}${style}"
        if [[ "$input_color" =~ ^[0-9]+$ ]] && [[ "$input_color" -ge 0 ]] && [[ "$input_color" -le 255 ]]; then
            _active_esc="${bg_esc}${style}$(_c "$input_color")"
        fi
        if [[ -n "$_active_esc" ]]; then
            printf '\[%b\]' "$_active_esc"
        else
            printf '\[%b\]' "$(_r)"
        fi
        return 0
    else
        targets=("No text provided")
    fi

    # 4. Render
    local rst="$(_r)"
    [[ $reset_bg -eq 1 ]] && rst="$(_rbg)"
    [[ $is_ps -eq 1 ]] && rst="\[${rst}\]"

    for text in "${targets[@]}"; do
        if [[ "$input_color" =~ ^[0-9]+$ ]] && [[ "$input_color" -ge 0 ]] && [[ "$input_color" -le 255 ]]; then
            # 256-color path
            if [[ $is_ps -eq 1 ]]; then
                printf '\[%b\]%s%b' "${bg_esc}${style}$(_c "$input_color")" "$text" "$rst"
            else
                printf "${bg_esc}${style}$(_c "$input_color")%s${rst}${eol}" "$text"
            fi
        else
            # Short-name path (V2 vars)
            if [[ $is_ps -eq 1 ]]; then
                printf '\[%b\]%s%b' "${bg_esc}${color_}${style}" "$text" "$rst"
            else
                printf "%b" "${bg_esc}${color_}${style}${text}${rst}${eol}"
            fi
        fi
    done
}

# c  — พิมพ์สี ไม่มี newline (ตัวหลัก — ต่อสีในบรรทัดเดียวได้)
c() { _color_render 0 "$@"; }

# cn — พิมพ์สี + ขึ้นบรรทัดใหม่ (ตัวปิดท้ายบรรทัด)
cn() { _color_render 1 "$@"; }

# psc — พิมพ์สีสำหรับ PS1 Prompt (PS1-safe: ทุก escape sequence ถูกหุ้มด้วย \[ ... \])
psc() { _color_render ps "$@"; }

# color — ชื่อเต็ม (legacy = มี newline เหมือนเดิม, ใช้ใน color_comparison/c256_/rainbo)
color() { _color_render 1 "$@"; }

# ============================================================
# ESCAPE HELPERS (V3 — เขียนสั้น ใช้ซ้ำ เปลี่ยนแค่เลข)
#   _c <num>   = สี 256  (พิมพ์ต่อเนื่อง ไม่มี newline)
#   _r         = reset
#   _b  _d  _i  _u  = bold / dim / italic / underline
# ตัวอย่าง: echo -e "$(_c 208)$(_b)text$(_r)"
# ============================================================
# foreground 256
_fg() { printf '\033[38;5;%sm' "$1"; }
# background 256
_bg() { printf '\033[48;5;%sm' "$1"; }
# reset
r_() { printf '\033[0m'; }

# color 256
_c() { printf '\e[38;5;%sm' "$1"; }
_r() { printf '\e[0m'; }                # reset all
_rbg() { printf '\e[49m'; }             # reset background only
_rfg() { printf '\e[39m'; }             # reset foreground only
_b() { printf '\e[1m'; }                # bold
_d() { printf '\e[2m'; }                # dim
_i() { printf '\e[3m'; }                # italic
_u() { printf '\e[4m'; }                # underline
# _c_apply <existing_color_esc> <text> — wrap text with an existing color escape (used when color is computed at runtime)
_c_apply() { printf '%s%s\e[0m' "$1" "$2"; }


# ============================================================
# RAINBOW (V2 — full spectrum)
# ============================================================
# rainbow_palette [style] [text] — ข้อความสีรุ้ง
#   style : b=bold d=dim i=italic u=underline (ต่อกันได้ เช่น bu)
# ตัวอย่าง: rainbow_palette "HELLO"   → สีรุ้งธรรมดา
#           rainbow_palette bu "HELLO" → สีรุ้ง หนา+ขีดเส้นใต้
rainbow_palette() {
    local text="${1:-}"
    local style=""

    # ตัวแรกเป็น style ถ้าตรงแพทเทิร์น b/d/i/u (แบบเดียวกับ rc)
    if [[ -z "$1" ]] || [[ "$1" =~ ^[bdiu]{1,4}$ ]]; then
        style="$1"
        shift 1
        text="${1:-}"
    fi

    local length="${#text}"
    local palette=(196 208 226 46 51 21 129)
    local palette_size="${#palette[@]}"
    local result=""

    # สร้าง style prefix (b/d/i/u → escape)
    local st=""
    for (( i=0; i<${#style}; i++ )); do
        local char="${style:$i:1}"
        case "$char" in
            b) st+="$(_b)" ;; d) st+="$(_d)" ;;
            i) st+="$(_i)" ;; u) st+="$(_u)" ;;
        esac
    done

    # ต่อสีรุ้งทีละตัวอักษร (style ติดหน้าแต่ละตัว — กัน reset ระหว่างทาง)
    for (( i=0; i<length; i++ )); do
        local char="${text:$i:1}"
        local color_code="${palette[$(( i % palette_size ))]}"
        result+="${st}$(_c "$color_code")${char}"
    done

    # คืนค่าสีเดิม (\033[0m) ตบท้าย แล้วพ่นทีเดียวทั้งประโยค
    echo -e "${result}$(_r)"
}
mc(){ rainbow_palette "$@"; }  # mc = multi-color (alias)

# ============================================================
# TABLE HELPERS (V3 — ตารางหลายคอลัมน์ อ่านง่าย ไม่มี escape เยอะ)
# ============================================================
# ctab "<col-spec> <col-spec> ..." <value> <value> ...
#   col-spec = [style][color]:width
#     style : b=bold d=dim u=underline (ต่อกันได้ เช่น bu)
#     color : 0=default | ตัวเลข=256-color | x=ไม่ wrap สี (arg มีสีเอง)
#     width : 0=อัตโนมัติ (%s) | ตัวเลข=ความกว้าง
# ตัวอย่าง: ctab "46:22 244:28 0:0" "fm ls" "fm ls [path]" "desc"
ctab() {
  local -a spec=($1); shift
  local fmt="  " i=0 col c w st esc
  for col in "${spec[@]}"; do
    c="${col%%:*}"; w="${col##*:}"
    esc=""
    st=""
    while [[ "$c" =~ ^[bdu] ]]; do st+="${c:0:1}"; c="${c:1}"; done
    case "$st" in *b*) esc+="$(_b)";; esac
    case "$st" in *d*) esc+="$(_d)";; esac
    case "$st" in *u*) esc+="$(_u)";; esac
    if [[ "$c" == "x" ]]; then
      esc=""
    elif [[ "$c" =~ ^[0-9]+$ && "$c" != "0" ]]; then
      esc+="$(_c "$c")"
    fi
    if [[ "$w" =~ ^[0-9]+$ && "$w" != "0" ]]; then
      fmt+="${esc}%-${w}s$(_r)"
    else
      fmt+="${esc}%s$(_r)"
    fi
    (( i < ${#spec[@]} - 1 )) && fmt+="  "
    (( i++ ))
  done
  # แปลง \e literal ใน args → ESC จริง (เขียนได้ทุก bash version)
  local -a out=() a
  for a in "$@"; do out+=("${a//\\e/$'\e'}"); done
  printf "$fmt\n" "${out[@]}"
}

# hline [width] [color] — เส้นคั่นแนวนอน ───── (color 0 = dim)
hline() {
  local w="${1:-66}" c="${2:-0}" j dash="" char=${3:-"▬"}
  for ((j=0; j<w; j++)); do dash+="${char:-▬}"; done
  local esc="$(_d)"
  [[ "$c" != "0" ]] && esc="$(_c "$c")"
  printf "  %s%s%s\n" "$esc" "$dash" "$(_r)"
}

# ============================================================
# 16-COLOR BASE (V2 — used by color() short names)
# ============================================================
R='\e[38;5;196m'   ; LR='\e[38;5;203m'
G='\e[38;5;82m'    ; LG='\e[38;5;46m'
Y='\e[38;5;226m'
CR='\e[38;5;51m'   ; LCR='\e[38;5;87m'
B='\e[38;5;33m'    ; LB='\e[38;5;75m'
M='\e[38;5;141m'   ; LM='\e[38;5;141m'
W='\e[38;5;255m'   ; GR='\e[38;5;244m'
ORA='\e[38;5;208m'

# Styles — ใช้ผ่าน helpers: $(_b) bold / $(_d) dim / $(_i) italic / $(_u) underline / $(_r) reset

# -- Palette globals for JOE_BLOCK engine (_THEME[_pal_*])
lr='\e[38;5;203m'   # light red
lb='\e[38;5;75m'    # light blue
lg='\e[38;5;46m'    # light green
ora='\e[38;5;208m'  # orange
gr='\e[38;5;244m'   # gray
lm='\e[38;5;141m'   # light magenta
lc='\e[38;5;87m'    # light cyan
y='\e[38;5;226m'    # yellow

# ============================================================
# RANDOM COLOR PALETTES & CORE ENGINE (V3 - Stateful & Decoupled)
# ============================================================

# random_core — RNG & State Engine (Subshell-safe, Slot-based)
#   Usage: random_core [flags] [action: roll|get|last] [slot] [palette]
#   Actions:
#     roll [slot] [palette] : สุ่มสีใหม่บันทึกลง slot (default: "default")
#     get  [slot] [palette] : ดึงสีของ slot ปัจจุบัน (ถ้ายังไม่มีจะ roll ให้อัตโนมัติ)
#     last                  : ดึงสีที่เพิ่งถูกสุ่มไปล่าสุด (sync กับคำสั่งก่อนหน้าทันที)
#   Flags:
#     -n / --num (default)  : คืนค่าเป็นตัวเลขสี 256 (เช่น 208)
#     -e / --esc            : คืนค่าเป็น ANSI escape sequence (\e[38;5;...m)
#     -p / --ps             : คืนค่าเป็น PS1-safe escape (\[\e[38;5;...m\])
random_core() {
    [[ -n "${ZSH_VERSION:-}" ]] && emulate -L sh

    local out_mode="num"
    local action="get"
    local slot="default"
    local palette_str="$RC_PALETTE_DEFAULT"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--num) out_mode="num"; shift ;;
            -e|--esc) out_mode="esc"; shift ;;
            -p|--ps)  out_mode="ps";  shift ;;
            roll|get|last) action="$1"; shift ;;
            *)
                if [[ "$slot" == "default" ]]; then
                    slot="$1"
                else
                    palette_str="$1"
                fi
                shift
                ;;
        esac
    done

    # PID-scoped directory: Shared across subshells $(...), isolated per session
    local state_dir="/tmp/.rc_state_$$"
    [[ ! -d "$state_dir" ]] && mkdir -m 700 -p "$state_dir" 2>/dev/null

    local selected=""

    if [[ "$action" == "last" ]]; then
        [[ -f "$state_dir/_last" ]] && read -r selected < "$state_dir/_last" 2>/dev/null || true
        [[ -z "$selected" ]] && action="roll"
    elif [[ "$action" == "get" ]]; then
        [[ -f "$state_dir/$slot" ]] && read -r selected < "$state_dir/$slot" 2>/dev/null || true
        [[ -z "$selected" ]] && action="roll"
    fi

    if [[ "$action" == "roll" ]]; then
        # Safety fallback: Ensure palette_str is never empty
        [[ -z "$palette_str" ]] && palette_str="${RC_PALETTE_DEFAULT:-45 82 190 196 208 201 39 226 129 48 203 141}"

        local -a palette=($palette_str)
        local offset=0
        local test_arr=(x)
        [[ "${test_arr[0]}" != "x" ]] && offset=1

        local last_color=""
        [[ -f "$state_dir/_last" ]] && read -r last_color < "$state_dir/_last" 2>/dev/null || true

        local avail=() c
        for c in "${palette[@]}"; do
            [[ "$c" != "$last_color" ]] && avail+=("$c")
        done
        [[ ${#avail[@]} -eq 0 ]] && avail=("${palette[@]}")

        # Absolute protection against division by 0
        if (( ${#avail[@]} == 0 )); then
            avail=(45)
        fi

        local rand_val
        rand_val=$(date +%s%N 2>/dev/null | tr -dc '0-9' | tail -c 4)
        local ri=$(( (10#${rand_val:-$$} + RANDOM) % ${#avail[@]} ))
        selected="${avail[$(( ri + offset ))]}"

        printf "%s\n" "$selected" > "$state_dir/$slot" 2>/dev/null
        printf "%s\n" "$selected" > "$state_dir/_last" 2>/dev/null
    fi

    case "$out_mode" in
        num) printf "%s" "$selected" ;;
        esc) _c "$selected" ;;
        ps)  printf '\[\e[38;5;%sm\]' "$selected" ;;
    esac
}

# Legacy wrapper for backward compatibility
_rc_core() {
    random_core -e roll default "${1:-$RC_PALETTE_DEFAULT}"
}

# random_color — Presentation & Rendering Layer
#   Flags:
#     -s <slot> / --slot <slot> : ผูกสีกับ slot ที่กำหนด (เช่น -s border)
#     -k / --keep               : ใช้สีเดิมที่เพิ่งสุ่มไปล่าสุด
#     -p / --ps                 : PS1-safe render (ไม่มี newline ตกค้าง)
#     -0                        : No newline (เหมือน c)
#     --palette <str>           : ระบุชุด palette เฉพาะ
#     [style]                   : สไตล์ข้อความ (b, d, i, u)
random_color() {
    local slot=""
    local use_last=0
    local is_ps=0
    local nl=1
    local style=""
    local palette_str="$RC_PALETTE_DEFAULT"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--slot)    slot="$2"; shift 2 ;;
            -k|--keep)    use_last=1; shift ;;
            -p|--ps)      is_ps=1; nl=0; shift ;;
            -0)           nl=0; shift ;;
            --palette)    palette_str="$2"; shift 2 ;;
            b|d|i|u|bd|bi|bu|di|du|iu|bdi|bdu|biu|diu|bdiu)
                          style="$1"; shift ;;
            *)            break ;;
        esac
    done

    local col_num
    if [[ $use_last -eq 1 ]]; then
        col_num=$(random_core last)
    elif [[ -n "$slot" ]]; then
        col_num=$(random_core get "$slot" "$palette_str")
    else
        col_num=$(random_core roll default "$palette_str")
    fi

    if [[ $is_ps -eq 1 ]]; then
        psc "$col_num" "$style" "$@"
    elif [[ $nl -eq 0 ]]; then
        c "$col_num" "$style" "$@"
    else
        cn "$col_num" "$style" "$@"
    fi
}

# ============================================================
# PALETTE DEFINITIONS
# ============================================================
RC_PALETTE_DEFAULT="45 82 190 196 208 201 39 226 129 48 203 141"
RC_PALETTE_PASTEL="167 173 136 71 68 105 132 178 150 139 174 180"
RC_PALETTE_NEON="21 10 196 200 225 27 202 123 229 205"
RC_PALETTE_DIM="53 22 23 17 54 58 236 64 61"
# rc — Vibrant rainbow (12 colors)
rc() {
    random_color --palette "$RC_PALETTE_DIM" "$@"
}

# rc1 — Pastel/earthy (12 colors)
rc1() {
    random_color --palette "$RC_PALETTE_PASTEL" "$@"
}

# rc2 — Bold/neon (10 colors)
rc2() {
    random_color --palette "$RC_PALETTE_NEON" "$@"
}

# rc3 / rc4 — Dim/Dark tones
rc3() {
    random_color --palette "$RC_PALETTE_DIM" "$@"
}
rc4() {
    random_color --palette "$RC_PALETTE_DIM" "$@"
}

# ============================================================
# RANDOM CHARACTER COLOR (V3 — random color per character, no adjacent duplicates)
# ============================================================
_rc_char_render() {
    [[ -n "${ZSH_VERSION:-}" ]] && emulate -L sh
    local palette_str="$1"; shift
    local -a palette=($palette_str)

    local input_style=""
    if [[ $# -gt 1 && "$1" =~ ^[bdiu]{1,4}$ ]]; then
        input_style="$1"
        shift 1
    elif [[ $# -eq 1 && "$1" =~ ^[bdiu]{1,4}$ ]]; then
        input_style="$1"
        shift 1
    fi

    local style="" i char
    for (( i=0; i<${#input_style}; i++ )); do
        char="${input_style:$i:1}"
        case "$char" in
            b) style+="$(_b)" ;; d) style+="$(_d)" ;;
            i) style+="$(_i)" ;; u) style+="$(_u)" ;;
        esac
    done

    local targets=()
    if [[ $# -gt 0 ]]; then
        targets=("${@}")
    else
        targets=("No text provided")
    fi

    local last_color=""
    for text in "${targets[@]}"; do
        local length="${#text}"
        local result=""
        for (( i=0; i<length; i++ )); do
            local ch="${text:$i:1}"
            if [[ "$ch" == " " ]]; then
                result+=" "
                continue
            fi
            local avail=() c
            for c in "${palette[@]}"; do
                [[ "$c" != "$last_color" ]] && avail+=("$c")
            done
            [[ ${#avail[@]} -eq 0 ]] && avail=("${palette[@]}")
            local rand_idx=$(( RANDOM % ${#avail[@]} ))
            local chosen="${avail[$rand_idx]}"
            last_color="$chosen"
            result+="${style}$(_c "$chosen")${ch}"
        done
        echo -e "${result}$(_r)"
    done
}

# rcc — Random Color per Character (Vibrant rainbow, 12 colors)
rcc() {
    local palette="45 82 190 196 208 201 39 226 129 48 203 141"
    _rc_char_render "$palette" "$@"
}

# rcc1 — Pastel/earthy per character (12 colors)
rcc1() {
    local palette="167 173 136 71 68 105 132 178 150 139 174 180"
    _rc_char_render "$palette" "$@"
}

# rcc2 — Bold/neon per character (10 colors)
rcc2() {
    local palette="21 10 196 200 225 27 202 123 229 205"
    _rc_char_render "$palette" "$@"
}

# Alias
rc_char() { rcc "$@"; }

# ============================================================
# COLOR COMPARISON (V2 — visual picker)
# ============================================================
color_comparison() {
    local colors=("$@")
    for color_ in "${colors[@]}"; do
        local bar=$(color "$color_" b "█████████████████████████")
        printf "∎%s∎\n" "$bar"
    done
}
alias cmp='color_comparison'

color_comparison2() {
    local colors=("$@")
    for color_ in "${colors[@]}"; do
        local b=$(rcc b "█████████████████████████")
        printf "∎%s%s%s∎\n" "$b" "$b" "$b"
    done
}
alias cmp2='color_comparison2'

# ============================================================
# 256-COLOR CHART (V2 — visual reference)
# ============================================================
c256() {
    local i
    for i in {0..255}; do
        printf "%s%3d%s " "$(_c "$i")" "$i" "$(_r)"
        (( (i+1)%16==0 )) && echo
    done
}

# c256bg — visual reference for 256-color backgrounds (auto-contrast text)
c256bg() {
    local i fg val r g b lum
    for i in {0..255}; do
        # เลือกสีตัวเลข (fg) ให้อ่านง่ายบนสีพื้นหลัง (bg)
        if (( i < 16 )); then
            case "$i" in 0|1|2|4|5|8) fg=15 ;; *) fg=0 ;; esac
        elif (( i >= 232 )); then
            (( i > 243 )) && fg=0 || fg=15
        else
            val=$(( i - 16 ))
            r=$(( val / 36 ))
            g=$(( (val % 36) / 6 ))
            b=$(( val % 6 ))
            lum=$(( r * 30 + g * 59 + b * 11 ))
            (( lum > 240 )) && fg=0 || fg=15
        fi
        printf "%s%s%3d%s " "$(_bg "$i")" "$(_c "$fg")" "$i" "$(_r)"
        (( (i+1)%16==0 )) && echo
    done
}

c256_() {
    local i
    for i in {0..255}; do
        local block=$(cmp2 "$i")
        printf "%s code = %s\n" "$block" "$i"
        (( (i+1)%16==0 )) && echo
    done
}

# -- warn 
_warn(){
  cn y b "$@ ⚠"
}

# --error
_er(){
 cn 196 b "$@ ⛔"
}

 # --successfully
_sc(){
 	cn lg b "$@ ✅"
 }
_ok(){ _sc "$@"; }

 # --explain
 _ep(){
 	cn 45 b "$@ "
 }

Rcc() {
    # 1. เช็คว่ามี style ส่งเข้ามาหรือไม่
    # ถ้าตัวแรกว่างเปล่า หรือมีแค่ 1 parameter ให้มองว่าเป็น text ทั้งหมด
    local style=""
    local text=""

    if [[ $# -eq 1 ]]; then
        text="$1"
    else
        style="$1"
        shift # เลื่อน $1 (style) ออกไป เพื่อให้ $@ เหลือแค่ text ทั้งหมด
        text="$*"
    fi

    # 2. วน loop อ่านทีละ 1 ตัวอักษร (นับรวมช่องว่างด้วย)
    local i char
    for (( i=0; i<${#text}; i++ )); do
        char="${text:i:1}"
        rc "$style" "$char"
    done
}
draw_() {
   printf "%*s\n" "$2" "" | sed "s/ /$1/g"
}
alias d_='draw_'

# ============================================================
# REAL DISPLAY WIDTH & DYNAMIC TERMINAL BOX CARD
# ============================================================
get_real_width() {
    local text="$1"
    text="${text//\\[/}"
    text="${text//\\]/}"

    local plain_text
    plain_text=$(printf '%s' "$text" | sed -E $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g; s/\x1b\\][^\x07\x1b]*(\x07|\x1b\\\\)//g')

    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import sys, unicodedata
text = sys.argv[1]
w = 0
for ch in text:
    if unicodedata.combining(ch) or ch == "\ufe0f":
        continue
    code = ord(ch)
    if (0x1F300 <= code <= 0x1FAFF) or (0x2600 <= code <= 0x27BF) or (0x2300 <= code <= 0x23FF):
        w += 2
        continue
    eaw = unicodedata.east_asian_width(ch)
    w += 2 if eaw in ("W", "F") else 1
print(w)
' "$plain_text" 2>/dev/null || echo "${#plain_text}"
    else
        echo "${#plain_text}"
    fi
}

_w() {
    get_real_width "$@"
}

box_card() {
    # Usage: box_card [--border <color_code>] "line1" "---" "line2" ...
    #        or via pipe: printf "%s\n" "..." | box_card
    local border_color="240"
    local lines=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --border|-b)
                border_color="$2"
                shift 2
                ;;
            *)
                lines+=("$1")
                shift
                ;;
        esac
    done

    # Read from stdin if no lines provided as arguments
    if [[ ${#lines[@]} -eq 0 ]]; then
        while IFS= read -r line; do
            lines+=("$line")
        done
    fi

    [[ ${#lines[@]} -eq 0 ]] && return 0

    if command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "${lines[@]}" | python3 -c '
import sys, re, unicodedata

def real_width(s):
    plain = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)", "", s)
    plain = plain.replace("\\[", "").replace("\\]", "")
    w = 0
    for ch in plain:
        if unicodedata.combining(ch) or ch == "\ufe0f":
            continue
        code = ord(ch)
        if (0x1F300 <= code <= 0x1FAFF) or (0x2600 <= code <= 0x27BF) or (0x2300 <= code <= 0x23FF):
            w += 2
        elif unicodedata.east_asian_width(ch) in ("W", "F"):
            w += 2
        else:
            w += 1
    return w

lines = sys.stdin.read().splitlines()
border_c = sys.argv[1] if len(sys.argv) > 1 else "240"
bc = f"\033[38;5;{border_c}m"
rst = "\033[0m"

widths = [real_width(line) if line != "---" else 0 for line in lines]
max_w = max(widths) if widths else 40
max_w = max(max_w, 32)

div = "─" * (max_w + 2)
print(f"{bc}╭{div}╮{rst}")
for line, w in zip(lines, widths):
    if line == "---":
        print(f"{bc}├{div}┤{rst}")
    else:
        pad = max_w - w
        sp = " " * pad
        print(f"{bc}│{rst} {line}{sp} {bc}│{rst}")
print(f"{bc}╰{div}╯{rst}")
' "$border_color"
    else
        # Fallback without python
        local max_w=46
        local div
        div="$(draw_ "─" "$((max_w + 2))")"
        cn "$border_color" "╭${div}╮"
        for l in "${lines[@]}"; do
            if [[ "$l" == "---" ]]; then
                cn "$border_color" "├${div}┤"
            else
                printf "%s │\n" "$(cn "$border_color" "│") $l"
            fi
        done
        cn "$border_color" "╰${div}╯"
    fi
}


