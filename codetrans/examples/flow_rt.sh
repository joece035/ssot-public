#!/usr/bin/env bash


# python: import glob
# bash ไม่ต้อง import: import glob
# python: import os
# bash ไม่ต้อง import: import os
# python: import shutil
# bash ไม่ต้อง import: import shutil
# python: import subprocess
# bash ไม่ต้อง import: import subprocess


# python: def _run(cmd):
_run() {  # def -> name() { }
    # TODO: parameter python (cmd) = $1, $2, ... ใน bash
# """รันคำสั่ง shell ตรงๆ แล้วคืน exit status (ใช้กับคำสั่งที่ไม่ได้แปลงเป็น python) """
    # python: return subprocess.run(cmd, shell=True).returncode
    # TODO: return ค่าซับซ้อน: return subprocess.run(cmd, shell=True).returncode


    :
}
# python: def _sh(cmd):
_sh() {  # def -> name() { }
    # TODO: parameter python (cmd) = $1, $2, ... ใน bash
# """รันคำสั่ง shell แล้วคืนผลลัพธ์ stdout (เทียบเท่า $(...) ใน bash) """
    # python: return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.rstrip("\n")
    # TODO: return ค่าซับซ้อน: return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.rstrip("\n")



    # ครอบคลุม: while, if/elif/else, case, substitution, redirect, glob
    # bash: set -u
    # TODO: 'set' ไม่มีใน python ตรงตัว: set -u
    # bash: dir=/tmp/codetrans-test2
    :
}
# python: dir = "/tmp/codetrans-test2"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
dir="/tmp/codetrans-test2"  # ตัวแปร -> NAME=value
# bash: mkdir -p "$dir"
# python: os.makedirs(dir, exist_ok=True)  # mkdir -> os.makedirs()
mkdir -p $dir
# bash: total=0
# python: total = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
total=0  # ตัวแปร -> NAME=value
# bash: while [ $total -lt 3 ]; do
# python: while int(total) < 3:  # ใส่ : แทน do
while [ $total -lt 3 ]; do  # while: -> while ...; do
    # bash: total=$((total + 1))
    # python: total = (total + 1)  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
    total=$((total + 1))  # ตัวแปร -> NAME=value
    # bash: echo "step $total"
    # python: print(f"step {total}")  # echo -> print(); $VAR -> f-string {VAR}
    echo "step $total"  # print -> echo
    # bash: done
    # -> จบ loop — python เยื้องกลับ (dedent) แทน done

    # bash: if [ -d "$dir" ]; then
done
# python: if os.path.isdir(dir):  # ใส่ : แทน then
if [ -d $dir ]; then  # if: -> if ...; then
    # bash: echo "dir exists"
    # python: print("dir exists")  # echo -> print()
    echo "dir exists"  # print -> echo
    # bash: elif [ -n "$dir" ]; then
    # python: elif dir:  # ใส่ : แทน then
    elif [ -n "$dir" ]; then  # elif: -> elif ...; then
    # bash: echo "dir name set"
    # python: print("dir name set")  # echo -> print()
    echo "dir name set"  # print -> echo
    # bash: else
    # python: else:  # else: (ไม่ต้องมี then)
    else  # else: -> else
    # bash: echo "no dir"
    # python: print("no dir")  # echo -> print()
    echo "no dir"  # print -> echo
    # bash: fi
    # -> จบ if — python เยื้องกลับ (dedent) แทน fi

    # bash: case "$total" in
fi
# python: match total:  # case -> match/case (python 3.10+)
case $total in  # match: -> case ... in
    # bash: 3) echo "three" ;;
    # python: case _ if str(total) == "3":  # แยกเงื่อนไข case -> case:
    3)  # case: -> pattern)
    # python: print("three")  # echo -> print()
    echo "three"  # print -> echo
    # bash: 4) echo "four" ;;
    # python: case _ if str(total) == "4":  # แยกเงื่อนไข case -> case:
    ;;
    4)  # case: -> pattern)
    # python: print("four")  # echo -> print()
    echo "four"  # print -> echo
    # bash: *) echo "other" ;;
    # python: case _:  # แยกเงื่อนไข case -> case:
    ;;
    *)  # case: -> pattern)
    # python: print("other")  # echo -> print()
    echo "other"  # print -> echo
    # bash: esac
    # -> จบ case — python เยื้องกลับแทน esac

    # bash: files=$(ls /tmp | head -2)
    ;;
esac
# python: files = _sh("ls /tmp | head -2")  # กำหนดค่าตัวแปร (ไม่ต้องมี export); $(cmd) -> _sh() (subprocess)
files=$(ls /tmp | head -2)  # ตัวแปร -> NAME=value
# bash: echo "files: $files"
# python: print(f"files: {files}")  # echo -> print(); $VAR -> f-string {VAR}
echo "files: $files"  # print -> echo

# bash: grep -c . /etc/hostname > "$dir/count.txt"
# python: _run("grep -c . /etc/hostname > \"" + str(dir) + "/count.txt\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
grep -c . /etc/hostname > "$dir/count.txt"  # _run() -> รันคำสั่ง shell ตรงๆ
# bash: cat "$dir/count.txt"
# python: print(open(f"{dir}/count.txt").read(), end="")  # cat -> open().read(); $VAR -> f-string {VAR}
cat "$dir/count.txt"  # print -> echo

# bash: for f in "$dir"/*.txt; do
# python: for f in glob.glob(f"{dir}/*.txt"):  # ใส่ : แทน do
for f in $dir/*.txt; do  # for: -> for ...; do
    # bash: echo "file: $f"
    # python: print(f"file: {f}")  # echo -> print(); $VAR -> f-string {VAR}
    echo "file: $f"  # print -> echo
    # bash: done
    # -> จบ loop — python เยื้องกลับ (dedent) แทน done

    # bash: rm -rf "$dir"
done
# python: shutil.rmtree(dir)  # rm -> os.remove() / shutil.rmtree()
rm -rf $dir
