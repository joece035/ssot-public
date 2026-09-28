#!/usr/bin/env python3
"""Comprehensive test suite for codetrans.py - all 4 translation pairs."""
import subprocess, sys, os, textwrap, json, shutil
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from codetrans import translate

GREEN = '\033[32m\u2713\033[0m'
RED   = '\033[31m\u2717\033[0m'
YELLOW = '\033[33m~\033[0m'
results = {'pass': 0, 'fail': 0, 'skip': 0}

def check(label, got, expected, exact=False):
    got_s, exp_s = str(got).strip(), str(expected).strip()
    if got_s == 'SKIP':
        print(f'  {YELLOW} {label} (skipped - executable not available)')
        results['skip'] += 1
        return
    ok = (got_s == exp_s) if exact else (exp_s in got_s)
    sym = GREEN if ok else RED
    print(f'  {sym} {label}')
    if not ok:
        print(f'       expected: {repr(exp_s[:120])}')
        print(f'       got:      {repr(got_s[:120])}')
    results['pass' if ok else 'fail'] += 1

def run_bash(code):
    r = subprocess.run(['bash','-c',code], capture_output=True, text=True)
    return (r.stdout+r.stderr).strip()

def run_python(code):
    r = subprocess.run([sys.executable,'-c',code], capture_output=True, text=True,
        env={**os.environ,'HOME':os.environ.get('HOME',os.path.expanduser('~'))})
    return (r.stdout+r.stderr).strip()

def run_pwsh(code):
    exe = (shutil.which('pwsh') or
           shutil.which('powershell.exe') or
           ('/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
            if os.path.exists('/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe')
            else None))
    if not exe:
        return 'SKIP'
    r = subprocess.run([exe, '-NoProfile', '-NonInteractive', '-Command', code],
        capture_output=True, text=True)
    return (r.stdout+r.stderr).strip()

def trans(src, dst, code, strip_comments=True):
    result = translate(textwrap.dedent(code), src, dst)
    if strip_comments:
        lines = [ln for ln in result.splitlines()
                 if not ln.strip().startswith('# ->') and not ln.strip().startswith('# bash:')]
        return '\n'.join(lines)
    return result

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 1: bash -> python
# ═══════════════════════════════════════════════════════════════════════════
print('\n'+'='*60+'\nSECTION 1: bash -> python\n'+'='*60)

print('\n[1.1] Variable assignment')
py = trans('bash','python','NAME="World"\nNUM=42\n')
check('string assign',  py, 'NAME = "World"')
check('int assign',     py, 'NUM = 42')

print('\n[1.2] export -> plain assign')
py = trans('bash','python','export PATH_X="/usr/local"\n')
check('export -> assign', py, 'PATH_X = "/usr/local"')

print('\n[1.3] echo -> print')
py = trans('bash','python','echo "Hello World"\n')
check('echo string', py, 'print("Hello World")')
py = trans('bash','python','echo -n "no newline"\n')
check('echo -n (end="")', py, 'end=""')

print('\n[1.4] Parameter expansions')
py = trans('bash','python','echo "${NAME:-default}"\n')
check('${var:-default}', py, ' or ')
py = trans('bash','python','echo "${#NAME}"\n')
check('${#var} -> len()', py, 'len(NAME)')
py = trans('bash','python','echo "${NAME^^}"\n')
check('${var^^} -> upper', py, '.upper()')
py = trans('bash','python','echo "${NAME,,}"\n')
check('${var,,} -> lower', py, '.lower()')
py = trans('bash','python','echo "${NAME:0:3}"\n')
check('${var:0:3} -> slice', py, 'NAME[0:3]')
py = trans('bash','python','echo "${NAME/foo/bar}"\n')
check('${var/foo/bar}', py, '.replace("foo", "bar"')
py = trans('bash','python',r'echo "${NAME/#$HOME/\~}"' + '\n')
check('${var/#prefix/~} prefix-replace', py, '.startswith(')
py = trans('bash','python','echo "${NAME%suffix}"\n')
check('${var%suffix} strip suffix', py, '.endswith(')
py = trans('bash','python','echo "${NAME+alt}"\n')
check('${var+alt} -> conditional', py, 'if NAME')
py = trans('bash','python','echo "${NAME//foo/bar}"\n')
check('${var//foo/bar} global replace', py, '.replace("foo", "bar")')

print('\n[1.5] Arithmetic')
py = trans('bash','python','echo $((2 + 3))\n')
check('$(( arith ))', py, '2 + 3')
py = trans('bash','python','echo $((10 / 3))\n')
check('division -> //', py, '10 // 3')
py = trans('bash','python','((i++))\n')
check('((i++)) -> += 1', py, 'i += 1')
py = trans('bash','python','((i--))\n')
check('((i--)) -> -= 1', py, 'i -= 1')
py = trans('bash','python','((x += 5))\n')
check('((x += 5))', py, 'x += 5')
py = trans('bash','python','((y *= 2))\n')
check('((y *= 2))', py, 'y *= 2')

print('\n[1.6] Conditionals')
py = trans('bash','python','if [ -f "$FILE" ]; then\n  echo yes\nfi\n')
check('[ -f ] -> os.path.exists', py, 'os.path.exists')
py = trans('bash','python','if [[ -d "$DIR" ]]; then\n  echo yes\nfi\n')
check('[[ -d ]] -> os.path.isdir', py, 'os.path.isdir')
py = trans('bash','python','if [ ! -f "$FILE" ]; then\n  echo no\nfi\n')
check('[ ! -f ] negation', py, 'not (os.path.exists')
py = trans('bash','python','if [ "$A" = "$B" ]; then\n  echo eq\nfi\n')
check('[ = ] -> ==', py, '==')
py = trans('bash','python','if [ "$A" -gt 5 ]; then\n  echo big\nfi\n')
check('[ -gt ] -> >', py, '>')
py = trans('bash','python','if [ "$A" -eq "$B" ]; then\n  echo eq\nfi\n')
check('[ -eq ] -> ==', py, '==')
py = trans('bash','python','if [ -z "$VAR" ]; then\n  echo empty\nfi\n')
check('[ -z ] -> not', py, 'not')
py = trans('bash','python','if [ -n "$VAR" ]; then\n  echo nonempty\nfi\n')
check('[ -n ] -> truthy', py, 'VAR')
py = trans('bash','python','if [ -r "$FILE" ]; then\n  echo readable\nfi\n')
check('[ -r ] -> os.access', py, 'os.access')
py = trans('bash','python','if [ -L "$LINK" ]; then\n  echo link\nfi\n')
check('[ -L ] -> islink', py, 'os.path.islink')

print('\n[1.7] Loops')
py = trans('bash','python','for f in *.txt; do\n  echo "$f"\ndone\n')
check('for..in glob', py, 'for f in')
py = trans('bash','python','for i in 1 2 3; do\n  echo $i\ndone\n')
check('for i in list', py, 'for i in')
py = trans('bash','python','for ((i=0; i<5; i++)); do\n  echo $i\ndone\n')
check('C-style for -> range()', py, 'range(')
py = trans('bash','python','while [ $n -gt 0 ]; do\n  echo $n\ndone\n')
check('while loop', py, 'while')
py = trans('bash','python','while true; do\n  echo loop\ndone\n')
check('while true', py, 'while True')

print('\n[1.8] Functions')
py = trans('bash','python','greet() {\n  echo "Hello"\n}\n')
check('func() {} -> def', py, 'def greet():')
py = trans('bash','python','function greet {\n  echo "Hi"\n}\n')
check('function keyword -> def', py, 'def greet():')

print('\n[1.9] case -> match')
py = trans('bash','python','case "$x" in\n  a) echo A;;\n  b|c) echo BC;;\n  *) echo other;;\nesac\n')
check('case -> match', py, 'match')
check('case arm a', py, '"a"')

print('\n[1.10] Redirects / pipes / subst')
py = trans('bash','python','ls -la | grep foo\n')
check('pipe -> _run()', py, '_run(')
py = trans('bash','python','echo "hello" > /tmp/out.txt\n')
check('echo > -> open(w)', py, 'open(')
py = trans('bash','python','echo "hello" >> /tmp/out.txt\n')
check('echo >> -> open(a)', py, '"a"')
py = trans('bash','python','result=$(ls /tmp)\n')
check('$() -> _sh()', py, '_sh(')

print('\n[1.11] Special params')
py = trans('bash','python','echo "$#"\n')
check('$# -> len(sys.argv)', py, 'len(sys.argv)')
py = trans('bash','python','echo "$@"\n')
check('$@ -> sys.argv[1:]', py, 'sys.argv[1:]')
py = trans('bash','python','echo "$$"\n')
check('$$ -> os.getpid()', py, 'os.getpid()')
py = trans('bash','python','echo "$1"\n')
check('$1 -> sys.argv[1]', py, 'sys.argv[1]')

print('\n[1.12] File ops')
py = trans('bash','python','cd /tmp\n')
check('cd -> os.chdir', py, 'os.chdir')
py = trans('bash','python','cd\n')
check('cd (bare) -> expanduser ~', py, 'expanduser')
py = trans('bash','python','pwd\n')
check('pwd -> os.getcwd', py, 'os.getcwd')
py = trans('bash','python','mkdir -p /tmp/dir\n')
check('mkdir -p -> makedirs', py, 'makedirs')
py = trans('bash','python','rm -rf /tmp/dir\n')
check('rm -rf -> rmtree', py, 'rmtree')
py = trans('bash','python','cp src dst\n')
check('cp -> shutil.copy', py, 'shutil.copy')
py = trans('bash','python','mv src dst\n')
check('mv -> shutil.move', py, 'shutil.move')
py = trans('bash','python','which python3\n')
check('which -> shutil.which', py, 'shutil.which')

print('\n[1.13] EXECUTION VERIFY: bash output == python output')
exec_cases = [
    ('string+printf',  r'X="hello"; printf "%s world\n" "$X"'),
    ('arithmetic',     'A=5; B=3; echo $((A + B))'),
    ('param_length',   'NAME="hello"; echo "${#NAME}"'),
    ('upper',          'NAME="hello"; echo "${NAME^^}"'),
    ('lower',          'NAME="HELLO"; echo "${NAME,,}"'),
    ('slice',          'NAME="hello"; echo "${NAME:1:3}"'),
    ('replace',        'NAME="hello world"; echo "${NAME/world/python}"'),
    ('default',        'UNSET=""; echo "${UNSET:-fallback}"'),
    ('strip-suffix',   'NAME="hello.sh"; echo "${NAME%.sh}"'),
    ('arith-div',      'echo $((10 / 3))'),
    ('arith-mod',      'echo $((10 % 3))'),
]
for label, bash_code in exec_cases:
    bash_out = run_bash(bash_code)
    py_code  = trans('bash','python', bash_code + '\n')
    py_out   = run_python(py_code)
    check(f'exec: {label}', py_out, bash_out, exact=True)

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 2: bash -> powershell
# ═══════════════════════════════════════════════════════════════════════════
print('\n'+'='*60+'\nSECTION 2: bash -> powershell\n'+'='*60)

print('\n[2.1] Assignment + echo')
ps = trans('bash','powershell','NAME="World"\n')
check('$NAME = ...', ps, '$NAME')
ps = trans('bash','powershell','echo "Hello"\n')
check('echo -> Write-Output', ps, 'Write-Output')

print('\n[2.2] printf -> Write-Output -f')
ps = trans('bash','powershell',r'printf "%s\n" "val"' + '\n')
check('printf -> -f format', ps, '-f')

print('\n[2.3] Conditionals')
ps = trans('bash','powershell','if [ -f "$FILE" ]; then\n  echo yes\nfi\n')
check('[ -f ] -> Test-Path', ps, 'Test-Path')
ps = trans('bash','powershell','if [ ! -d "$DIR" ]; then\n  echo no\nfi\n')
check('[ ! -d ] -> -not', ps, '-not')
ps = trans('bash','powershell','if [ "$A" -gt 5 ]; then\n  echo big\nfi\n')
check('[ -gt ] -> -gt', ps, '-gt')

print('\n[2.4] Loops + function')
ps = trans('bash','powershell','for f in *.txt; do\n  echo "$f"\ndone\n')
check('for in -> foreach', ps, 'foreach')
ps = trans('bash','powershell','while [ $n -gt 0 ]; do\n  echo $n\ndone\n')
check('while in ps', ps, 'while')
ps = trans('bash','powershell','greet() {\n  echo "Hello"\n}\n')
check('func -> function keyword', ps, 'function greet')

print('\n[2.5] cd / pwd')
ps = trans('bash','powershell','cd /tmp\n')
check('cd -> Set-Location', ps, 'Set-Location')
ps = trans('bash','powershell','pwd\n')
check('pwd -> Get-Location', ps, 'Get-Location')

print('\n[2.6] Prefix-replace ${var/#$HOME/~}')
ps = trans('bash','powershell',
    r'test_p="$HOME/ssot"' + '\n' + r'printf "%s\n" "${test_p/#$HOME/\~}"' + '\n')
check('-replace [regex]::Escape', ps, '[regex]::Escape')
check("replace with '~'", ps, "'~'")

print('\n[2.7] EXECUTION VERIFY: bash output == pwsh output')
ps_cases = [
    ('echo hello',    'echo "Hello World"'),
    ('printf %s',     r'printf "%s world\n" "hello"'),
]
for label, bash_code in ps_cases:
    bash_out = run_bash(bash_code)
    ps_code  = trans('bash','powershell', bash_code + '\n')
    ps_out   = run_pwsh(ps_code)
    check(f'exec: {label}', ps_out, bash_out, exact=True)

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 3: python -> bash
# ═══════════════════════════════════════════════════════════════════════════
print('\n'+'='*60+'\nSECTION 3: python -> bash\n'+'='*60)

bash = trans('python','bash','NAME = "World"\n')
check('NAME=...', bash, 'NAME=')
bash = trans('python','bash','print("Hello")\n')
check('print -> echo', bash, 'echo')
bash = trans('python','bash','sys.exit(1)\n')
check('sys.exit(1) -> exit 1', bash, 'exit 1')
bash = trans('python','bash','if os.path.exists("/tmp/foo"):\n    print("yes")\n')
check('os.path.exists -> -f', bash, '-f')
bash = trans('python','bash','if os.path.isdir("/tmp"):\n    print("yes")\n')
check('os.path.isdir -> -d', bash, '-d')
bash = trans('python','bash','for i in range(5):\n    print(i)\n')
check('range() -> for/seq', bash, 'for')
bash = trans('python','bash','os.chdir("/tmp")\n')
check('os.chdir -> cd', bash, 'cd')

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 4: powershell -> bash
# ═══════════════════════════════════════════════════════════════════════════
print('\n'+'='*60+'\nSECTION 4: powershell -> bash\n'+'='*60)

bash = trans('powershell','bash','$NAME = "World"\n')
check('$NAME -> NAME=', bash, 'NAME=')
bash = trans('powershell','bash','Write-Host "Hello"\n')
check('Write-Host -> echo', bash, 'echo')
bash = trans('powershell','bash','Set-Location /tmp\n')
check('Set-Location -> cd', bash, 'cd')
bash = trans('powershell','bash','if (Test-Path "/tmp/foo") {\n  Write-Host "yes"\n}\n')
check('Test-Path -> -e', bash, '-e')
bash = trans('powershell','bash','foreach ($f in Get-ChildItem "*.txt") {\n  Write-Host $f\n}\n')
check('foreach -> for..in', bash, 'for')
bash = trans('powershell','bash','Get-Location\n')
check('Get-Location -> pwd', bash, 'pwd')

# ── Summary ───────────────────────────────────────────────────────────────────
total = results['pass'] + results['fail']
print('\n'+'='*60)
print(f"RESULTS: {results['pass']}/{total} passed  |  {results['fail']} failed  |  {results['skip']} skipped")
print('='*60)
sys.exit(1 if results['fail'] > 0 else 0)
