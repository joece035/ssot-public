# codetrans

แปลงโค้ด **bash <-> python แบบ line-by-line พร้อม comment เทียบกัน** —
สร้างมาเพื่อคนที่ฝึกเขียน bash แล้วกำลังต่อยอดเขียน python

## ตัวอย่าง

```bash
$ python3 codetrans.py script.sh -t python
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

ภาษาเดาจากนามสกุลไฟล์ (`.sh` -> bash, `.py` -> python) ถ้าไม่ได้ระบุ `--from`

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

- `_run()` / `_sh()` คือ helper ที่ generate ให้头顶สุดของไฟล์ — ใช้ `subprocess`
  แปลไม่ได้ 100% พวก array/map/heredoc/trap/`select`
- `set -e`/`alias` ได้เป็น comment `# TODO:` ไม่ใช่พฤติกรรมเดิม
- โค้ดที่ซับซ้อนมาก ผลที่ได้อาจต้องตรวจเองทีละบรรทัด (ซึ่งก็เป็นจุดประสงค์ของการเอามาอ่าน)

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
examples/flow.sh/.py   # ตัวอย่าง case/while/redirect/glob
examples/*_rt.sh       # แปลงกลับ python -> bash (ตรวจผ่าน bash -n)
```
