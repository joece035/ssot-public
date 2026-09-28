#!/usr/bin/env bash
# bash: #!/bin/bash
# powershell: #!/usr/bin/env pwsh
#!/usr/bin/env bash
# ครอบคลุม: while, if/elif/else, case, substitution, redirect, glob
# bash: set -u
# powershell: Set-StrictMode -Version Latest  # set -u -> Set-StrictMode (ใช้ตัวแปรก่อนกำหนดแล้ว error)
set -u  # Set-StrictMode -> set -u (เช็คตัวแปรก่อนกำหนด)
# bash: dir=/tmp/codetrans-test2
# powershell: $dir = '/tmp/codetrans-test2'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
dir='/tmp/codetrans-test2'  # pwsh $x=.. -> bash x=.. (เอา $ ออก)
# bash: mkdir -p "$dir"
# powershell: New-Item -ItemType Directory -Force $dir  # mkdir -p -> New-Item -ItemType Directory -Force
mkdir -p $dir  # New-Item -ItemType Directory -> mkdir -p
# bash: total=0
# powershell: $total = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
total=0  # pwsh $x=.. -> bash x=.. (เอา $ ออก)
# bash: while [ $total -lt 3 ]; do
# powershell: while ($total -lt 3) {  # while ...; do -> while (...) {
while [ $total -lt 3 ]; do  # while (...) { -> while ...; do
    # bash: total=$((total + 1))
    # powershell: $total = ($total + 1)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    total=$((total + 1))  # pwsh $x=.. -> bash x=.. (เอา $ ออก); $((...)) คำนวณจำนวนเต็มเหมือน bash
    # bash: echo "step $total"
    # powershell: Write-Output "step $total"  # echo -> Write-Output
    echo "step $total"  # Write-Output -> echo
    # bash: done
    # -> จบ loop — pwsh ปิดด้วย } แทน done
# powershell: }
done

# bash: if [ -d "$dir" ]; then
# powershell: if (Test-Path $dir -PathType Container) {  # if ...; then -> if (...) {
if [ -d $dir ]; then  # if (...) { -> if ...; then
    # bash: echo "dir exists"
    # powershell: Write-Output 'dir exists'  # echo -> Write-Output
    echo 'dir exists'  # Write-Output -> echo
    # bash: elif [ -n "$dir" ]; then
# powershell: } elseif (-not [string]::IsNullOrEmpty($dir)) {  # elif ...; then -> } elseif (...) {
elif [ -n "$dir" ]; then  # } elseif (...) { -> elif ...; then
    # bash: echo "dir name set"
    # powershell: Write-Output 'dir name set'  # echo -> Write-Output
    echo 'dir name set'  # Write-Output -> echo
    # bash: else
# powershell: } else {  # else -> } else {
else  # } else { -> else
    # bash: echo "no dir"
    # powershell: Write-Output 'no dir'  # echo -> Write-Output
    echo 'no dir'  # Write-Output -> echo
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
# powershell: }
fi

# bash: case "$total" in
# powershell: switch -Wildcard ($total) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
case $total in  # switch (...) { -> case ... in (-Wildcard ตรงกับ glob ของ case)
    # bash: 3) echo "three" ;;
    # powershell: 3 {  # pattern) -> "..." {
    3)  # "..." { -> pattern)
        # powershell: Write-Output 'three'  # echo -> Write-Output
        echo 'three'  # Write-Output -> echo
        # powershell: break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        # -> break ของ switch ไม่ต้องมีใน bash (ใช้ ;; แทน)
        # powershell: }
        ;;
    # bash: 4) echo "four" ;;
    # powershell: 4 {  # pattern) -> "..." {
    4)  # "..." { -> pattern)
        # powershell: Write-Output 'four'  # echo -> Write-Output
        echo 'four'  # Write-Output -> echo
        # powershell: break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        # -> break ของ switch ไม่ต้องมีใน bash (ใช้ ;; แทน)
        # powershell: }
        ;;
    # bash: *) echo "other" ;;
    # powershell: default {  # *) -> default
    *)  # default -> *)
        # powershell: Write-Output 'other'  # echo -> Write-Output
        echo 'other'  # Write-Output -> echo
        # powershell: break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        # -> break ของ switch ไม่ต้องมีใน bash (ใช้ ;; แทน)
        # powershell: }
        ;;
    # bash: esac
    # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
# powershell: }
esac

# bash: files=$(ls /tmp | head -2)
# powershell: $files = $(ls /tmp | head -2)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
files=$(ls /tmp | head -2)  # pwsh $x=.. -> bash x=.. (เอา $ ออก)
# bash: echo "files: $files"
# powershell: Write-Output "files: $files"  # echo -> Write-Output
echo "files: $files"  # Write-Output -> echo

# bash: grep -c . /etc/hostname > "$dir/count.txt"
# powershell: grep -c . /etc/hostname > "$dir/count.txt"  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
grep -c . /etc/hostname > "$dir/count.txt"  # ส่งผ่านตรง (native ใน bash ได้)
# bash: cat "$dir/count.txt"
# powershell: Get-Content "$dir/count.txt"  # cat -> Get-Content (ไฟล์ใหญ่เติม -Raw)
cat "$dir/count.txt"  # Get-Content -> cat

# bash: for f in "$dir"/*.txt; do
# powershell: foreach ($f in (Get-ChildItem "$dir/*.txt")) {  # for..in -> foreach
for f in "$dir/*.txt"; do  # foreach -> for ...; do; Get-ChildItem (glob) -> pattern ตรงๆ
    # bash: echo "file: $f"
    # powershell: Write-Output "file: $f"  # echo -> Write-Output
    echo "file: $f"  # Write-Output -> echo
    # bash: done
    # -> จบ loop — pwsh ปิดด้วย } แทน done
# powershell: }
done

# bash: rm -rf "$dir"
# powershell: Remove-Item -Recurse -Force $dir  # rm -> Remove-Item (-r=-Recurse, -f=-Force)
rm -rf $dir  # Remove-Item -> rm (-Recurse/-Force เป็น -r/-f)
