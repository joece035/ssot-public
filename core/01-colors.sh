# ============================================================
# 01-colors.sh — Color Engine V3
# ============================================================

#   color 202 "text"         # 256 color number
#   color m bu "magenta bu"  # magenta + bold+underline
# ============================================================
# COLOR RENDER CORE
#   _color_render <newline> <color> [style] <text...>
#     newline : 1 = ลงท้ายด้วย \n (cn) | 0 = ไม่มี newline (c)
#   c  <color> [style] <text...>   → พิมพ์สี ไม่มี newline (ต่อ layout ได้)
#   cn <color> [style] <text...>   → พิมพ์สี + ขึ้นบรรทัดใหม่ (จบบรรทัด)
# ตัวอย่าง: c 46 b "ON "; c 226 "| "; cn 208 "WARN"
#   →  ON | WARN  (สีละท่อน ในบรรทัดเดียว)
# NOTE: ชื่อ cn (ไม่ใช่ cp) เพราะ cp ชนกับคำสั่งจริงของระบบ
# ============================================================
_color_render() {
    local nl="$1"; shift
    local input_color="${1:-""}"

    # 1. Resolve color
    local color_=""
    case "$input_color" in
        r)   color_="$R"   ;;  lr)  color_="$LR"  ;;
        g)   color_="$G"   ;;  lg)  color_="$LG"  ;;
        y)   color_="$Y"   ;;
        cr)  color_="$CR"  ;;  lcr) color_="$LCR" ;;
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
    if [[ $# -gt 0 ]]; then targets=("${@}")
    else targets=("No text provided")
    fi

    # 4. Render
    local eol="\n"
    [[ "$nl" == "0" ]] && eol=""
    for text in "${targets[@]}"; do
        if [[ "$input_color" =~ ^[0-9]+$ ]] && [[ "$input_color" -ge 0 ]] && [[ "$input_color" -le 255 ]]; then
            # 256-color path
            printf "${style}$(_c "$input_color")%s$(_r)${eol}" "$text"
        else
            # Short-name path (V2 vars)
            printf "%b" "${color_}${style}${text}$(_r)${eol}"
        fi
    done
}

# c  — พิมพ์สี ไม่มี newline (ตัวหลัก — ต่อสีในบรรทัดเดียวได้)
c() { _color_render 0 "$@"; }

# cn — พิมพ์สี + ขึ้นบรรทัดใหม่ (ตัวปิดท้ายบรรทัด)
cn() { _color_render 1 "$@"; }

# color — ชื่อเต็ม (legacy = มี newline เหมือนเดิม, ใช้ใน color_comparison/c256_/rainbo)
color() { _color_render 1 "$@"; }

# ============================================================
# ESCAPE HELPERS (V3 — เขียนสั้น ใช้ซ้ำ เปลี่ยนแค่เลข)
#   _c <num>   = สี 256  (พิมพ์ต่อเนื่อง ไม่มี newline)
#   _r         = reset
#   _b  _d  _i  _u  = bold / dim / italic / underline
# ตัวอย่าง: echo -e "$(_c 208)$(_b)text$(_r)"
# ============================================================
_c() { printf '\e[38;5;%sm' "$1"; }   # color 256
_r() { printf '\e[0m'; }                # reset
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
# RANDOM COLOR PALETTES (V2 — kept, used by Joe's prompts)
# ============================================================
_rc_core() {
    [[ -n "${ZSH_VERSION:-}" ]] && emulate -L sh
    local palette=($1)

    local test_arr=(x)
    local offset=0
    if [[ "${test_arr[0]}" != "x" ]]; then offset=1; fi

    local state_dir="/tmp"
    [[ ! -d "$state_dir" || ! -w "$state_dir" ]] && state_dir="$HOME"
    local state_file="$state_dir/.rc_last_color_$$"
    local last_color_num=""
    local seed_counter=0

    if [[ -f "$state_file" ]]; then
        { read -r last_color_num; read -r seed_counter; } < "$state_file" 2>/dev/null
    fi

    if [[ ! "$seed_counter" =~ ^[0-9]+$ ]]; then
        local initial_seed
        initial_seed=$(date +%s%N 2>/dev/null | tr -dc '0-9' | tail -c 5)
        seed_counter=$(( 10#${initial_seed:-$$} ))
    else
        seed_counter=$(( seed_counter + 1 ))
    fi
    RANDOM=$seed_counter

    local avail=() c
    for c in "${palette[@]}"; do
        [[ "$c" != "$last_color_num" ]] && avail+=("$c")
    done
    [[ ${#avail[@]} -eq 0 ]] && avail=("${palette[@]}")

    local total=${#avail[@]}
    local ri=$(( RANDOM % total ))
    local sc_idx=$(( ri + offset ))
    local selected="${avail[$sc_idx]}"

    printf "%s\n%s\n" "$selected" "$seed_counter" > "$state_file" 2>/dev/null
    _c "$selected"
}

_rc_render() {
    local palette_str="$1"; shift
    local input_style=""

    if [[ $# -eq 0 ]]; then
        :
    elif [[ -z "$1" ]] || [[ "$1" =~ ^[bdiu]{1,4}$ ]]; then
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

    local sc
    sc=$(_rc_core "$palette_str")

    local targets=()
    if [[ $# -gt 0 ]]; then
        targets=("${@}")
    else
        targets=("No text provided")
    fi

    for text in "${targets[@]}"; do
        echo -e "${sc}${style}${text}$(_r)"
    done
}

# rc — Vibrant rainbow (12 colors)
rc() {
    local palette="45 82 190 196 208 201 39 226 129 48 203 141"
    _rc_render "$palette" "$@"
}

# rc1 — Pastel/earthy (12 colors)
rc1() {
    local palette="167 173 136 71 68 105 132 178 150 139 174 180"
    _rc_render "$palette" "$@"
}

# rc2 — Bold/neon (10 colors)
rc2() {
    local palette="21 10 196 200 225 27 202 123 229 205"
    _rc_render "$palette" "$@"
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

c256_() {
    local i
    for i in {0..255}; do
        local block=$(cmp2 "$i")
        printf "%s code = %s\n" "$block" "$i"
        (( (i+1)%16==0 )) && echo
    done
}

# --error
_er(){
 cn lr b "$@ ⛔"
}

 # --successfully
_sc(){
 	cn lg b "$@ ✅"
 }

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
