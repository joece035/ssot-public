#!/usr/bin/env python3


import glob
import os
import shutil
import subprocess


def _run(cmd):
    """รันคำสั่ง shell ตรงๆ แล้วคืน exit status (ใช้กับคำสั่งที่ไม่ได้แปลงเป็น python) """
    return subprocess.run(cmd, shell=True).returncode


def _sh(cmd):
    """รันคำสั่ง shell แล้วคืนผลลัพธ์ stdout (เทียบเท่า $(...) ใน bash) """
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.rstrip("\n")



# ครอบคลุม: while, if/elif/else, case, substitution, redirect, glob
# bash: set -u
# TODO: 'set' ไม่มีใน python ตรงตัว: set -u
# bash: dir=/tmp/codetrans-test2
dir = "/tmp/codetrans-test2"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: mkdir -p "$dir"
os.makedirs(dir, exist_ok=True)  # mkdir -> os.makedirs()
# bash: total=0
total = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: while [ $total -lt 3 ]; do
while int(total) < 3:  # ใส่ : แทน do
    # bash: total=$((total + 1))
    total = (total + 1)  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
    # bash: echo "step $total"
    print(f"step {total}")  # echo -> print(); $VAR -> f-string {VAR}
# bash: done
# -> จบ loop — python เยื้องกลับ (dedent) แทน done

# bash: if [ -d "$dir" ]; then
if os.path.isdir(dir):  # ใส่ : แทน then
    # bash: echo "dir exists"
    print("dir exists")  # echo -> print()
# bash: elif [ -n "$dir" ]; then
elif dir:  # ใส่ : แทน then
    # bash: echo "dir name set"
    print("dir name set")  # echo -> print()
# bash: else
else:  # else: (ไม่ต้องมี then)
    # bash: echo "no dir"
    print("no dir")  # echo -> print()
# bash: fi
# -> จบ if — python เยื้องกลับ (dedent) แทน fi

# bash: case "$total" in
match total:  # case -> match/case (python 3.10+)
    # bash: 3) echo "three" ;;
    case _ if str(total) == "3":  # แยกเงื่อนไข case -> case:
        print("three")  # echo -> print()
    # bash: 4) echo "four" ;;
    case _ if str(total) == "4":  # แยกเงื่อนไข case -> case:
        print("four")  # echo -> print()
    # bash: *) echo "other" ;;
    case _:  # แยกเงื่อนไข case -> case:
        print("other")  # echo -> print()
# bash: esac
# -> จบ case — python เยื้องกลับแทน esac

# bash: files=$(ls /tmp | head -2)
files = _sh("ls /tmp | head -2")  # กำหนดค่าตัวแปร (ไม่ต้องมี export); $(cmd) -> _sh() (subprocess)
# bash: echo "files: $files"
print(f"files: {files}")  # echo -> print(); $VAR -> f-string {VAR}

# bash: grep -c . /etc/hostname > "$dir/count.txt"
_run("grep -c . /etc/hostname > \"" + str(dir) + "/count.txt\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
# bash: cat "$dir/count.txt"
print(open(f"{dir}/count.txt").read(), end="")  # cat -> open().read(); $VAR -> f-string {VAR}

# bash: for f in "$dir"/*.txt; do
for f in glob.glob(f"{dir}/*.txt"):  # ใส่ : แทน do
    # bash: echo "file: $f"
    print(f"file: {f}")  # echo -> print(); $VAR -> f-string {VAR}
# bash: done
# -> จบ loop — python เยื้องกลับ (dedent) แทน done

# bash: rm -rf "$dir"
shutil.rmtree(dir)  # rm -> os.remove() / shutil.rmtree()
