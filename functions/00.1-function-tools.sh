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
#   mth if(100>50, "yes", "no")    → yes               (Excel IF)
#   mth pi() * 2                   → 6.28              (constant)
#   mth SQRT(144) + 2^3            → 20                (mixed)
#
# Functions (case-insensitive): SUM, AVG, MIN, MAX, ABS, INT, ROUND,
#   ROUNDUP, ROUNDDOWN, CEIL, FLOOR, POW, SQRT, MOD, IF,
#   SIN, COS, TAN, ASIN, ACOS, ATAN, LOG, LN, EXP, PI, E
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

TIP: Variadic functions (SUM, AVG, MIN, MAX) use commas like Excel.
     Space-separated args need quotes: mth "sqrt(5^2 + 10^2)" works
EOF
        return 1
    }

    local scale="${MATH_DEFAULT_SCALE:-2}"
    local mode="${MATH_DEFAULT_MODE:-round}"

    # ── Lead-arg parsing: optional [scale] [mode] at the front ──
    # Supports maths-style invocation:  mth 2 22/7 | mth 2 u 22/7 | mth 0 22/7
    # Only triggers when $1 is a pure non-negative integer AND more args follow,
    # so genuine expressions like `mth 10/3` or `mth 2^10` are left untouched.
    if [[ $# -ge 2 ]] && [[ "$1" =~ ^[0-9]+$ ]]; then
        scale="$1"; shift
        # Optional mode keyword right after the leading scale
        case "${1:-}" in
            u|up|roundup|ceil)        mode="up";    shift ;;
            d|down|rounddown|floor|trunc) mode="down";  shift ;;
            r|round)                  mode="round"; shift ;;
        esac
    fi

    # ── Tail-arg parsing: peel off optional [scale] [mode] from the end ──
    local raw="$*"
    raw="$(echo "$raw" | sed 's/  */ /g; s/^ //; s/ $//')"

    # Try to peel a trailing [scale] [mode] pair (order: either works)
    # Output format: "<peeled_expr>|<scale>|<mode>" so caller can extract
    _mth_peel() {
        local s="$1"
        local last="${s##* }"
        local rest="${s% *}"
        local prev=""
        [[ "$rest" != "$s" ]] && prev="${rest##* }"
        local peeled=0 new_s="$s" out_scale="" out_mode=""

        # Normalize mode keyword to canonical form
        _mth_norm_mode() {
            case "$1" in
                u|up|roundup|ceil) echo "up" ;;
                d|down|rounddown|floor|trunc) echo "down" ;;
                r|round) echo "round" ;;
                *) echo "$1" ;;
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
        # MSYS bash chokes on ) in char class, so check digit/operator via case
        # Only peel if prev is a digit or ")" — NOT a bare operator (which would
        # leave an incomplete expression like "2 +" after peeling "3")
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
        # Only apply peel if expression is "simple" (no function calls) or peel
        # is a mode-only (Pattern D). For function calls, only peel mode, not scale.
        local _rest="${peeled_result#*|}"
        local _pscale="${_rest%|*}"
        local _pmode="${_rest##*|}"
        if [[ "$raw" == *\(* ]] && [[ -n "$_pscale" ]]; then
            # Function call + trailing scale → take the new_s (drop trailing scale)
            # but don't apply the scale to the result (function result has its own scale)
            raw="${peeled_result%%|*}"
        else
            raw="${peeled_result%%|*}"
            [[ -n "$_pscale" ]] && scale="$_pscale"
            [[ -n "$_pmode" ]]  && mode="$_pmode"
            # Try second peel
            if peeled_result="$(_mth_peel "$raw")"; then
                _rest="${peeled_result#*|}"
                _pscale="${_rest%|*}"
                _pmode="${_rest##*|}"
                if [[ "$raw" == *\(* ]] && [[ -n "$_pscale" ]]; then
                    raw="${peeled_result%%|*}"
                else
                    raw="${peeled_result%%|*}"
                    [[ -n "$_pscale" ]] && scale="$_pscale"
                    [[ -n "$_pmode" ]]  && mode="$_pmode"
                fi
            fi
        fi
    fi

    # Now $raw is the pure expression. Translate Excel syntax → awk.
    # (Note: declare expr AFTER peel so it captures the trimmed raw)
    local expr="$raw"

    # 1. Normalize operators: ** → ^ (Excel uses ^)
    expr="${expr//\*\*/^}"

    # 2. Lowercase ONLY outside of double-quoted strings (preserve string literals)
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

    local awk_out
    awk_out="$(awk -v expr="$expr" -v scale="$scale" -v mode="$mode" '
    BEGIN {
        s = expr
        n = 0; i = 1; L = length(s)

        # ---- 1. Tokenize + count args per function call ----
        # While tokenizing, when we see FN:name, scan ahead to count commas
        # at the function-call parenthesis depth to know argc.
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
                    # Count commas at this paren-depth
                    depth = 1; m = k + 1; commas = 0
                    while (m <= L && depth > 0) {
                        ch = substr(s, m, 1)
                        if (ch == "(") depth++
                        else if (ch == ")") { depth--; if (depth == 0) break }
                        else if (ch == "," && depth == 1) commas++
                        m++
                    }
                    argcount[n] = commas + 1   # 0 commas → 1 arg
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

        # ---- 2. Shunting-yard ----
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
                rpn_argc[op_top] = argcount[t]   # remember argc for this fn call
            } else if (tt == "COMMA") {
                while (op_top > 0 && op[op_top] != "LP") rpn[++rn] = op[op_top--]
            } else if (tt == "LP") {
                op[++op_top] = tt
            } else if (tt == "RP") {
                while (op_top > 0 && op[op_top] != "LP") rpn[++rn] = op[op_top--]
                if (op_top > 0 && op[op_top] == "LP") op_top--
                if (op_top > 0 && substr(op[op_top], 1, 3) == "FN:") {
                    rpn_argc[rn+1] = rpn_argc[op_top]   # propagate to RPN slot
                    rpn[++rn] = op[op_top--]
                }
            } else if (tt == "OP:-" || tt == "OP:+") {
                # Detect unary: at start, or after an operator/LP/COMMA
                is_unary = (prev_tok == "" || substr(prev_tok, 1, 3) == "OP:" || prev_tok == "LP" || prev_tok == "COMMA")
                if (is_unary && tt == "OP:-") {
                    # Unary minus → UNEG. Push WITHOUT popping — the preceding
                    # binary operator (if any) is still waiting for its right
                    # operand, which is what UNEG applies to.
                    op[++op_top] = "UNEG"
                } else if (is_unary && tt == "OP:+") {
                    # Unary plus → no-op, skip entirely
                } else {
                    # Binary +/-
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

        # ---- 3. Evaluate RPN ----
        # Two parallel stacks: st[] (values) and sttype[] ("n"=num, "s"=str)
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
                else if (fn == "round") { v = st[sp--]; st[++sp] = (v < 0 ? -int(-v+0.5) : int(v+0.5)); sttype[sp] = "n" }
                else if (fn == "ceil")  { v = st[sp--]; st[++sp] = (v == int(v) ? v : (v > 0 ? int(v)+1 : int(v))); sttype[sp] = "n" }
                else if (fn == "floor") { v = st[sp--]; st[++sp] = (v < 0 && v != int(v) ? int(v)-1 : int(v)); sttype[sp] = "n" }
                else if (fn == "sin")   { v = st[sp--]; st[++sp] = sin(v); sttype[sp] = "n" }
                else if (fn == "cos")   { v = st[sp--]; st[++sp] = cos(v); sttype[sp] = "n" }
                else if (fn == "tan")   { v = st[sp--]; st[++sp] = sin(v)/cos(v); sttype[sp] = "n" }
                else if (fn == "asin")  { v = st[sp--]; st[++sp] = atan2(v, sqrt(1-v*v)); sttype[sp] = "n" }
                else if (fn == "acos")  { v = st[sp--]; st[++sp] = atan2(sqrt(1-v*v), v); sttype[sp] = "n" }
                else if (fn == "atan")  { v = st[sp--]; st[++sp] = atan2(v, 1); sttype[sp] = "n" }
                else if (fn == "ln")    { v = st[sp--]; st[++sp] = log(v); sttype[sp] = "n" }
                else if (fn == "exp")   { v = st[sp--]; st[++sp] = exp(v); sttype[sp] = "n" }
                else if (fn == "log")   { base = st[sp--]; x = st[sp--]; st[++sp] = (base<=0||base==1||x<=0) ? 0 : log(x)/log(base); sttype[sp] = "n" }
                else if (fn == "pow")   { b = st[sp--]; a = st[sp--]; st[++sp] = (a<0&&int(b)!=b) ? 0 : (a==0&&b<0) ? 0 : a^b; sttype[sp] = "n" }
                else if (fn == "mod")   { b = st[sp--]; a = st[sp--]; st[++sp] = (b==0) ? 0 : a - int(a/b)*b; sttype[sp] = "n" }
                else if (fn == "if")    {
                    c = st[sp--]; b = st[sp--]; a = st[sp--]
                    # After 3 pops: a(cond)=st[sp+1], b(true)=st[sp+2], c(false)=st[sp+3]
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

        # ---- 4. Apply rounding mode (only for numeric results) ----
        if (sttype[sp] == "s") {
            print st[sp]   # string passthrough (no rounding)
        } else {
            val = st[sp]
            mult = 10 ^ scale
            sgn = (val >= 0 ? 1 : -1)
            av  = (val >= 0 ? val : -val) * mult
            iv  = int(av)
            if (mode == "up")   res = sgn * (av > iv ? iv + 1 : iv) / mult
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
}

# Friendly aliases — use whichever name feels natural
bc_()  { mth "$@"; }
math()  { mth "$@"; }




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
    [[ -f $SSOT/tools/hermes.sh ]] && source $SSOT/tools/hermes.sh
    
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
      "/home/usercivenz/ssot" \
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
    cn 220 bi "syncctl.sh not found in $_ssot/tools/"
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




