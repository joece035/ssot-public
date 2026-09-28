# bash: #!/bin/bash
#!/usr/bin/env pwsh
# ตัวอย่างสำหรับฝึกอ่าน python
# bash: name="World"
$name = 'World'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: export COUNT=3
$env:COUNT = 3  # export -> $env:VAR

# bash: echo "Hello $name"
Write-Output "Hello $name"  # echo -> Write-Output
# bash: echo "count = $COUNT"
Write-Output "count = $COUNT"  # echo -> Write-Output

# bash: if [ -f /etc/hostname ]; then
if (Test-Path '/etc/hostname' -PathType Leaf) {  # if ...; then -> if (...) {
    # bash: cat /etc/hostname
    Get-Content '/etc/hostname'  # cat -> Get-Content (ไฟล์ใหญ่เติม -Raw)
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# bash: for i in 1 2 3; do
foreach ($i in 1, 2, 3) {  # for..in -> foreach (array ของ pwsh คั่นด้วย ,)
    # bash: echo "loop $i"
    Write-Output "loop $i"  # echo -> Write-Output
# bash: done
# -> จบ loop — pwsh ปิดด้วย } แทน done
}

# bash: greet() {
function greet {  # ฟังก์ชัน bash -> function name {
    # bash: echo "Hi there"
    Write-Output 'Hi there'  # echo -> Write-Output
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# bash: mkdir -p /tmp/codetrans-demo
New-Item -ItemType Directory -Force '/tmp/codetrans-demo'  # mkdir -p -> New-Item -ItemType Directory -Force
# bash: touch /tmp/codetrans-demo/a.txt
New-Item -ItemType File '/tmp/codetrans-demo/a.txt'  # touch -> New-Item -ItemType File
# bash: cp /tmp/codetrans-demo/a.txt /tmp/codetrans-demo/b.txt
Copy-Item '/tmp/codetrans-demo/a.txt' '/tmp/codetrans-demo/b.txt'  # cp -> Copy-Item
# bash: ls /tmp/codetrans-demo
ls /tmp/codetrans-demo  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: rm /tmp/codetrans-demo/b.txt
Remove-Item '/tmp/codetrans-demo/b.txt'  # rm -> Remove-Item (-r=-Recurse, -f=-Force)
