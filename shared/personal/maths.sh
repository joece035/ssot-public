#!/usr/bin/env bash
# ------------------------------------------------------------
# File: maths.sh (Standalone Version)
# Repository: https://github.com/joece035/maths-helper
# ------------------------------------------------------------
# ============================================================
# mth — Excel-style Maths Helper (human-friendly)
#   (alias: calc, math — type whichever feels natural)
# ============================================================
# Usage:
#   mth <expression> [decimals] [mode]
#
# Expression accepts Excel-style:
#   mth 10/3                       → 3.33              (infix)
#   mth sqrt(5^2+10^2)             → 11.18             (function call)
#   mth POW(2,10)                  → 1024              (comma args)
#   mth SUM 10 20 30               → 60                (space args)
#   mth AVG 10 20 30 2             → 20.00             (scale suffix)
#   mth 10/3 0 d                   → 3                 (down)
#   mth 10/3 4                     → 3.3333            (scale, default round)
#   mth "45/(3*(5+10))"            → 1.00              (nested parens)
#   mth "100/(3*((30-70)/40))" 5 d → -33.33333         (scale+mode with parens)
#   mth if(100>50, "yes", "no")    → yes               (Excel IF)
#   mth pi() * 2                   → 6.28              (constant)
#   mth SQRT(144) + 2^3            → 20                (mixed)
#
# Functions (case-insensitive): SUM, AVG, MIN, MAX, ABS, INT,
#   ROUND(expr,digits)    — round half-up to N decimals
#   ROUNDUP(expr,digits)  — always round away from zero (Excel ROUNDUP)
#   ROUNDDOWN(expr,digits)— always round toward zero   (Excel ROUNDDOWN)
#   CEIL, FLOOR, POW, SQRT, MOD, IF,
#   SIN, COS, TAN, ASIN, ACOS, ATAN, LOG, LN, EXP, PI, E
#
# ── Degree-friendly Trig (Non-IT Friendly) ──────────────────
#   sind(30)   cosd(60)   tand(45)   → input in DEGREES, output numeric
#   asind(0.5) acosd(1)   atand(1)   → output in DEGREES
#   sin(30deg) cos(45°)   tan(1.57rad) → unit suffix syntax
#
# Smart Hint: if you type sin(30) or cos(45) with large angles,
#   mth prints a yellow warning suggesting sind(30) or sin(30deg)
#
# Operators: + - * / ^ %  (^ = power, % = mod; ** also accepted)
# ============================================================

mth() {
    [[ $# -eq 0 || -z "$*" ]] && {
        cat <<'EOF' >&2
mth — Excel-style Maths Helper (alias: calc, math)
Usage: mth <expression> [decimals] [mode]
       mode: r|round (default) | u|up | d|down
Examples:
  mth 10/3                 # 3.33
  mth sqrt(5^2+10^2)       # 11.18
  mth SUM(10,20,30)        # 60     (Excel-style: comma-separated)
  mth POW(2,10)            # 1024
  mth if(100>50,"y","n")   # y

Trigonometry (Degree-friendly — Non-IT safe):
  mth sind(30)             # 0.50   (sin ของ 30 องศา)
  mth cosd(60)             # 0.50   (cos ของ 60 องศา)
  mth tand(45)             # 1.00   (tan ของ 45 องศา)
  mth asind(0.5)           # 30.00  (arc sin → ผลลัพธ์เป็นองศา)
  mth "sin(30deg)"         # 0.50   (unit suffix syntax)
  mth "cos(45°)"           # 0.71   (Unicode degree symbol)

💡 TIP: sind/cosd/tand รับ-ส่งเป็นองศา ปลอดภัยสำหรับงานวิศวกรรม
        sin/cos/tan แบบปกติใช้หน่วย Radian (สำหรับคนที่รู้อยู่แล้ว)
EOF
        return 1
    }

    local scale="${MATH_DEFAULT_SCALE:-2}"
    local mode="${MATH_DEFAULT_MODE:-round}"

    # ── Lead-arg parsing: optional [scale] [mode] at the front ──
    if [[ $# -ge 2 ]] && [[ "$1" =~ ^[0-9]+$ ]]; then
        scale="$1"; shift
        case "${1:-}" in
            u|up|roundup|ceil)            mode="up";    shift ;;
            d|down|rounddown|floor|trunc) mode="down";  shift ;;
            r|round)                      mode="round"; shift ;;
        esac
    fi

    # ── Tail-arg parsing: peel off optional [scale] [mode] from the end ──
    local raw="$*"
    raw="$(echo "$raw" | sed 's/  */ /g; s/^ //; s/ $//')"

    _mth_peel() {
        local s="$1"
        local last="${s##* }"
        local rest="${s% *}"
        local prev=""
        [[ "$rest" != "$s" ]] && prev="${rest##* }"
        local peeled=0 new_s="$s" out_scale="" out_mode=""

        _mth_norm_mode() {
            case "$1" in
                u|up|roundup|ceil)            echo "up" ;;
                d|down|rounddown|floor|trunc) echo "down" ;;
                r|round)                      echo "round" ;;
                *)                            echo "$1" ;;
            esac
        }

        # Pattern A: ... <int> <mode-keyword>
        if [[ "$last" =~ ^(u|up|roundup|ceil|d|down|rounddown|floor|trunc|r|round)$ ]] \
           && [[ "$prev" =~ ^[0-9]+$ ]]; then
            out_scale="$prev"; out_mode="$(_mth_norm_mode "$last")"
            new_s="${rest% *}"
            peeled=1
        # Pattern B: ... <mode-keyword> <int>
        elif [[ "$last" =~ ^[0-9]+$ ]] \
           && [[ "$prev" =~ ^(u|up|roundup|ceil|d|down|rounddown|floor|trunc|r|round)$ ]]; then
            out_mode="$(_mth_norm_mode "$prev")"; out_scale="$last"
            new_s="${rest% *}"
            peeled=1
        # Pattern C: ... <int> only  (scale only)
        elif [[ "$last" =~ ^[0-9]+$ ]] && \
             { [[ "$prev" =~ ^[0-9].* ]] || [[ "$prev" == ")"* ]]; }; then
            out_scale="$last"
            new_s="$rest"
            peeled=1
        # Pattern D: ... <mode-keyword> only
        elif [[ "$last" =~ ^(u|up|roundup|ceil|d|down|rounddown|floor|trunc|r|round)$ ]]; then
            out_mode="$(_mth_norm_mode "$last")"
            new_s="$rest"
            peeled=1
        fi

        if (( peeled )); then
            printf '%s|%s|%s\n' "$new_s" "$out_scale" "$out_mode"
            return 0
        fi
        return 1
    }

    local peeled_result
    if peeled_result="$(_mth_peel "$raw")"; then
        local _rest="${peeled_result#*|}"
        local _pscale="${_rest%|*}"
        local _pmode="${_rest##*|}"
        raw="${peeled_result%%|*}"
        [[ -n "$_pscale" ]] && scale="$_pscale"
        [[ -n "$_pmode" ]]  && mode="$_pmode"
        if peeled_result="$(_mth_peel "$raw")"; then
            _rest="${peeled_result#*|}"
            _pscale="${_rest%|*}"
            _pmode="${_rest##*|}"
            raw="${peeled_result%%|*}"
            [[ -n "$_pscale" ]] && scale="$_pscale"
            [[ -n "$_pmode" ]]  && mode="$_pmode"
        fi
    fi

    local expr="$raw"

    # 1. Normalize operators: ** → ^ (Excel uses ^)
    expr="${expr//\*\*/^}"

    # 2. Lowercase ONLY outside of double-quoted strings
    expr="$(awk 'BEGIN{inq=0; out=""}
        {
            for (i=1; i<=length($0); i++) {
                c = substr($0,i,1)
                if (c == "\"") { inq = !inq; out = out c }
                else if (inq) { out = out c }
                else { out = out tolower(c) }
            }
        }
        END { print out }' <<< "$expr")"

    # 3. Convert Excel constants: pi() → 3.14159..., e() → 2.71828...
    expr="${expr//pi()/3.14159265358979}"
    expr="${expr//e()/2.71828182845905}"

    # ── 4. Degree Unit Suffix: convert 30deg / 30° / 30rad ──────────
    # Matches: <number>deg, <number>°, <number>rad (case-insensitive)
    # Replace NUMBERdeg → (NUMBER*3.14159265358979/180)
    # Replace NUMBER°   → (NUMBER*3.14159265358979/180)
    # Replace NUMBERrad → NUMBER  (explicit rad is already radian)
    expr="$(echo "$expr" | sed \
        -e 's/\([0-9][0-9.]*\)deg/\(\1*3.14159265358979\/180\)/gI' \
        -e 's/\([0-9][0-9.]*\)°/\(\1*3.14159265358979\/180\)/g' \
        -e 's/\([0-9][0-9.]*\)rad/\1/gI')"

    # ── 5. Degree Family Functions: expand sind/cosd/tand/asind/acosd/atand ──
    # sind(X)  → sin(X*pi/180)   — accepts degrees, returns numeric
    # cosd(X)  → cos(X*pi/180)
    # tand(X)  → tan(X*pi/180)
    # asind(X) → asin(X)*180/pi  — returns degrees
    # acosd(X) → acos(X)*180/pi
    # atand(X) → atan(X)*180/pi
    # Note: We use placeholder token __PI__ to avoid double-expanding pi()
    local PI_VAL="3.14159265358979"
    expr="$(echo "$expr" | sed \
        -e "s/\bsind(/__SIND(/gI" \
        -e "s/\bcosd(/__COSD(/gI" \
        -e "s/\btand(/__TAND(/gI" \
        -e "s/\basind(/__ASIND(/gI" \
        -e "s/\bacosd(/__ACOSD(/gI" \
        -e "s/\batand(/__ATAND(/gI")"
    # Expand degree-family placeholders (awk will see these as normal FN names)
    # We map them to awk FN tokens via the FN handler in awk below.
    # Restore names so awk can identify them:
    expr="$(echo "$expr" | sed \
        -e 's/__SIND/sind/g' \
        -e 's/__COSD/cosd/g' \
        -e 's/__TAND/tand/g' \
        -e 's/__ASIND/asind/g' \
        -e 's/__ACOSD/acosd/g' \
        -e 's/__ATAND/atand/g')"

    # ── 6. Smart Hint: detect sin/cos/tan(N) where N looks like degrees ──
    # If N > 2*pi (~6.28) user almost certainly meant degrees, not radians.
    # We print a warning AFTER computing (non-blocking), captured in __hint__.
    local _hint_expr="$expr"
    local _smart_hint=""
    # Extract first trig call argument for heuristic check
    local _trig_match
    _trig_match="$(echo "$_hint_expr" | grep -oP '(?<=\b(?:sin|cos|tan)\()[^)]+' | head -1 2>/dev/null || true)"
    if [[ -n "$_trig_match" ]]; then
        # Evaluate the argument numerically to check if > 2*pi
        local _ang
        _ang="$(echo "$_trig_match" | awk '{v=$1+0; printf "%.4f", v}' 2>/dev/null || true)"
        if [[ -n "$_ang" ]] && awk "BEGIN{exit !($_ang+0 > 6.2832)}" 2>/dev/null; then
            local _deg_result
            _deg_result="$(echo "$_trig_match" | awk '{v=$1+0; printf "%.4f", v*3.14159265358979/180}' 2>/dev/null || true)"
            _smart_hint="\033[1;33m💡 Tip: sin/cos/tan ใช้หน่วย Radian — ถ้าต้องการมุม ${_trig_match} องศา ให้ใช้ sind/cosd/tand แทนครับ\033[0m"
        fi
    fi

    local awk_out
    awk_out="$(awk -v expr="$expr" -v scale="$scale" -v mode="$mode" '
    BEGIN {
        s = expr
        n = 0; i = 1; L = length(s)

        while (i <= L) {
            c = substr(s, i, 1)
            if (c == " " || c == "\t") { i++; continue }

            if (c == "\"") {
                j = i + 1; str = ""
                while (j <= L && substr(s, j, 1) != "\"") { str = str substr(s, j, 1); j++ }
                tok[++n] = "STR:" str
                i = j + 1; continue
            }

            if (c ~ /[0-9.]/ && (i == 1 || substr(s, i-1, 1) !~ /[a-zA-Z0-9_]/)) {
                j = i
                while (j <= L && substr(s, j, 1) ~ /[0-9.]/) j++
                if (j <= L && substr(s, j, 1) == "e" && j < L && substr(s, j+1, 1) ~ /[0-9+-]/) {
                    j++
                    if (j <= L && (substr(s, j, 1) == "+" || substr(s, j, 1) == "-")) j++
                    while (j <= L && substr(s, j, 1) ~ /[0-9]/) j++
                }
                tok[++n] = "NUM:" substr(s, i, j-i)
                i = j; continue
            }

            if (c ~ /[a-zA-Z_]/) {
                j = i
                while (j <= L && substr(s, j, 1) ~ /[a-zA-Z0-9_]/) j++
                name = substr(s, i, j-i)
                k = j
                while (k <= L && substr(s, k, 1) == " ") k++
                if (k <= L && substr(s, k, 1) == "(") {
                    tok[++n] = "FN:" name
                    depth = 1; m = k + 1; commas = 0
                    while (m <= L && depth > 0) {
                        ch = substr(s, m, 1)
                        if (ch == "(") depth++
                        else if (ch == ")") { depth--; if (depth == 0) break }
                        else if (ch == "," && depth == 1) commas++
                        m++
                    }
                    argcount[n] = commas + 1
                } else {
                    tok[++n] = "ERR:unknown identifier " name
                }
                i = j; continue
            }

            if (c == "(") { tok[++n] = "LP"; i++; continue }
            if (c == ")") { tok[++n] = "RP"; i++; continue }
            if (c == ",") { tok[++n] = "COMMA"; i++; continue }

            if (i < L) {
                c2 = substr(s, i, 2)
                if (c2 == ">=") { tok[++n] = "OP:>="; i+=2; continue }
                if (c2 == "<=") { tok[++n] = "OP:<="; i+=2; continue }
                if (c2 == "==") { tok[++n] = "OP:=="; i+=2; continue }
                if (c2 == "!=") { tok[++n] = "OP:!="; i+=2; continue }
            }
            if (c == ">" ) { tok[++n] = "OP:>";  i++; continue }
            if (c == "<" ) { tok[++n] = "OP:<";  i++; continue }
            if (c == "=" ) { tok[++n] = "OP:=="; i++; continue }
            if (c == "+" ) { tok[++n] = "OP:+";  i++; continue }
            if (c == "-" ) { tok[++n] = "OP:-";  i++; continue }
            if (c == "*" ) { tok[++n] = "OP:*";  i++; continue }
            if (c == "/" ) { tok[++n] = "OP:/";  i++; continue }
            if (c == "^" ) { tok[++n] = "OP:^";  i++; continue }
            if (c == "%" ) { tok[++n] = "OP:%";  i++; continue }

            tok[++n] = "ERR:bad char [" c "]"; i++
        }

        op_top = 0
        prev_tok = ""
        for (t = 1; t <= n; t++) {
            tt = tok[t]
            if (substr(tt, 1, 4) == "ERR:") {
                print tt > "/dev/stderr"; exit 1
            }
            if (substr(tt, 1, 4) == "NUM:" || substr(tt, 1, 4) == "STR:") {
                rpn[++rn] = tt
            } else if (substr(tt, 1, 3) == "FN:") {
                op[++op_top] = tt
                rpn_argc[op_top] = argcount[t]
            } else if (tt == "COMMA") {
                while (op_top > 0 && op[op_top] != "LP") rpn[++rn] = op[op_top--]
            } else if (tt == "LP") {
                op[++op_top] = tt
            } else if (tt == "RP") {
                while (op_top > 0 && op[op_top] != "LP") rpn[++rn] = op[op_top--]
                if (op_top > 0 && op[op_top] == "LP") op_top--
                if (op_top > 0 && substr(op[op_top], 1, 3) == "FN:") {
                    rpn_argc[rn+1] = rpn_argc[op_top]
                    rpn[++rn] = op[op_top--]
                }
            } else if (tt == "OP:-" || tt == "OP:+") {
                is_unary = (prev_tok == "" || substr(prev_tok, 1, 3) == "OP:" || prev_tok == "LP" || prev_tok == "COMMA")
                if (is_unary && tt == "OP:-") {
                    op[++op_top] = "UNEG"
                } else if (is_unary && tt == "OP:+") {
                    # Unary plus → no-op
                } else {
                    prec = 2; rassoc = 0
                    while (op_top > 0 && op[op_top] != "LP" && substr(op[op_top], 1, 3) == "OP:") {
                        top_prec = 0; topc = substr(op[op_top], 4)
                        if (topc == "^") top_prec = 4
                        else if (op[op_top] == "UNEG") top_prec = 5
                        else if (topc == "*" || topc == "/" || topc == "%") top_prec = 3
                        else if (topc == "+" || topc == "-") top_prec = 2
                        else top_prec = 1
                        if (top_prec > prec || (top_prec == prec && !rassoc)) rpn[++rn] = op[op_top--]
                        else break
                    }
                    op[++op_top] = tt
                }
            } else if (substr(tt, 1, 3) == "OP:") {
                prec = 0; rassoc = 0; opc = substr(tt, 4)
                if (opc == "^") { prec = 4; rassoc = 1 }
                else if (opc == "*" || opc == "/" || opc == "%") prec = 3
                else if (opc == "+" || opc == "-") prec = 2
                else prec = 1
                while (op_top > 0 && op[op_top] != "LP" && substr(op[op_top], 1, 3) == "OP:") {
                    top_prec = 0; topc = substr(op[op_top], 4)
                    if (op[op_top] == "UNEG") top_prec = 5
                    else if (topc == "^") top_prec = 4
                    else if (topc == "*" || topc == "/" || topc == "%") top_prec = 3
                    else if (topc == "+" || topc == "-") top_prec = 2
                    else top_prec = 1
                    if (top_prec > prec || (top_prec == prec && !rassoc)) rpn[++rn] = op[op_top--]
                    else break
                }
                op[++op_top] = tt
            }
            prev_tok = tt
        }
        while (op_top > 0) rpn[++rn] = op[op_top--]

        for (t = 1; t <= rn; t++) {
            tt = rpn[t]
            if (substr(tt, 1, 4) == "NUM:") { st[++sp] = substr(tt, 5) + 0; sttype[sp] = "n" }
            else if (substr(tt, 1, 4) == "STR:") { st[++sp] = substr(tt, 5); sttype[sp] = "s" }
            else if (tt == "UNEG") { v = st[sp--]; st[++sp] = -v; sttype[sp] = "n" }
            else if (substr(tt, 1, 3) == "OP:") {
                opc = substr(tt, 4); b = st[sp--]; a = st[sp--]; bt = sttype[sp+1]; at = sttype[sp]
                if (opc == "+") { st[++sp] = a + b; sttype[sp] = "n" }
                else if (opc == "-") { st[++sp] = a - b; sttype[sp] = "n" }
                else if (opc == "*") { st[++sp] = a * b; sttype[sp] = "n" }
                else if (opc == "/") { st[++sp] = (b == 0 ? 0 : a / b); sttype[sp] = "n" }
                else if (opc == "^") { v = (a<0&&int(b)!=b)?0:(a==0&&b<0)?0:a^b; st[++sp]=v; sttype[sp]="n" }
                else if (opc == "%") { st[++sp] = (b == 0 ? 0 : a - int(a/b) * b); sttype[sp] = "n" }
                else if (opc == ">")  { st[++sp] = (a >  b ? 1 : 0); sttype[sp] = "n" }
                else if (opc == "<")  { st[++sp] = (a <  b ? 1 : 0); sttype[sp] = "n" }
                else if (opc == ">=") { st[++sp] = (a >= b ? 1 : 0); sttype[sp] = "n" }
                else if (opc == "<=") { st[++sp] = (a <= b ? 1 : 0); sttype[sp] = "n" }
                else if (opc == "==") { st[++sp] = (a == b ? 1 : 0); sttype[sp] = "n" }
                else if (opc == "!=") { st[++sp] = (a != b ? 1 : 0); sttype[sp] = "n" }
            } else if (substr(tt, 1, 3) == "FN:") {
                fn = substr(tt, 4)
                if (fn == "sqrt")  { v = st[sp--]; st[++sp] = sqrt(v); sttype[sp] = "n" }
                else if (fn == "abs")   { v = st[sp--]; st[++sp] = (v < 0 ? -v : v); sttype[sp] = "n" }
                else if (fn == "int")   { v = st[sp--]; st[++sp] = int(v); sttype[sp] = "n" }
                else if (fn == "round") {
                    argc = rpn_argc[t]; if (argc == 0) argc = 1
                    if (argc >= 2) {
                        d = int(st[sp--]); v = st[sp--]
                        m = 10^(d<0?0:d); sgn=(v>=0?1:-1); av=(v>=0?v:-v)*m
                        st[++sp] = sgn * int(av+0.5) / m; sttype[sp] = "n"
                    } else {
                        v = st[sp--]; st[++sp] = (v < 0 ? -int(-v+0.5) : int(v+0.5)); sttype[sp] = "n"
                    }
                }
                else if (fn == "roundup") {
                    argc = rpn_argc[t]; if (argc == 0) argc = 1
                    if (argc >= 2) {
                        d = int(st[sp--]); v = st[sp--]
                        m = 10^(d<0?0:d); sgn=(v>=0?1:-1); av=(v>=0?v:-v)*m; iv=int(av)
                        st[++sp] = sgn * (av > iv ? iv+1 : iv) / m; sttype[sp] = "n"
                    } else {
                        v = st[sp--]; iv=int(v>=0?v:-v); sgn=(v>=0?1:-1)
                        st[++sp] = sgn*(v!=int(v)?iv+1:iv); sttype[sp] = "n"
                    }
                }
                else if (fn == "rounddown") {
                    argc = rpn_argc[t]; if (argc == 0) argc = 1
                    if (argc >= 2) {
                        d = int(st[sp--]); v = st[sp--]
                        m = 10^(d<0?0:d); sgn=(v>=0?1:-1); av=(v>=0?v:-v)*m
                        st[++sp] = sgn * int(av) / m; sttype[sp] = "n"
                    } else {
                        v = st[sp--]; st[++sp] = int(v); sttype[sp] = "n"
                    }
                }
                else if (fn == "ceil")  { v = st[sp--]; st[++sp] = (v == int(v) ? v : (v > 0 ? int(v)+1 : int(v))); sttype[sp] = "n" }
                else if (fn == "floor") { v = st[sp--]; st[++sp] = (v < 0 && v != int(v) ? int(v)-1 : int(v)); sttype[sp] = "n" }
                else if (fn == "sin")   { v = st[sp--]; st[++sp] = sin(v); sttype[sp] = "n" }
                else if (fn == "cos")   { v = st[sp--]; st[++sp] = cos(v); sttype[sp] = "n" }
                else if (fn == "tan")   { v = st[sp--]; st[++sp] = sin(v)/cos(v); sttype[sp] = "n" }
                else if (fn == "asin")  { v = st[sp--]; st[++sp] = atan2(v, sqrt(1-v*v)); sttype[sp] = "n" }
                else if (fn == "acos")  { v = st[sp--]; st[++sp] = atan2(sqrt(1-v*v), v); sttype[sp] = "n" }
                else if (fn == "atan")  { v = st[sp--]; st[++sp] = atan2(v, 1); sttype[sp] = "n" }
                # ── Degree-family: sind/cosd/tand → accept degrees, numeric out ──
                else if (fn == "sind")  { v = st[sp--]; r=v*3.14159265358979/180; st[++sp] = sin(r); sttype[sp] = "n" }
                else if (fn == "cosd")  { v = st[sp--]; r=v*3.14159265358979/180; st[++sp] = cos(r); sttype[sp] = "n" }
                else if (fn == "tand")  { v = st[sp--]; r=v*3.14159265358979/180; st[++sp] = sin(r)/cos(r); sttype[sp] = "n" }
                # ── Arc degree-family: asind/acosd/atand → accept numeric, output degrees ──
                else if (fn == "asind") { v = st[sp--]; st[++sp] = atan2(v, sqrt(1-v*v))*180/3.14159265358979; sttype[sp] = "n" }
                else if (fn == "acosd") { v = st[sp--]; st[++sp] = atan2(sqrt(1-v*v), v)*180/3.14159265358979; sttype[sp] = "n" }
                else if (fn == "atand") { v = st[sp--]; st[++sp] = atan2(v, 1)*180/3.14159265358979; sttype[sp] = "n" }
                else if (fn == "ln")    { v = st[sp--]; st[++sp] = log(v); sttype[sp] = "n" }
                else if (fn == "exp")   { v = st[sp--]; st[++sp] = exp(v); sttype[sp] = "n" }
                else if (fn == "log")   { base = st[sp--]; x = st[sp--]; st[++sp] = (base<=0||base==1||x<=0) ? 0 : log(x)/log(base); sttype[sp] = "n" }
                else if (fn == "pow")   { b = st[sp--]; a = st[sp--]; st[++sp] = (a<0&&int(b)!=b) ? 0 : (a==0&&b<0) ? 0 : a^b; sttype[sp] = "n" }
                else if (fn == "mod")   { b = st[sp--]; a = st[sp--]; st[++sp] = (b==0) ? 0 : a - int(a/b)*b; sttype[sp] = "n" }
                else if (fn == "if")    {
                    c = st[sp--]; b = st[sp--]; a = st[sp--]
                    at = sttype[sp+1]; bt = sttype[sp+2]; ct = sttype[sp+3]
                    st[++sp] = (a != 0) ? b : c
                    sttype[sp] = (a != 0) ? bt : ct
                }
                else if (fn == "sum") {
                    argc = rpn_argc[t]; if (argc == 0) argc = 1
                    s2 = 0; for (k = 1; k <= argc; k++) s2 += st[sp--]
                    st[++sp] = s2; sttype[sp] = "n"
                }
                else if (fn == "avg") {
                    argc = rpn_argc[t]; if (argc == 0) argc = 1
                    s2 = 0; for (k = 1; k <= argc; k++) s2 += st[sp--]
                    st[++sp] = s2 / argc; sttype[sp] = "n"
                }
                else if (fn == "min") {
                    argc = rpn_argc[t]; if (argc == 0) argc = 1
                    mn = st[sp--]
                    for (k = 2; k <= argc; k++) { v = st[sp--]; if (v < mn) mn = v }
                    st[++sp] = mn; sttype[sp] = "n"
                }
                else if (fn == "max") {
                    argc = rpn_argc[t]; if (argc == 0) argc = 1
                    mx = st[sp--]
                    for (k = 2; k <= argc; k++) { v = st[sp--]; if (v > mx) mx = v }
                    st[++sp] = mx; sttype[sp] = "n"
                }
                else { st[++sp] = 0; sttype[sp] = "n" }
            } else if (substr(tt, 1, 4) == "ERR:") {
                print tt > "/dev/stderr"; exit 1
            }
        }

        if (sttype[sp] == "s") {
            print st[sp]
        } else {
            val = st[sp]
            mult = 10 ^ scale
            sgn = (val >= 0 ? 1 : -1)
            av  = (val >= 0 ? val : -val) * mult
            iv  = int(av)
            if (mode == "up")        res = sgn * (av > iv ? iv + 1 : iv) / mult
            else if (mode == "down") res = sgn * iv / mult
            else if (mode == "round") res = sgn * int(av + 0.5) / mult
            else res = sgn * iv / mult

            printf "%.*f\n", scale, res
        }
    }
    ' </dev/null)"

    local rc=$?
    if (( rc != 0 )); then
        echo "mth: parse error in expression: $expr" >&2
        return 1
    fi
    printf '%s\n' "$awk_out"
    # Print smart hint AFTER the result (non-blocking, to stderr so it doesn't pollute pipes)
    [[ -n "$_smart_hint" ]] && printf "${_smart_hint}\n" >&2
}

# Friendly aliases
bc_()   { mth "$@"; }
math()  { mth "$@"; }
calc()  { mth "$@"; }

# ── Standalone Dependency Helper (Zero SSOT requirement) ────
_maths_helper_ensure_python() {
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
    elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info[0]>=3 else 1)' 2>/dev/null; then
        PYTHON_CMD="python"
    else
        echo "slv: python3 is required. Attempting installation..." >&2
        if command -v apt-get >/dev/null 2>&1; then
            if [[ $EUID -eq 0 ]]; then
                apt-get update -qq && apt-get install -y python3 python3-pip python3-sympy
            elif command -v sudo >/dev/null 2>&1; then
                sudo apt-get update -qq && sudo apt-get install -y python3 python3-pip python3-sympy
            fi
        elif command -v pkg >/dev/null 2>&1; then
            pkg install -y python python-pip python-sympy
        elif command -v brew >/dev/null 2>&1; then
            brew install python
        else
            echo "slv: error: please install Python 3 manually." >&2
            return 1
        fi
        PYTHON_CMD="python3"
    fi

    # Ensure sympy is installed
    if ! "$PYTHON_CMD" -c "import sympy" 2>/dev/null; then
        echo "slv: sympy not found. Installing sympy..." >&2
        if "$PYTHON_CMD" -m pip --version >/dev/null 2>&1; then
            "$PYTHON_CMD" -m pip install --quiet sympy 2>/dev/null || \
            "$PYTHON_CMD" -m pip install --quiet --break-system-packages sympy 2>/dev/null || true
        elif command -v apt-get >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
            sudo apt-get update -qq && sudo apt-get install -y python3-sympy
        fi

        if ! "$PYTHON_CMD" -c "import sympy" 2>/dev/null; then
            echo "slv: failed to auto-install sympy. Please run: pip install sympy" >&2
            return 1
        fi
    fi
    return 0
}

# ============================================================
# slv — Algebraic Equation Solver (symbolic + numeric)
#   (alias: solve — type whichever feels natural)
# ============================================================
slv() {
    local -a clean_args=()
    local deg_mode="0"
    for arg in "$@"; do
        case "$arg" in
            -d|--deg|--degree) deg_mode="1" ;;
            *) clean_args+=("$arg") ;;
        esac
    done

    [[ ${#clean_args[@]} -eq 0 ]] && {
        cat <<'EOF' >&2
slv — Algebraic Equation Solver (alias: solve)
Usage: slv [--deg|-d] <equation> [var=value] ...

Options:
  -d, --deg, --degree   Use degrees for trigonometric functions (default: radians)

Examples:
  slv "x=2x+y" "y=2"                # x=-2  y=2
  slv --deg "h=a*sin(b)" a=10 b=30  # h=5   (sin(30°) = 0.5)
  slv "2x=2y"                       # x=y   (symbolic)
  slv "a^2+b^2=c^2" "a=3" "b=4"     # c=5
  slv "F=m*a" "m=10" "a=9.8"        # F=98
EOF
        return 1
    }

    local PYTHON_CMD="python3"
    _maths_helper_ensure_python || return 1

    local eq="${clean_args[0]}"
    local -a knowns=("${clean_args[@]:1}")

    "$PYTHON_CMD" - "$deg_mode" "$eq" "${knowns[@]}" <<'PYEOF'
import sys, re
from sympy import (symbols, Eq, solve, simplify, sympify,
                   sqrt, Rational, pi, E as euler, zoo, oo, nan,
                   sin, cos, tan, asin, acos, atan, sinh, cosh, tanh,
                   exp, log, Abs, factorial, floor, ceiling, I, rad, deg)
from sympy.parsing.sympy_parser import (parse_expr,
    standard_transformations, implicit_multiplication_application,
    convert_xor)

transformations = (standard_transformations +
                   (implicit_multiplication_application, convert_xor))

deg_mode = (sys.argv[1] == "1")
eq_str   = sys.argv[2]
knowns   = sys.argv[3:]

MATH_FUNCS = {
    "sqrt": sqrt, "pi": pi, "e": euler, "E": euler,
    "sinh": sinh, "cosh": cosh, "tanh": tanh,
    "exp": exp, "log": log, "ln": log,
    "abs": Abs, "Abs": Abs,
    "factorial": factorial, "floor": floor, "ceiling": ceiling,
    "rad": rad, "deg": deg,
    "sind": lambda x: sin(rad(x)),
    "cosd": lambda x: cos(rad(x)),
    "tand": lambda x: tan(rad(x)),
    "asind": lambda x: deg(asin(x)),
    "acosd": lambda x: deg(acos(x)),
    "atand": lambda x: deg(atan(x)),
}

if deg_mode:
    MATH_FUNCS.update({
        "sin": lambda x: sin(rad(x)),
        "cos": lambda x: cos(rad(x)),
        "tan": lambda x: tan(rad(x)),
        "asin": lambda x: deg(asin(x)),
        "acos": lambda x: deg(acos(x)),
        "atan": lambda x: deg(atan(x)),
    })
else:
    MATH_FUNCS.update({
        "sin": sin, "cos": cos, "tan": tan,
        "asin": asin, "acos": acos, "atan": atan,
    })

BUILTINS = set(MATH_FUNCS.keys()) | {"int","mod","pow","min","max","sum","avg"}

raw_vars_set = set(re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*', eq_str))
raw_vars_set = {v for v in raw_vars_set if v not in BUILTINS}

for kv in knowns:
    k = kv.split("=", 1)[0].strip()
    if k and k not in BUILTINS:
        raw_vars_set.add(k)

raw_vars = sorted(raw_vars_set)
sym_map = {v: symbols(v) for v in raw_vars}

def parse(s):
    ns = dict(MATH_FUNCS)
    ns.update({str(v): v for v in sym_map.values()})
    return parse_expr(s, local_dict=ns, transformations=transformations)

subs = {}
for kv in knowns:
    if "=" not in kv:
        print(f"slv: bad known value '{kv}' (need var=value)", file=sys.stderr)
        sys.exit(1)
    k, v = kv.split("=", 1)
    k = k.strip(); v = v.strip()
    if k in sym_map:
        try:
            subs[sym_map[k]] = parse(v)
        except Exception:
            subs[sym_map[k]] = sympify(v)

if "=" not in eq_str:
    print("slv: equation must contain '='", file=sys.stderr)
    sys.exit(1)

lhs_s, rhs_s = eq_str.split("=", 1)
try:
    lhs = parse(lhs_s.strip())
    rhs = parse(rhs_s.strip())
except Exception as exc:
    print(f"slv: parse error — {exc}", file=sys.stderr)
    sys.exit(1)

equation = Eq(lhs, rhs)
equation_subst = equation.subs(subs)

if equation_subst.has(zoo) or lhs.subs(subs).has(zoo) or rhs.subs(subs).has(zoo):
    print("\n  \033[1;31mUndefined\033[0m (division by zero / singularity)\n")
    sys.exit(0)

unknowns = [sym_map[v] for v in raw_vars if sym_map[v] not in subs]

if not unknowns:
    val = simplify(lhs.subs(subs) - rhs.subs(subs))
    if val == 0:
        print("\n  \033[1;32m✓ Equation is satisfied (both sides equal).\033[0m\n")
    else:
        print(f"\n  \033[1;31m✗ Equation NOT satisfied (difference = {val}).\033[0m\n")
    sys.exit(0)

try:
    sol = solve(equation_subst, unknowns, dict=True)
except Exception as exc:
    print(f"slv: solver error — {exc}", file=sys.stderr)
    sys.exit(1)

ANSI_G  = "\033[1;32m"
ANSI_C  = "\033[1;36m"
ANSI_Y  = "\033[1;33m"
ANSI_R  = "\033[0m"

def fmt_val(v):
    try:
        if v.is_number and v.is_real:
            f = float(v)
            if f == int(f) and abs(f) < 1e15:
                return str(int(f))
            if abs(f) > 1e10 or (f != 0 and abs(f) < 1e-4):
                return f"{f:.6g}"
            return f"{f:.6g}"
    except (TypeError, ValueError, AttributeError):
        pass
    return str(simplify(v))

print()

def _prefer_positive(solutions, unknowns, subs):
    if len(solutions) <= 1:
        return solutions[0] if solutions else {}
    for candidate in solutions:
        vals = [candidate.get(sym, sym).subs(subs) for sym in unknowns]
        try:
            if all(v.is_real and float(v) > 0 for v in vals):
                return candidate
        except (TypeError, ValueError, AttributeError):
            pass
    return solutions[0]

def _symbolic_solve(lhs, rhs, unknowns, subs):
    expr = simplify(lhs - rhs)
    printed_any = False
    for unk in unknowns:
        try:
            sym_sol = solve(expr.subs(subs), unk)
            if sym_sol:
                chosen = sym_sol[0]
                chosen_str = fmt_val(chosen)
                if str(chosen) != str(unk):
                    note = f"  {ANSI_Y}(imaginary / no real solution){ANSI_R}" if chosen.has(I) else ""
                    print(f"  {ANSI_G}{unk}{ANSI_R} = {ANSI_C}{chosen_str}{ANSI_R}{note}")
                    printed_any = True
                    break
        except Exception:
            pass
    if not printed_any:
        for unk in unknowns:
            print(f"  {ANSI_G}{unk}{ANSI_R} = {ANSI_C}(no closed-form solution){ANSI_R}")

if sol:
    solution = _prefer_positive(sol, unknowns, subs)
    for sym in unknowns:
        val = solution.get(sym, sym)
        val_sub = val.subs(subs)
        if val_sub == sym and len(unknowns) > 1 and len(solution) < len(unknowns):
            continue
        s_name = str(sym)
        s_val  = fmt_val(val_sub)
        note   = f"  {ANSI_Y}(imaginary / no real solution){ANSI_R}" if val_sub.has(I) else ""
        print(f"  {ANSI_G}{s_name}{ANSI_R} = {ANSI_C}{s_val}{ANSI_R}{note}")
    for sym, val in subs.items():
        s_name = str(sym)
        s_val  = fmt_val(val)
        print(f"  {ANSI_G}{s_name}{ANSI_R} = {ANSI_C}{s_val}{ANSI_R}")
else:
    _symbolic_solve(lhs, rhs, unknowns, subs)
    for sym, val in subs.items():
        print(f"  {ANSI_G}{sym}{ANSI_R} = {ANSI_C}{fmt_val(val)}{ANSI_R}")
print()
PYEOF
}

solve() { slv "$@"; }

# ── Direct Execution Dispatcher (when run directly as a script) ─
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd_name="$(basename "$0")"
    case "$cmd_name" in
        mth|calc|math|bc_)
            mth "$@"
            ;;
        slv|solve)
            slv "$@"
            ;;
        *)
            if [[ "$1" == "mth" || "$1" == "calc" || "$1" == "math" ]]; then
                shift; mth "$@"
            elif [[ "$1" == "slv" || "$1" == "solve" ]]; then
                shift; slv "$@"
            else
                echo "Usage: $0 [mth|slv] <arguments...>" >&2
                echo "Or source this file in your ~/.bashrc" >&2
                exit 1
            fi
            ;;
    esac
fi
