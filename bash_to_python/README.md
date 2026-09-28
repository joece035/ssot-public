# codetrans

แปลงโค้ด **bash <-> python <-> powershell แบบ line-by-line พร้อม comment เทียบกัน** —
สร้างมาเพื่อคนที่ฝึกเขียน bash แล้วกำลังต่อยอดเขียน python / powershell
(`pwsh` คือ alias ของ `powershell` ใช้แทนกันได้ทุก flag)

## ตัวอย่าง

```bash
$ python3 codetrans.py script.sh -t python
$ python3 codetrans.py script.sh -t pwsh
$ python3 codetrans.py script.ps1 -t bash
```

ได้โค้ด python ที่มี comment คู่กันทุกบรรทัด:

```python
#!/usr/bin/env python3
import os
import shutil

# bash: export var=value
var = "value"  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
# bash: echo "hi $var"
print(f"hi {var}")  # echo -> print(); $VAR -> f-string {VAR}
# bash: if [ -f "$file" ]; then
if os.path.exists(file):  # ใส่ : แทน then
    # bash: cat "$file"
    print(open(file).read(), end="")  # cat -> open().read()
# bash: fi
# -> จบ if — python เยื้องกลับ (dedent) แทน fi
```

บรรทัด `# bash:` คือต้นฉบับ / บรรทัดโค้ดคือ python / คอมเมนต์ท้ายแถวคือคำอธิบายว่า
construct ไหนเทียบกับอะไร

## ใช้งาน

```bash
python3 codetrans.py script.sh -t python           # bash -> python
python3 codetrans.py script.sh -t pwsh             # bash -> powershell
python3 codetrans.py script.ps1 -t bash            # powershell -> bash (.ps1 เดาภาษาให้เอง)
python3 codetrans.py script.py -f python -t bash    # python -> bash
cat script.sh | python3 codetrans.py -f bash -t python
python3 codetrans.py script.sh -t python -o out.py
python3 codetrans.py --list                         # ดูคู่ภาษา
```

Flags:

| flag | ผล |
|---|---|
| `--clean` | เอา comment ออกหมด เหลือโค้ดล้วน |
| `--no-notes` | ตัดคำอธิบายท้ายบรรทัด เหลือแค่ `# bash:` / `# python:` |
| `--list` | แสดงคู่ภาษาที่ register ไว้ |

ภาษาเดาจากนามสกุลไฟล์ (`.sh` -> bash, `.py` -> python, `.ps1`/`.psm1` -> powershell) ถ้าไม่ได้ระบุ `--from`

## แปลงอะไรได้บ้าง (bash -> powershell)

pwsh เป็น shell เหมือน bash คำสั่ง native (`ls/grep/git/...`) จึง**ส่งผ่านตรง**ได้เลย
(ต่างจาก python ที่ต้องห่อ `_run()`):

- ตัวแปร `x=..` -> `$x=..` (เติม `$`), `export V=..` -> `$env:V=..`, `unset` -> `Remove-Variable`
- `echo` -> `Write-Output` (`-n` -> `Write-Host -NoNewline`), `printf "%s"` -> `("..." -f ...)` (`{0}` แทน `%s`, `\n` -> `` `n ``)
- `$1/$@/$#/$?/$$/$0` -> `$args[0]/$args/$args.Count/$?/$PID/$PSCommandPath`
- `${1:-def}` -> `($args[0] ?? 'def')` (PS 7+), `${#V}` -> `($V.Length)`, `$((..))` -> `(..)` (เติม `$` ให้ตัวแปร)
- `[ -f/-d/-e/-s x ]`, `= / != / -eq..-ge`, `-z/-n`, `=~` -> `Test-Path [-PathType]`, `-eq/-ne/...` (ชุดเดียวกัน!), `[string]::IsNullOrEmpty()`, `-match`
- `if/elif/else/fi`, `while/until/for..do/done`, `for ((;;))`, `case/esac`, `name() { }`
  -> `if/elseif/else { }`, `while/foreach/for { }` (`until` ใช้ `while (-not ...)`), `switch -Wildcard { }` (+ `break` แทน `;;`), `function name { }`
- `for i in $(seq A B)/{A..B}` -> `foreach ($i in A..B)`, glob -> `(Get-ChildItem "...")`
- `cd/pwd/cat/cp/mv/rm/mkdir/touch/which/read/source` -> `Set-Location/Get-Location/Get-Content/Copy-Item/Move-Item/Remove-Item/New-Item/Get-Command/Read-Host/.`
- `set -e/-u/-x` -> `$ErrorActionPreference='Stop'` / `Set-StrictMode` / `Set-PSDebug -Trace 1`
- `&&/||` ใช้ได้บน PS 7+ (มี note เตือน), `&` (background) -> `Start-Job`, `<` ไม่มีใน pwsh (ใช้ `Get-Content |`)

## แปลงอะไรได้บ้าง (powershell -> bash)

- `$x/$env:X/$args[0]/$@/$#/$?/PID` กลับเป็น `x/V/$1/$@/$#/$?/$$` (`$env:USERNAME` -> `$USER`)
- `Write-Output/Write-Host` -> `echo`, `("..." -f ...)` กลับเป็น `printf`, cmdlet หลักกลับเป็นคำสั่งเดิม
- `Test-Path/-eq/.../-match/IsNullOrEmpty` -> `[ -f/-d/-e ]`, `[ =/-eq ]`, `[[ =~ ]]`, `[ -z ]`
- `if/elseif/else/while/foreach/for/switch/function` -> `if/elif/else/fi`, `while/until/for..do/done`, `for ((;;))`, `case/esac`, `name() { }`
- ขาไปสร้าง `break` ใน switch ให้ — ขากลับรู้จักรหัสนี้แล้วตัดทิ้ง (bash ใช้ `;;` แทน)
- `try/catch/finally`, `param()`, hashtable `@{ }`, `$_` ไม่มีใน bash — ออกเป็น `# TODO:` / comment กันพัง (`bash -n` ผ่าน)

## แปลงอะไรได้บ้าง (bash -> python)

- ตัวแปร / `export` / `local` -> assignment (ไม่ต้อง export)
- `echo` / `printf` -> `print()` (+ `%` format)
- `$VAR` ใน string -> f-string `{VAR}` / `$(cmd)` -> `_sh("cmd")`
- `if/elif/else/fi`, `while/done`, `for..do`, `for ((;;))` -> `if:`, `while:`, `for..in:`
- condition `[ -f x ]`, `[ a = b ]`, `-eq/-lt/...`, `&&/||`, `=~` ->
  `os.path.exists()`, `str(a) == b`, `and/or`, `re.search()`
- `case/esac` -> `match/case` (python 3.10+)
- ฟังก์ชัน `name() { }` -> `def name():`
- `cd/pwd/cat/cp/mv/rm/mkdir/touch/which/exit/read/source` -> `os/shutil/sys`
- redirect `>` / `>>` กับ echo -> `open(..., "w"/"a")`
- คำสั่งที่ไม่รู้จัก / pipe / `&&` -> `_run("...")` (รันผ่าน shell 保住พฤติกรรมเดิม)

## ข้อจำกัด (จงใจไว้)

### bash <-> python (ของเดิม)

- `_run()` / `_sh()` คือ helper ที่ generate ให้头顶สุดของไฟล์ — ใช้ `subprocess`
  แปลไม่ได้ 100% พวก array/map/heredoc/trap/`select`
- `set -e`/`alias` ได้เป็น comment `# TODO:` ไม่ใช่พฤติกรรมเดิม
- โค้ดที่ซับซ้อนมาก ผลที่ได้อาจต้องตรวจเองทีละบรรทัด (ซึ่งก็เป็นจุดประสงค์ของการเอามาอ่าน)

### bash <-> powershell (ของใหม่)

- ไม่มี pwsh บนเครื่องนี้ เลยตรวจได้แค่ brace-balance + round-trip `bash -n` — ถ้ามี pwsh ให้รัน `pwsh -NoProfile -Command` ซ้ำเอง
- pwsh หาร `/` ได้ทศนิยม แต่ bash `$(( ))` หารปัดลง — โค้ดคำนวณต้องตรวจเอง
- `Write-Output` เขียนไฟล์ผ่าน `>` เป็น UTF-8 (bash เขียน bytes) — ตรวจ encoding เอง
- `${var%..}` / `${var#..}` / `${var/..}` / `;&` fallthrough / subshell คร่อม `;` ยังส่งผ่านดิบ + note
- เงื่อนไขที่เป็นคำสั่ง (`if grep -q ...`) แปลงเป็น `if (grep ...)` พร้อม note ว่า bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน — ต้องดู `$?`/`$LASTEXITCODE` เอง

## เพิ่มคู่ภาษาใหม่

registry เป็นแบบ pluggable:

```python
from codetrans import register

@register("ruby", "python")
def ruby_to_python(code: str, headers: bool = True, notes: bool = True) -> str:
    ...
```

แล้วรัน `python3 codetrans.py file.rb -t python` ได้เลย

## โครงไฟล์

```
codetrans.py           # ตัว tool ทั้งหมด (ไม่มี dependency นอก stdlib)
examples/demo.sh       # ตัวอย่าง bash
examples/demo.py       # ผลที่แปลงแล้ว (พร้อม comment คู่กัน)
examples/demo.ps1      # bash -> powershell ของ demo.sh
examples/demo_ps_rt.sh # powershell -> bash ของ demo.ps1 (ตรวจผ่าน bash -n)
examples/flow.sh/.py   # ตัวอย่าง case/while/redirect/glob
examples/flow.ps1      # bash -> powershell ของ flow.sh
examples/flow_ps_rt.sh # powershell -> bash ของ flow.ps1
examples/*_rt.sh       # แปลงกลับ python -> bash (ตรวจผ่าน bash -n)
```
