# bash: #!/bin/bash
#!/usr/bin/env pwsh
# ครอบคลุม: while, if/elif/else, case, substitution, redirect, glob
# bash: set -u
Set-StrictMode -Version Latest  # set -u -> Set-StrictMode (ใช้ตัวแปรก่อนกำหนดแล้ว error)
# bash: dir=/tmp/codetrans-test2
$dir = '/tmp/codetrans-test2'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: mkdir -p "$dir"
New-Item -ItemType Directory -Force $dir  # mkdir -p -> New-Item -ItemType Directory -Force
# bash: total=0
$total = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: while [ $total -lt 3 ]; do
while ($total -lt 3) {  # while ...; do -> while (...) {
    # bash: total=$((total + 1))
    $total = ($total + 1)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: echo "step $total"
    Write-Output "step $total"  # echo -> Write-Output
# bash: done
# -> จบ loop — pwsh ปิดด้วย } แทน done
}

# bash: if [ -d "$dir" ]; then
if (Test-Path $dir -PathType Container) {  # if ...; then -> if (...) {
    # bash: echo "dir exists"
    Write-Output 'dir exists'  # echo -> Write-Output
# bash: elif [ -n "$dir" ]; then
} elseif (-not [string]::IsNullOrEmpty($dir)) {  # elif ...; then -> } elseif (...) {
    # bash: echo "dir name set"
    Write-Output 'dir name set'  # echo -> Write-Output
# bash: else
} else {  # else -> } else {
    # bash: echo "no dir"
    Write-Output 'no dir'  # echo -> Write-Output
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# bash: case "$total" in
switch -Wildcard ($total) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
    # bash: 3) echo "three" ;;
    3 {  # pattern) -> "..." {
        Write-Output 'three'  # echo -> Write-Output
        break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
    }
    # bash: 4) echo "four" ;;
    4 {  # pattern) -> "..." {
        Write-Output 'four'  # echo -> Write-Output
        break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
    }
    # bash: *) echo "other" ;;
    default {  # *) -> default
        Write-Output 'other'  # echo -> Write-Output
        break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
    }
# bash: esac
# -> จบ case — pwsh ปิด switch ด้วย } แทน esac
}

# bash: files=$(ls /tmp | head -2)
$files = $(ls /tmp | head -2)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: echo "files: $files"
Write-Output "files: $files"  # echo -> Write-Output

# bash: grep -c . /etc/hostname > "$dir/count.txt"
grep -c . /etc/hostname > "$dir/count.txt"  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
# bash: cat "$dir/count.txt"
Get-Content "$dir/count.txt"  # cat -> Get-Content (ไฟล์ใหญ่เติม -Raw)

# bash: for f in "$dir"/*.txt; do
foreach ($f in (Get-ChildItem "$dir/*.txt")) {  # for..in -> foreach
    # bash: echo "file: $f"
    Write-Output "file: $f"  # echo -> Write-Output
# bash: done
# -> จบ loop — pwsh ปิดด้วย } แทน done
}

# bash: rm -rf "$dir"
Remove-Item -Recurse -Force $dir  # rm -> Remove-Item (-r=-Recurse, -f=-Force)
