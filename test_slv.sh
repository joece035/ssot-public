#!/usr/bin/env bash
source ~/.bashrc 2>/dev/null || true
command -v slv >/dev/null 2>&1 || source "${SSOT:-$HOME/ssot}/shared/functions/00.1-function-tools.sh"

# test_solve.sh - Test suite for `slv` helper

echo "=========================================="
echo "          SLV HELPER TEST SUITE           "
echo "=========================================="
echo

run_test() {
    local category="$1"
    local command="$2"
    echo "------------------------------------------"
    echo "[TEST] $category"
    echo ">>> $command"
    eval "$command"
    echo
}

# --------------------------------------------------
# 1. Basic & Operator Priority Tests
# --------------------------------------------------
run_test "Parentheses & Division" \
    'slv "y=(a+b)/(c-d)" a=10 b=5 c=8 d=3'

run_test "Power Operator & Negative Numbers (-3^2 + 10)" \
    'slv "y=-a^2 + b" a=3 b=10'

run_test "Float Division handling" \
    'slv "c=a/b" a=7 b=2'


# --------------------------------------------------
# 2. Engineering & Math Functions
# --------------------------------------------------
run_test "Trigonometry (Default: Radian)" \
    'slv "h=a*sin(b)" a=10 b=30'

run_test "Trigonometry (--deg / Degree Mode)" \
    'slv --deg "h=a*sin(b)" a=10 b=30'

run_test "Trigonometry (sind built-in function without flag)" \
    'slv "h=a*sind(b)" a=10 b=30'

run_test "Logarithm & Exponential" \
    'slv "y=log(x) + exp(1)" x=100'

run_test "Absolute Values & Square Root" \
    'slv "y=abs(a-b) + sqrt(c)" a=3 b=10 c=16'


# --------------------------------------------------
# 3. Symbolic & Variable Handling
# --------------------------------------------------
run_test "Partial Substitution (Missing variable y)" \
    'slv "z=x^2 + y^2 + k" x=2 k=5'

run_test "Whitespace Robustness" \
    'slv "y =  a * b  +   c"   a=2   b=3   c=4'

run_test "Multi-character Variable Names" \
    'slv "total_cost = price * qty + vat" price=100 qty=5 vat=35'


# --------------------------------------------------
# 4. Edge Cases & Error Handling
# --------------------------------------------------
run_test "Division by Zero" \
    'slv "y=a/b" a=10 b=0'

run_test "Square root of Negative Number (Imaginary Number)" \
    'slv "y=sqrt(a)" a=-16'

run_test "Implicit Multiplication (2a + 3b)" \
    'slv "y=2a+3b" a=2 b=3'

echo "=========================================="
echo "             TESTS COMPLETED              "
echo "=========================================="




