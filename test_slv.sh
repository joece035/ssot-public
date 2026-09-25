#!/usr/bin/env bash
source ~/.bashrc 2>/dev/null || true
command -v slv >/dev/null 2>&1 && echo "yes" || source "${SSOT:-$HOME/ssot}/shared/personal/maths.sh"

_check_ -f slv || exit 1
# test_solve.sh - Test suite for `slv` helper

for f in "${BASH_SOURCE[@]}" ; do
		echo $f
done		
# ============================================================
# SLV EDGE / STRESS TEST SUITE
# ============================================================

#set -u

PASS=0
FAIL=0
SKIP=0


run_test() {
    local name="$1"
    shift

    echo
    echo "============================================================"
    echo "[TEST] $name"
    echo '>>> slv $*'
    echo "------------------------------------------------------------"

    if timeout 50 slv "$@"; then
        echo "[PASS] command executed"
        ((PASS++))
    else
        local rc=$?
        echo "[FAIL] exit code: $rc"
        ((FAIL++))
    fi
}

# ------------------------------------------------------------
# 1. BASIC LINEAR
# ------------------------------------------------------------

run_test \
    "Linear equation" \
    "2x + 10 = 30"

run_test \
    "Negative solution" \
    "2x + 10 = 0"

run_test \
    "Fraction coefficient" \
    "x/2 = 10"

run_test \
    "Decimal coefficient" \
    "2.5x = 10"


# ------------------------------------------------------------
# 2. IMPLICIT MULTIPLICATION
# ------------------------------------------------------------

run_test \
    "Implicit multiplication" \
    "2x + 3x = 25"

run_test \
    "Number × parenthesis" \
    "2(x + 3) = 14"

run_test \
    "Variable × parenthesis" \
    "x(x + 2) = 15"

run_test \
    "Two variables implicit multiplication" \
    "xy = 20" \
    "x = 4"


# ------------------------------------------------------------
# 3. OPERATOR PRECEDENCE
# ------------------------------------------------------------

run_test \
    "Power precedence" \
    "y=-a^2+b" \
    "a=3" \
    "b=10"

run_test \
    "Parentheses override precedence" \
    "y=(-a)^2+b" \
    "a=3" \
    "b=10"

run_test \
    "Mixed operators" \
    "y=2+3*4^2"

run_test \
    "Nested parentheses" \
    "y=((2+3)*(4+5))/3"


# ------------------------------------------------------------
# 4. POLYNOMIAL / MULTIPLE ROOTS
# ------------------------------------------------------------

run_test \
    "Quadratic positive root" \
    "x^2 = 25"

run_test \
    "Quadratic negative root" \
    "x^2 = 25" \
    "x=-5"

run_test \
    "Quadratic with two roots" \
    "x^2 - 5x + 6 = 0"

run_test \
    "Cubic" \
    "x^3 = 27"

run_test \
    "Polynomial factor form" \
    "(x-2)*(x-3)=0"


# ------------------------------------------------------------
# 5. MULTI-VARIABLE
# ------------------------------------------------------------

run_test \
    "Two-variable substitution" \
    "x=2x+y" \
    "y=2"

run_test \
    "Beam reactions" \
    "Ra+Rb=100" \
    "Ra=40"

run_test \
    "Three-variable chain" \
    "x=y+z" \
    "y=a*2" \
    "z=10" \
    "a=5"

run_test \
    "Pythagorean" \
    "a^2+b^2=c^2" \
    "a=3" \
    "b=4"


# ------------------------------------------------------------
# 6. CHAINED DEPENDENCY
# ------------------------------------------------------------

run_test \
    "Dependency chain A -> B -> C" \
    "c=b*2" \
    "b=a+3" \
    "a=5"

run_test \
    "Reverse dependency" \
    "a=b+3" \
    "b=c*2" \
    "c=4"


# ------------------------------------------------------------
# 7. TRIGONOMETRY
# ------------------------------------------------------------

run_test \
    "sin radian" \
    "y=sin(0)"

run_test \
    "sin degree" \
    --deg \
    "y=sin(30)"

run_test \
    "cos degree" \
    --deg \
    "y=cos(60)"

run_test \
    "tan degree" \
    --deg \
    "y=tan(45)"

run_test \
    "Trig with variable" \
    --deg \
    "h=a*sin(b)" \
    "a=10" \
    "b=30"

run_test \
    "Trig expression" \
    --deg \
    "y=10*sin(30)+10*cos(60)"


# ------------------------------------------------------------
# 8. NESTED FUNCTIONS
# ------------------------------------------------------------

run_test \
    "Nested sin/cos" \
    --deg \
    "y=sin(cos(0))"

run_test \
    "Trig + power" \
    --deg \
    "y=sin(30)^2"

run_test \
    "Trig + arithmetic" \
    --deg \
    "y=2*sin(30)+3"


# ------------------------------------------------------------
# 9. FLOAT / PRECISION
# ------------------------------------------------------------

run_test \
    "Simple float" \
    "x=7/2"

run_test \
    "Repeating decimal" \
    "x=1/3"

run_test \
    "Float equation" \
    "2.75x=11"

run_test \
    "Small decimal" \
    "x=0.001/2"

run_test \
    "Large number" \
    "x=999999999*999999999"


# ------------------------------------------------------------
# 10. ZERO / NEGATIVE / SPECIAL VALUES
# ------------------------------------------------------------

run_test \
    "Zero" \
    "x=0"

run_test \
    "Negative number" \
    "x=-10"

run_test \
    "Negative coefficient" \
    "-2x=10"

run_test \
    "Negative inside parentheses" \
    "x=(-2)*(-5)"

run_test \
    "Zero multiplication" \
    "x=0*999999"


# ------------------------------------------------------------
# 11. DIVISION EDGE CASES
# ------------------------------------------------------------

run_test \
    "Division by non-zero" \
    "x=10/2"

run_test \
    "Division by variable" \
    "x=10/a" \
    "a=2"

run_test \
    "Division by zero" \
    "x=10/0"

run_test \
    "Zero denominator variable" \
    "x=10/a" \
    "a=0"


# ------------------------------------------------------------
# 12. DOMAIN / MATHEMATICAL EDGE CASES
# ------------------------------------------------------------

run_test \
    "sqrt positive" \
    "x=sqrt(25)"

run_test \
    "sqrt zero" \
    "x=sqrt(0)"

run_test \
    "sqrt negative" \
    "x=sqrt(-1)"

run_test \
    "log positive" \
    "x=log(10)"

run_test \
    "log zero" \
    "x=log(0)"

run_test \
    "log negative" \
    "x=log(-1)"


# ------------------------------------------------------------
# 13. WHITESPACE
# ------------------------------------------------------------

run_test \
    "No spaces" \
    "x=2+3*4"

run_test \
    "Normal spaces" \
    "x = 2 + 3 * 4"

run_test \
    "Ugly spaces" \
    "  x   =   ( 2 + 3 ) * 4  "


# ------------------------------------------------------------
# 14. VARIABLE NAMES
# ------------------------------------------------------------

run_test \
    "Single-letter variable" \
    "x=10"

run_test \
    "Multi-letter variable" \
    "width=10" \
    "length=20"

run_test \
    "Engineering variables" \
    "stress=force/area" \
    "force=1000" \
    "area=50"


# ------------------------------------------------------------
# 15. ENGINEERING EQUATIONS
# ------------------------------------------------------------

run_test \
    "Stress" \
    "stress=force/area" \
    "force=1000" \
    "area=50"

run_test \
    "Rectangle area" \
    "A=b*h" \
    "b=5" \
    "h=10"

run_test \
    "Beam reaction" \
    "Ra+Rb=P" \
    "P=100" \
    "Ra=40"

run_test \
    "Pythagorean engineering length" \
    "L^2=x^2+y^2" \
    "x=300" \
    "y=400"


# ------------------------------------------------------------
# 16. WINRATE CASE
# ------------------------------------------------------------

run_test \
    "Winrate target" \
    "88.99/100=w/(w+L)" \
    "w=2675"


# ------------------------------------------------------------
# 17. POTENTIAL PARSER CONFUSION
# ------------------------------------------------------------

run_test \
    "a+b*c" \
    "y=a+b*c" \
    "a=2" \
    "b=3" \
    "c=4"

run_test \
    "(a+b)*c" \
    "y=(a+b)*c" \
    "a=2" \
    "b=3" \
    "c=4"

run_test \
    "a^b^c" \
    "y=a^b^c" \
    "a=2" \
    "b=2" \
    "c=3"

run_test \
    "Unary minus + power" \
    "y=-a^2" \
    "a=3"


# ------------------------------------------------------------
# 18. EMPTY / INVALID INPUT
# ------------------------------------------------------------

run_test \
    "Empty expression" \
    ""

run_test \
    "Incomplete equation" \
    "x="

run_test \
    "Broken parenthesis" \
    "x=(2+3"

run_test \
    "Unknown variable" \
    "x=a+10"

run_test \
    "Invalid operator" \
    "x=2*/3"


# ------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------

echo
echo
echo "============================================================"
echo "                    SLV TEST SUMMARY"
echo "============================================================"
echo
echo "PASS : $PASS"
echo "FAIL : $FAIL"
echo "SKIP : $SKIP"
echo
echo "============================================================"



