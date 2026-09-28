#!/usr/bin/env python3
"""
Comprehensive test suite for codetrans.py verifying all translation pairs:
1. bash -> python
2. bash -> powershell
3. python -> bash
4. powershell -> bash
"""

import sys
import unittest
from codetrans import translate


class TestBashToPython(unittest.TestCase):
    def test_variable_assignment(self):
        code = 'export NAME="World"\nlocal num=42\ncount=$((num + 1))'
        res = translate(code, "bash", "python", headers=False, notes=False)
        self.assertIn('NAME = "World"', res)
        self.assertIn("num = 42", res)
        self.assertIn("count = (num + 1)", res)

    def test_parameter_expansion(self):
        code = (
            'test_p="$HOME/ssot/shared/personal"\n'
            's="${test_p/#$HOME/~}"\n'
            'l="${#test_p}"\n'
            'd="${var:-default_val}"\n'
            'u="${var^^}"\n'
            'sub="${var:2:5}"\n'
            'rep="${var//foo/bar}"\n'
            'strip="${var#prefix_}"\n'
        )
        res = translate(code, "bash", "python", headers=False, notes=False)
        self.assertIn(".startswith(HOME)", res)
        self.assertIn("len(test_p)", res)
        self.assertIn('or "default_val"', res)
        self.assertIn("var.upper()", res)
        self.assertIn("var[2:7]", res)
        self.assertIn('.replace("foo", "bar")', res)
        self.assertIn('.startswith("prefix_")', res)

    def test_printf_escaping(self):
        code = 'printf \'\\"%s\\"\\n\' "$val"'
        res = translate(code, "bash", "python", headers=False, notes=False)
        # Should NOT contain \\\"
        self.assertIn('print("\\"%s\\"\\n" % (val,))', res)

    def test_conditions_and_negation(self):
        code = (
            'if [ -f "$file" ]; then echo "exists"; fi\n'
            'if [ ! -f "$file" ]; then echo "missing"; fi\n'
            'if [[ ! -d "$dir" ]]; then echo "no dir"; fi\n'
            'if [[ "$str" == *.txt ]]; then echo "txt"; fi\n'
        )
        res = translate(code, "bash", "python", headers=False, notes=False)
        self.assertIn("if os.path.exists(file):", res)
        self.assertIn("if not (os.path.exists(file)):", res)
        self.assertIn("if not (os.path.isdir(dir)):", res)
        self.assertIn('fnmatch.fnmatch(str(str), "*.txt")', res)

    def test_loops_and_functions(self):
        code = (
            'for i in 1 2 3; do echo "$i"; done\n'
            'for ((i=0; i<3; i++)); do echo "$i"; done\n'
            'while [ $i -lt 3 ]; do ((i++)); done\n'
            'greet() { echo "hi $1"; }\n'
        )
        res = translate(code, "bash", "python", headers=False, notes=False)
        self.assertIn("for i in [1, 2, 3]:", res)
        self.assertIn("for i in range(0, 3):", res)
        self.assertIn("while i < 3:", res)
        self.assertIn("def greet():", res)


class TestBashToPowerShell(unittest.TestCase):
    def test_variable_assignment(self):
        code = 'NAME="World"\nexport ENV_VAR="123"'
        res = translate(code, "bash", "powershell", headers=False, notes=False)
        self.assertIn('$NAME = "World"', res)
        self.assertIn('$env:ENV_VAR = "123"', res)

    def test_parameter_expansion(self):
        code = (
            'test_p="$HOME/ssot/shared/personal"\n'
            's="${test_p/#$HOME/~}"\n'
            'l="${#test_p}"\n'
            'd="${var:-default}"\n'
            'u="${var^^}"\n'
            'rep="${var//foo/bar}"\n'
        )
        res = translate(code, "bash", "powershell", headers=False, notes=False)
        self.assertIn("-replace ('^' + [regex]::Escape($HOME)), '~'", res)
        self.assertIn("($test_p.Length)", res)
        self.assertIn("($var ?? 'default')", res)
        self.assertIn("($var.ToUpper())", res)
        self.assertIn("-replace [regex]::Escape('foo'), 'bar'", res)

    def test_printf(self):
        code = 'printf \'\\"%s\\"\\n\' "$val"'
        res = translate(code, "bash", "powershell", headers=False, notes=False)
        self.assertIn('Write-Host -NoNewline ("`"{0}`"`n" -f $val)', res)

    def test_conditions_and_negation(self):
        code = (
            'if [ -f "$file" ]; then echo "ok"; fi\n'
            'if [ ! -f "$file" ]; then echo "not ok"; fi\n'
            'if [[ ! -d "$dir" ]]; then echo "no dir"; fi\n'
            'if [[ "$str" == *.txt ]]; then echo "txt"; fi\n'
        )
        res = translate(code, "bash", "powershell", headers=False, notes=False)
        self.assertIn("Test-Path $file -PathType Leaf", res)
        self.assertIn("-not (Test-Path $file -PathType Leaf)", res)
        self.assertIn("-not (Test-Path $dir -PathType Container)", res)
        self.assertIn('$str -like "*.txt"', res)

    def test_loops_and_functions(self):
        code = (
            'for i in 1 2 3; do echo "$i"; done\n'
            'for ((i=0; i<3; i++)); do echo "$i"; done\n'
            'myfunc() { echo "hello"; }\n'
        )
        res = translate(code, "bash", "powershell", headers=False, notes=False)
        self.assertIn("foreach ($i in 1, 2, 3) {", res)
        self.assertIn("for ($i = 0; $i -lt 3; $i++) {", res)
        self.assertIn("function myfunc {", res)


class TestPythonToBash(unittest.TestCase):
    def test_arithmetic(self):
        code = "x = y + 1\nz = a - b\nm = p * 2\nd = q // 4"
        res = translate(code, "python", "bash", headers=False, notes=False)
        self.assertIn("x=$((y + 1))", res)
        self.assertIn("z=$((a - b))", res)
        self.assertIn("m=$((p * 2))", res)
        self.assertIn("d=$((q / 4))", res)

    def test_control_flow(self):
        code = (
            "if os.path.exists(file):\n"
            "    print(f'hi {name}')\n"
            "for i in range(1, 4):\n"
            "    print(i)\n"
        )
        res = translate(code, "python", "bash", headers=False, notes=False)
        self.assertIn("if [ -f $file ]; then", res)
        self.assertIn('echo "hi $name"', res)
        self.assertIn("for i in $(seq 1 3); do", res)


class TestPowerShellToBash(unittest.TestCase):
    def test_variables_and_arithmetic(self):
        code = '$x = 10\n$y = $x + 1\n$env:NAME = "Joe"'
        res = translate(code, "powershell", "bash", headers=False, notes=False)
        self.assertIn("x=10", res)
        self.assertIn("y=$((x + 1))", res)
        self.assertIn('export NAME="Joe"', res)

    def test_printf_and_replace_roundtrip(self):
        code = 'Write-Host -NoNewline ("`"{0}`"`n" -f ($test_p -replace (\'^\' + [regex]::Escape($HOME)), \'~\'))'
        res = translate(code, "powershell", "bash", headers=False, notes=False)
        self.assertIn('printf \'"%s"\\n\' "${test_p/#$HOME/\\~}"', res)

    def test_conditions(self):
        code = (
            'if (Test-Path $file -PathType Leaf) { Write-Output "ok" }\n'
            'if ($str -like "*.txt") { Write-Output "match" }\n'
        )
        res = translate(code, "powershell", "bash", headers=False, notes=False)
        self.assertIn("if [ -f $file ]; then", res)
        self.assertIn('if [[ $str == *.txt ]]; then', res)


if __name__ == "__main__":
    unittest.main()
