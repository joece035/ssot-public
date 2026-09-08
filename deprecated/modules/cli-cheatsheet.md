---
title: 🔧 CLI Cheat Sheet
tags: [cli, cheatsheet, bash, reference]
created: 2026-07-21
updated: 2026-07-21
---

# 🔧 CLI Cheat Sheet

> [!info] วิธีใช้
> เปิดใน Obsidian แล้วใช้ `Ctrl+Shift+F` ค้นหา keyword ได้เลย

---

## 📄 1. CAT — อ่านไฟล์

### พื้นฐาน

```bash
cat file.txt                  # แสดงทั้งไฟล์
cat file1.txt file2.txt       # ต่อกัน
```

### หมายเลขบรรทัด

```bash
cat -n file.txt               # ทุกบรรทัดมีเลข
cat -n file.txt | head -20    # 20 บรรทัดแรกพร้อมเลข
cat -b file.txt               # เลขเฉพาะบรรทัดที่ไม่ empty
```

### แสดง Hidden Characters

```bash
cat -A file.txt
```

> [!tip] เช็ค CRLF
> ถ้าเห็น `^M$` แปลว่ามี Windows line ending (`\r\n`)
> แก้ด้วย: `sed -i 's/\r$//' file.txt`

### สร้างไฟล์ (heredoc)

```bash
cat > newfile.txt << 'EOF'
line 1
line 2
EOF
```

### ต่อไฟล์

```bash
cat file1.txt file2.txt > merged.txt
```

---

## 🔍 2. GREP — ค้นหาข้อความ

### พื้นฐาน

```bash
grep "error" file.txt              # หาคำว่า error
grep "error" *.log                 # หาในทุกไฟล์ .log
grep "error" /path/to/dir -r      # หาทั้ง directory (recursive)
```

### Flag สำคัญ

| Flag | ใช้ทำอะไร | ตัวอย่าง |
|------|----------|----------|
| `-i` | ไม่สนตัวเล็ก/ใหญ่ | `grep -i "error"` |
| `-v` | แสดงบรรทัดที่ **ไม่** match | `grep -v "debug"` |
| `-n` | แสดงหมายเลขบรรทัด | `grep -n "error"` |
| `-c` | นับจำนวนบรรทัดที่ match | `grep -c "error"` |
| `-l` | แสดงเฉพาะชื่อไฟล์ที่ match | `grep -rl "error" dir/` |
| `-w` | match ทั้งคำ | `grep -w "to"` (ไม่ match "today") |
| `-o` | แสดงแค่ส่วนที่ match | `grep -o "[0-9]*"` |
| `--color` | เน้นสีคำที่ match | `grep --color "error"` |

### Context — แสดงรอบๆ match

```bash
grep -A 3 "error" file.txt    # 3 บรรทัดหลัง match
grep -B 3 "error" file.txt    # 3 บรรทัดก่อน match
grep -C 3 "error" file.txt    # 3 บรรทัดก่อน + หลัง
```

### Regex

```bash
# Extended regex (-E) — ใช้ +, ?, |, () ได้
grep -E "error|warn|fail" file.txt       # หา error หรือ warn หรือ fail
grep -E "^[0-9]+" file.txt               # ขึ้นต้นด้วยตัวเลข
grep -E "error.+code" file.txt           # error ตามด้วยอะไรก็ได้ แล้ว code

# Perl regex (-P) — lookahead, \d, \t
grep -P "\d{3}-\d{4}" file.txt           # หา电话 123-4567
grep -P "\t" file.txt                    # หา Tab
grep -P "error(?= code)" file.txt        # error ที่ตามด้วย " code"
```

### Combinations ที่ใช้บ่อย

```bash
grep -rni "TODO" ~/project/              # หา TODO ทั้ง project
grep -rnv "^#\|^$" script.sh            # ข้าม comment + empty lines
grep -rE "\.py$|\.sh$" ~/scripts/        # หาไฟล์ .py หรือ .sh
```

---

## ✂️ 3. CUT — ตัด Columns/Fields

### -d — กำหนด Delimiter

```bash
echo "name:age:city" | cut -d":" -f1          # name
echo "name:age:city" | cut -d":" -f2          # age
echo "name:age:city" | cut -d":" -f1,3        # name:city
echo "name:age:city" | cut -d":" -f2-         # age:city (到最后)
```

### -f — เลือก Field (คอลัมน์)

```bash
cut -d":" -f1,6 /etc/passwd              # user + home dir
ps aux | cut -d" " -f1,11                # user + command
```

### -c — ตัดตามตำแหน่งตัวอักษร

```bash
echo "hello world" | cut -c1-5           # hello
echo "hello world" | cut -c7-            # world
```

### --complement — แสดง field ที่ไม่ได้เลือก

```bash
echo "a:b:c:d" | cut -d":" -f2 --complement  # a:c:d
```

### ตัวอย่างจริง

```bash
# ดึง IP address
ip addr | grep "inet " | cut -d"/" -f1 | cut -d" " -f2

# ดึง username จาก /etc/passwd
cut -d":" -f1 /etc/passwd
```

---

## 🔗 4. PIPE `|` — เชื่อม Command ต่อกัน

### หลักการ

```bash
command1 | command2
# output ของ command1 → input ของ command2
# ซ้าย → ขวา เสมอ
```

### Stacking

```bash
cat file.txt | grep "error" | head -5          # หา error แสดง 5 ตัวแรก
cat file.txt | grep "error" | wc -l             # นับจำนวน error
ls -la | sort -k5 -n | tail -10                # ไฟล์ใหญ่สุด 10 อัน
```

### `tee` — แสดง + 保存 พร้อมกัน

```bash
cat file.txt | grep "error" | tee errors.txt | wc -l
# → แสดง count บน terminal + 保存 ใน errors.txt
```

### `xargs` — ส่ง output เป็น argument

```bash
find . -name "*.tmp" | xargs rm -f
cat files.txt | xargs -I {} cp {} /backup/
ls *.log | xargs wc -l
```

### `&&` และ `||`

```bash
mkdir newdir && cd newdir && echo "done"       # ทำทีละขั้น ถ้าสำเร็จทำต่อ
rm file.txt || echo "file not found"           # ถ้าลบไม่ได้ แสดงข้อความ
```

---

## 📊 5. AWK — คอลัมน์ + คำนวณ

### เลือกคอลัมน์

```bash
echo "a b c" | awk '{print $2}'                      # b
echo "name:age:city" | awk -F: '{print $1, $3}'      # name city
```

### Condition

```bash
ps aux | awk '$3 > 50 {print $1, $3, $11}'           # CPU > 50%
awk -F: '$3 >= 1000' /etc/passwd                     # UID >= 1000
```

### BEGIN / END

```bash
awk '{sum += $1} END {print sum}' <<< "1
2
3"                                                    # 6
```

### ตัวอย่างจริง

```bash
# แสดง PID + Memory ที่ใช้เยอะ
ps aux | awk 'NR>1 {printf "%-8s %6s %s\n", $1, $4, $11}' | sort -k2 -rn | head
```

---

## 🔄 6. SORT / UNIQ / WC

### sort

```bash
sort file.txt                   # A→Z
sort -n file.txt                # ตัวเลข
sort -r file.txt                # กลับด้าน
sort -k2 -n file.txt            # เรียงตามคอลัมน์ 2 (ตัวเลข)
sort -u file.txt                # เรียง + ตัดซ้ำ
```

### uniq (ต้อง sort ก่อน!)

```bash
sort file.txt | uniq            # ตัดบรรทัดซ้ำ
sort file.txt | uniq -c         # ตัดซ้ำ + นับ
sort file.txt | uniq -d         # แสดงเฉพาะบรรทัดที่ซ้ำ
```

### wc

```bash
wc -l file.txt                  # นับบรรทัด
wc -w file.txt                  # นับคำ
wc -c file.txt                  # นับ byte
cat file.txt | wc -l            # นับจาก pipe
```

---

## 🔄 7. TR / SED — แทนที่ / ลบตัวอักษร

### tr — แทนที่หรือลบตัวอักษร

```bash
echo "hello" | tr "a-z" "A-Z"           # HELLO
echo "hello" | tr -d "l"                # heo
echo "hello world" | tr " " "\n"        # แยกคำ (space→newline)
echo "aabbcc" | tr -s "a-c"            # abc (บีบซ้ำ)
```

### sed — แก้ไข text

```bash
sed 's/old/new/' file.txt                # แทนที่ (ครั้งแรกต่อบรรทัด)
sed 's/old/new/g' file.txt              # แทนที่ทุกครั้ง
sed -i 's/old/new/g' file.txt          # แก้ไฟล์จริง (in-place)
sed -n '5,10p' file.txt                # แสดงบรรทัด 5-10
sed '3d' file.txt                       # ลบบรรทัดที่ 3
sed '/^#/d' file.txt                    # ลบ comment
sed '/^$/d' file.txt                    # ลบ empty lines
```

> [!warning] sed ใน Termux
> `sed $'s/\033\[0m//g'` ใช้ใน zsh ไม่ได้ ให้ใช้:
> ```bash
> sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'
> ```

---

## 📤 8. REDIRECT — ส่ง Output ลงไฟล์

```bash
command > file.txt            # เขียน output (แทนที่)
command >> file.txt           # เขียนต่อท้าย (append)
command 2> errors.txt         # ส่ง stderr ลงไฟล์
command 2>&1 > all.txt        # stdout + stderr ลงไฟล์เดียวกัน
command > /dev/null 2>&1      # ปิด output ทั้งหมด (silent)
```

> [!tip] ลำดับ redirect
> `2>&1 > file` ≠ `> file 2>&1`
> - `2>&1 > file` → stderr ไป terminal, stdout ไป file
> - `> file 2>&1` → ทั้งคู่ไป file ✅

---

## 🎯 9. ตัวอย่าง Combine จริง

```bash
# หา process ที่กิน RAM เยอะสุด 5 อัน
ps aux | awk 'NR>1 {printf "%s %s%% %s\n", $1, $4, $11}' | sort -k2 -rn | head -5

# นับจำนวน file แต่ละ type
find . -type f | sed 's/.*\.//' | sort | uniq -c | sort -rn

# หา IP ที่เข้า server บ่อยสุด
cat access.log | cut -d" " -f1 | sort | uniq -c | sort -rn | head -10

# ลบ CRLF
sed -i 's/\r$//' script.sh

# หา port ที่กำลัง listen
ss -tlnp | awk 'NR>1 {print $4}' | cut -d: -f2 | sort -n

# หา TODO ทั้ง project + นับจำนวน
grep -rn "TODO" ~/project/ | wc -l
```

---

> [!note] Links
> - [[256 Color Chart]] — ANSI 256 สี reference
> - `man grep` / `man awk` / `man sed` — ดูเพิ่มใน terminal
