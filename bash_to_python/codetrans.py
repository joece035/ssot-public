#!/usr/bin/env python3
"""
codetrans - แปลงโค้ด bash <-> python <-> powershell แบบ line-by-line สำหรับคนฝึกภาษาที่สอง

ผลลัพธ์จะวาง comment คู่กันทุกบรรทัด เพื่อให้แกะเทียบได้ง่าย:

    # bash: export NAME="World"
    NAME = "World"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

Flags:
    --clean      เอา comment ออกทั้งหมด (เหลือโค้ดล้วน)
    --no-notes   เหลือเฉพาะบรรทัด `# bash: ...` ตัดคำอธิบายท้ายบรรทัด
    --list       ดูคู่ภาษาที่รองรับ

เพิ่มคู่ภาษาใหม่ (registry ขยายได้):

    from codetrans import register

    @register("ruby", "python")
    def ruby_to_python(code: str) -> str:
        ...

Usage:
    python3 codetrans.py script.sh -t python
    python3 codetrans.py script.sh -t powershell   # หรือ -t pwsh (alias เดียวกัน)
    python3 codetrans.py script.ps1 -f powershell -t bash
    cat script.sh | python3 codetrans.py -f bash -t pwsh
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

# ==========================================================================
# registry
# ==========================================================================

REGISTRY: dict[tuple[str, str], object] = {}

_LANG_ALIAS = {"pwsh": "powershell", "ps": "powershell", "ps1": "powershell"}


def _canon(lang: str) -> str:
    l = lang.strip().lower()
    return _LANG_ALIAS.get(l, l)


def register(src: str, dst: str):
    def deco(fn):
        REGISTRY[(_canon(src), _canon(dst))] = fn
        return fn
    return deco


def pairs() -> list[tuple[str, str]]:
    return sorted(REGISTRY)


def translate(code: str, src: str, dst: str, **kw) -> str:
    src, dst = _canon(src), _canon(dst)
    if src == dst:
        return code
    fn = REGISTRY.get((src, dst))
    if fn is not None:
        return fn(code, **kw)
    raise SystemExit(
        "codetrans: ไม่มีตัวแปลง %s -> %s (คู่ที่รองรับ: %s)"
        % (src, dst, ", ".join(f"{s}->{d}" for s, d in pairs()) or "-")
    )


# ==========================================================================
# quote-aware scanners
# ==========================================================================

def _split_top(text: str, seps: tuple[str, ...]) -> list[str]:
    order = sorted(seps, key=len, reverse=True)
    parts: list[str] = []
    buf: list[str] = []
    i, n = 0, len(text)
    q = None
    while i < n:
        c = text[i]
        if q:
            buf.append(c)
            if c == "\\" and q == '"' and i + 1 < n:
                buf.append(text[i + 1])
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if c in "'\"":
            q = c
            buf.append(c)
            i += 1
            continue
        for sep in order:
            if text.startswith(sep, i):
                parts.append("".join(buf))
                buf = []
                i += len(sep)
                break
        else:
            buf.append(c)
            i += 1
    parts.append("".join(buf))
    return parts


def _top_ops(text: str, ops: tuple[str, ...]) -> list[str]:
    found = []
    i, n = 0, len(text)
    q = None
    while i < n:
        c = text[i]
        if q:
            if c == "\\" and q == '"' and i + 1 < n:
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if c in "'\"":
            q = c
            i += 1
            continue
        matched = False
        for op in sorted(ops, key=len, reverse=True):
            if text.startswith(op, i):
                found.append(op)
                i += len(op)
                matched = True
                break
        if not matched:
            i += 1
    return found


def _split_comment(line: str) -> tuple[str, str]:
    i, n = 0, len(line)
    q = None
    while i < n:
        c = line[i]
        if q:
            if c == "\\" and q == '"' and i + 1 < n:
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if c in "'\"":
            q = c
            i += 1
            continue
        if c == "#" and (i == 0 or line[i - 1] in " \t"):
            return line[:i].rstrip(), line[i:]
        i += 1
    return line, ""


def _words(text: str) -> list[str]:
    """Split on whitespace outside quotes/subshells, keeping quote characters."""
    out: list[str] = []
    buf: list[str] = []
    q = None
    paren_depth = 0  # track $( ) and $(( )) depth so spaces inside don't split
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if q:
            buf.append(c)
            if c == "\\" and q == '"' and i + 1 < n:
                buf.append(text[i + 1])
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if c in "'\"":
            q = c
            buf.append(c)
            i += 1
            continue
        # Track $( or $(( depth so inner spaces are kept
        if c == '$' and i + 1 < n and text[i + 1] == '(':
            paren_depth += 1
            buf.append(c)
            i += 1
            continue
        if c == '(' and paren_depth > 0:
            buf.append(c)
            i += 1
            continue
        if c == ')':
            if paren_depth > 0:
                paren_depth -= 1
                buf.append(c)
                i += 1
                continue
        if c.isspace() and paren_depth == 0:
            if buf:
                out.append("".join(buf))
                buf = []
            i += 1
            continue
        buf.append(c)
        i += 1
    if buf:
        out.append("".join(buf))
    return out


# ==========================================================================
# bash -> python
# ==========================================================================

_ASSIGN_RE = re.compile(r"^([A-Za-z_]\w*)\s*(\+?=)(.*)$")
_VAR_RE = re.compile(r"\$(?:\{(\w+)\}|(\w+))")
_ARG_RE = re.compile(r"\$(\d)")
_ARITH_RE = re.compile(r"^\$\(\((.*)\)\)$")
_GLOB_CHARS = "*?["

_PYTHON_RESERVED = {
    "False", "None", "True", "and", "as", "assert", "async", "await", "break",
    "class", "continue", "def", "del", "elif", "else", "except", "finally",
    "for", "from", "global", "if", "import", "in", "is", "lambda", "nonlocal",
    "not", "or", "pass", "raise", "return", "try", "while", "with", "yield",
}

_PY_HELPERS = {
    "_run": (
        "def _run(cmd):\n"
        '    """รันคำสั่ง shell ตรงๆ แล้วคืน exit status (ใช้กับคำสั่งที่ไม่ได้แปลงเป็น python) """\n'
        "    return subprocess.run(cmd, shell=True).returncode\n"
    ),
    "_sh": (
        "def _sh(cmd):\n"
        '    """รันคำสั่ง shell แล้วคืนผลลัพธ์ stdout (เทียบเท่า $(...) ใน bash) """\n'
        "    return subprocess.run(cmd, shell=True, capture_output=True, text=True)"
        '.stdout.rstrip("\\n")\n'
    ),
    "_ok": (
        "def _ok(cmd):\n"
        '    """คืน True เมื่อคำสั่ง exit status = 0 (เทียบเท่าการเช็ค condition ใน if) """\n'
        "    return subprocess.run(cmd, shell=True).returncode == 0\n"
    ),
}


def _parse_param_exp(inner: str) -> dict | None:
    """Parses bash parameter expansion inner content from ${...}."""
    if not inner:
        return None
    # ${#var}
    if inner.startswith("#") and len(inner) > 1 and re.fullmatch(r"[A-Za-z_]\w*|\d+|[@*]", inner[1:]):
        return {"type": "len", "var": inner[1:]}
    # ${var^^}, ${var^}, ${var,,}, ${var,}
    m = re.fullmatch(r"([A-Za-z_]\w*)(\^\^|\^|,,|,)", inner)
    if m:
        return {"type": "case", "var": m.group(1), "op": m.group(2)}
    # ${var:offset} or ${var:offset:length}
    m = re.fullmatch(r"([A-Za-z_]\w*):(-?\d+)(?::(-?\d+))?", inner)
    if m:
        return {"type": "slice", "var": m.group(1), "offset": m.group(2), "length": m.group(3)}
    # ${var:-default} or ${var-default}
    m = re.fullmatch(r"([A-Za-z_]\w*|\d+)(:?-)(.*)", inner, re.S)
    if m:
        return {"type": "default", "var": m.group(1), "dflt": m.group(3)}
    # ${var:=default} or ${var=default}
    m = re.fullmatch(r"([A-Za-z_]\w*)(:?=)(.*)", inner, re.S)
    if m:
        return {"type": "assign", "var": m.group(1), "dflt": m.group(3)}
    # ${var:+alt} or ${var+alt}
    m = re.fullmatch(r"([A-Za-z_]\w*|\d+)(:?\+)(.*)", inner, re.S)
    if m:
        return {"type": "alt", "var": m.group(1), "alt": m.group(3)}
    # Pattern replacement: ${var/pat/repl}, ${var//pat/repl}, ${var/#pat/repl}, ${var/%pat/repl}
    m = re.match(r"^([A-Za-z_]\w*)/", inner)
    if m:
        var = m.group(1)
        rest = inner[len(var) + 1 :]
        mode = ""
        if rest.startswith(("/", "#", "%")):
            mode = rest[0]
            rest = rest[1:]
        parts = []
        buf = []
        esc = False
        for ch in rest:
            if esc:
                buf.append(ch)
                esc = False
            elif ch == "\\":
                buf.append(ch)
                esc = True
            elif ch == "/":
                parts.append("".join(buf))
                buf = []
            else:
                buf.append(ch)
        parts.append("".join(buf))
        pat = parts[0]
        repl = parts[1] if len(parts) > 1 else ""
        return {"type": "replace", "var": var, "mode": mode, "pat": pat, "repl": repl}
    # Pattern removal: ${var#pattern}, ${var##pattern}, ${var%pattern}, ${var%%pattern}
    m = re.match(r"^([A-Za-z_]\w*)(##|#|%%|%)(.*)$", inner, re.S)
    if m:
        return {"type": "strip", "var": m.group(1), "mode": m.group(2), "pat": m.group(3)}
    # Simple variable: ${var}
    if re.fullmatch(r"[A-Za-z_]\w*|\d+|[@*#?$!0]", inner):
        return {"type": "simple", "var": inner}
    return None


def _tokens(text: str, keep_quotes: bool) -> list[tuple[str, str]]:
    """Tokenize: ('lit'|'var'|'code'|'arith'|'param_exp', value)"""
    toks: list[tuple[str, str]] = []
    buf: list[str] = []
    q = None
    i, n = 0, len(text)

    def flush():
        if buf:
            toks.append(("lit", "".join(buf)))
            del buf[:]

    while i < n:
        c = text[i]
        if q == "'":
            # single quotes: ไม่มี expansion ใน bash
            if c == "'":
                q = None
                i += 1
                continue
            buf.append(c)
            i += 1
            continue
        if q is None:
            if c == "'":
                if keep_quotes:
                    buf.append("'")
                q = "'"
                i += 1
                continue
            if c == '"':
                q = '"'
                if keep_quotes:
                    buf.append('"')
                i += 1
                continue
        if q == '"':
            # double quotes: มี expansion แต่ \ ยังเป็น escape
            if c == "\\" and i + 1 < n:
                buf.append(text[i : i + 2])
                i += 2
                continue
            if c == '"':
                q = None
                if keep_quotes:
                    buf.append('"')
                i += 1
                continue
        # expansion checks (นอก quote หรือ inside double quotes)
        if text.startswith("$((", i):
            close = text.find("))", i + 3)
            if close != -1:
                flush()
                toks.append(("arith", text[i + 3 : close]))
                i = close + 2
                continue
        if text.startswith("${", i):
            close = text.find("}", i + 2)
            if close != -1:
                inner = text[i + 2 : close]
                pe = _parse_param_exp(inner)
                if pe is not None:
                    flush()
                    if pe["type"] == "simple":
                        toks.append(("var", pe["var"]))
                    else:
                        toks.append(("param_exp", inner))
                    i = close + 1
                    continue
        if text.startswith("$(", i):
            depth, j, sq = 1, i + 2, None
            while j < n and depth:
                ch = text[j]
                if sq:
                    if ch == sq and text[j - 1] != "\\":
                        sq = None
                elif ch in "'\"":
                    sq = ch
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                j += 1
            if depth == 0:
                flush()
                toks.append(("code", "_sh(" + json.dumps(text[i + 2 : j - 1]) + ")"))
                i = j
                continue
        # Special params must come BEFORE _VAR_RE (which would eat digits as var names)
        if text.startswith("$$", i):
            flush()
            toks.append(("code", "os.getpid()"))
            i += 2
            continue
        if text.startswith("$@", i) or text.startswith("$*", i):
            flush()
            toks.append(("code", '" ".join(sys.argv[1:])'))
            i += 2
            continue
        if text.startswith("$#", i):
            flush()
            toks.append(("code", "len(sys.argv) - 1"))
            i += 2
            continue
        if text.startswith("$0", i) and (i + 2 >= n or not text[i + 2].isdigit()):
            flush()
            toks.append(("code", "sys.argv[0]"))
            i += 2
            continue
        m = _ARG_RE.match(text, i)
        if m:
            flush()
            toks.append(("code", f"sys.argv[{m.group(1)}]"))
            i = m.end()
            continue
        m = _VAR_RE.match(text, i)
        if m:
            flush()
            toks.append(("var", m.group(1) or m.group(2)))
            i = m.end()
            continue
        buf.append(c)
        i += 1
    if q in ("'", '"') and keep_quotes:
        buf.append(q)
    flush()
    return toks


def _arith_to_py(expr: str) -> str:
    expr = _VAR_RE.sub(lambda m: m.group(1) or m.group(2), expr)
    return expr.replace("/", "//")


def _join_expr(toks: list[tuple[str, str]]) -> str:
    if not toks:
        return '""'
    if len(toks) == 1:
        kind, val = toks[0]
        if kind == "lit":
            return json.dumps(val)
        if kind == "var":
            return val
        if kind == "code":
            return val
        if kind == "arith":
            return "(" + _arith_to_py(val) + ")"
        if kind == "param_exp":
            return _param_to_py(_parse_param_exp(val))
    non_lit = [t for t in toks if t[0] != "lit"]
    if all(k == "var" for k, _ in non_lit) and all(
        "\\" not in v and "{" not in v and "}" not in v and '"' not in v
        for k, v in toks if k == "lit"
    ):
        body = "".join(v if k == "lit" else "{" + v + "}" for k, v in toks)
        return 'f"' + body + '"'
    parts = []
    for k, v in toks:
        if k == "lit":
            parts.append(json.dumps(v))
        elif k == "var":
            parts.append("str(" + v + ")")
        elif k == "arith":
            parts.append("(" + _arith_to_py(v) + ")")
        elif k == "param_exp":
            parts.append("str(" + _param_to_py(_parse_param_exp(v)) + ")")
        else:
            parts.append("(" + v + ")")
    return " + ".join(parts)


def _cmd_expr(text: str) -> str:
    """Python expression ที่คืนคำสั่ง shell พร้อม expansion"""
    return _join_expr(_tokens(text, keep_quotes=True))


def _word_expr(word: str, split: bool = False) -> str:
    """Python expression สำหรับ word เดียวใน bash (ตัด quote ออกแล้ว)"""
    if word[:1] not in "\"'" and re.fullmatch(r"-?\d+(?:\.\d+)?", word):
        return word  # ตัวเลขเปล่า -> number ของ python (จะได้คำนวณ $(( )) ต่อได้)
    arith = _ARITH_RE.match(word)
    if arith:
        return "(" + _arith_to_py(arith.group(1)) + ")"
    toks = _tokens(word, keep_quotes=False)
    if not toks:
        return '""'
    if all(k == "lit" for k, _ in toks):
        return json.dumps("".join(v for _, v in toks))
    lit = "".join(v for k, v in toks if k == "lit")
    if all(k == "lit" for k, _ in toks) and any(c in lit for c in _GLOB_CHARS):
        return "glob.glob(" + json.dumps(lit) + ")"
    expr = _join_expr(toks)
    if any(c in lit for c in _GLOB_CHARS):
        return "glob.glob(" + expr + ")"   # เช่น "$dir"/*.txt
    if split and (len(toks) > 1 or toks[0][0] in ("var", "code")):
        expr += ".split()"
    return expr


def _param_to_py(pe: dict | None) -> str:
    if pe is None:
        return '""'
    t = pe["type"]
    var = pe["var"]
    if t == "simple":
        return var
    if t == "len":
        return f"len({var})"
    if t == "case":
        if pe["op"] in ("^^", "^"):
            return f"{var}.upper()"
        return f"{var}.lower()"
    if t == "slice":
        off = int(pe["offset"])
        if pe.get("length"):
            return f"{var}[{off}:{off + int(pe['length'])}]"
        return f"{var}[{off}:]"
    if t == "default":
        dflt_expr = _word_expr(pe["dflt"])
        return f"({var} or {dflt_expr})"
    if t == "alt":
        alt_expr = _word_expr(pe["alt"])
        return f"({alt_expr} if {var} else '')"
    if t == "replace":
        mode = pe["mode"]
        pat = pe["pat"]
        repl = pe["repl"].replace(r"\~", "~").replace(r"\/", "/")
        pat_expr = _word_expr(pat)
        repl_expr = _word_expr(repl)
        if mode == "#":
            return f"({repl_expr} + {var}[len({pat_expr}):] if {var}.startswith({pat_expr}) else {var})"
        if mode == "%":
            return f"({var}[:-len({pat_expr})] + {repl_expr} if {var}.endswith({pat_expr}) else {var})"
        if mode == "/":
            return f"{var}.replace({pat_expr}, {repl_expr})"
        return f"{var}.replace({pat_expr}, {repl_expr}, 1)"
    if t == "strip":
        mode = pe["mode"]
        pat = pe["pat"]
        pat_expr = _word_expr(pat)
        if mode in ("#", "##"):
            return f"({var}[len({pat_expr}):] if {var}.startswith({pat_expr}) else {var})"
        return f"({var}[:-len({pat_expr})] if {var}.endswith({pat_expr}) else {var})"
    return var


def _lit_content(word: str) -> str | None:
    toks = _tokens(word, keep_quotes=False)
    if not toks or not all(k == "lit" for k, _ in toks):
        return None
    return "".join(v for _, v in toks)


def _num_expr(word: str) -> str:
    if re.fullmatch(r"-?\d+", word):
        return word
    e = _word_expr(word)
    return e if re.fullmatch(r"-?\d+", e) else f"int({e})"


def _as_str(expr: str) -> str:
    """หุ้มด้วย str() เฉพาะเมื่อไม่ใช่ string literal อยู่แล้ว (bash เทียบเป็น string)"""
    if re.fullmatch(r'"(?:[^"\\]|\\.)*"', expr):
        return expr
    return f"str({expr})"


def _test_expr(inner: str) -> str | None:
    words = _words(inner)
    if not words:
        return None
    if len(words) == 2 and words[0] in ("-z", "-n"):
        e = _word_expr(words[1])
        return f"not ({e})" if words[0] == "-z" else e
    if len(words) == 2 and words[0] in (
        "-f", "-d", "-e", "-s", "-r", "-w", "-x", "-L", "-h",
    ):
        p = _word_expr(words[1])
        op = words[0]
        if op in ("-f", "-e"):
            return f"os.path.exists({p})"
        if op == "-d":
            return f"os.path.isdir({p})"
        if op == "-s":
            return f"os.path.getsize({p}) > 0"
        if op in ("-r", "-w", "-x"):
            acc = {"-r": "os.R_OK", "-w": "os.W_OK", "-x": "os.X_OK"}[op]
            return f"os.access({p}, {acc})"
        if op in ("-L", "-h"):
            return f"os.path.islink({p})"
    if "=~" in inner:
        parts = [p.strip() for p in inner.split("=~")]
        if len(parts) == 2:
            rx = _lit_content(parts[1]) or parts[1].strip('"').strip("'")
            return f"re.search({json.dumps(rx)}, {_word_expr(parts[0])}) is not None"
    if len(words) == 3:
        l, op, r = words
        if op in ("=", "=="):
            if any(ch in r for ch in _GLOB_CHARS):
                return f"fnmatch.fnmatch({_as_str(_word_expr(l))}, {_as_str(_word_expr(r))})"
            return f"{_as_str(_word_expr(l))} == {_as_str(_word_expr(r))}"
        if op == "!=":
            if any(ch in r for ch in _GLOB_CHARS):
                return f"not fnmatch.fnmatch({_as_str(_word_expr(l))}, {_as_str(_word_expr(r))})"
            return f"{_as_str(_word_expr(l))} != {_as_str(_word_expr(r))}"
        num = {"-eq": "==", "-ne": "!=", "-lt": "<", "-le": "<=", "-gt": ">", "-ge": ">="}
        if op in num:
            return f"{_num_expr(l)} {num[op]} {_num_expr(r)}"
    return None


def _cond_atom(a: str) -> str:
    a = a.strip()
    if a == "true":
        return "True"
    if a == "false":
        return "False"
    neg = False
    while a.startswith("!"):
        neg = not neg
        a = a[1:].strip()
    inner = a
    if inner.startswith("[[") and inner.endswith("]]"):
        inner = inner[2:-2].strip()
    elif inner.startswith("[") and inner.endswith("]"):
        inner = inner[1:-1].strip()
    while inner.startswith("!") and (len(inner) == 1 or inner[1].isspace()):
        neg = not neg
        inner = inner[1:].strip()
    py = _test_expr(inner)
    if py is None:
        py = "_ok(" + _cmd_expr(inner) + ")"
    return ("not (" + py + ")") if neg else py


def _cond(text: str) -> str:
    groups = _split_top(text.strip(), ("||",))
    rendered = []
    for g in groups:
        atoms = [x for x in _split_top(g, ("&&",)) if x.strip()]
        pys = [_cond_atom(x) for x in atoms]
        rendered.append("(" + " and ".join(pys) + ")" if len(pys) > 1 else pys[0])
    return " or ".join(rendered)


def _for_line(rest: str) -> str:
    m = re.match(r"^(\w+)\s+in\s+(.*)$", rest.strip())
    if not m:
        return f"for _ in []:  # TODO: ยังแปลง for แบบนี้ไม่ได้: for {rest}"
    var, items = m.group(1), m.group(2)
    exprs = [_word_expr(w, split=True) for w in _words(items)]
    if len(exprs) == 1:
        return f"for {var} in {exprs[0]}:"
    return f"for {var} in [{', '.join(exprs)}]:"


def _arith_for(rest: str) -> str:
    m = re.match(r"^\(\((.*)\)\)$", rest.strip())
    if not m:
        return "if True:  # TODO: for แบบ arithmetic"
    pieces = [_x.strip() for _x in _split_top(m.group(1), (";",))]
    if len(pieces) != 3:
        return "if True:  # TODO: for แบบ arithmetic"
    init, cond, step = pieces
    am = re.match(r"^(\w+)\s*=\s*(.+)$", init)
    cm = re.match(r"^(\w+)\s*(<|<=)\s*(.+)$", cond)
    sm = re.match(r"^(\w+)\s*(\+\+)$", step)
    if not (am and cm and sm and am.group(1) == cm.group(1) == sm.group(1)):
        return "if True:  # TODO: for แบบ arithmetic"
    var, start, bound, op = am.group(1), am.group(2).strip(), cm.group(3).strip(), cm.group(2)
    stop = str(int(bound) + 1) if (op == "<" and bound.isdigit()) else bound
    return f"for {var} in range({start}, {stop}):"


def _echo_py(args_text: str) -> str:
    words = _words(args_text)
    end = ""
    while words and words[0] in ("-n", "-e", "-E", "--"):
        if words[0] == "-n":
            end = ', end=""'
        words.pop(0)
    parts: list[str] = []
    lit: list[str] = []

    def flush():
        if lit:
            parts.append(json.dumps(" ".join(lit)))
            lit.clear()

    for w in words:
        content = _lit_content(w)
        if content is not None:
            lit.append(content)
        else:
            flush()
            parts.append(_word_expr(w))
    flush()
    return "print(" + ", ".join(parts) + end + ")"


def _printf_py(args_text: str) -> str:
    words = _words(args_text)
    if not words:
        return "print()"
    fmt = _lit_content(words[0])
    args = words[1:]
    if fmt is None:
        return _echo_py(args_text)
    fmt = (
        fmt.replace(r'\"', '"')
        .replace(r"\'", "'")
        .replace("\\\\", "\x00")
        .replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace("\\r", "\r")
        .replace("\x00", "\\")
    )
    if not args:
        return "print(" + json.dumps(fmt) + ")"
    exprs = ", ".join(_word_expr(w) for w in args)
    tup = f"({exprs},)" if len(args) == 1 else f"({exprs})"
    return f"print({json.dumps(fmt)} % {tup})"


def _shell_words(args_text: str) -> tuple[list[str], list[str]]:
    flags, operands = [], []
    for w in _words(args_text):
        if w.startswith("-") and len(w) > 1 and not w.startswith("--"):
            flags.append(w)
        else:
            operands.append(w)
    return flags, operands


def _simple_cmd_py(s: str) -> str | None:
    words = _words(s)
    if not words:
        return None
    cmd, rest = words[0], s[len(words[0]) :].strip()

    if cmd == "echo":
        return _echo_py(rest)
    if cmd == "printf":
        return _printf_py(rest)
    if cmd == "pwd":
        return "print(os.getcwd())"
    if cmd == "cd":
        targets = _words(rest)
        if not targets:
            return 'os.chdir(os.path.expanduser("~"))'
        return f"os.chdir({_word_expr(targets[0])})"
    if cmd == "cat" and not rest.startswith("-") and len(_words(rest)) == 1:
        return f'print(open({_word_expr(_words(rest)[0])}).read(), end="")'
    if cmd == "cp":
        flags, ops = _shell_words(rest)
        if len(ops) == 2:
            a, b = (_word_expr(x) for x in ops)
            if any("r" in f.lstrip("-") or "a" in f.lstrip("-") for f in flags):
                return f"shutil.copytree({a}, {b})"
            return f"shutil.copy({a}, {b})"
    if cmd == "mv":
        _flags, ops = _shell_words(rest)
        if len(ops) == 2:
            a, b = (_word_expr(x) for x in ops)
            return f"shutil.move({a}, {b})"
    if cmd == "rm":
        flags, ops = _shell_words(rest)
        recursive = any("r" in f.lstrip("-") for f in flags)
        if ops:
            out = []
            for t in ops:
                if any(c in t for c in _GLOB_CHARS):
                    p = _word_expr(t)          # ได้ glob.glob(...) มาแล้ว
                    inner = "shutil.rmtree(p)" if recursive else "os.remove(p)"
                    out.append(f"[{inner} for p in {p}]")
                else:
                    e = _word_expr(t)
                    out.append(f"shutil.rmtree({e})" if recursive else f"os.remove({e})")
            return "; ".join(out)
    if cmd == "mkdir":
        flags, ops = _shell_words(rest)
        if ops:
            make_dir = "p" in "".join(flags) or "-p" in flags
            calls = []
            for t in ops:
                e = _word_expr(t)
                calls.append(f"os.makedirs({e}, exist_ok=True)" if make_dir else f"os.mkdir({e})")
            return "; ".join(calls)
    if cmd == "touch":
        _flags, ops = _shell_words(rest)
        if ops:
            out = []
            for t in ops:
                if any(c in t for c in _GLOB_CHARS):
                    out.append(f'[open(p, "a").close() for p in {_word_expr(t)}]')
                else:
                    out.append(f'open({_word_expr(t)}, "a").close()')
            return "; ".join(out)
    if cmd == "which":
        _flags, ops = _shell_words(rest)
        if len(ops) == 1:
            return f'print(shutil.which({_word_expr(ops[0])}) or "")'
    if cmd == "exit":
        args = _words(rest)
        return "sys.exit(0)" if not args else f"sys.exit({_num_expr(args[0])})"
    if cmd == "return":
        args = _words(rest)
        return "return" if not args else f"return {_word_expr(args[0])}"
    if cmd in ("break", "continue"):
        return cmd
    if cmd == "true":
        return "pass"
    if cmd == "false":
        return '_run("false")'
    if cmd in ("source", "."):
        args = _words(rest)
        if len(args) == 1:
            return f"exec(open({_word_expr(args[0])}).read())"
    if cmd == "read":
        args = _words(rest)
        if len(args) == 1 and re.fullmatch(r"[A-Za-z_]\w*", args[0]):
            return f"{args[0]} = input()"
    if cmd == "let":
        body = rest.strip().strip('"').strip("'")
        body = _VAR_RE.sub(lambda m: m.group(1) or m.group(2), body)
        if "=" in body:
            return body.replace("=", " = ", 1)
    if cmd == "test":
        return _cond_atom("[" + rest + "]")
    if cmd == "export":
        m = _ASSIGN_RE.match(rest)
        if m and m.group(2) == "=":
            return f"{m.group(1)} = {_word_expr(m.group(3).strip())}"
    if cmd in ("trap", "shift", "ulimit", "umask", "alias", "unalias", "set", "unset"):
        return f"# TODO: '{cmd}' ไม่มีใน python ตรงตัว: {s}"
    return None


def _stmt_to_py(stmt: str) -> str | None:
    s = stmt.strip()
    if not s:
        return None
    if s.startswith("#"):
        return s

    m = re.match(r"^(?:local|declare|readonly|export)\s+(.*)$", s)
    if m:
        s = m.group(1).strip()

    # ((i++)) / ((i += 1))
    m = re.fullmatch(r"\(\((.*)\)\)", s)
    if m:
        body = m.group(1).strip()
        mm = re.match(r"^(\w+)\s*(\+\+|--)$", body)
        if mm:
            op = "+=" if mm.group(2) == "++" else "-="
            return f"{mm.group(1)} {op} 1"
        mm = re.match(r"^(\w+)\s*([+\-*/%])=\s*(.+)$", body)
        if mm:
            expr = _arith_to_py(mm.group(3))
            if mm.group(2) == "/":
                return f"{mm.group(1)} //= {expr}"
            return f"{mm.group(1)} {mm.group(2)}= {expr}"
        return "_run(" + _cmd_expr(s) + ")"

    # assignment
    m = _ASSIGN_RE.match(s)
    if m and m.group(1) not in _PYTHON_RESERVED:
        name, op, value = m.group(1), m.group(2), m.group(3).strip()
        expr = _word_expr(value)
        if op == "+=":
            return f"{name} += {expr}"
        return f"{name} = {expr}"

    # pipe / redirect / && ||  ->  รันผ่าน shell (หรือ echo > file แบบเฉพาาะ)
    ops = _top_ops(s, (">>", ">", "<", "|", "&&", "||", "&"))
    if ops:
        wm = re.match(r"^(echo|printf)\s+(.*?)\s*(>>?)\s*(\S+)$", s)
        if wm and set(ops) <= {">", ">>"}:
            mode = "a" if wm.group(3) == ">>" else "w"
            body = _echo_py(wm.group(2)) if wm.group(1) == "echo" else _printf_py(wm.group(2))
            inner = body[len("print(") : -1]
            return f'with open({_word_expr(wm.group(4))}, "{mode}") as _fh:\n    print({inner}, file=_fh)'
        tail = "  # background (&)" if s.endswith("&") and not s.endswith("&&") else ""
        return "_run(" + _cmd_expr(s.rstrip().rstrip("&").rstrip()) + ")" + tail

    simple = _simple_cmd_py(s)
    if simple is not None:
        return simple
    return "_run(" + _cmd_expr(s) + ")"


# --- คำอธิบาย (note) ท้ายบรรทัด ------------------------------------------------

_STMT_NOTES: list[tuple[re.Pattern, str]] = [
    (re.compile(r"^export\b"), "ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export"),
    (re.compile(r"^local\b"), "python ไม่มี local"),
    (re.compile(r"^readonly\b"), "python ไม่มี readonly"),
    (re.compile(r"^echo\b"), "echo -> print()"),
    (re.compile(r"^printf\b"), "printf -> print() + % format"),
    (re.compile(r"^read\b"), "read -> input()"),
    (re.compile(r"^cd\b"), "cd -> os.chdir()"),
    (re.compile(r"^pwd\b"), "pwd -> os.getcwd()"),
    (re.compile(r"^cat\b"), "cat -> open().read()"),
    (re.compile(r"^cp\b"), "cp -> shutil.copy()"),
    (re.compile(r"^mv\b"), "mv -> shutil.move()"),
    (re.compile(r"^rm\b"), "rm -> os.remove() / shutil.rmtree()"),
    (re.compile(r"^mkdir\b"), "mkdir -> os.makedirs()"),
    (re.compile(r"^touch\b"), "touch -> open(f, 'a')"),
    (re.compile(r"^which\b"), "which -> shutil.which()"),
    (re.compile(r"^exit\b"), "exit -> sys.exit()"),
    (re.compile(r"^(source|\.)\b"), "source -> exec(open().read())"),
    (re.compile(r"^\[\[?|^\s*\[|^test\b"), "[ ] condition -> นิพจน์ python (and/or/not)"),
    (re.compile(r"^\w+\s*(\+?=)"), "กำหนดค่าตัวแปร (ไม่ต้องมี export)"),
    (re.compile(r"^for\b"), "for..in: แทน for..do"),
    (re.compile(r"^while\b"), "while: แทน while..do"),
    (re.compile(r"^\w+\(\)\s*\{|^function\b"), "ฟังก์ชัน -> def name():"),
    (re.compile(r"^break$|^continue$"), "ชื่อเหมือนกันใน python"),
    (re.compile(r"^return\b"), "return เหมือนกันใน python"),
]

_STRUCT_NOTES = {
    "else": "else: (ไม่ต้องมี then)",
    "fi": "จบ if — python เยื้องกลับ (dedent) แทน fi",
    "done": "จบ loop — python เยื้องกลับ (dedent) แทน done",
    "}": "จบฟังก์ชัน — python เยื้องกลับแทน }",
    "esac": "จบ case — python เยื้องกลับแทน esac",
}


def _note_for_stmt(s: str, py: str) -> str:
    notes: list[str] = []
    for rx, txt in _STMT_NOTES:
        if rx.search(s):
            notes.append(txt)
            break
    if re.search(r"\$\{?\w+", s) and "f\"" in py:
        notes.append("$VAR -> f-string {VAR}")
    if "_sh(" in py and "$(" in s:
        notes.append("$(cmd) -> _sh() (subprocess)")
    if "_run(" in py:
        notes.append("คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell")
    if "with open(" in py and ">" in s:
        notes.append("redirect > -> open(..., 'w')")
    return "; ".join(notes)


_OPEN_NOTES = {
    "if": "ใส่ : แทน then",
    "elif": "ใส่ : แทน then",
    "while": "ใส่ : แทน do",
    "for": "ใส่ : แทน do",
    "forarith": "ใส่ : แทน do",
}


@register("bash", "python")
def bash_to_python(code: str, headers: bool = True, notes: bool = True) -> str:
    out: list[str] = []
    depth = 0
    pending: tuple[str, str] | None = None
    stack: list[str] = []
    case_subj: str | None = None
    case_base: int | None = None
    pending_header: str | None = None

    def emit(text: str):
        nonlocal pending_header
        if pending_header is not None:
            out.append("    " * depth + "# bash: " + pending_header.strip())
            pending_header = None
        out.append("    " * depth + text)

    def emit_note(text: str):
        if notes and text:
            emit("# -> " + text)

    def attach(py: str, note: str) -> str:
        if notes and note:
            first, _, rest = py.partition("\n")
            first = first + "  # " + note
            return first + (("\n" + rest) if rest else "")
        return py

    def flush_open(kind: str, text: str):
        nonlocal depth
        if kind == "if":
            emit(attach(f"if {_cond(text)}:", _OPEN_NOTES["if"]))
        elif kind == "elif":
            depth = max(depth - 1, 0)
            emit(attach(f"elif {_cond(text)}:", _OPEN_NOTES["elif"]))
        elif kind == "while":
            emit(attach(f"while {_cond(text)}:", _OPEN_NOTES["while"]))
        elif kind == "for":
            emit(attach(_for_line(text), _OPEN_NOTES["for"]))
        elif kind == "forarith":
            emit(attach(_arith_for(text), _OPEN_NOTES["forarith"]))
        depth += 1

    # logical lines (join "\")
    logical: list[str] = []
    buf = ""
    for raw in code.splitlines():
        line = raw.rstrip()
        if line.endswith("\\"):
            buf += line[:-1] + " "
            continue
        logical.append(buf + line)
        buf = ""
    if buf:
        logical.append(buf)

    for line in logical:
        if not line.strip():
            pending_header = None
            out.append("")
            continue
        code_part, _inline = _split_comment(line)
        if not code_part.strip():
            # comment ล้วน -> ส่งผ่านเป็น comment ของ python
            pending_header = None
            emit(line.strip())
            continue
        pending_header = line if headers else None

        queue = _split_stmts(code_part)
        while queue:
            s = queue.pop(0).strip()
            if not s:
                continue

            # then/do ต่อด้วยคำสั่งในบรรทัดเดียว
            mtd = re.match(r"^(then|do)(?=\s)(.*)$", s, re.S)
            if mtd and pending:
                kind = mtd.group(1)
                if kind == "then" or pending[0] in ("while", "for", "forarith"):
                    flush_open(*pending)
                    pending = None
                    rest = mtd.group(2).strip()
                    if rest:
                        queue.insert(0, rest)
                    continue

            # เงื่อนไขข้ามบรรทัด (รอ then/do)
            if pending and s not in ("then", "do") and not s.startswith(("elif ", "fi", "done", "esac")):
                pending = (pending[0], pending[1] + " " + s)
                continue

            if s == "then":
                if pending:
                    flush_open(*pending)
                    pending = None
                continue
            if s == "do":
                if pending and pending[0] in ("while", "for", "forarith"):
                    flush_open(*pending)
                    pending = None
                continue

            m = re.match(r"^(if|elif)\s+(.*)$", s)
            if m:
                if m.group(1) == "elif":
                    depth = max(depth - 1, 0)
                pending = (m.group(1), m.group(2))
                continue
            m = re.match(r"^while\s+(.*)$", s)
            if m:
                pending = ("while", m.group(1))
                continue
            m = re.match(r"^for\s+(.*)$", s)
            if m:
                pending = ("forarith" if m.group(1).strip().startswith("((") else "for", m.group(1))
                continue
            if s == "else":
                depth = max(depth - 1, 0)
                emit(attach("else:", _STRUCT_NOTES["else"]))
                depth += 1
                continue
            if s in ("fi", "done"):
                depth = max(depth - 1, 0)
                emit_note(_STRUCT_NOTES[s])
                continue
            if s == "esac":
                depth = max(case_base - 1, 0) if case_base is not None else max(depth - 1, 0)
                if stack:
                    stack.pop()
                case_subj = None
                case_base = None
                emit_note(_STRUCT_NOTES["esac"])
                continue

            # case
            m = re.match(r"^case\s+(.*)\s+in$", s)
            if m:
                case_subj = _word_expr(m.group(1))
                emit(attach(f"match {case_subj}:", "case -> match/case (python 3.10+)"))
                stack.append("match")
                case_base = depth + 1
                depth = case_base
                continue
            m = re.match(r"^([^\s()]+)\)\s*(.*)$", s)
            if m and case_subj is not None:
                base = case_base if case_base is not None else depth
                depth = base
                emit(attach(_match_case_line(m.group(1), case_subj), "แยกเงื่อนไข case -> case:"))
                depth = base + 1
                rest = m.group(2).strip()
                if rest:
                    py = _stmt_to_py(rest)
                    if py:
                        emit(attach(py, _note_for_stmt(rest, py)))
                continue

            # function / block
            m = re.match(r"^(?:function\s+)?([A-Za-z_]\w*)\s*\(\s*\)\s*\{(.*)$", s) or re.match(
                r"^function\s+([A-Za-z_]\w*)\s*\{(.*)$", s
            )
            if m:
                emit(attach(f"def {m.group(1)}():", "ฟังก์ชัน bash -> def name():"))
                depth += 1
                rest = m.group(2).strip()
                if rest:
                    queue.insert(0, rest)
                continue
            if s == "{":
                emit(attach("if True:  # bash { }", "group { } -> block ของ python"))
                depth += 1
                continue
            if s == "}":
                depth = max(depth - 1, 0)
                emit_note(_STRUCT_NOTES["}"])
                continue

            py = _stmt_to_py(s)
            if py is None:
                continue
            emit(attach(py, _note_for_stmt(s, py)))

    body = "\n".join(out)
    return _add_python_header(body, keep_shebang=True)


def _match_case_line(pats_text: str, subj: str) -> str:
    pats = [p.strip() for p in pats_text.split("|")]
    if pats == ["*"]:
        return "case _:"
    conds = []
    for p in pats:
        content = _lit_content(p) or p.strip("\"'")
        if content == "*":
            continue
        if any(ch in content for ch in _GLOB_CHARS):
            conds.append(f"fnmatch.fnmatch(str({subj}), {json.dumps(content)})")
        else:
            conds.append(f"str({subj}) == {json.dumps(content)}")
    if not conds:
        return "case _:"
    if len(conds) == 1:
        return f"case _ if {conds[0]}:"
    return "case _ if any(" + ", ".join(conds) + "):"


def _add_python_header(body: str, keep_shebang: bool = True) -> str:
    mods: list[str] = []
    for needle, mod in [
        ("os.", "os"),
        ("shutil.", "shutil"),
        ("sys.", "sys"),
        ("glob.", "glob"),
        ("re.", "re"),
        ("fnmatch.", "fnmatch"),
    ]:
        if needle in body:
            mods.append(mod)
    env_inits: list[str] = []
    code_lines = [ln for ln in body.splitlines() if not ln.strip().startswith("#")]
    code_text = "\n".join(code_lines)
    if re.search(r"\bHOME\b", code_text) and not re.search(r"^\s*HOME\s*=", code_text, re.M):
        if "os" not in mods:
            mods.append("os")
        env_inits.append('HOME = os.environ.get("HOME", os.path.expanduser("~"))')
    if re.search(r"\bUSER\b", code_text) and not re.search(r"^\s*USER\s*=", code_text, re.M):
        if "os" not in mods:
            mods.append("os")
        env_inits.append('USER = os.environ.get("USER", os.environ.get("USERNAME", ""))')

    helpers = [h for h in _PY_HELPERS if re.search(rf"\b{h}\(", body)]
    for h in helpers:
        if h == "_run" or h == "_sh" or h == "_ok":
            if "subprocess" not in mods:
                mods.append("subprocess")
    shebang = ""
    lines = body.splitlines()
    if keep_shebang and lines and lines[0].startswith("#!"):
        old = lines[0]
        shebang = old if "python" in old else "#!/usr/bin/env python3"
        body = "\n".join(lines[1:])
    parts = []
    if mods:
        parts.append("\n".join(f"import {m}" for m in sorted(mods)))
    if env_inits:
        parts.append("\n".join(env_inits))
    if helpers:
        parts.append("\n\n".join(_PY_HELPERS[h] for h in helpers))
    chunks = [c for c in (shebang, *parts, body) if c]
    return "\n\n\n".join(chunks) + "\n"


# ==========================================================================
# python -> bash
# ==========================================================================

def _fstring_to_sh(text: str) -> str:
    def repl(m):
        inner = m.group(1)
        if re.fullmatch(r"\w+", inner):
            return "$" + inner
        sm = re.fullmatch(r'_sh\("(.*)"\)', inner)
        if sm:
            return "$(" + sm.group(1) + ")"
        return "${" + inner + "}"

    return re.sub(r"\{([^{}]*)\}", repl, text)


def _strip_quotes(w: str) -> str:
    if len(w) >= 2 and w[0] == w[-1] and w[0] in "\"'":
        return w[1:-1]
    return w


def _sh_word(expr: str) -> str:
    e = expr.strip()
    if not e:
        return "''"
    if (e.startswith('f"') and e.endswith('"')) or (e.startswith("f'") and e.endswith("'")):
        return '"' + _fstring_to_sh(e[2:-1]) + '"'
    if e.startswith('"') and e.endswith('"') and e.count('"') == 2:
        return e
    if e.startswith("'") and e.endswith("'"):
        return '"' + e[1:-1] + '"'
    m = re.fullmatch(r'_sh\((.*)\)', e, re.S)
    if m:
        inner = m.group(1)
        if inner.startswith('"') and inner.endswith('"'):
            inner = inner[1:-1]
        return "$(" + inner + ")"
    m = re.fullmatch(r"str\((\w+)\)", e)
    if m:
        return "$" + m.group(1)
    if re.fullmatch(r"[A-Za-z_]\w*", e):
        return "$" + e
    if re.fullmatch(r"-?\d+(\.\d+)?", e):
        return e
    inner = _fstring_to_sh(e)
    inner = re.sub(r'^"(.*)"$', r"\1", inner, flags=re.S)
    inner = re.sub(r"^\s*str\((\w+)\)\s*$", r"$\1", inner)
    inner = re.sub(r"\s\+\s", "", inner)
    return '"' + inner.replace('"', '\\"') + '"'


def _split_args(text: str) -> list[str]:
    return [p.strip() for p in _split_top(text, (",")) if p.strip()]


def _call_parts(s: str) -> tuple[str, list[str]] | None:
    m = re.match(r"^([A-Za-z_][\w.]*)\((.*)\)$", s, re.S)
    if not m:
        return None
    return m.group(1), _split_args(m.group(2))


def _concat_to_sh(e: str) -> str:
    """ถอดนิพจน์ python แบบ string concat / f-string กลับเป็นข้อความ shell"""
    e = e.strip()
    parts = _split_top(e, ("+",))
    if len(parts) > 1:
        return "".join(_concat_to_sh(p) for p in parts)
    if (e.startswith('f"') and e.endswith('"')) or (e.startswith("f'") and e.endswith("'")):
        return _fstring_to_sh(e[2:-1])
    m = re.fullmatch(r'"((?:[^"\\]|\\.)*)"', e, re.S)
    if m:
        return m.group(1).replace('\\"', '"').replace("\\\\", "\\")
    m = re.fullmatch(r"str\((\w+)\)", e)
    if m:
        return "$" + m.group(1)
    if re.fullmatch(r"[A-Za-z_]\w*", e):
        return "$" + e
    if re.fullmatch(r"-?\d+(?:\.\d+)?", e):
        return e
    return e


def _py_expr_to_sh(expr: str) -> str:
    e = expr.strip()
    m = _call_parts(e)
    if m:
        fn, args = m
        if fn == "glob.glob" and len(args) == 1:
            a = args[0]
            if a.startswith('"') and a.endswith('"'):
                return a[1:-1]
    return _sh_word(e)


def _sh_value(expr: str) -> str:
    e = expr.strip()
    if re.fullmatch(r"-?\d+", e):
        return e
    if re.fullmatch(r"[A-Za-z_]\w*", e):
        return "$" + e
    if e.startswith('f"') and e.endswith('"'):
        return '"' + _fstring_to_sh(e[2:-1]) + '"'
    if e.startswith('"') and e.endswith('"'):
        return e
    if re.fullmatch(r'_sh\(".*"\)', e):
        return _sh_word(e)
    return '"' + _fold_concat(e) + '"'


def _fold_concat(expr: str) -> str:
    e = expr.strip()
    if re.fullmatch(r'"[^"\\]*"', e):
        return e[1:-1]
    if re.fullmatch(r"[A-Za-z_]\w*", e):
        return "$" + e
    parts = _split_top(e, ("+",))
    if len(parts) > 1:
        return "".join(_fold_concat(p) for p in parts)
    for fn in ("str", "int"):
        if e.startswith(fn + "(") and e.endswith(")"):
            return _fold_concat(e[len(fn) + 1 : -1])
    return _fstring_to_sh(e)


def _sh_cond(expr: str) -> str:
    groups = _split_top(expr.strip(), (" or ",))
    rendered = []
    for g in groups:
        atoms = [x for x in _split_top(g, (" and ",)) if x.strip()]
        rendered.append(" && ".join(_sh_cond_atom(a) for a in atoms))
    if len(rendered) > 1:
        return " || ".join(f"({r})" for r in rendered)
    return rendered[0]


def _sh_cond_atom(atom: str) -> str:
    a = atom.strip()
    if a.startswith("(") and a.endswith(")"):
        a = a[1:-1].strip()
    m = re.match(r"^not\s+(.*)$", a)
    if m:
        inner = m.group(1).strip()
        if inner.startswith("(") and inner.endswith(")"):
            inner = inner[1:-1]
        return "! " + _sh_cond_atom(inner)
    if a == "True":
        return "true"
    if a == "False":
        return "false"
    m = _call_parts(a)
    if m:
        fn, args = m
        p = _sh_word(args[0]) if args else ""
        if fn in ("os.path.exists", "os.path.isfile"):
            return f"[ -f {p} ]"
        if fn == "os.path.isdir":
            return f"[ -d {p} ]"
        if fn == "os.path.islink":
            return f"[ -L {p} ]"
        if fn == "os.path.getsize":
            return f"[ -s {p} ]"
        if fn == "shutil.which" and "is not None" in a:
            return f'[ -n "$(command -v {_sh_word(args[0])})" ]'
        if fn == "_ok":
            inner = args[0]
            if inner.startswith('"') and inner.endswith('"'):
                inner = inner[1:-1]
            return inner
        if fn == "re.search" and len(args) == 2:
            return f"[[ {_sh_word(args[1])} =~ {_strip_quotes(_sh_word(args[0]))} ]]"
    for pyop, shop in (("==", "="), ("!=", "!="), ("<=", "-le"), (">=", "-ge"),
                       ("<", "-lt"), (">", "-gt")):
        parts = _split_top(a, (pyop,))
        if len(parts) == 2 and all(p.strip() for p in parts):
            l, r = (_sh_value(p.strip()) for p in parts)
            if shop in ("-le", "-ge", "-lt", "-gt"):
                l, r = _strip_quotes(l), _strip_quotes(r)
            return f"[ {l} {shop} {r} ]"
    # เงื่อนไขเป็นตัวแปร/ค่า string ล้วน -> [ -n "$x" ]
    if re.fullmatch(r"[A-Za-z_]\w*", a):
        return f'[ -n "${a}" ]'
    if re.fullmatch(r'"(?:[^"\\]|\\.)*"', a):
        return f"[ -n {a} ]"
    return _py_expr_to_sh(a)


def _py_for_to_sh(head: str) -> str:
    m = re.match(r"^for\s+(\w+)\s+in\s+(.*)$", head)
    if not m:
        return 'for _ in ""'
    var, items = m.group(1), m.group(2).strip()
    rm = re.fullmatch(r"range\((.*)\)", items)
    if rm:
        nums = [a.strip() for a in rm.group(1).split(",")]
        if all(re.fullmatch(r"-?\d+", a) for a in nums):
            v = [int(a) for a in nums]
            start = v[0] if len(v) >= 2 else 0
            stop = v[1] if len(v) >= 2 else v[0]
            step = v[2] if len(v) == 3 else 1
            if step == 1:
                return f"for {var} in $({f'seq {start} {stop - 1}'})"
            return f"for {var} in $({f'seq {start} {step} {stop - 1}'})"
        return f"for {var} in $({items})"
    if items.startswith("glob.glob("):
        inner = items[len("glob.glob(") : -1].strip()
        if inner.startswith('f"') and inner.endswith('"'):
            inner = _fstring_to_sh(inner[2:-1])
        else:
            inner = _strip_quotes(inner)
        return f"for {var} in {inner}"
    if items.startswith("[") and items.endswith("]"):
        words = [_sh_word(p) for p in _split_args(items[1:-1])]
        return f"for {var} in {' '.join(words)}"
    return f"for {var} in {_sh_word(items)}"


def _py_case_to_sh(head: str) -> str:
    m = re.match(r"^(.*?)(?:\s+if\s+(.*))?$", head)
    pat = m.group(1).strip() if m else head
    guard = m.group(2).strip() if m and m.group(2) else None
    if pat == "_":
        pats = ["*"]
    elif pat.startswith('"') and pat.endswith('"'):
        pats = [pat[1:-1]]
    else:
        pats = [pat]
    if guard:
        gm = re.search(r'fnmatch\.fnmatch\([^,]+,\s*"([^"]*)"\)', guard)
        if gm:
            pats = [gm.group(1)]
        else:
            em = re.search(r'==\s*"([^"]*)"', guard)
            if em:
                pats = [em.group(1)]
    return "|".join(pats)


def _py_stmt_to_sh(s: str) -> str | None:
    if s.startswith("import ") or s.startswith("from "):
        return "# bash ไม่ต้อง import: " + s
    if s == "pass":
        return ":"
    if s in ("break", "continue"):
        return s
    if s.startswith("return"):
        arg = s[6:].strip()
        if not arg:
            return "return"
        if re.fullmatch(r'(-?\d+(\.\d+)?|"[^"]*"|\'[^\']*\'|[A-Za-z_]\w*|_sh\(".*"\))', arg):
            return "return " + _sh_value(arg)
        return "# TODO: return ค่าซับซ้อน: " + s

    m = re.match(r"^(\w+)\s*([+\-*/])=\s*(.+)$", s)
    if m:
        var, op, val = m.group(1), m.group(2), m.group(3).strip()
        if op == "*":
            return f'{var}="$(({var} * {_strip_quotes(_sh_value(val))}))"'
        return f'{var}="$(({var} {op} {_strip_quotes(_sh_value(val))}))"'

    m = re.match(r"^(\w+)\s*=\s*(.*)$", s)
    if m:
        name, val = m.group(1), m.group(2).strip()
        if val == "input()":
            return f"read {name}"
        # python expression แบบคำนวณ -> $(( ... ))
        am = re.fullmatch(r"\((.+)\)", val)
        if am and re.fullmatch(r"[\w\s+\-*/%()]+", am.group(1)):
            return f"{name}=$(({am.group(1)}))"
        if re.fullmatch(r"[\w\s+\-*/%()]+", val) and any(c in val for c in ("+", "-", "*", "/", "%")):
            toks_val = re.findall(r"[A-Za-z_]\w*|\d+|[+\-*/%()]", val)
            if any(t in ("+", "-", "*", "/", "%") for t in toks_val):
                return f"{name}=$(({val.replace('//', '/')}))"
        return f"{name}={_sh_value(val)}"

    if s.startswith("print(") and s.endswith(")"):
        # print(open(f).read(), ...) -> cat f
        cm = re.fullmatch(r"print\(open\((.*)\)\.read\(\)(?:,\s*end\s*=\s*[\"'][\"'])?\)", s)
        if cm:
            return "cat " + _sh_word(cm.group(1))
        args = _split_args(s[len("print(") : -1])
        end_expr = None
        if args and re.match(r"^end\s*=", args[-1]):
            end_expr = args.pop().split("=", 1)[1].strip()
        words = [_sh_word(a) for a in args]
        if end_expr in ('""', "''"):
            return "printf %s " + " ".join(words) if words else "printf %s ''"
        if not words:
            return 'echo ""'
        return "echo " + " ".join(words)

    call = _call_parts(s)
    if call:
        fn, args = call
        if fn == "os.chdir" and args:
            return "cd " + _sh_word(args[0])
        if fn == "os.getcwd":
            return "pwd"
        if fn in ("shutil.copy",) and len(args) == 2:
            return f"cp {_sh_word(args[0])} {_sh_word(args[1])}"
        if fn == "shutil.copytree" and len(args) == 2:
            return f"cp -r {_sh_word(args[0])} {_sh_word(args[1])}"
        if fn in ("os.rename", "shutil.move") and len(args) == 2:
            return f"mv {_sh_word(args[0])} {_sh_word(args[1])}"
        if fn == "os.remove" and args:
            return "rm " + _sh_word(args[0])
        if fn == "shutil.rmtree" and args:
            return "rm -rf " + _sh_word(args[0])
        if fn == "os.makedirs" and args:
            return "mkdir -p " + _sh_word(args[0])
        if fn == "os.mkdir" and args:
            return "mkdir " + _sh_word(args[0])
        if fn == "sys.exit":
            return "exit" + ("" if not args else " " + _strip_quotes(_sh_value(args[0])))
        if fn == "_run" and len(args) == 1:
            return _concat_to_sh(args[0])
        if fn == "_sh" and len(args) == 1:
            inner = args[0]
            if inner.startswith('"') and inner.endswith('"'):
                inner = inner[1:-1]
            return 'echo "$(' + inner + ')"'
        if fn == "open" and s.endswith(".close()") and len(args) >= 1:
            mode = args[1] if len(args) > 1 else '"r"'
            if '"a"' in mode:
                return "touch " + _sh_word(args[0])
            return "# TODO: เขียนไฟล์: " + s
        if fn == "glob.glob":
            return "# TODO: วนไฟล์จาก glob: " + s
    return None


_PY_STMT_NOTES: list[tuple[re.Pattern, str]] = [
    (re.compile(r"^import |^from "), "bash ไม่ต้อง import"),
    (re.compile(r"^pass$"), "pass -> : (คำสั่งเปล่าของ bash)"),
    (re.compile(r"^print\("), "print -> echo"),
    (re.compile(r"^\w+\s*=\s*input\(\)"), "input() -> read"),
    (re.compile(r"^\w+\s*="), "ตัวแปร -> NAME=value"),
    (re.compile(r"^\w+\s*[+\-*/]="), "บวกเพิ่ม -> $(( ... ))"),
    (re.compile(r"^if\b"), "if: -> if ...; then"),
    (re.compile(r"^elif\b"), "elif: -> elif ...; then"),
    (re.compile(r"^while\b"), "while: -> while ...; do"),
    (re.compile(r"^for\b"), "for: -> for ...; do"),
    (re.compile(r"^def\b"), "def -> name() { }"),
    (re.compile(r"^match\b"), "match: -> case ... in"),
    (re.compile(r"^case\b"), "case: -> pattern)"),
    (re.compile(r"_run\("), "_run() -> รันคำสั่ง shell ตรงๆ"),
    (re.compile(r"^\[.*for .* in glob\.glob"), "list comprehension -> for + glob"),
]


@register("python", "bash")
def python_to_bash(code: str, headers: bool = True, notes: bool = True) -> str:
    out: list[str] = []
    stack: list[tuple[str, int]] = []
    closer_text = {"while": "done", "for": "done", "def": "}", "match": "esac",
                   "try": None, "with": None, "if": "fi"}
    in_doc: str | None = None
    depth = 0
    pending_header: str | None = None
    case_open = False

    def emit(text: str, d: int | None = None):
        nonlocal pending_header
        d = depth if d is None else d
        if pending_header is not None:
            out.append("    " * d + "# python: " + pending_header.strip())
            pending_header = None
        out.append("    " * d + text)

    def attach(bash_line: str, note: str) -> str:
        if notes and note:
            return bash_line + "  # " + note
        return bash_line

    def note_for(s: str) -> str:
        for rx, txt in _PY_STMT_NOTES:
            if rx.search(s):
                return txt
        return ""

    def close_to(target: int):
        """ปิดบล็อก (fi/done/}) จนเหลือความลึก = target"""
        nonlocal case_open
        while len(stack) > target:
            key, start = stack.pop()
            ct = closer_text.get(key)
            if ct is None:
                continue
            if key == "match" and case_open:
                emit(";;", len(stack) + 1)   # bash ต้องปิดทุก branch ด้วย ;;
                case_open = False
            if key == "def" and not any(
                ln.strip() and not ln.strip().startswith("#") for ln in out[start:]
            ):
                # bash ไม่ยอมให้ฟังก์ชันว่างเปล่า -> ใส่ : (noop) ก่อนปิด
                out.append("    " * (len(stack) + 1) + ":")
            emit(ct, len(stack))

    lines = code.splitlines()
    if lines and lines[0].startswith("#!") and "python" in lines[0]:
        emit("#!/usr/bin/env bash", 0)
        lines = lines[1:]

    for raw in lines:
        stripped = raw.strip()
        indent = len(raw) - len(raw.lstrip(" "))
        level = indent // 4
        pending_header = None

        if in_doc:
            emit("# " + stripped, depth)
            if stripped.endswith(in_doc):
                in_doc = None
            continue
        if stripped.startswith(('"""', "'''")):
            quote = stripped[:3]
            emit("# " + stripped, depth)
            if stripped.count(quote) < 2:
                in_doc = quote
            continue

        if not stripped:
            out.append("")
            continue

        # ตัด comment ท้ายบรรทัดออกก่อน (ต้นฉบับอยู่ที่ header แล้ว)
        expr_line, _ = _split_comment(stripped)
        is_comment = not expr_line.strip()
        is_branch = (not is_comment) and bool(
            re.match(r"^(elif\b|else\b|except\b|finally\b)", expr_line)
        )

        # ปิดบล็อกที่จบแล้วก่อนเสมอ จะได้ไม่ปิดเลย comment ของบรรทัดถัดไป
        # (comment ไม่ต้องปิดบล็อก — header ของ elif/else ถูกวางไว้นอกบล็อกอยู่แล้ว)
        if not is_comment:
            close_to(level + 1 if is_branch else level)
        depth = len(stack)

        if is_comment:
            emit(stripped, depth)
            continue
        if stripped.startswith("@"):
            emit("# TODO: decorator ไม่มีใน bash: " + stripped, depth)
            continue

        pending_header = raw if headers else None

        if expr_line.endswith(":"):
            kw = expr_line.split(None, 1)[0].rstrip(":")
            head = expr_line[:-1].strip()
            if kw == "if":
                emit(attach(f"if {_sh_cond(head[3:])}; then", "if: -> if ...; then"), depth)
                stack.append(("if", len(out)))
                continue
            if kw == "elif":
                emit(attach(f"elif {_sh_cond(head[4:])}; then", "elif: -> elif ...; then"), depth)
                continue
            if kw == "else":
                emit(attach("else", "else: -> else"), depth)
                continue
            if kw == "while":
                emit(attach(f"while {_sh_cond(head[5:])}; do", "while: -> while ...; do"), depth)
                stack.append(("while", len(out)))
                continue
            if kw == "for":
                emit(attach(_py_for_to_sh(head) + "; do", "for: -> for ...; do"), depth)
                stack.append(("for", len(out)))
                continue
            if kw == "def":
                m = re.match(r"^def\s+(\w+)\s*\((.*)\)$", head)
                if m:
                    name, params = m.group(1), m.group(2).strip()
                    emit(attach(f"{name}() {{", "def -> name() { }"), depth)
                    idx = len(out)
                    if params:
                        emit(f"# TODO: parameter python ({params}) = $1, $2, ... ใน bash", depth + 1)
                    stack.append(("def", idx))
                continue
            if kw == "match":
                case_open = False
                emit(attach(f"case {_sh_word(head[6:])} in", "match: -> case ... in"), depth)
                stack.append(("match", len(out)))
                continue
            if kw == "case":
                if case_open:
                    emit(";;", depth)   # ปิด branch ก่อนหน้า
                emit(attach(_py_case_to_sh(head[5:]) + ")", "case: -> pattern)"), depth)
                case_open = True
                continue
            if kw in ("try", "with"):
                emit(f"# TODO: python '{kw}' block ไม่มีใน bash", depth)
                stack.append((kw, len(out)))
                continue
            if kw in ("except", "finally"):
                emit(f"# TODO: python '{expr_line}' ไม่มีใน bash", depth)
                continue
            emit("# TODO: " + expr_line, depth)
            stack.append(("try", len(out)))
            continue

        stmt = _py_stmt_to_sh(expr_line)
        if stmt is None:
            emit("# TODO: port to bash: " + expr_line, depth)
        elif stmt.startswith("#"):
            emit(stmt, depth)
        else:
            emit(attach(stmt, note_for(expr_line)), depth)

    close_to(0)

    body = "\n".join(out)
    if not headers:
        body = "\n".join(ln for ln in body.splitlines()
                         if not ln.strip().startswith("# python: "))
    if body and not body.startswith("#!"):
        body = "#!/usr/bin/env bash\n" + body
    return body + "\n"


# ==========================================================================
# bash <-> powershell
# ==========================================================================
# หมายเหตุ: pwsh เป็น shell เหมือน bash คำสั่ง native (ls/grep/git/...)
# รันได้ตรงๆ จึงส่งผ่าน (pass-through) ได้เลย ต่างจาก python ที่ต้องห่อ _run()

_PS_SHEBANG = "#!/usr/bin/env pwsh"


def _ps_sq(s: str) -> str:
    """สตริง literal ของ pwsh แบบ quote เดี่ยว (ไม่มี expansion เหมือน bash '...')."""
    return "'" + s.replace("'", "''") + "'"


def _ps_dq_escape(s: str) -> str:
    """escape ข้อความ literal สำหรับใส่ใน "..." ของ pwsh.

    ยุบ escape คู่ของ bash ใน "..." ก่อน (\\" -> \\, \\" -> ", \\$ -> $ literal)
    เหลือ \\n/\\t แบบ literal (bash ไม่ตีความถ้าไม่ใช่ -e/printf — pwsh ก็ไม่ตีความ)
    """
    s = re.sub(r"(?<!`)`(?!`)", "\x02", s)  # ` เดี่ยวๆ ของ bash -> placeholder
    s = (
        s.replace("\\\\", "\x00")
        .replace('\\"', '"')
        .replace("\\$", "\x01")
        .replace("\\`", "``")
    )
    s = s.replace("\x00", "\\")
    s = s.replace('"', '`"').replace("$", "`$")
    return s.replace("\x02", "``").replace("\x01", "`$")


def _ps_dq_esc_interp(v: str) -> str:
    """escape สำหรับโหมดตีความ (echo -e): \\n -> `n ของ pwsh ก่อน แล้วค่อย escape."""
    v = re.sub(r"(?<!`)`(?!`)", "\x02", v)
    v = v.replace("\\\\", "\x00").replace("\\`", "``")
    v = v.replace("\\n", "`n").replace("\\t", "`t").replace("\\r", "`r")
    v = v.replace("\x00", "\\")
    v = v.replace('"', '`"').replace("$", "`$")
    return v.replace("\x02", "``")


def _ps_frags(word: str) -> list[tuple[str, str]]:
    """แยก word ของ bash เป็นชิ้นส่วนสำหรับประกอบเป็น powershell.

    kinds: lit/var/cmd/arith/arg/args/argc/status/pid/prog/raw
    (escape คู่แบบ \\n เก็บไว้ทั้งคู่ ให้ caller ตัดสินใจทีหลังว่าจะตีความหรือไม่)
    """
    frags: list[tuple[str, str]] = []
    buf: list[str] = []
    i, n = 0, len(word)
    q = None  # None | "'" | '"'
    while i < n:
        c = word[i]
        if q == "'":
            if c == "'":
                q = None
                i += 1
                continue
            buf.append(c)
            i += 1
            continue
        if q is None and c == "'":
            q = "'"
            i += 1
            continue
        if c == '"' and q is None:
            q = '"'
            i += 1
            continue
        if c == '"' and q == '"':
            q = None
            i += 1
            continue
        if c == "\\" and q != "'":
            if i + 1 < n:
                buf.append(word[i : i + 2])
                i += 2
                continue
            i += 1
            continue
        if c == "`" and q != "'":
            j = word.find("`", i + 1)
            if j == -1:
                buf.append(c)
                i += 1
                continue
            if buf:
                frags.append(("lit", "".join(buf)))
                buf = []
            frags.append(("cmd", word[i + 1 : j]))
            i = j + 1
            continue
        if c == "$" and q != "'":
            if word.startswith("$((", i):
                close = word.find("))", i + 3)
                if close == -1:
                    buf.append(c)
                    i += 1
                    continue
                if buf:
                    frags.append(("lit", "".join(buf)))
                    buf = []
                frags.append(("arith", word[i + 3 : close]))
                i = close + 2
                continue
            if word.startswith("$(", i):
                depth, j, sq = 1, i + 2, None
                while j < n and depth:
                    ch = word[j]
                    if sq:
                        if ch == sq and word[j - 1] != "\\":
                            sq = None
                    elif ch in "'\"":
                        sq = ch
                    elif ch == "(":
                        depth += 1
                    elif ch == ")":
                        depth -= 1
                    j += 1
                if depth == 0:
                    if buf:
                        frags.append(("lit", "".join(buf)))
                        buf = []
                    frags.append(("cmd", word[i + 2 : j - 1]))
                    i = j
                    continue
                buf.append(c)
                i += 1
                continue
            if i + 1 < n and word[i + 1] == "{":
                close = word.find("}", i + 2)
                if close == -1:
                    buf.append(c)
                    i += 1
                    continue
                inner = word[i + 2 : close]
                pe = _parse_param_exp(inner)
                if pe is not None:
                    if buf:
                        frags.append(("lit", "".join(buf)))
                        buf = []
                    if pe["type"] == "simple":
                        frags.append(("var", pe["var"]))
                    elif pe["type"] == "len":
                        frags.append(("varlen", pe["var"]))
                    elif pe["type"] == "default":
                        dflt = _ps_join_words(_words(pe["dflt"]) or [pe["dflt"]])
                        if pe["var"].isdigit():
                            frags.append(("argdef", pe["var"] + "\x00" + dflt))
                        else:
                            frags.append(("vardef", pe["var"] + "\x00" + dflt))
                    else:
                        frags.append(("param_exp", inner))
                    i = close + 1
                    continue
                frags.append(("raw", word[i : close + 1]))
                i = close + 1
                continue
            m = re.match(r"\$(\d+)", word[i:])
            if m:
                if buf:
                    frags.append(("lit", "".join(buf)))
                    buf = []
                if m.group(1) == "0":
                    frags.append(("prog", ""))
                else:
                    frags.append(("arg", m.group(1)))
                i += len(m.group(0))
                continue
            m = re.match(r"\$([A-Za-z_]\w*)", word[i:])
            if m:
                if buf:
                    frags.append(("lit", "".join(buf)))
                    buf = []
                frags.append(("var", m.group(1)))
                i += len(m.group(0))
                continue
            nxt = word[i + 1] if i + 1 < n else ""
            if nxt in "@*":
                if buf:
                    frags.append(("lit", "".join(buf)))
                    buf = []
                frags.append(("args", ""))
                i += 2
                continue
            if nxt == "#":
                if buf:
                    frags.append(("lit", "".join(buf)))
                    buf = []
                frags.append(("argc", ""))
                i += 2
                continue
            if nxt == "?":
                if buf:
                    frags.append(("lit", "".join(buf)))
                    buf = []
                frags.append(("status", ""))
                i += 2
                continue
            if nxt == "$":
                if buf:
                    frags.append(("lit", "".join(buf)))
                    buf = []
                frags.append(("pid", ""))
                i += 2
                continue
            if nxt == "!":
                if buf:
                    frags.append(("lit", "".join(buf)))
                    buf = []
                frags.append(("raw", "$!"))
                i += 2
                continue
            buf.append(c)
            i += 1
            continue
        buf.append(c)
        i += 1
    if buf:
        frags.append(("lit", "".join(buf)))
    return frags


def _arith_to_ps(expr: str) -> str:
    """$((a+1)) ของ bash -> ($a + 1) ของ pwsh (เติม $ ให้ชื่อตัวแปรเปลือย)."""
    e = re.sub(r"\$\{([A-Za-z_]\w*)\}", r"$\1", expr)

    def _pre(m: re.Match) -> str:
        if m.group(0) in ("true", "false"):
            return m.group(0)
        return "$" + m.group(0)

    return re.sub(r"(?<![$\w])([A-Za-z_]\w*)(?!\s*\()", _pre, e)


def _ps_atom(k: str, v: str) -> str:
    """ชิ้นเดียวทั้ง word (นอก string) — ใช้รูป bare ได้เลย."""
    if k == "var":
        return "$" + v
    if k == "cmd":
        return "$(" + v + ")"
    if k == "arith":
        return "(" + _arith_to_ps(v) + ")"
    if k == "arg":
        return "$args[%d]" % (int(v) - 1)
    if k == "argdef":
        num, _, dflt = v.partition("\x00")
        return "($args[%d] ?? %s)" % (int(num) - 1, dflt)
    if k == "vardef":
        name, _, dflt = v.partition("\x00")
        return "($%s ?? %s)" % (name, dflt)
    if k == "varlen":
        return "($%s.Length)" % v
    if k == "args":
        return "$args"
    if k == "argc":
        return "$args.Count"
    if k == "status":
        return "$?"
    if k == "pid":
        return "$PID"
    if k == "prog":
        return "$PSCommandPath"
    if k == "param_exp":
        return _param_to_ps(_parse_param_exp(v))
    return v  # raw — ส่งผ่านพร้อม note ให้ตรวจเอง


def _ps_build(frags: list[tuple[str, str]], interpret: bool = False) -> str:
    """ประกอบชิ้นส่วนเป็นนิพจน์ pwsh (ผสม -> "..." แบบ double-quote).

    interpret=True (echo -e): บังคับ "..." เสมอ และแปลง \\n -> `n ของ pwsh
    (ห้ามคืนสตริงที่มี newline จริง — จะทำให้เลขบรรทัด/attach note พัง)
    """
    if not frags:
        return "''"
    if len(frags) == 1 and not interpret:
        k, v = frags[0]
        if k == "lit":
            if re.fullmatch(r"-?\d+(?:\.\d+)?", v):
                return v
            return _ps_sq(v)
        return _ps_atom(k, v)

    def esc_lit(v: str) -> str:
        return _ps_dq_esc_interp(v) if interpret else _ps_dq_escape(v)

    # ชิ้นเดียว + interpret -> "..." เสมอ (ไม่ใช้ _ps_sq เพราะ escape ต้องเป็น `n)
    if len(frags) == 1 and frags[0][0] == "lit":
        return '"' + esc_lit(frags[0][1]) + '"'
    body: list[str] = []
    for k, v in frags:
        if k == "lit":
            body.append(esc_lit(v))
        elif k == "var":
            body.append("$" + v)
        elif k == "cmd":
            body.append("$(" + v + ")")
        elif k == "arith":
            # ใน "..." ต้องใช้ $(...) (subexpression) ถึงจะคำนวณ
            body.append("$(" + _arith_to_ps(v) + ")")
        elif k == "arg":
            # $args[0] ใน "..." ไม่ expand index ต้องห่อ $()
            body.append("$($args[%d])" % (int(v) - 1))
        elif k == "argdef":
            num, _, dflt = v.partition("\x00")
            body.append("$(($args[%d] ?? %s))" % (int(num) - 1, dflt))
        elif k == "vardef":
            name, _, dflt = v.partition("\x00")
            body.append("$(($%s ?? %s))" % (name, dflt))
        elif k == "varlen":
            body.append("$($%s.Length)" % v)
        elif k == "args":
            body.append("$($args)")
        elif k == "argc":
            body.append("$($args.Count)")
        elif k == "status":
            body.append("$?")
        elif k == "pid":
            body.append("$PID")
        elif k == "prog":
            body.append("$PSCommandPath")
        elif k == "param_exp":
            pv = _param_to_ps(_parse_param_exp(v))
            body.append("$(" + pv + ")" if not (pv.startswith("$(") and pv.endswith(")")) else pv)
        else:
            body.append(esc_lit(v))
    return '"' + "".join(body) + '"'


def _ps_word(word: str) -> str:
    if word[:1] not in "\"'" and re.fullmatch(r"-?\d+(?:\.\d+)?", word):
        return word
    return _ps_build(_ps_frags(word))


def _ps_join_words(words: list[str], interpret: bool = False) -> str:
    """รวมหลาย word ด้วยช่องว่างเป็นสตริงเดียว (แบบ echo ที่ join ด้วย space)."""
    if not words:
        return "''"
    if len(words) == 1 and not interpret:
        return _ps_word(words[0])
    combo: list[tuple[str, str]] = []
    for idx, w in enumerate(words):
        if idx:
            combo.append(("lit", " "))
        combo.extend(_ps_frags(w))
    return _ps_build(combo, interpret=interpret)


def _param_to_ps(pe: dict | None) -> str:
    if pe is None:
        return "''"
    t = pe["type"]
    var = pe["var"]
    pvar = f"${var}"
    if t == "simple":
        return pvar
    if t == "len":
        return f"({pvar}.Length)"
    if t == "case":
        if pe["op"] in ("^^", "^"):
            return f"({pvar}.ToUpper())"
        return f"({pvar}.ToLower())"
    if t == "slice":
        off = pe["offset"]
        if pe.get("length"):
            return f"({pvar}.Substring({off}, {pe['length']}))"
        return f"({pvar}.Substring({off}))"
    if t == "default":
        dflt_code = _ps_join_words(_words(pe["dflt"]) or [pe["dflt"]])
        return f"({pvar} ?? {dflt_code})"
    if t == "alt":
        alt_code = _ps_join_words(_words(pe["alt"]) or [pe["alt"]])
        return f"($(if ({pvar}) {{ {alt_code} }} else {{ '' }}))"
    if t == "replace":
        mode = pe["mode"]
        pat = pe["pat"]
        repl = pe["repl"].replace(r"\~", "~").replace(r"\/", "/")
        if pat.startswith("$") and re.fullmatch(r"\$[A-Za-z_]\w*", pat):
            pat_code = pat
        else:
            pat_code = _ps_word(pat)
        repl_code = _ps_word(repl)
        if mode == "#":
            return f"({pvar} -replace ('^' + [regex]::Escape({pat_code})), {repl_code})"
        if mode == "%":
            return f"({pvar} -replace ([regex]::Escape({pat_code}) + '$'), {repl_code})"
        if mode == "/":
            return f"({pvar} -replace [regex]::Escape({pat_code}), {repl_code})"
        return f"([regex]::new([regex]::Escape({pat_code})).Replace({pvar}, {repl_code}, 1))"
    if t == "strip":
        mode = pe["mode"]
        pat = pe["pat"]
        if pat.startswith("$") and re.fullmatch(r"\$[A-Za-z_]\w*", pat):
            pat_code = pat
        else:
            pat_code = _ps_word(pat)
        if mode in ("#", "##"):
            return f"({pvar} -replace ('^' + [regex]::Escape({pat_code})), '')"
        return f"({pvar} -replace ([regex]::Escape({pat_code}) + '$'), '')"
    return pvar


def _ps_has_raw(word: str) -> bool:
    return any(k == "raw" for k, _ in _ps_frags(word))


def _ps_test_expr(inner: str) -> str | None:
    """[ ... ] / [[ ... ]] ของ bash -> นิพจน์ pwsh (None = ไม่รู้จัก ส่งผ่านตรง)."""
    words = _words(inner)
    if words and words[0] == "test":
        words = words[1:]
    if not words:
        return None
    if len(words) == 1:
        w = words[0]
        if w == "true":
            return "$true"
        if w == "false":
            return "$false"
        frags = _ps_frags(w)
        if all(k == "lit" for k, _ in frags):
            return "$true" if "".join(v for _, v in frags) else "$false"
        return "-not [string]::IsNullOrEmpty(%s)" % _ps_word(w)
    if len(words) == 2 and words[0] in ("-z", "-n"):
        e = _ps_word(words[1])
        if words[0] == "-z":
            return "[string]::IsNullOrEmpty(%s)" % e
        return "-not [string]::IsNullOrEmpty(%s)" % e
    if len(words) == 2 and words[0] == "-f":
        return "Test-Path %s -PathType Leaf" % _ps_word(words[1])
    if len(words) == 2 and words[0] == "-e":
        return "Test-Path %s" % _ps_word(words[1])
    if len(words) == 2 and words[0] == "-d":
        return "Test-Path %s -PathType Container" % _ps_word(words[1])
    if len(words) == 2 and words[0] == "-s":
        return "(Get-Item %s).Length -gt 0" % _ps_word(words[1])
    if len(words) == 2 and words[0] in ("-L", "-h"):
        return "(Get-Item %s).LinkType" % _ps_word(words[1])
    if len(words) == 3:
        l, op, r = words
        if op in ("=", "=="):
            if any(ch in r for ch in "*?["):
                return "%s -like %s" % (_ps_word(l), _ps_word(r))
            return "%s -eq %s" % (_ps_word(l), _ps_word(r))
        if op == "!=":
            if any(ch in r for ch in "*?["):
                return "%s -notlike %s" % (_ps_word(l), _ps_word(r))
            return "%s -ne %s" % (_ps_word(l), _ps_word(r))
        if op in ("-eq", "-ne", "-lt", "-le", "-gt", "-ge"):
            # โชคดี: pwsh ใช้ operator ตัวเลขชุดเดียวกับ test ของ bash
            return "%s %s %s" % (_ps_word(l), op, _ps_word(r))
        if op == "=~":
            return "%s -match %s" % (_ps_word(l), _ps_word(r))
    return None


def _ps_cond_atom(a: str) -> tuple[str, bool]:
    """คืน (นิพจน์ pwsh, is_raw) — is_raw=True คือเงื่อนไขเป็นคำสั่ง ต้องดู $?.exit code เอง."""
    t = a.strip()
    if t == "true":
        return "$true", False
    if t == "false":
        return "$false", False
    neg = False
    while t.startswith("!"):
        neg = not neg
        t = t[1:].strip()
    inner = t
    if inner.startswith("[[") and inner.endswith("]]"):
        inner = inner[2:-2].strip()
    elif inner.startswith("[") and inner.endswith("]"):
        inner = inner[1:-1].strip()
    elif inner == "test" or inner.startswith("test "):
        inner = inner[4:].strip()
    while inner.startswith("!") and (len(inner) == 1 or inner[1].isspace()):
        neg = not neg
        inner = inner[1:].strip()
    m = re.fullmatch(r"\(\((.*)\)\)", inner, re.S)
    if m:
        expr = "(" + _arith_to_ps(m.group(1)) + ")"
        return (("(-not %s)" % expr) if neg else expr), False
    conv = _ps_test_expr(inner)
    if conv is None:
        expr = ("-not (%s)" % inner) if neg else inner
        return expr, True
    if neg:
        conv = "-not (%s)" % conv
    return conv, False


def _ps_cond(text: str) -> tuple[str, bool]:
    groups = _split_top(text.strip(), ("||",))
    rendered = []
    raw_any = False
    for g in groups:
        atoms = [x for x in _split_top(g, ("&&",)) if x.strip()]
        parts = []
        for x in atoms:
            e, r = _ps_cond_atom(x)
            raw_any = raw_any or r
            parts.append(e)
        rendered.append(("(" + " -and ".join(parts) + ")") if len(parts) > 1 else parts[0])
    return " -or ".join(rendered), raw_any


def _ps_for_line(rest: str) -> tuple[str, str]:
    m = re.match(r"^(\w+)\s+in\s+(.*)$", rest.strip(), re.S)
    if not m:
        return "foreach ($_ in @()) {", "TODO: แปลง for แบบนี้ไม่ได้"
    var, items = m.group(1), m.group(2).strip()
    pv = "$" + var
    sm = re.fullmatch(r"\$\(\s*seq\s+([^)]+)\)", items)
    if sm:
        nums = sm.group(1).split()
        if len(nums) == 1 and re.fullmatch(r"-?\d+", nums[0]):
            return "foreach (%s in 1..%s) {" % (pv, nums[0]), "$(seq N) -> 1..N (range ของ pwsh)"
        if len(nums) == 2 and all(re.fullmatch(r"-?\d+", x) for x in nums):
            return "foreach (%s in %s..%s) {" % (pv, nums[0], nums[1]), "$(seq A B) -> A..B"
        return "foreach (%s in $(%s)) {" % (pv, items), "seq แบบมี step ซับซ้อน — ตรวจเอง"
    bm = re.fullmatch(r"\{(-?\d+)\.\.(-?\d+)\}", items)
    if bm:
        return "foreach (%s in %s..%s) {" % (pv, bm.group(1), bm.group(2)), "{A..B} -> A..B (ไวยากรณ์เดียวกัน)"
    words = _words(items)
    if not words:
        return "foreach (%s in @()) {" % pv, ""
    exprs = []
    for w in words:
        e = _ps_word(w)
        if any(ch in v for k, v in _ps_frags(w) if k == "lit" for ch in "*?["):
            e = "(Get-ChildItem %s)" % e
        exprs.append(e)
    if len(exprs) == 1:
        return "foreach (%s in %s) {" % (pv, exprs[0]), "for..in -> foreach"
    return "foreach (%s in %s) {" % (pv, ", ".join(exprs)), "for..in -> foreach (array ของ pwsh คั่นด้วย ,)"


def _ps_arith_for(rest: str) -> tuple[str, str]:
    m = re.match(r"^\(\((.*)\)\)$", rest.strip(), re.S)
    if not m:
        return "foreach ($_ in @()) {", "TODO: for แบบ arithmetic"
    pieces = [_x.strip() for _x in _split_top(m.group(1), (";",))]
    if len(pieces) != 3:
        return "foreach ($_ in @()) {", "TODO: for แบบ arithmetic"
    init, cond, step = pieces
    im = re.match(r"^([A-Za-z_]\w*)\s*=\s*(.+)$", init)
    i_txt = ("$%s = %s" % (im.group(1), _arith_to_ps(im.group(2)))) if im else None
    cm = re.match(r"^(.+?)\s*(<=|>=|==|!=|<|>)\s*(.+)$", cond)
    ops = {"<": "-lt", "<=": "-le", ">": "-gt", ">=": "-ge", "==": "-eq", "!=": "-ne"}
    c_txt = (
        "%s %s %s" % (_arith_to_ps(cm.group(1)), ops[cm.group(2)], _arith_to_ps(cm.group(3)))
        if cm
        else None
    )
    sm = re.match(r"^([A-Za-z_]\w*)\s*(\+\+|--)$", step)
    if sm:
        s_txt: str | None = "$%s%s" % (sm.group(1), sm.group(2))
    else:
        am = re.match(r"^([A-Za-z_]\w*)\s*([+\-*/%])=\s*(.+)$", step)
        s_txt = ("$%s %s= %s" % (am.group(1), am.group(2), _arith_to_ps(am.group(3)))) if am else None
    if not (i_txt and c_txt and s_txt):
        return "foreach ($_ in @()) {", "TODO: for แบบ arithmetic"
    return "for (%s; %s; %s) {" % (i_txt, c_txt, s_txt), "for ((;;)) -> for (;;) (< เป็น -lt)"


def _ps_echo(args_text: str) -> tuple[str, str]:
    words = _words(args_text)
    nl, interp = True, False
    while words and words[0] in ("-n", "-e", "-E", "--"):
        if words[0] == "-n":
            nl = False
        if words[0] == "-e":
            interp = True
        words.pop(0)
    if not words:
        return 'Write-Output ""', ""
    combined = _ps_join_words(words, interpret=interp)
    notes = []
    if interp:
        notes.append("echo -e ตีความ \\n -> `n ของ pwsh")
    if nl:
        base = "Write-Output %s" % combined
        notes.append("echo -> Write-Output")
    else:
        base = "Write-Host -NoNewline %s" % combined
        notes.append("echo -n -> Write-Host -NoNewline (Write-Output ไม่มี -NoNewline)")
    return base, "; ".join(notes)


_PRINTF_FMT_RE = re.compile(r"%([-+0-9.]*)([sdiufc%])")


def _ps_printf(args_text: str) -> tuple[str, str] | None:
    words = _words(args_text)
    if not words:
        return 'Write-Output ""', ""
    fmt_lit = _lit_content(words[0])
    args = words[1:]
    if fmt_lit is None:
        return None  # fmt มี expansion — ให้ caller ส่งผ่านพร้อม note
    f = fmt_lit.replace(r'\"', '"').replace(r"\'", "'")
    f = f.replace("`", "``").replace('"', '`"')
    f = (
        f.replace("\\\\", "\x00")
        .replace("\\n", "`n")
        .replace("\\t", "`t")
        .replace("\\r", "`r")
        .replace("\x00", "\\")
    )
    idx = [0]

    def _sub(m: re.Match) -> str:
        if m.group(2) == "%":
            return "%"
        out = "{%d}" % idx[0]
        idx[0] += 1
        return out

    f2, nsub = _PRINTF_FMT_RE.subn(_sub, f)
    notes = ["printf -> Write-Host -NoNewline + -f ({0} แทน %s)", "\\n -> `n"]
    if "%" in f2:
        notes.append("เหลือ % แบบที่แปลงไม่ได้ (%q/%x/...) — ตรวจเอง")
    if args and len(args) != nsub:
        notes.append("bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง")
    dq = '"' + f2.replace("$", "`$") + '"'
    if not args:
        return "Write-Host -NoNewline %s" % dq, "; ".join(notes)
    return "Write-Host -NoNewline (%s -f %s)" % (dq, ", ".join(_ps_word(w) for w in args)), "; ".join(notes)


def _ps_simple_cmd(s: str) -> tuple[str, str] | None:
    """คำสั่งเดี่ยว bash -> pwsh (None = ไม่รู้จัก ให้ส่งผ่านตรง)."""
    words = _words(s)
    if not words:
        return None
    cmd, rest = words[0], s[len(words[0]) :].strip()

    if cmd == "echo":
        return _ps_echo(rest)
    if cmd == "printf":
        conv = _ps_printf(rest)
        if conv is not None:
            return conv
        return None
    if cmd == "pwd":
        return "Get-Location", "pwd -> Get-Location"
    if cmd == "cd":
        targets = _words(rest)
        if not targets:
            return "Set-Location ~", "cd (ไม่มี arg) -> Set-Location ~ (home)"
        if len(targets) == 1 and targets[0] == "-":
            return 'Set-Location -', "cd - -> Set-Location - (กลับที่เดิม)"
        return "Set-Location %s" % _ps_word(targets[0]), "cd -> Set-Location"
    if cmd == "cat" and rest and not rest.startswith("-"):
        ops = _words(rest)
        if len(ops) == 1:
            return "Get-Content %s" % _ps_word(ops[0]), "cat -> Get-Content (ไฟล์ใหญ่เติม -Raw)"
    if cmd == "cp":
        flags, ops = _shell_words(rest)
        if len(ops) == 2:
            rec = any("r" in f.lstrip("-") or "a" in f.lstrip("-") for f in flags)
            a, b = (_ps_word(x) for x in ops)
            if rec:
                return "Copy-Item -Recurse %s %s" % (a, b), "cp -r -> Copy-Item -Recurse"
            return "Copy-Item %s %s" % (a, b), "cp -> Copy-Item"
    if cmd == "mv":
        _flags, ops = _shell_words(rest)
        if len(ops) == 2:
            a, b = (_ps_word(x) for x in ops)
            return "Move-Item %s %s" % (a, b), "mv -> Move-Item"
    if cmd == "rm":
        flags, ops = _shell_words(rest)
        if ops:
            rec = any("r" in f.lstrip("-") for f in flags)
            force = any("f" in f.lstrip("-") for f in flags)
            extra = "".join([" -Recurse" if rec else "", " -Force" if force else ""])
            return "Remove-Item%s %s" % (extra, " ".join(_ps_word(t) for t in ops)), \
                "rm -> Remove-Item (-r=-Recurse, -f=-Force)"
    if cmd == "mkdir":
        flags, ops = _shell_words(rest)
        if ops:
            force = " -Force" if ("p" in "".join(flags) or "-p" in flags) else ""
            calls = ["New-Item -ItemType Directory%s %s" % (force, _ps_word(t)) for t in ops]
            return "; ".join(calls), "mkdir -p -> New-Item -ItemType Directory -Force"
    if cmd == "touch":
        _flags, ops = _shell_words(rest)
        if ops:
            calls = ["New-Item -ItemType File %s" % _ps_word(t) for t in ops]
            return "; ".join(calls), "touch -> New-Item -ItemType File"
    if cmd == "which":
        _flags, ops = _shell_words(rest)
        if len(ops) == 1:
            return "Get-Command %s" % _ps_word(ops[0]), "which -> Get-Command"
    if cmd in ("ls", "ll", "la"):
        return None  # Get-ChildItem ก็ได้ แต่ alias ls มีใน pwsh อยู่แล้ว ส่งผ่านตรง
    if cmd == "exit":
        args = _words(rest)
        if not args:
            return "exit", "exit เหมือนกัน"
        return "exit %s" % _ps_word(args[0]), "exit เหมือนกัน"
    if cmd == "return":
        args = _words(rest)
        if not args:
            return "return", "return เหมือนกัน"
        return "return %s" % _ps_word(args[0]), "return เหมือนกัน"
    if cmd in ("break", "continue"):
        return cmd, "ชื่อเหมือนกันใน pwsh"
    if cmd == "true":
        return "$true", "true -> $true"
    if cmd == "false":
        return "$false", "false -> $false"
    if cmd in ("source", "."):
        args = _words(rest)
        if len(args) == 1:
            return ". %s" % _ps_word(args[0]), "source -> . (dot-sourcing เหมือนกัน)"
    if cmd == "read":
        args = _words(rest)
        prompt = ""
        names: list[str] = []
        skip = False
        for w in args:
            if skip:
                skip = False
                continue
            if w == "-p":
                skip = True
                continue
            if w.startswith("-"):
                continue
            if w == "-p":
                continue
            names.append(w)
        # ดึง prompt แบบง่าย: read -p "msg" var
        pm = re.search(r'-p\s+("[^"]*"|\'[^\']*\'|\S+)', rest)
        if pm:
            prompt = " %s" % _ps_word(pm.group(1))
        if len(names) == 1 and re.fullmatch(r"[A-Za-z_]\w*", names[0]):
            return "$%s = Read-Host%s" % (names[0], prompt), "read -> Read-Host"
        return None
    if cmd == "let":
        body = rest.strip().strip('"').strip("'")
        if "=" in body:
            k, _, v = body.partition("=")
            k = k.strip()
            if re.fullmatch(r"[A-Za-z_]\w*", k):
                return "$%s = %s" % (k, _arith_to_ps(_VAR_RE.sub(lambda m: m.group(1) or m.group(2), v))), \
                    "let -> $x = (...) (คำนวณ)"
        return None
    if cmd == "test":
        conv = _ps_test_expr(rest)
        if conv is not None:
            return conv, "test ... -> นิพจน์ pwsh (Test-Path/-eq/...) ตรงๆ"
        return None
    if cmd == "export":
        m = _ASSIGN_RE.match(rest)
        if m and m.group(2) == "=":
            return "$env:%s = %s" % (m.group(1), _ps_word(m.group(3).strip())), \
                "export -> $env:VAR (ตัวแปรสภาพแวดล้อมของ pwsh)"
        if re.fullmatch(r"[A-Za-z_]\w*", rest.strip()):
            return "# TODO: 'export %s' ไม่มีค่าใหม่ — pwsh ใช้ $env:%s (มีอยู่แล้ว)" % (rest.strip(), rest.strip()), ""
        return None
    if cmd == "unset":
        args = _words(rest)
        if len(args) == 1 and re.fullmatch(r"[A-Za-z_]\w*", args[0]):
            return "Remove-Variable %s -ErrorAction SilentlyContinue" % args[0], \
                "unset -> Remove-Variable"
        return None
    if cmd == "set":
        flags = rest.strip()
        if flags in ("-e", "-o pipefail"):
            return '$ErrorActionPreference = "Stop"', "set -e -> $ErrorActionPreference = 'Stop'"
        if flags == "-u":
            return "Set-StrictMode -Version Latest", "set -u -> Set-StrictMode (ใช้ตัวแปรก่อนกำหนดแล้ว error)"
        if flags == "-x":
            return "Set-PSDebug -Trace 1", "set -x -> Set-PSDebug -Trace 1"
        if flags in ("+e", "+u", "+x"):
            return "# TODO: '%s' ปิด strict/debug — pwsh เปิดแล้วปิดยาก (%s)" % (rest, rest), ""
        return "# TODO: 'set %s' ไม่มีใน pwsh ตรงตัว: %s" % (flags, s), ""
    if cmd in ("trap", "shift", "ulimit", "umask", "alias", "unalias", "shopt", "bind", "history"):
        return "# TODO: '%s' ไม่มีใน pwsh ตรงตัว: %s" % (cmd, s), ""
    if cmd == "select":
        return "# TODO: 'select' เมนูของ bash ไม่มีใน pwsh ตรงตัว (ใช้ Read-Host + switch): %s" % s, ""
    return None


def _ps_stmt(s: str) -> tuple[str, str]:
    """bash 1 statement -> (โค้ด pwsh, note) — โค้ดอาจมีหลายบรรทัด (\\n) ได้."""
    t = s.strip()
    if not t:
        return "", ""
    if t.startswith("#"):
        return t, ""

    m = re.match(r"^(?:local|declare|readonly|export)\s+(.*)$", t)
    prefix = ""
    if m:
        prefix, t = t.split(None, 1)[0], m.group(1).strip()

    # ((i++)) / ((a = b + 1))
    m = re.fullmatch(r"\(\((.*)\)\)", t, re.S)
    if m:
        body = m.group(1).strip()
        mm = re.match(r"^(\w+)\s*(\+\+|--)$", body)
        if mm:
            return "$%s%s" % (mm.group(1), mm.group(2)), "((i++)) -> $i++ (เหมือนกัน)"
        mm = re.match(r"^(\w+)\s*([+\-*/%])=\s*(.+)$", body)
        if mm:
            return "$%s %s= %s" % (mm.group(1), mm.group(2), _arith_to_ps(mm.group(3))), \
                "((x += 1)) -> $x += 1"
        mm = re.match(r"^(\w+)\s*=\s*(.+)$", body)
        if mm:
            return "$%s = %s" % (mm.group(1), _arith_to_ps(mm.group(2))), "((x = ...)) -> $x = ..."
        return t, "TODO: นิพจน์ ((...)) แบบนี้ต้องตรวจเอง"

    # assignment (รวม export/local ที่ปอก prefix แล้ว)
    m = _ASSIGN_RE.match(t)
    if m and m.group(1) not in ("true", "false"):
        name, op, value = m.group(1), m.group(2), m.group(3).strip()
        expr = _ps_word(value)
        notes = []
        if prefix == "export":
            left = "$env:%s" % name
            notes.append("export -> $env:VAR")
        elif prefix == "readonly":
            left = "$%s" % name
            notes.append("readonly ไม่มีตรงตัว — ตรวจว่าห้ามแก้เอง (pwsh: Set-Variable -Option ReadOnly)")
        elif prefix == "local":
            left = "$%s" % name
            notes.append("local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)")
        else:
            left = "$%s" % name
            notes.append("กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)")
        if op == "+=":
            code = "%s += %s" % (left, expr)
        else:
            code = "%s = %s" % (left, expr)
        if _ps_has_raw(value):
            notes.append("${..:-..} / $! แบบซับซ้อนต้องแปลงเอง")
        if "${#" in value:
            notes.append("${#VAR} -> ($VAR.Length)")
        if "??" in expr:
            notes.append("${..:-def} -> ?? (null-coalescing ของ PS 7+)")
        if "**" in value:
            notes.append("** (ยกกำลัง) pwsh ไม่รองรับตรงๆ — ใช้ [math]::Pow()")
        return code, "; ".join(notes)

    # pipe / redirect / && || / background
    ops = _top_ops(t, (">>", ">", "<", "|", "&&", "||", "&"))
    if ops:
        wm = re.match(r"^(echo|printf)\s+(.*?)\s*(>>?)\s*(\S+)$", t, re.S)
        if wm and set(ops) <= {">", ">>"}:
            mode = ">>" if wm.group(3) == ">>" else ">"
            if wm.group(1) == "echo":
                body, _n = _ps_echo(wm.group(2))
                bm = re.match(r"^(Write-Output|Write-Host -NoNewline)\s+(.*)$", body, re.S)
                inner = bm.group(2) if bm else _ps_join_words(_words(wm.group(2)))
            else:
                conv = _ps_printf(wm.group(2))
                inner = conv[0].split(None, 1)[1] if conv and " " in conv[0] else _ps_join_words(_words(wm.group(2)))
            return "Write-Output %s %s %s" % (inner, mode, _ps_word(wm.group(4))), \
                "redirect >/>> เหมือน bash (แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง)"
        notes = []
        if "<" in ops:
            notes.append("pwsh ไม่มี < (input redirect) — ใช้ Get-Content file | cmd แทน")
        if ">" in ops or ">>" in ops:
            notes.append(">/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง")
        if "&&" in ops or "||" in ops:
            notes.append("&&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้ ; if ($?) แทน)")
        if t.rstrip().endswith("&") and not t.rstrip().endswith("&&"):
            notes.append("background (&) ของ bash -> pwsh ใช้ Start-Job -ScriptBlock {...}")
        if re.search(r"\$\d|\$[@*#]", t):
            notes.append("$1/$@/$# -> $args[0]/$args/$args.Count")
        if "$!" in t:
            notes.append("$! (pid job ล่าสุด) ไม่มีตรงตัว — ตรวจเอง")
        notes.append("คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)")
        return t, "; ".join(notes)

    simple = _ps_simple_cmd(t)
    if simple is not None:
        return simple
    # ไม่รู้จัก -> ส่งผ่านตรง (pwsh เป็น shell รัน native ได้)
    notes = ["ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)"]
    if re.search(r"\$\d|\$[@*#]", t):
        notes.append("$1/$@/$# -> $args[0]/$args/$args.Count")
    if ";;" in t:
        notes.append(";; เป็นของ case — อยู่นอก case ต้องเอาออก")
    return t, "; ".join(notes)


def _merge_notes(*parts: str) -> str:
    segs: list[str] = []
    for p in parts:
        for seg in p.split("; "):
            seg = seg.strip()
            if seg and seg not in segs:
                segs.append(seg)
    return "; ".join(segs)


_PS_STMT_NOTES: list[tuple[re.Pattern, str]] = [
    (re.compile(r"^select\b"), "select ไม่มีใน pwsh ตรงตัว"),
]

_PS_STRUCT_NOTES = {
    "then": "then -> {",
    "do": "do -> {",
    "else": "else -> } else {",
    "fi": "จบ if — pwsh ปิดด้วย } แทน fi",
    "done": "จบ loop — pwsh ปิดด้วย } แทน done",
    "func_end": "จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)",
    "esac": "จบ case — pwsh ปิด switch ด้วย } แทน esac",
}


def _ps_bash_var_note(s: str) -> str:
    """note ตัวแปรเฉพาะ bash ($USER/$RANDOM/...) — เช็คเสมอกันพลาด."""
    for vm in re.finditer(r"\$(?:\{)?([A-Za-z_]\w*)\}?", s):
        if vm.group(1) in _PS_BASH_ONLY_VARS:
            return "bash $%s ไม่มีใน pwsh ตรงๆ — ใช้ %s" % (vm.group(1), _PS_BASH_ONLY_VARS[vm.group(1)])
    return ""


def _ps_note_for_stmt(s: str, ps: str) -> str:
    notes: list[str] = []
    for rx, txt in _PS_STMT_NOTES:
        if rx.search(s):
            notes.append(txt)
            break
    if "$args" in ps and re.search(r"\$\d|\$[@*#]", s):
        notes.append("$1/$@/$# -> $args[0]/$args/$args.Count")
    if "Get-ChildItem" in ps:
        notes.append("glob -> Get-ChildItem")
    if ".." in ps and ("seq" in s or ".." in s):
        notes.append("seq/{A..B} -> range A..B")
    return "; ".join(notes)


def _split_stmts(code_part: str) -> list[str]:
    """split `;` ระดับบน แต่ข้าม `;` ที่อยู่ใน $((...)) / $(...) (เช่น for ((i=0; i<3; i++)))."""
    buf: list[str] = []
    i, n = 0, len(code_part)
    q = None
    while i < n:
        c = code_part[i]
        if q:
            buf.append(c)
            if c == "\\" and q == '"' and i + 1 < n:
                buf.append(code_part[i + 1])
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if c in "'\"":
            q = c
            buf.append(c)
            i += 1
            continue
        if code_part.startswith("$((", i):
            j = code_part.find("))", i + 3)
            if j == -1:
                buf.append(c)
                i += 1
                continue
            buf.append(code_part[i : j + 2].replace(";", "\x01"))
            i = j + 2
            continue
        if code_part.startswith("((", i):
            # arithmetic/command group เปลือย เช่น for ((i=0; i<3; i++))
            j = code_part.find("))", i + 2)
            if j == -1:
                buf.append(c)
                i += 1
                continue
            buf.append(code_part[i : j + 2].replace(";", "\x01"))
            i = j + 2
            continue
        if code_part.startswith("$(", i):
            depth, j, sq = 1, i + 2, None
            while j < n and depth:
                ch = code_part[j]
                if sq:
                    if ch == sq and code_part[j - 1] != "\\":
                        sq = None
                elif ch in "'\"":
                    sq = ch
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                j += 1
            if depth == 0:
                buf.append(code_part[i:j].replace(";", "\x01"))
                i = j
                continue
            buf.append(c)
            i += 1
            continue
        buf.append(c)
        i += 1
    return [p.replace("\x01", ";") for p in _split_top("".join(buf), (";",))]


_PS_BASH_ONLY_VARS = {
    "USER": "$env:USERNAME",
    "HOSTNAME": "$(hostname)",
    "UID": "ไม่มีตรงตัว (ใช้ id -u)",
    "EUID": "ไม่มีตรงตัว (ใช้ id -u)",
    "RANDOM": "Get-Random",
    "OSTYPE": "$PSVersionTable.OS",
    "MACHTYPE": "ไม่มีตรงตัว",
    "BASH_VERSION": "$PSVersionTable.PSVersion",
    "FUNCNAME": "$MyInvocation.MyCommand.Name",
    "OLDPWD": "ไม่มีตรงตัว (ใช้ Get-Location -Stack)",
}


@register("bash", "powershell")
def bash_to_pwsh(code: str, headers: bool = True, notes: bool = True) -> str:
    out: list[str] = []
    depth = 0
    pending: tuple[str, str] | None = None
    stack: list[str] = []
    case_subj: str | None = None
    case_base: int | None = None
    branch_body = False  # มีคำสั่งใน branch ปัจจุบันของ switch แล้วหรือยัง
    branch_fall = False  # branch นี้ตั้งใจ fallthrough (; &) — ไม่ต้อง break
    pending_header: str | None = None

    def emit(text: str):
        nonlocal pending_header
        if pending_header is not None:
            out.append("    " * depth + "# bash: " + pending_header.strip())
            pending_header = None
        out.append("    " * depth + text)

    def emit_raw(text: str, d: int):
        out.append("    " * d + text)

    def emit_note(text: str):
        if notes and text:
            emit("# -> " + text)

    def attach(ps: str, note: str) -> str:
        if notes and note:
            first, _, rest = ps.partition("\n")
            first = first + "  # " + note
            return first + (("\n" + rest) if rest else "")
        return ps

    def emit_stmt(ps: str, note: str):
        for i, ln in enumerate(ps.split("\n")):
            emit(attach(ln, note) if i == 0 else ln)

    def close_branch():
        """ปิด branch ของ switch: break (แทน ;;) + } ปิด { ของ branch."""
        nonlocal branch_body, branch_fall, pending_header, depth
        if case_base is None:
            branch_body = False
            branch_fall = False
            return
        if branch_body:
            if not branch_fall:
                saved, pending_header = pending_header, None
                emit_raw("break" + ("  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)" if notes else ""), depth)
                pending_header = saved
            emit_raw("}", case_base)  # ปิด { ของ "pattern" {
            depth = case_base
        branch_body = False
        branch_fall = False
        branch_body = False
        branch_fall = False

    def flush_open(kind: str, text: str):
        nonlocal depth
        if kind == "if":
            cond, raw = _ps_cond(text)
            note = "if ...; then -> if (...) {"
            if raw:
                note += "; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง"
            emit(attach("if (%s) {" % cond, note))
            stack.append("if")
        elif kind == "elif":
            depth = max(depth - 1, 0)
            cond, raw = _ps_cond(text)
            note = "elif ...; then -> } elseif (...) {"
            if raw:
                note += "; เงื่อนไขเป็นคำสั่ง — ดู $? เอง"
            emit(attach("} elseif (%s) {" % cond, note))
            depth += 1
            return
        elif kind == "while":
            cond, raw = _ps_cond(text)
            note = "while ...; do -> while (...) {"
            if raw:
                note += "; เงื่อนไขเป็นคำสั่ง — ดู $? เอง"
            emit(attach("while (%s) {" % cond, note))
            stack.append("while")
        elif kind == "until":
            cond, raw = _ps_cond(text)
            note = "until ...; do -> while (-not (...)) { (pwsh ไม่มี until)"
            if raw:
                note += "; เงื่อนไขเป็นคำสั่ง — ดู $? เอง"
            emit(attach("while (-not (%s)) {" % cond, note))
            stack.append("while")
        elif kind == "for":
            line, note = _ps_for_line(text)
            emit(attach(line, note))
            stack.append("for")
        elif kind == "forarith":
            line, note = _ps_arith_for(text)
            emit(attach(line, note))
            stack.append("for")
        depth += 1

    # logical lines (join "\")
    logical: list[str] = []
    buf = ""
    for raw in code.splitlines():
        line = raw.rstrip()
        if line.endswith("\\"):
            buf += line[:-1] + " "
            continue
        logical.append(buf + line)
        buf = ""
    if buf:
        logical.append(buf)

    for line in logical:
        if not line.strip():
            pending_header = None
            out.append("")
            continue
        code_part, _inline = _split_comment(line)
        if not code_part.strip():
            stripped = line.strip()
            if re.match(r"^#!.*\b(bash|sh|zsh)\b", stripped):
                if headers:
                    out.append("    " * depth + "# bash: " + stripped)
                emit(_PS_SHEBANG)
                continue
            pending_header = None
            emit(stripped)
            continue
        pending_header = line if headers else None

        queue = _split_stmts(code_part)
        while queue:
            s = queue.pop(0).strip()
            if not s:
                continue

            # then/do ต่อด้วยคำสั่งในบรรทัดเดียว (do echo hi; done ถูก bash)
            mtd = re.match(r"^(then|do)(?=\s)(.*)$", s, re.S)
            if mtd and pending:
                kind = mtd.group(1)
                if kind == "then" or pending[0] in ("while", "until", "for", "forarith"):
                    flush_open(*pending)
                    pending = None
                    rest = mtd.group(2).strip()
                    if rest:
                        queue.insert(0, rest)
                    continue

            if pending and s not in ("then", "do") and not s.startswith(("elif ", "fi", "done", "esac")):
                pending = (pending[0], pending[1] + " " + s)
                continue

            if s == "then":
                if pending:
                    flush_open(*pending)
                    pending = None
                continue
            if s == "do":
                if pending and pending[0] in ("while", "until", "for", "forarith"):
                    flush_open(*pending)
                    pending = None
                continue

            m = re.match(r"^(if|elif)\s+(.*)$", s, re.S)
            if m:
                pending = (m.group(1), m.group(2))
                continue
            m = re.match(r"^while\s+(.*)$", s, re.S)
            if m:
                pending = ("while", m.group(1))
                continue
            m = re.match(r"^until\s+(.*)$", s, re.S)
            if m:
                pending = ("until", m.group(1))
                continue
            m = re.match(r"^for\s+(.*)$", s, re.S)
            if m:
                pending = ("forarith" if m.group(1).strip().startswith("((") else "for", m.group(1))
                continue
            if s == "else":
                depth = max(depth - 1, 0)
                emit(attach("} else {", _PS_STRUCT_NOTES["else"]))
                depth += 1
                continue
            if s == "fi":
                depth = max(depth - 1, 0)
                if stack and stack[-1] == "if":
                    stack.pop()
                emit_note(_PS_STRUCT_NOTES["fi"])
                emit("}")
                continue
            if s == "done":
                depth = max(depth - 1, 0)
                if stack and stack[-1] in ("while", "for"):
                    stack.pop()
                emit_note(_PS_STRUCT_NOTES["done"])
                emit("}")
                continue
            if s == "esac":
                close_branch()
                depth = max(case_base - 1, 0) if case_base is not None else max(depth - 1, 0)
                if stack and stack[-1] == "switch":
                    stack.pop()
                case_subj = None
                case_base = None
                emit_note(_PS_STRUCT_NOTES["esac"])
                emit("}")
                continue

            # case
            m = re.match(r"^case\s+(.*)\s+in$", s, re.S)
            if m:
                case_subj = _ps_word(m.group(1))
                emit(attach("switch -Wildcard (%s) {" % case_subj,
                            "case -> switch -Wildcard (glob * ใช้ได้เลย)"))
                stack.append("switch")
                case_base = depth + 1
                depth = case_base
                branch_body = False
                branch_fall = False
                continue
            m = re.match(r"^([^\s()]+)\)\s*(.*)$", s, re.S)
            if m and case_subj is not None:
                close_branch()
                base = case_base if case_base is not None else depth
                depth = base
                pats_text, rest = m.group(1), m.group(2).strip()
                pats = [p.strip() for p in pats_text.split("|")]
                if pats == ["*"]:
                    emit(attach("default {", "*) -> default"))
                elif len(pats) == 1:
                    emit(attach("%s {" % _ps_word(pats[0]), "pattern) -> \"...\" {"))
                else:
                    cond = " -or ".join("$_ -eq %s" % _ps_word(p) for p in pats)
                    emit(attach("{ %s } {" % cond, "a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)"))
                depth = base + 1
                branch_body = False
                branch_fall = False
                if rest:
                    for ender in (";;&", ";&", ";;"):
                        if rest.endswith(ender):
                            rest = rest[: -len(ender)].strip()
                            if ender != ";;":
                                branch_fall = True
                            break
                    if rest:
                        ps, note = _ps_stmt(rest)
                        if ps and not ps.startswith("# TODO"):
                            branch_body = True
                        if not note or "ส่งผ่านตรง" in note or ps.startswith("# TODO"):
                            extra = _ps_note_for_stmt(rest, ps)
                        else:
                            extra = ""
                        emit_stmt(ps, _merge_notes(note, extra, _ps_bash_var_note(rest)))
                continue
            if s in (";;", ";&", ";;&"):
                if case_subj is not None:
                    if s != ";;":
                        branch_fall = True
                    pending_header = None
                    if s != ";;" and notes:
                        emit("# -> %s ตั้งใจ fallthrough — pwsh ไม่ต้อง break" % s)
                    continue

            # function / block
            m = re.match(r"^(?:function\s+)?([A-Za-z_]\w*)\s*\(\s*\)\s*\{(.*)$", s) or re.match(
                r"^function\s+([A-Za-z_]\w*)\s*\{(.*)$", s
            )
            if m:
                emit(attach("function %s {" % m.group(1), "ฟังก์ชัน bash -> function name {"))
                stack.append("func")
                depth += 1
                rest = m.group(2).strip()
                if rest:
                    queue.insert(0, rest)
                continue
            if s == "{":
                emit(attach("& {", "group { } -> & { } (script block แล้วรัน)"))
                stack.append("group")
                depth += 1
                continue
            if s == "}":
                depth = max(depth - 1, 0)
                if stack and stack[-1] in ("func", "group"):
                    stack.pop()
                emit_note(_PS_STRUCT_NOTES["func_end"])
                emit("}")
                continue

            ps, note = _ps_stmt(s)
            if not ps:
                continue
            if case_subj is not None and case_base is not None and depth >= case_base + 1:
                if ps and not ps.startswith("# TODO") and not ps.startswith("# bash"):
                    branch_body = True
            if not note or "ส่งผ่านตรง" in note or ps.startswith("# TODO"):
                extra = _ps_note_for_stmt(s, ps)
            else:
                extra = ""
            emit_stmt(ps, _merge_notes(note, extra, _ps_bash_var_note(s)))

    body = "\n".join(out)
    if not headers:
        body = "\n".join(ln for ln in body.splitlines()
                         if not ln.strip().startswith("# bash: "))
    if not any(ln.startswith("#!") for ln in body.splitlines()[:3]):
        body = _PS_SHEBANG + "\n" + body
    return body + "\n"


# ==========================================================================
# powershell -> bash
# ==========================================================================

def _ps_split_comment(line: str) -> tuple[str, str]:
    """แยก comment (#) ของ pwsh — # ใน '...' / "..." ไม่ใช่ comment."""
    i, n = 0, len(line)
    q = None
    while i < n:
        c = line[i]
        if q:
            if c == "`" and q == '"' and i + 1 < n:
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if c in "'\"":
            q = c
            i += 1
            continue
        if c == "#":
            return line[:i].rstrip(), line[i:]
        i += 1
    return line, ""


def _ps_to_bash_vars(line: str) -> tuple[str, bool]:
    """แปลง $ ตัวแปร pwsh -> bash นอก '...' (คืน text, มี $_ ที่ต้องตรวจเองไหม)."""
    out: list[str] = []
    has_us = False
    i, n = 0, len(line)
    q = None
    while i < n:
        c = line[i]
        if q == "'":
            if c == "'":
                if line.startswith("''", i):
                    out.append("''")
                    i += 2
                    continue
                q = None
            out.append(c)
            i += 1
            continue
        if q is None and c == "'":
            q = "'"
            out.append(c)
            i += 1
            continue
        if c == '"' and q is None:
            q = '"'
            out.append(c)
            i += 1
            continue
        if c == '"' and q == '"':
            q = None
            out.append(c)
            i += 1
            continue
        if c == "`" and q == '"':
            # escape ใน "..." ของ pwsh -> escape ของ bash "..."
            nxt = line[i + 1] if i + 1 < n else ""
            conv = {"n": "\\n", "t": "\\t", "r": "\\r", "`": "`", '"': '\\"', "$": "\\$"}
            if nxt in conv:
                out.append(conv[nxt])
                i += 2
                continue
            if nxt == "\n":
                i += 2  # continuations: ตัดทิ้ง
                continue
            out.append(c)
            i += 1
            continue
        if c == "$":
            m = re.match(r"\$args\[(\d+)\]", line[i:])
            if m:
                out.append("$%d" % (int(m.group(1)) + 1))
                i += len(m.group(0))
                continue
            if line.startswith("$args.Count", i):
                out.append("$#")
                i += len("$args.Count")
                continue
            if re.match(r"\$args(?![\w.])", line[i:]):
                out.append("$@")
                i += len("$args")
                continue
            m = re.match(r"\$env:([A-Za-z_]\w*)", line[i:])
            if m:
                name = m.group(1)
                out.append("$USER" if name == "USERNAME" else "$" + name)
                i += len(m.group(0))
                continue
            m = re.match(r"\$\{env:([^}]*)\}", line[i:])
            if m:
                out.append("$" + m.group(1))
                i += len(m.group(0))
                continue
            for pw, ba in (("$PSCommandPath", "$0"), ("$PSScriptRoot", "$0"),
                           ("$LASTEXITCODE", "$?"), ("$PID", "$$"),
                           ("$PSVersionTable", "$BASH_VERSION")):
                if line.startswith(pw, i):
                    out.append(ba)
                    i += len(pw)
                    break
            else:
                if line.startswith("$null", i) and not re.match(r"\$null[\w]", line[i:]):
                    out.append('""')
                    i += len("$null")
                    continue
                if line.startswith("$_", i) and not re.match(r"\$_[\w]", line[i:]):
                    has_us = True
                    out.append("$_")
                    i += 2
                    continue
                out.append(c)
                i += 1
                continue
            continue
        out.append(c)
        i += 1
    return "".join(out), has_us


def _ps_strip_outer_parens(t: str) -> str:
    t = t.strip()
    while len(t) >= 2 and t.startswith("(") and t.endswith(")"):
        depth, ok = 0, True
        q = None
        for idx, ch in enumerate(t):
            if q:
                if ch == q:
                    q = None
                continue
            if ch in "'\"":
                q = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0 and idx != len(t) - 1:
                    ok = False
                    break
        if not ok or depth != 0:
            break
        t = t[1:-1].strip()
    return t


def _ps_split_bool(text: str) -> list[tuple[str, str | None]]:
    """split -or / -and ระดับบน (case-insensitive, นอก quote)."""
    parts: list[tuple[str, str | None]] = []
    buf: list[str] = []
    i, n = 0, len(text)
    q = None
    while i < n:
        c = text[i]
        if q:
            buf.append(c)
            if c == "`" and i + 1 < n:
                buf.append(text[i + 1])
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if c in "'\"":
            q = c
            buf.append(c)
            i += 1
            continue
        m = re.match(r"\s+-(or|and)\s+", text[i:], re.I)
        if m:
            parts.append(("".join(buf), m.group(1).lower()))
            buf = []
            i += m.end()
            continue
        buf.append(c)
        i += 1
    parts.append(("".join(buf), None))
    return parts


_PS_CMP_SPLIT = ("-eq", "-ne", "-lt", "-le", "-gt", "-ge", "-match", "-notmatch", "-like", "-notlike")


def _ps_catom_to_bash(a: str) -> tuple[str, bool]:
    """atom เงื่อนไข pwsh -> bash (คืน text, is_raw)."""
    t = a.strip()
    neg = False
    while True:
        if t.startswith("!"):
            neg = not neg
            t = t[1:].strip()
            continue
        if re.match(r"(?i)^-not\b", t):
            neg = not neg
            t = re.sub(r"(?i)^-not\b", "", t, count=1).strip()
            continue
        break
    t = _ps_strip_outer_parens(t)
    if t == "$true":
        return ("! true" if neg else "true"), False
    if t == "$false":
        return ("! false" if neg else "false"), False

    m = re.match(r"(?i)^Test-Path\s+(.*)$", t, re.S)
    if m:
        arg = m.group(1).strip()
        is_dir = bool(re.search(r"(?i)-PathType\s+(Container|Directory)\b", arg))
        is_file = bool(re.search(r"(?i)-PathType\s+Leaf\b", arg))
        arg = re.sub(r"(?i)\s*-PathType\s+\w+", "", arg).strip()
        arg = _ps_to_bash_vars(arg)[0]
        op = "-d" if is_dir else ("-f" if is_file else "-e")
        cond = "[ %s %s ]" % (op, arg)
        return (("! %s" % cond) if neg else cond), False

    m = re.fullmatch(r"\[string\]::IsNullOrEmpty\((.*)\)", t, re.S)
    if m:
        arg = _ps_to_bash_vars(m.group(1).strip())[0]
        cond = '[ -z "%s" ]' % arg if not arg.startswith('"') else "[ -z %s ]" % arg
        if neg:
            cond = cond.replace("-z", "-n", 1)
        return cond, False

    for op in _PS_CMP_SPLIT:
        # split นอก quote และต้องมีช่องว่างขนาบ (กัน -order ฯลฯ) + รับตัวพิมพ์ใหญ่
        use = [p for p in _split_top(t, (" " + op + " ", " " + op.upper() + " ")) if p.strip()]
        if len(use) == 2 and all(p.strip() for p in use):
            l, r = (x.strip() for x in use)
            if op in ("-match", "-notmatch"):
                l2 = _ps_to_bash_vars(l)[0]
                r2 = _ps_to_bash_vars(r)[0].strip("\"'")
                cond = "[[ %s =~ %s ]]" % (l2, r2)
                if op == "-notmatch":
                    cond = "! " + cond
            elif op in ("-like", "-notlike"):
                l2 = _ps_to_bash_vars(l)[0]
                r2 = _ps_to_bash_vars(r)[0].strip("\"'")
                cond = "[[ %s == %s ]]" % (l2, r2)
                if op == "-notlike":
                    cond = "! " + cond
            else:
                l2 = _ps_to_bash_vars(l)[0]
                r2 = _ps_to_bash_vars(r)[0]
                if re.fullmatch(r'\$null|""|\'\'', r.strip()):
                    cond = '[ -z "%s" ]' % l2 if op == "-eq" else '[ -n "%s" ]' % l2
                else:
                    cond = "[ %s %s %s ]" % (l2, op, r2)
            return (("! %s" % cond) if neg else cond), False

    if re.fullmatch(r"\$[A-Za-z_]\w*(\[\d+\])?", t):
        arg = _ps_to_bash_vars(t)[0]
        cond = '[ -n "%s" ]' % arg
        return (("! %s" % cond) if neg else cond), False
    if re.fullmatch(r'"(?:[^"\\]|\\.)*"', t) or re.fullmatch(r"'(?:[^']|'')*'", t):
        arg = _ps_to_bash_vars(t)[0]
        cond = "[ -n %s ]" % arg
        return (("! %s" % cond) if neg else cond), False

    raw, has_us = _ps_to_bash_vars(t)
    cond = '[ -n "$(%s)" ]' % raw
    return (("! %s" % cond) if neg else cond), True


def _ps_cond_to_bash(text: str) -> tuple[str, bool]:
    parts = _ps_split_bool(text.strip())
    rendered = []
    raw_any = False
    for expr, op in parts:
        c, r = _ps_catom_to_bash(expr)
        raw_any = raw_any or r
        rendered.append((c, op))
    out = rendered[0][0]
    for idx in range(len(rendered) - 1):
        out += (" && " if rendered[idx][1] == "and" else " || ") + rendered[idx + 1][0]
    if re.search(r"\$[A-Za-z_]\w*\.", out):
        raw_any = True  # $obj.prop ไม่มีใน bash — ให้ note เตือน
    return out, raw_any


def _ps_val_to_bash(expr: str) -> tuple[str, str]:
    """ค่า pwsh -> bash (คืน text, note)."""
    e = expr.strip()
    if e == "$null":
        return '""', ""
    if e in ("$true", "$false"):
        return ("true" if e == "$true" else "false"), "บูลีน pwsh -> string ใน bash"
    m = re.fullmatch(r"\(\$args\[(\d+)\]\s*\?\?\s*(.*)\)", e, re.S)
    if m:
        d, n = _ps_val_to_bash(m.group(2))
        return "${%d:-%s}" % (int(m.group(1)) + 1, d), n
    m = re.fullmatch(r"\(\$([A-Za-z_]\w*)\s*\?\?\s*(.*)\)", e, re.S)
    if m:
        d, n = _ps_val_to_bash(m.group(2))
        return "${%s:-%s}" % (m.group(1), d), n
    m = re.fullmatch(r"\(\$([A-Za-z_]\w*)\.Length\)", e)
    if m:
        return "${#%s}" % m.group(1), "${#VAR} (ความยาว string)"
    # -replace -> ${var/#pat/repl}, ${var/%pat/repl}, ${var//pat/repl}
    rm = re.fullmatch(r"\(\$([A-Za-z_]\w*)\s+-replace\s+(.*?),\s*(.*?)\)", e, re.S)
    if rm:
        vname, pat_raw, repl_raw = rm.group(1), rm.group(2).strip(), rm.group(3).strip()
        repl_val = repl_raw.strip("'\"")
        repl_sh = r"\~" if repl_val == "~" else repl_val
        pm = re.fullmatch(r"\('\^'\s*\+\s*\[regex\]::Escape\((\$?[A-Za-z_]\w*|'.*?'|\".*?\")\)\)", pat_raw)
        if pm:
            pat_arg = pm.group(1).strip("'\"")
            return f"${{{vname}/#{pat_arg}/{repl_sh}}}", f"-replace ^... -> ${{{vname}/#...}}"
        pm = re.fullmatch(r"\(\[regex\]::Escape\((\$?[A-Za-z_]\w*|'.*?'|\".*?\")\)\s*\+\s*'\$'\)", pat_raw)
        if pm:
            pat_arg = pm.group(1).strip("'\"")
            return f"${{{vname}/%{pat_arg}/{repl_sh}}}", f"-replace ...$ -> ${{{vname}/%...}}"
        pm = re.fullmatch(r"\[regex\]::Escape\((\$?[A-Za-z_]\w*|'.*?'|\".*?\")\)", pat_raw)
        if pm:
            pat_arg = pm.group(1).strip("'\"")
            return f"${{{vname}//{pat_arg}/{repl_sh}}}", f"-replace ... -> ${{{vname}//...}}"
    m = re.fullmatch(r"(-?\d+)\.\.(-?\d+)", e)
    if m:
        return "$(seq %s %s)" % (m.group(1), m.group(2)), "range A..B -> $(seq A B)"
    m = re.fullmatch(r"\((.*)\)", e, re.S)
    if m and not e.startswith("$("):
        inner = m.group(1)
        tmp = re.sub(r"\$args\[\d+\]|\$[A-Za-z_]\w*|-?\d+(?:\.\d+)?|[\s+\-*/%().]", "", inner)
        if tmp == "":
            conv = re.sub(r"\$args\[(\d+)\]", lambda mm: "$%d" % (int(mm.group(1)) + 1), inner)
            conv = re.sub(r"\$([A-Za-z_]\w*)", r"\1", conv)
            return "$((%s))" % conv.strip(), "$((...)) คำนวณจำนวนเต็มเหมือน bash"
    v, has_us = _ps_to_bash_vars(e)
    note = ""
    if has_us:
        note = "$_ (pipeline) ไม่มีใน bash ตรงตัว — ตรวจเอง"
    if v in ("$@", "$*"):
        v = '"$@"'
    return v, note


def _split_args_paren(text: str) -> list[str]:
    """Split on comma outside quotes and outside parentheses."""
    parts = []
    buf = []
    i, n = 0, len(text)
    q = None
    depth = 0
    while i < n:
        c = text[i]
        if q:
            buf.append(c)
            if c == "`" and q == '"' and i + 1 < n:
                buf.append(text[i + 1])
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if c in "'\"":
            q = c
            buf.append(c)
            i += 1
            continue
        if c == "(":
            depth += 1
            buf.append(c)
            i += 1
            continue
        if c == ")":
            depth = max(depth - 1, 0)
            buf.append(c)
            i += 1
            continue
        if c == "," and depth == 0:
            parts.append("".join(buf).strip())
            buf = []
            i += 1
            continue
        buf.append(c)
        i += 1
    if buf:
        parts.append("".join(buf).strip())
    return [p for p in parts if p]


def _ps_write_to_bash(s: str) -> tuple[str, str] | None:
    m = re.match(r"^(Write-Output|Write-Host|echo)\s*(.*)$", s, re.S)
    if not m:
        return None
    cmd, rest = m.group(1), m.group(2).strip()
    no_nl = False
    if cmd == "Write-Host":
        fm = re.match(r"^-NoNewline\s+(.*)$", rest, re.S)
        if fm:
            no_nl = True
            rest = fm.group(1).strip()
        else:
            # Write-Host ธรรมดาลงจอ ไม่ใช่ stdout — เทียบ echo ได้หยาบๆ
            pass
    # ("fmt" -f a, b) -> printf
    fm = re.fullmatch(r'\("(.*)"\s+-f\s+(.*)\)', rest, re.S)
    if fm:
        fmt_str = fm.group(1)
        fmt_str = (
            fmt_str.replace("`n", "\\n")
            .replace("`t", "\\t")
            .replace("`r", "\\r")
            .replace('`"', '\\"')
            .replace("`$", "$")
            .replace("``", "`")
        )
        fmt = re.sub(r"\{(\d+)\}", "%s", fmt_str)
        args = _split_args_paren(fm.group(2))
        parts = ['"%s"' % _ps_val_to_bash(a)[0] if _ps_val_to_bash(a)[0].startswith("${") else _ps_val_to_bash(a)[0] for a in args]
        body = "printf '%s' %s" % (fmt, " ".join(parts)) if parts else "printf '%s'" % fmt
        return body, '("..." -f ...) -> printf \'...\' ({0} กลับเป็น %s)'
    if not rest:
        return "echo", "Write-Output ว่าง -> echo (บรรทัดเปล่า)"
    args = [a.strip() for a in _split_top(rest, (" ",)) if a.strip()]
    cleaned = []
    for a in args:
        if a.endswith(",") and not (a.startswith("'") or a.startswith('"')):
            a = a[:-1]
        cleaned.append(a)
    parts = [_ps_val_to_bash(a)[0] for a in cleaned if a]
    prefix = "echo -n" if no_nl else "echo"
    return "%s %s" % (prefix, " ".join(parts)), \
        "%s -> %s" % ("Write-Host -NoNewline" if no_nl else "Write-Output", prefix)


def _ps_stmt_to_bash(s: str) -> tuple[str, str] | None:
    """statement pwsh -> bash (None = ไม่รู้จัก ให้ส่งผ่านพร้อมแปลง $)."""
    t = s.strip()
    if not t:
        return None
    if t.startswith("#"):
        return t, ""

    w = _ps_write_to_bash(t)
    if w is not None:
        return w

    m = re.match(r"^([A-Za-z_][\w.-]*)\s*(.*)$", t, re.S)
    cmd = (m.group(1) if m else t).split()[0] if t else ""
    rest = (m.group(2).strip() if m else t[len(cmd):].strip()) if t else ""
    first = cmd.split(".")[-1] if "." in cmd and not cmd.startswith(".") else cmd

    if first == "Get-Location" and not rest:
        return "pwd", "Get-Location -> pwd"
    if first == "Set-Location":
        args = [a for a in _split_top(rest, (" ",)) if a.strip()]
        args = [a for a in args if not a.startswith("-") or a == "-"]
        if not args:
            return "cd ~", "Set-Location (ไม่มี arg) -> cd ~"
        v, n = _ps_val_to_bash(args[0])
        return "cd %s" % v, _merge_notes("Set-Location -> cd", n)
    if first == "Get-Content":
        args = [a for a in _split_top(rest, (" ",)) if a.strip() and not a.startswith("-")]
        if len(args) == 1:
            v, n = _ps_val_to_bash(args[0])
            return "cat %s" % v, _merge_notes("Get-Content -> cat", n)
    if first in ("Copy-Item", "cp"):
        flags = rest
        rec = bool(re.search(r"(?i)-Recurse\b", flags))
        args = [a for a in _split_top(re.sub(r"(?i)-Recurse\b", "", rest), (" ",)) if a.strip()]
        if len(args) == 2:
            a, _n1 = _ps_val_to_bash(args[0])
            b, _n2 = _ps_val_to_bash(args[1])
            return "%s %s %s" % ("cp -r" if rec else "cp", a, b), \
                "Copy-Item -Recurse -> cp -r" if rec else "Copy-Item -> cp"
    if first in ("Move-Item", "mv"):
        args = [a for a in _split_top(rest, (" ",)) if a.strip()]
        if len(args) == 2:
            a, _n1 = _ps_val_to_bash(args[0])
            b, _n2 = _ps_val_to_bash(args[1])
            return "mv %s %s" % (a, b), "Move-Item -> mv"
    if first in ("Remove-Item", "rm"):
        rec = bool(re.search(r"(?i)-Recurse\b", rest))
        force = bool(re.search(r"(?i)-Force\b", rest))
        tmp = re.sub(r"(?i)-(Recurse|Force)\b", "", rest)
        args = [a for a in _split_top(tmp, (" ",)) if a.strip()]
        if args:
            vals = [_ps_val_to_bash(a)[0] for a in args]
            flags = "".join(["r" if rec else "", "f" if force else ""])
            flags = ("-" + flags + " ") if flags else ""
            return "rm %s%s" % (flags, " ".join(vals)), \
                "Remove-Item -> rm (-Recurse/-Force เป็น -r/-f)"
    if first == "New-Item":
        mt = re.search(r"(?i)-ItemType\s+(Directory|File)\b", rest)
        if mt:
            kind = mt.group(1).lower()
            tmp = re.sub(r"(?i)-ItemType\s+\w+|-Force\b|-Path\b", "", rest)
            args = [a.strip() for a in _split_top(tmp, (",",)) if a.strip()]
            vals = [_ps_val_to_bash(a)[0] for a in args]
            if kind == "directory":
                return "mkdir -p %s" % " ".join(vals), "New-Item -ItemType Directory -> mkdir -p"
            return "touch %s" % " ".join(vals), "New-Item -ItemType File -> touch"
    if first == "Get-Command":
        args = [a for a in _split_top(rest, (" ",)) if a.strip()]
        if len(args) == 1:
            v, n = _ps_val_to_bash(args[0])
            return "which %s" % v, _merge_notes("Get-Command -> which", n)
    if first == "Get-ChildItem":
        args = [a for a in _split_top(rest, (" ",)) if a.strip() and not a.startswith("-")]
        if not args:
            return "ls", "Get-ChildItem -> ls"
        if len(args) == 1:
            v, n = _ps_val_to_bash(args[0])
            return "ls %s" % v, _merge_notes("Get-ChildItem -> ls", n)
    if first == "Get-Date" and not rest:
        return "date", "Get-Date -> date"
    if first == "Start-Sleep":
        args = [a for a in _split_top(rest, (" ",)) if a.strip()]
        if args:
            v, n = _ps_val_to_bash(args[-1])
            return "sleep %s" % v, _merge_notes("Start-Sleep -> sleep", n)
    if first == "Clear-Host" and not rest:
        return "clear", "Clear-Host -> clear"
    if first == "Write-Error":
        args = [a for a in _split_top(rest, (" ",)) if a.strip()]
        if args:
            v, n = _ps_val_to_bash(args[0])
            return "echo %s >&2" % v, _merge_notes("Write-Error -> echo ... >&2", n)
    if first in ("exit", "return", "break", "continue"):
        return t, "ชื่อเหมือนกันใน bash"
    if t in ("$true", "$false"):
        return ("true" if t == "$true" else "false"), "$true/$false -> true/false"
    if first == "." and rest:
        v, n = _ps_val_to_bash(rest)
        return "source %s" % v, _merge_notes(". (dot-source) -> source (เหมือนกัน)", n)
    if first == "Remove-Variable":
        args = [a for a in _split_top(rest, (" ",)) if a.strip() and not a.startswith("-")]
        if len(args) == 1:
            return "unset %s" % args[0], "Remove-Variable -> unset"
    if first == "Set-StrictMode":
        return "set -u", "Set-StrictMode -> set -u (เช็คตัวแปรก่อนกำหนด)"
    if first == "Set-PSDebug":
        return "set -x", "Set-PSDebug -Trace 1 -> set -x"
    if t == "param" or t.startswith("param(") or t.startswith("param ("):
        return "# TODO: param (...) ของ pwsh = $1, $2, ... ใน bash: %s" % t, ""
    if t.startswith("[") and (t.endswith(")]") or re.match(r"^\[\w[\w.]*\(\s*\)\]", t)):
        return "# TODO: attribute pwsh ไม่มีใน bash: %s" % t, ""

    # $env:X = val -> export X=val
    m = re.match(r"^\$env:([A-Za-z_]\w*)\s*=\s*(.*)$", t, re.S)
    if m:
        v, n = _ps_val_to_bash(m.group(2))
        return "export %s=%s" % (m.group(1), v), _merge_notes("$env:VAR -> export VAR=...", n)
    # $ErrorActionPreference = "Stop" -> set -e
    if re.match(r'^\$ErrorActionPreference\s*=\s*"Stop"', t):
        return "set -e", "$ErrorActionPreference = 'Stop' -> set -e"
    # $x = val
    m = re.match(r"^\$([A-Za-z_]\w*)\s*(\+?=|-?=)\s*(.*)$", t, re.S)
    if m:
        name, op, val = m.group(1), m.group(2), m.group(3).strip()
        if val == "Read-Host" or val.startswith("Read-Host ") or val.startswith("Read-Host("):
            pm = re.search(r'Read-Host\s+("[^"]*"|\'[^\']*\'|\S+)', val)
            if pm:
                p, _n = _ps_val_to_bash(pm.group(1))
                return "read -p %s %s" % (p, name), "Read-Host -> read -p"
            return "read %s" % name, "Read-Host -> read"
        arith_m = re.fullmatch(r"[\$\w\s+\-*/%()]+", val)
        if arith_m and any(c in val for c in ("+", "-", "*", "/", "%")) and not val.startswith('"') and not val.startswith("'"):
            conv = re.sub(r"\$([A-Za-z_]\w*)", r"\1", val)
            return "%s=$((%s))" % (name, conv.strip()), "คำนวณตัวเลข -> $(( ... ))"
        v, n = _ps_val_to_bash(val)
        if op == "+=":
            return "%s+=%s" % (name, v), _merge_notes("+= เหมือนกัน ($ หายไป)", n)
        return "%s=%s" % (name, v), _merge_notes("pwsh $x=.. -> bash x=.. (เอา $ ออก)", n)
    # $x++ / $x-- / $x += 2
    m = re.fullmatch(r"\$([A-Za-z_]\w*)\s*(\+\+|--)", t)
    if m:
        return "((%s%s))" % (m.group(1), m.group(2)), "$i++ -> ((i++))"
    m = re.fullmatch(r"\$([A-Za-z_]\w*)\s*([+\-*/%])=\s*(.+)", t, re.S)
    if m:
        v, n = _ps_val_to_bash(m.group(3))
        return "((%s %s= %s))" % (m.group(1), m.group(2), v), _merge_notes("$x += 1 -> ((x += 1))", n)
    return None


def _ps_foreach_items_to_bash(y: str) -> tuple[str, str]:
    t = _ps_strip_outer_parens(y.strip()) if y.strip().startswith("(") else y.strip()
    m = re.fullmatch(r"(-?\d+)\.\.(-?\d+)", t)
    if m:
        return "$(seq %s %s)" % (m.group(1), m.group(2)), "range A..B -> $(seq A B)"
    m = re.fullmatch(r"(.+)\.\.(.+)", t)
    if m:
        a, _n1 = _ps_val_to_bash(m.group(1))
        b, _n2 = _ps_val_to_bash(m.group(2))
        return "$(seq %s %s)" % (a, b), "range A..B -> $(seq A B)"
    m = re.fullmatch(r"Get-ChildItem\s+(.*)", t, re.S)
    if m:
        v, _n = _ps_val_to_bash(m.group(1).strip())
        return v, "Get-ChildItem (glob) -> pattern ตรงๆ"
    if t == "@()":
        return '""', "@() ว่าง -> \"\" (bash ไม่มี array ว่างแบบนี้)"
    if "," in t:
        words = [w.strip() for w in _split_top(t, (",",)) if w.strip()]
        return " ".join(_ps_val_to_bash(w)[0] for w in words), "array คั่น , -> คั่น space"
    v, n = _ps_val_to_bash(t)
    return v, n


def _ps_for_paren_to_bash(paren: str) -> tuple[str, str]:
    inner = _ps_strip_outer_parens(paren.strip())
    pieces = [p.strip() for p in _split_top(inner, (";",)) if p.strip()]
    if len(pieces) != 3:
        v, _ = _ps_val_to_bash(paren)
        return "((" + v + "))", "for แบบนี้ซับซ้อน — ตรวจเอง"
    init, cond, step = pieces
    im = re.match(r"^\$([A-Za-z_]\w*)\s*=\s*(.*)$", init, re.S)
    i_txt = ("%s=%s" % (im.group(1), _ps_val_to_bash(im.group(2))[0])) if im else _ps_to_bash_vars(init)[0].replace("$", "")
    ops = {"-lt": "<", "-le": "<=", "-gt": ">", "-ge": ">=", "-eq": "==", "-ne": "!="}
    c_txt = _ps_to_bash_vars(cond)[0].replace("$", "")
    for pw, ba in ops.items():
        c_txt = re.sub(r"\s*%s\s*" % pw, ba, c_txt, flags=re.I)
        c_txt = re.sub(r"\s*%s\s*" % pw.upper(), ba, c_txt)
    sm = re.match(r"^\$([A-Za-z_]\w*)\s*(\+\+|--)$", step)
    if sm:
        s_txt = "%s%s" % (sm.group(1), sm.group(2))
    else:
        am = re.match(r"^\$([A-Za-z_]\w*)\s*([+\-*/%])=\s*(.*)$", step, re.S)
        s_txt = ("%s%s=%s" % (am.group(1), am.group(2), _ps_val_to_bash(am.group(3))[0])) if am else \
            _ps_to_bash_vars(step)[0].replace("$", "")
    return "((%s; %s; %s))" % (i_txt, c_txt, s_txt), "for (;;) -> for ((;;)); do (< กลับเป็น <)"


@register("powershell", "bash")
def powershell_to_bash(code: str, headers: bool = True, notes: bool = True) -> str:
    out: list[str] = []
    stack: list = []  # str kind | {"kind":"switch","base":int,"branch":bool}
    depth = 0
    pending_header: str | None = None

    def emit(text: str, d: int | None = None):
        nonlocal pending_header
        dd = depth if d is None else d
        if pending_header is not None:
            out.append("    " * dd + "# powershell: " + pending_header.strip())
            pending_header = None
        out.append("    " * dd + text)

    def attach(line: str, note: str) -> str:
        if notes and note:
            return line + "  # " + note
        return line

    def emit_stmt(line: str, note: str):
        for i, ln in enumerate(line.split("\n")):
            emit(attach(ln, note) if i == 0 else ln)

    def emit_note(text: str):
        if notes and text:
            emit("# -> " + text)

    def sw_ctx():
        if stack and isinstance(stack[-1], dict) and stack[-1].get("kind") == "switch":
            return stack[-1]
        return None

    def in_switch_branch() -> bool:
        ctx = sw_ctx()
        return bool(ctx and ctx.get("branch"))

    def close_curly(nxt_word: str):
        nonlocal depth, pending_header
        if not stack:
            depth = max(depth - 1, 0)
            emit("}")
            return
        top = stack[-1]
        kind = top.get("kind") if isinstance(top, dict) else top
        if kind == "switch":
            if top.get("branch"):
                top["branch"] = False
                emit(";;")
                depth = top["base"]
            else:
                stack.pop()
                depth = top["base"] - 1
                emit("esac")
            return
        if kind == "if" and nxt_word in ("elseif", "else"):
            stack.pop()
            depth = max(depth - 1, 0)
            return  # เก็บ header ไว้ให้บรรทัด elseif/else
        stack.pop()
        if kind in ("brace", "try", "catch", "paren"):
            pending_header = None  # } ของ hashtable/try — ทิ้ง header กันเปื้อน
            depth = max(depth - 1, 0)
            return
        depth = max(depth - 1, 0)
        if kind == "if":
            emit("fi")
        elif kind in ("while", "for"):
            emit("done")
        elif kind == "func":
            emit("}")
        else:
            emit("}")

    def silent() -> bool:
        """อยู่ใน hashtable/scriptblock ที่ bash ไม่มี — เนื้อในออกเป็น comment กันพัง."""
        return bool(stack) and stack[-1] in ("brace", "paren")

    def do_block_stmts(inner: str):
        for st in _split_stmts(inner):
            st = st.strip()
            if not st:
                continue
            conv = _ps_stmt_to_bash(st)
            if conv is None:
                v, has_us = _ps_to_bash_vars(st)
                n = "ส่งผ่านตรง (native ใน bash ได้)" + ("; $_ ไม่มีใน bash — ตรวจเอง" if has_us else "")
                if silent():
                    emit("# " + v)
                else:
                    emit_stmt(v, n)
            elif conv[0].startswith("#"):
                emit(conv[0])
            else:
                if silent():
                    emit("# " + conv[0])
                else:
                    emit_stmt(conv[0], conv[1])

    def open_block(kind: str, bash_open: str, note: str, trailer: str):
        """เปิดบล็อก + จัดการ trailer (single-line { cmd } หรือเปิดค้าง)."""
        nonlocal depth
        tr = trailer.strip()
        if tr and tr.endswith("}"):
            emit(attach(bash_open, note))
            depth += 1
            stack.append(kind)
            do_block_stmts(tr[:-1])
            close_curly("")
        elif tr:
            emit(attach(bash_open, note + "; ต่อท้าย { มีของแปลก — ตรวจเอง"))
            depth += 1
            stack.append(kind)
            do_block_stmts(tr)
        else:
            emit(attach(bash_open, note))
            depth += 1
            stack.append(kind)

    # logical lines (join ` ท้ายบรรทัดแบบ pwsh)
    logical: list[str] = []
    buf = ""
    for raw in code.splitlines():
        line = raw.rstrip()
        cp, _ = _ps_split_comment(line)
        if cp.rstrip().endswith("`") and not cp.rstrip().endswith("``"):
            buf += cp.rstrip()[:-1] + " "
            continue
        logical.append(buf + line)
        buf = ""
    if buf:
        logical.append(buf)

    for line in logical:
        if not line.strip():
            pending_header = None
            out.append("")
            continue
        code_part, _inline = _ps_split_comment(line)
        if not code_part.strip():
            s = line.strip()
            if re.match(r"^#!.*\b(pwsh|powershell)\b", s):
                if headers:
                    out.append("    " * depth + "# powershell: " + s)
                emit("#!/usr/bin/env bash")
                continue
            pending_header = None
            emit(s)
            continue
        pending_header = line if headers else None
        rest = code_part.strip()

        while rest.startswith("}"):
            after = rest[1:].strip()
            nxt = after.split(None, 1)[0] if after else ""
            close_curly(nxt.rstrip("{").lower())
            rest = after
            if not rest:
                break
        if not rest:
            continue

        # --- switch branch (ต้องมาก่อน opener ทั่วไป) ---
        ctx = sw_ctx()
        if ctx is not None and depth == ctx["base"]:
            bm = re.match(r"^(default)\s*\{(.*)$", rest, re.S | re.I)
            if bm:
                _trailer = bm.group(2).strip()
                emit(attach("*)", "default -> *)"))
                depth = ctx["base"] + 1
                ctx["branch"] = True
                if _trailer:
                    if _trailer.endswith("}"):
                        do_block_stmts(_trailer[:-1])
                        close_curly("")
                    else:
                        do_block_stmts(_trailer)
                continue
            bm = re.match(r"^(\{.*?\})\s*\{(.*)$", rest, re.S)
            if bm and bm.group(1).strip().startswith("{"):
                # { $_ -eq ... } { (รูป multi-pattern ที่เราสร้าง)
                cond = bm.group(1).strip()[1:-1].strip() if bm.group(1).strip().endswith("}") else bm.group(1).strip()
                _trailer = bm.group(2).strip()
                pats = sorted(set(re.findall(r"-eq\s+('[^']*'|\"[^\"]*\"|\S+)", cond)))
                pats = [p.strip("'\"") for p in pats] or ["*"]
                emit(attach("%s)" % "|".join(pats), "{ $_ -eq ... } -> a|b)"))
                depth = ctx["base"] + 1
                ctx["branch"] = True
                if _trailer:
                    if _trailer.endswith("}"):
                        do_block_stmts(_trailer[:-1])
                        close_curly("")
                    else:
                        do_block_stmts(_trailer)
                continue
            bm = re.match(r"^('[^']*'|\"[^\"]*\"|\S+?)\s*\{(.*)$", rest, re.S)
            if bm:
                pat = bm.group(1).strip().strip("'\"")
                _trailer = bm.group(2).strip()
                emit(attach("%s)" % pat, "\"...\" { -> pattern)"))
                depth = ctx["base"] + 1
                ctx["branch"] = True
                if _trailer:
                    if _trailer.endswith("}"):
                        do_block_stmts(_trailer[:-1])
                        close_curly("")
                    else:
                        do_block_stmts(_trailer)
                continue

        # --- openers ---
        m = re.match(r"^(if|elseif|while)\s+(\(.*\))\s*\{(.*)$", rest, re.S | re.I)
        if m:
            kw, paren, trailer = m.group(1).lower(), m.group(2), m.group(3)
            cond = _ps_strip_outer_parens(paren)
            if kw == "while" and re.match(r"(?i)^-not\b", cond.strip()):
                inner = re.sub(r"(?i)^-not\b", "", cond.strip(), count=1).strip()
                c, raw = _ps_cond_to_bash(_ps_strip_outer_parens(inner))
                note = "while (-not (...)) -> until ...; do"
                if raw:
                    note += "; เงื่อนไขมีของที่ bash ไม่มีตรงตัว — ตรวจเอง"
                open_block("while", "until %s; do" % c, note, trailer)
            else:
                c, raw = _ps_cond_to_bash(cond)
                base = "if %s; then" % c if kw == "if" else ("elif %s; then" % c if kw == "elseif" else "while %s; do" % c)
                note = {"if": "if (...) { -> if ...; then",
                        "elseif": "} elseif (...) { -> elif ...; then",
                        "while": "while (...) { -> while ...; do"}[kw]
                if raw:
                    note += "; เงื่อนไขมีของที่ bash ไม่มีตรงตัว — ตรวจเอง ([ -n \"$(...)\" ] คือเช็ค output แทน exit code)"
                open_block("if" if kw in ("if", "elseif") else "while", base, note, trailer)
            continue
        m = re.match(r"^else\s*\{(.*)$", rest, re.S | re.I)
        if m:
            open_block("if", "else", "} else { -> else", m.group(1))
            continue
        m = re.match(r"^foreach\s*\(\s*(.*?)\s+in\s+(.*?)\s*\)\s*\{(.*)$", rest, re.S | re.I)
        if m:
            var = m.group(1).strip().lstrip("$")
            items, n = _ps_foreach_items_to_bash(m.group(2))
            open_block("for", "for %s in %s; do" % (var, items),
                       _merge_notes("foreach -> for ...; do", n), m.group(3))
            continue
        m = re.match(r"^for\s*\(\s*(.*?)\s*;\s*(.*?)\s*;\s*(.*?)\s*\)\s*\{(.*)$", rest, re.S | re.I)
        if m:
            arith, n = _ps_for_paren_to_bash("(%s; %s; %s)" % (m.group(1), m.group(2), m.group(3)))
            open_block("for", "for %s; do" % arith, _merge_notes(n), m.group(4))
            continue
        m = re.match(r"^switch\s+(.*?)\s*(\(.*\))\s*\{(.*)$", rest, re.S | re.I)
        if m:
            flags, paren, trailer = m.group(1), m.group(2), m.group(3)
            subj, n = _ps_val_to_bash(_ps_strip_outer_parens(paren))
            note = "switch (...) { -> case ... in"
            if re.search(r"(?i)-Wildcard", flags):
                note += " (-Wildcard ตรงกับ glob ของ case)"
            if re.search(r"(?i)-Regex", flags):
                note += " (-Regex ไม่มีใน case ตรงตัว — ตรวจ pattern เอง)"
            emit(attach("case %s in" % subj, _merge_notes(note, n)))
            depth += 1
            stack.append({"kind": "switch", "base": depth, "branch": False})
            if trailer.strip():
                do_block_stmts(trailer)  # switch บรรทัดเดียว — พยายามต่อ (อาจต้องตรวจเอง)
            continue
        m = re.match(r"^function\s+(\w+)\s*(\(.*\))?\s*\{(.*)$", rest, re.S | re.I)
        if m:
            extra = "; (parameter pwsh = $1, $2, ... ใน bash)" if m.group(2) else ""
            open_block("func", "%s() {" % m.group(1),
                       "function name { -> name() {%s" % extra, m.group(3))
            continue
        m = re.match(r"^&\s*\{(.*)$", rest, re.S)
        if m:
            open_block("brace", "{", "& { (script block) -> { } group", m.group(1))
            continue
        m = re.match(r"^try\s*\{(.*)$", rest, re.S | re.I)
        if m:
            emit("# TODO: try/catch ของ pwsh ไม่มีใน bash")
            depth += 1
            stack.append("try")
            if m.group(1).strip():
                do_block_stmts(m.group(1))
            continue
        m = re.match(r"^catch\b.*?\{(.*)$", rest, re.S | re.I)
        if m:
            emit("# TODO: catch ของ pwsh ไม่มีใน bash")
            depth += 1
            stack.append("catch")
            if m.group(1).strip():
                do_block_stmts(m.group(1))
            continue
        m = re.match(r"^finally\s*\{(.*)$", rest, re.S | re.I)
        if m:
            emit("# TODO: finally ของ pwsh ไม่มีใน bash")
            depth += 1
            stack.append("catch")
            if m.group(1).strip():
                do_block_stmts(m.group(1))
            continue
        if rest == "{" or re.search(r"@\{\s*$", rest) or rest.endswith("{"):
            # { เปลือย / hashtable @{ / scriptblock ที่ไม่รู้จัก — เก็บเงียบ กัน stack เพี้ยน
            if rest != "{":
                emit_note("บล็อก { ... } แบบนี้ (hashtable/scriptblock/...) ไม่มีใน bash ตรงตัว — เนื้อในเป็น comment")
            depth += 1
            stack.append("brace")
            continue

        # --- statements ---
        if rest == "break" and in_switch_branch():
            emit("# -> break ของ switch ไม่ต้องมีใน bash (ใช้ ;; แทน)")
            continue
        for st in _split_stmts(rest):
            st = st.strip()
            if not st:
                continue
            conv = _ps_stmt_to_bash(st)
            if conv is None:
                v, has_us = _ps_to_bash_vars(st)
                n = "ส่งผ่านตรง (native ใน bash ได้)" + ("; $_ ไม่มีใน bash — ตรวจเอง" if has_us else "")
                if silent():
                    emit("# " + v)
                else:
                    emit_stmt(v, n)
            elif conv[0].startswith("#"):
                emit(conv[0])
            else:
                if silent():
                    emit("# " + conv[0])
                else:
                    emit_stmt(conv[0], conv[1])

    body = "\n".join(out)
    if not headers:
        body = "\n".join(ln for ln in body.splitlines()
                         if not ln.strip().startswith("# powershell: "))
    if body and not body.startswith("#!"):
        body = "#!/usr/bin/env bash\n" + body
    return body + "\n"


# ==========================================================================
# CLI
# ==========================================================================

EXT_LANG = {".sh": "bash", ".bash": "bash", ".zsh": "bash", ".py": "python",
            ".ps1": "powershell", ".psm1": "powershell"}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="codetrans",
        description="แปลงโค้ด bash <-> python <-> powershell แบบ line-by-line พร้อม comment เทียบกัน (pwsh = powershell)",
    )
    ap.add_argument("file", nargs="?", help="ไฟล์อ่านเข้า (เว้นว่าง = อ่านจาก stdin)")
    ap.add_argument("-f", "--from", dest="src", help="ภาษาต้นทาง (bash, python, powershell/pwsh)")
    ap.add_argument("-t", "--to", dest="dst", help="ภาษาปลายทาง (bash, python, powershell/pwsh)")
    ap.add_argument("-o", "--output", help="เขียนผลลงไฟล์นี้")
    ap.add_argument("--list", action="store_true", help="ดูคู่ภาษาที่รองรับ")
    ap.add_argument("--clean", action="store_true", help="เอา comment ออกทั้งหมด")
    ap.add_argument("--no-notes", action="store_true",
                    help="ตัดคำอธิบายท้ายบรรทัด เหลือแค่ `# bash:` / `# python:`")
    args = ap.parse_args(argv)

    if args.list:
        print("คู่ภาษาที่รองรับ:")
        for src, dst in pairs():
            print(f"  {src} -> {dst}")
        print("\nเพิ่มคู่ใหม่: @register('src', 'dst')")
        return 0

    src = args.src or (EXT_LANG.get(os.path.splitext(args.file)[1]) if args.file else None)
    dst = args.dst
    if not src or not dst:
        print("codetrans: ระบุ --from/--to (หรือใช้ไฟล์ .sh/.py/.ps1)", file=sys.stderr)
        return 2
    src, dst = _canon(src), _canon(dst)

    if args.file:
        with open(args.file, encoding="utf-8") as fh:
            code = fh.read()
    else:
        code = sys.stdin.read()

    kw = {"headers": not args.clean, "notes": not (args.clean or args.no_notes)}
    result = translate(code, src, dst, **kw)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as fh:
            fh.write(result)
        print(f"เขียน {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
