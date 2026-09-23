#!/usr/bin/env python3


import os
import shutil
import subprocess


def _run(cmd):
    """รันคำสั่ง shell ตรงๆ แล้วคืน exit status (ใช้กับคำสั่งที่ไม่ได้แปลงเป็น python) """
    return subprocess.run(cmd, shell=True).returncode



# ตัวอย่างสำหรับฝึกอ่าน python
# bash: name="World"
name = "World"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: export COUNT=3
COUNT = 3  # ตัวแปร python เป็น global อยู่แล้ว ไม่ต้อง export

# bash: echo "Hello $name"
print(f"Hello {name}")  # echo -> print(); $VAR -> f-string {VAR}
# bash: echo "count = $COUNT"
print(f"count = {COUNT}")  # echo -> print(); $VAR -> f-string {VAR}

# bash: if [ -f /etc/hostname ]; then
if os.path.exists("/etc/hostname"):  # ใส่ : แทน then
    # bash: cat /etc/hostname
    print(open("/etc/hostname").read(), end="")  # cat -> open().read()
# bash: fi
# -> จบ if — python เยื้องกลับ (dedent) แทน fi

# bash: for i in 1 2 3; do
for i in [1, 2, 3]:  # ใส่ : แทน do
    # bash: echo "loop $i"
    print(f"loop {i}")  # echo -> print(); $VAR -> f-string {VAR}
# bash: done
# -> จบ loop — python เยื้องกลับ (dedent) แทน done

# bash: greet() {
def greet():  # ฟังก์ชัน bash -> def name():
    # bash: echo "Hi there"
    print("Hi there")  # echo -> print()
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }

# bash: mkdir -p /tmp/codetrans-demo
os.makedirs("/tmp/codetrans-demo", exist_ok=True)  # mkdir -> os.makedirs()
# bash: touch /tmp/codetrans-demo/a.txt
open("/tmp/codetrans-demo/a.txt", "a").close()  # touch -> open(f, 'a')
# bash: cp /tmp/codetrans-demo/a.txt /tmp/codetrans-demo/b.txt
shutil.copy("/tmp/codetrans-demo/a.txt", "/tmp/codetrans-demo/b.txt")  # cp -> shutil.copy()
# bash: ls /tmp/codetrans-demo
_run("ls /tmp/codetrans-demo")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
# bash: rm /tmp/codetrans-demo/b.txt
os.remove("/tmp/codetrans-demo/b.txt")  # rm -> os.remove() / shutil.rmtree()
