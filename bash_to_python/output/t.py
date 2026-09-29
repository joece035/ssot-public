#!/usr/bin/env python3


import os
import subprocess


HOME = os.environ.get("HOME", os.path.expanduser("~"))


def _sh(cmd):
    """รันคำสั่ง shell แล้วคืนผลลัพธ์ stdout (เทียบเท่า $(...) ใน bash) """
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.rstrip("\n")




# bash: source $HOME/.bashrc
exec(open(f"{HOME}/.bashrc").read())  # source -> exec(open().read()); $VAR -> f-string {VAR}
# bash: test_p="$HOME/ssot/shared/personal"
test_p = f"{HOME}/ssot/shared/personal"  # กำหนดค่าตัวแปร (ไม่ต้องมี export); $VAR -> f-string {VAR}
# bash: test_p2="/home/joez/ssot/shared/functions"
test_p2 = "/home/joez/ssot/shared/functions"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)



# bash: printf '\"%s\"\n\"%s\"\n' "${test_p/#$HOME/\~}" "${test_p2/#$HOME/\~}"
print("\"%s\"\n\"%s\"\n" % (("~" + test_p[len(HOME):] if test_p.startswith(HOME) else test_p), ("~" + test_p2[len(HOME):] if test_p2.startswith(HOME) else test_p2)))  # printf -> print() + % format





# bash: cmd=$(find $HOME -iname "*bak*" | sort )
cmd = _sh("find $HOME -iname \"*bak*\" | sort ")  # กำหนดค่าตัวแปร (ไม่ต้องมี export); $(cmd) -> _sh() (subprocess)
# bash: f_c=$(find $HOME -iname "*bak*" | wc -l)
f_c = _sh("find $HOME -iname \"*bak*\" | wc -l")  # กำหนดค่าตัวแปร (ไม่ต้องมี export); $(cmd) -> _sh() (subprocess)
# bash: echo $cmd
print(cmd)  # echo -> print()
# bash: echo $f_c
print(f_c)  # echo -> print()
