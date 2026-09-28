#!/usr/bin/env bash


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



    # ตัวอย่างสำหรับฝึกอ่าน python
    # bash: name="World"
    :
}
# python: name = "World"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
name="World"  # ตัวแปร -> NAME=value
# bash: export COUNT=3
# python: COUNT = 3  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export
COUNT=3  # ตัวแปร -> NAME=value

# bash: echo "Hello $name"
# python: print(f"Hello {name}")  # echo -> print(); $VAR -> f-string {VAR}
echo "Hello $name"  # print -> echo
# bash: echo "count = $COUNT"
# python: print(f"count = {COUNT}")  # echo -> print(); $VAR -> f-string {VAR}
echo "count = $COUNT"  # print -> echo

# bash: if [ -f /etc/hostname ]; then
# python: if os.path.exists("/etc/hostname"):  # ใส่ : แทน then
if [ -f "/etc/hostname" ]; then  # if: -> if ...; then
    # bash: cat /etc/hostname
    # python: print(open("/etc/hostname").read(), end="")  # cat -> open().read()
    cat "/etc/hostname"  # print -> echo
    # bash: fi
    # -> จบ if — python เยื้องกลับ (dedent) แทน fi

    # bash: for i in 1 2 3; do
fi
# python: for i in [1, 2, 3]:  # ใส่ : แทน do
for i in 1 2 3; do  # for: -> for ...; do
    # bash: echo "loop $i"
    # python: print(f"loop {i}")  # echo -> print(); $VAR -> f-string {VAR}
    echo "loop $i"  # print -> echo
    # bash: done
    # -> จบ loop — python เยื้องกลับ (dedent) แทน done

    # bash: greet() {
done
# python: def greet():  # ฟังก์ชัน bash -> def name():
greet() {  # def -> name() { }
    # bash: echo "Hi there"
    # python: print("Hi there")  # echo -> print()
    echo "Hi there"  # print -> echo
    # bash: }
    # -> จบฟังก์ชัน — python เยื้องกลับแทน }

    # bash: mkdir -p /tmp/codetrans-demo
}
# python: os.makedirs("/tmp/codetrans-demo", exist_ok=True)  # mkdir -> os.makedirs()
mkdir -p "/tmp/codetrans-demo"
# bash: touch /tmp/codetrans-demo/a.txt
# python: open("/tmp/codetrans-demo/a.txt", "a").close()  # touch -> open(f, 'a')
touch "/tmp/codetrans-demo/a.txt"
# bash: cp /tmp/codetrans-demo/a.txt /tmp/codetrans-demo/b.txt
# python: shutil.copy("/tmp/codetrans-demo/a.txt", "/tmp/codetrans-demo/b.txt")  # cp -> shutil.copy()
cp "/tmp/codetrans-demo/a.txt" "/tmp/codetrans-demo/b.txt"
# bash: ls /tmp/codetrans-demo
# python: _run("ls /tmp/codetrans-demo")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
ls /tmp/codetrans-demo  # _run() -> รันคำสั่ง shell ตรงๆ
# bash: rm /tmp/codetrans-demo/b.txt
# python: os.remove("/tmp/codetrans-demo/b.txt")  # rm -> os.remove() / shutil.rmtree()
rm "/tmp/codetrans-demo/b.txt"
