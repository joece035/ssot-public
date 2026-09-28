#!/usr/bin/env bash
# bash: #!/bin/bash
# powershell: #!/usr/bin/env pwsh
#!/usr/bin/env bash
# ตัวอย่างสำหรับฝึกอ่าน python
# bash: name="World"
# powershell: $name = 'World'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
name='World'  # pwsh $x=.. -> bash x=.. (เอา $ ออก)
# bash: export COUNT=3
# powershell: $env:COUNT = 3  # export -> $env:VAR
export COUNT=3  # $env:VAR -> export VAR=...

# bash: echo "Hello $name"
# powershell: Write-Output "Hello $name"  # echo -> Write-Output
echo "Hello $name"  # Write-Output -> echo
# bash: echo "count = $COUNT"
# powershell: Write-Output "count = $COUNT"  # echo -> Write-Output
echo "count = $COUNT"  # Write-Output -> echo

# bash: if [ -f /etc/hostname ]; then
# powershell: if (Test-Path '/etc/hostname' -PathType Leaf) {  # if ...; then -> if (...) {
if [ -f '/etc/hostname' ]; then  # if (...) { -> if ...; then
    # bash: cat /etc/hostname
    # powershell: Get-Content '/etc/hostname'  # cat -> Get-Content (ไฟล์ใหญ่เติม -Raw)
    cat '/etc/hostname'  # Get-Content -> cat
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
# powershell: }
fi

# bash: for i in 1 2 3; do
# powershell: foreach ($i in 1, 2, 3) {  # for..in -> foreach (array ของ pwsh คั่นด้วย ,)
for i in 1 2 3; do  # foreach -> for ...; do; array คั่น , -> คั่น space
    # bash: echo "loop $i"
    # powershell: Write-Output "loop $i"  # echo -> Write-Output
    echo "loop $i"  # Write-Output -> echo
    # bash: done
    # -> จบ loop — pwsh ปิดด้วย } แทน done
# powershell: }
done

# bash: greet() {
# powershell: function greet {  # ฟังก์ชัน bash -> function name {
greet() {  # function name { -> name() {
    # bash: echo "Hi there"
    # powershell: Write-Output 'Hi there'  # echo -> Write-Output
    echo 'Hi there'  # Write-Output -> echo
    # bash: }
    # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
# powershell: }
}

# bash: mkdir -p /tmp/codetrans-demo
# powershell: New-Item -ItemType Directory -Force '/tmp/codetrans-demo'  # mkdir -p -> New-Item -ItemType Directory -Force
mkdir -p '/tmp/codetrans-demo'  # New-Item -ItemType Directory -> mkdir -p
# bash: touch /tmp/codetrans-demo/a.txt
# powershell: New-Item -ItemType File '/tmp/codetrans-demo/a.txt'  # touch -> New-Item -ItemType File
touch '/tmp/codetrans-demo/a.txt'  # New-Item -ItemType File -> touch
# bash: cp /tmp/codetrans-demo/a.txt /tmp/codetrans-demo/b.txt
# powershell: Copy-Item '/tmp/codetrans-demo/a.txt' '/tmp/codetrans-demo/b.txt'  # cp -> Copy-Item
cp '/tmp/codetrans-demo/a.txt' '/tmp/codetrans-demo/b.txt'  # Copy-Item -> cp
# bash: ls /tmp/codetrans-demo
# powershell: ls /tmp/codetrans-demo  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
ls /tmp/codetrans-demo  # ส่งผ่านตรง (native ใน bash ได้)
# bash: rm /tmp/codetrans-demo/b.txt
# powershell: Remove-Item '/tmp/codetrans-demo/b.txt'  # rm -> Remove-Item (-r=-Recurse, -f=-Force)
rm '/tmp/codetrans-demo/b.txt'  # Remove-Item -> rm (-Recurse/-Force เป็น -r/-f)
