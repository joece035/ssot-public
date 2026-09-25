#!/usr/bin/env python3


import glob
import subprocess


def _run(cmd):
    """รันคำสั่ง shell ตรงๆ แล้วคืน exit status (ใช้กับคำสั่งที่ไม่ได้แปลงเป็น python) """
    return subprocess.run(cmd, shell=True).returncode



# bash: source ~/.bashrc 2>/dev/null || true
_run("source ~/.bashrc 2>/dev/null || true")  # source -> exec(open().read()); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
# bash: command -v slv >/dev/null 2>&1 || source "${SSOT:-$HOME/ssot}/shared/functions/00.1-function-tools.sh"
#_run("command -v slv >/dev/null 2>&1 || source \"${SSOT:-" + str(HOME) + "/ssot}/shared/functions/00.1-function-tools.sh\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# test_solve.sh - Test suite for `slv` helper

# bash: echo "=========================================="
print("==========================================")  # echo -> print()
# bash: echo "          SLV HELPER TEST SUITE           "
print("          SLV HELPER TEST SUITE           ")  # echo -> print()
# bash: echo "=========================================="
print("==========================================")  # echo -> print()
# bash: echo
print()  # echo -> print()

# bash: run_test() {
def run_test():  # ฟังก์ชัน bash -> def name():
    # bash: local category="$1"
    category = 1  # python ไม่มี local
    # bash: local command="$2"
    command = 2  # python ไม่มี local
    # bash: echo "------------------------------------------"
    print("------------------------------------------")  # echo -> print()
    # bash: echo "[TEST] $category"
    print(glob.glob(f"[TEST] {category}"))  # echo -> print(); $VAR -> f-string {VAR}
    # bash: echo ">>> $command"
    print(f">>> {command}")  # echo -> print(); $VAR -> f-string {VAR}
    # bash: eval "$command"
    _run("eval \"" + str(command) + "\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
    # bash: echo
    print()  # echo -> print()
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }

# --------------------------------------------------
# 1. Basic & Operator Priority Tests
# --------------------------------------------------
# bash: run_test "Parentheses & Division"      'slv "y=(a+b)/(c-d)" a=10 b=5 c=8 d=3'
_run("run_test \"Parentheses & Division\"      'slv \"y=(a+b)/(c-d)\" a=10 b=5 c=8 d=3")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: run_test "Power Operator & Negative Numbers (-3^2 + 10)"      'slv "y=-a^2 + b" a=3 b=10'
_run("run_test \"Power Operator & Negative Numbers (-3^2 + 10)\"      'slv \"y=-a^2 + b\" a=3 b=10")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: run_test "Float Division handling"      'slv "c=a/b" a=7 b=2'
_run("run_test \"Float Division handling\"      'slv \"c=a/b\" a=7 b=2")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell


# --------------------------------------------------
# 2. Engineering & Math Functions
# --------------------------------------------------
# bash: run_test "Trigonometry (Default: Radian)"      'slv "h=a*sin(b)" a=10 b=30'
_run("run_test \"Trigonometry (Default: Radian)\"      'slv \"h=a*sin(b)\" a=10 b=30")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: run_test "Trigonometry (--deg / Degree Mode)"      'slv --deg "h=a*sin(b)" a=10 b=30'
_run("run_test \"Trigonometry (--deg / Degree Mode)\"      'slv --deg \"h=a*sin(b)\" a=10 b=30")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: run_test "Trigonometry (sind built-in function without flag)"      'slv "h=a*sind(b)" a=10 b=30'
_run("run_test \"Trigonometry (sind built-in function without flag)\"      'slv \"h=a*sind(b)\" a=10 b=30")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: run_test "Logarithm & Exponential"      'slv "y=log(x) + exp(1)" x=100'
_run("run_test \"Logarithm & Exponential\"      'slv \"y=log(x) + exp(1)\" x=100")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: run_test "Absolute Values & Square Root"      'slv "y=abs(a-b) + sqrt(c)" a=3 b=10 c=16'
_run("run_test \"Absolute Values & Square Root\"      'slv \"y=abs(a-b) + sqrt(c)\" a=3 b=10 c=16")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell


# --------------------------------------------------
# 3. Symbolic & Variable Handling
# --------------------------------------------------
# bash: run_test "Partial Substitution (Missing variable y)"      'slv "z=x^2 + y^2 + k" x=2 k=5'
_run("run_test \"Partial Substitution (Missing variable y)\"      'slv \"z=x^2 + y^2 + k\" x=2 k=5")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: run_test "Whitespace Robustness"      'slv "y =  a * b  +   c"   a=2   b=3   c=4'
_run("run_test \"Whitespace Robustness\"      'slv \"y =  a * b  +   c\"   a=2   b=3   c=4")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: run_test "Multi-character Variable Names"      'slv "total_cost = price * qty + vat" price=100 qty=5 vat=35'
_run("run_test \"Multi-character Variable Names\"      'slv \"total_cost = price * qty + vat\" price=100 qty=5 vat=35")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell


# --------------------------------------------------
# 4. Edge Cases & Error Handling
# --------------------------------------------------
# bash: run_test "Division by Zero"      'slv "y=a/b" a=10 b=0'
_run("run_test \"Division by Zero\"      'slv \"y=a/b\" a=10 b=0")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: run_test "Square root of Negative Number (Imaginary Number)"      'slv "y=sqrt(a)" a=-16'
_run("run_test \"Square root of Negative Number (Imaginary Number)\"      'slv \"y=sqrt(a)\" a=-16")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: run_test "Implicit Multiplication (2a + 3b)"      'slv "y=2a+3b" a=2 b=3'
_run("run_test \"Implicit Multiplication (2a + 3b)\"      'slv \"y=2a+3b\" a=2 b=3")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

# bash: echo "=========================================="
print("==========================================")  # echo -> print()
# bash: echo "             TESTS COMPLETED              "
print("             TESTS COMPLETED              ")  # echo -> print()
# bash: echo "=========================================="
print("==========================================")  # echo -> print()



