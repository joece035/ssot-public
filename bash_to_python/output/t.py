#!/usr/bin/env python3


import os


HOME = os.environ.get("HOME", os.path.expanduser("~"))



# bash: test_p="$HOME/ssot/shared/personal"
test_p = f"{HOME}/ssot/shared/personal"  # กำหนดค่าตัวแปร (ไม่ต้องมี export); $VAR -> f-string {VAR}
# bash: test_p2="/home/joez/ssot/shared/functions"
test_p2 = "/home/joez/ssot/shared/functions"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)



# bash: printf '\"%s\"\n\"%s\"\n' "${test_p/#$HOME/\~}" "${test_p2/#$HOME/\~}"
print("\"%s\"\n\"%s\"\n" % (("~" + test_p[len(HOME):] if test_p.startswith(HOME) else test_p), ("~" + test_p2[len(HOME):] if test_p2.startswith(HOME) else test_p2)))  # printf -> print() + % format




