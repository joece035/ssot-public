#!/usr/bin/env python3
"""
codetrans - แปลงโค้ด bash <-> python แบบ line-by-line สำหรับคนฝึกเขียน python

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
    python3 codetrans.py script.sh -t python -o script.py
    cat script.sh | python3 codetrans.py -f bash -t python
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


def register(src: str, dst: str):
    def deco(fn):
        REGISTRY[(src, dst)] = fn
        return fn
    return deco


def pairs() -> list[tuple[str, str]]:
    return sorted(REGISTRY)


def translate(code: str, src: str, dst: str, **kw) -> str:
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
    """Split on whitespace outside quotes, keeping quote characters."""
    out: list[str] = []
    buf: list[str] = []
    q = None
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
        if c.isspace():
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


def _tokens(text: str, keep_quotes: bool) -> list[tuple[str, str]]:
    """Tokenize: ('lit'|'var'|'code'|'arith', value)"""
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
        m = _VAR_RE.match(text, i)
        if m:
            flush()
            toks.append(("var", m.group(1) or m.group(2)))
            i = m.end()
            continue
        m = _ARG_RE.match(text, i)
        if m:
            flush()
            toks.append(("code", f"sys.argv[{m.group(1)}]"))
            i = m.end()
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
            # bash เทียบเป็น string เสมอ
            return f"{_as_str(_word_expr(l))} == {_as_str(_word_expr(r))}"
        if op == "!=":
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
        fmt.replace("\\\\", "\x00")
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

        for idx, stmt in enumerate(_split_top(code_part, (";",))):
            s = stmt.strip()
            if not s:
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
            m = re.match(r"^(?:function\s+)?([A-Za-z_]\w*)\s*\(\s*\)\s*\{$", s) or re.match(
                r"^function\s+([A-Za-z_]\w*)\s*\{$", s
            )
            if m:
                emit(attach(f"def {m.group(1)}():", "ฟังก์ชัน bash -> def name():"))
                depth += 1
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
        ("re.search", "re"),
        ("fnmatch.", "fnmatch"),
    ]:
        if needle in body:
            mods.append(mod)
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
    if e.startswith('f"') and e.endswith('"'):
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
    if e.startswith('f"') and e.endswith('"'):
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
# CLI
# ==========================================================================

EXT_LANG = {".sh": "bash", ".bash": "bash", ".zsh": "bash", ".py": "python"}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="codetrans",
        description="แปลงโค้ด bash <-> python แบบ line-by-line พร้อม comment เทียบกัน",
    )
    ap.add_argument("file", nargs="?", help="ไฟล์อ่านเข้า (เว้นว่าง = อ่านจาก stdin)")
    ap.add_argument("-f", "--from", dest="src", help="ภาษาต้นทาง (bash, python)")
    ap.add_argument("-t", "--to", dest="dst", help="ภาษาปลายทาง (bash, python)")
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
        print("codetrans: ระบุ --from/--to (หรือใช้ไฟล์ .sh/.py)", file=sys.stderr)
        return 2

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
