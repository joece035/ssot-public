# Bash Fundamentals Cheat Sheet
# เอาไปแกะฝึกได้เลย — Nexus for P' Joe

---

## 🧱 1. Arguments & Parameters

### ตัวอย่าง: script รับ argument

```bash
#!/bin/bash
# === demo_args.sh ===

echo "ชื่อ script: $0"
echo "argv ทั้งหมด ($# ตัว): $@"
echo "argv ตัวแรก: $1"
echo "argv ตัวที่สอง: $2"

echo "--- \$@ vs \$* ---"
echo "\$@ = $@"        # แยกแต่ละตัว: "arg1" "arg2" "arg3"
echo "\$* = $*"        # รวมเป็น string: "arg1 arg2 arg3"
```

**รัน:**
```bash
bash demo_args.sh hello world 123
```
**ผล:**
```
ชื่อ script: demo_args.sh
argv ทั้งหมด (3 ตัว): hello world 123
argv ตัวแรก: hello
argv ตัวที่สอง: world
--- $@ vs $* ---
$@ = hello world 123
$* = hello world 123
```

### ⭐ Shift — เลื่อน argument

```bash
#!/bin/bash
# === demo_shift.sh ===
# concept: shift = "กิน argv ตัวซ้าย" เหลือตัวที่เหลือขยับซ้าย

echo "ก่อน shift: $@ (มี $# ตัว)"

while (( $# > 0 )); do
    echo "  → กำลังจัดการ: $1"
    shift    # $2 ขยับมาเป็น $1, $3 ขยับมาเป็น $2, ...
done

echo "หลัง shift หมด: $# ตัว"
```

**รัน:**
```bash
bash demo_shift.sh apple banana cherry
```
**ผล:**
```
ก่อน shift: apple banana cherry (มี 3 ตัว)
  → กำลังจัดการ: apple
  → กำลังจัดการ: banana
  → กำลังจัดการ: cherry
หลัง shift หมด: 0 ตัว
```

### ⭐ Pattern: flag parsing (解析 --flag=value)

```bash
#!/bin/bash
# === demo_flags.sh ===
# concept: วน while loop + case จับ flag ทีละตัว

VERBOSE=false
OUTPUT=""
COUNT=1

while (( $# > 0 )); do
    case "$1" in
        -v|--verbose) VERBOSE=true ;;
        -o|--output)  OUTPUT="$2"; shift ;;   # flag นี้มีค่า → shift ข้ามไปเอาค่า
        -n|--count)   COUNT="$2"; shift ;;
        -h|--help)
            echo "Usage: $0 [-v] [-o FILE] [-n COUNT]"
            exit 0
            ;;
        *)
            echo "Unknown flag: $1"
            exit 1
            ;;
    esac
    shift   # เลื่อนไป flag ตัวถัดไป
done

echo "VERBOSE=$VERBOSE  OUTPUT=$OUTPUT  COUNT=$COUNT"
```

**รัน:**
```bash
bash demo_flags.sh -v -o result.txt -n 5
bash demo_flags.sh --help
```

### ⭐ Pattern: ตรวจ argc (ต้องมี argv กี่ตัว)

```bash
#!/bin/bash
# === guard_args.sh ===

if (( $# < 2 )); then
    echo "❌ ต้องใส่อย่างน้อย 2 ค่า"
    echo "Usage: $0 <source> <dest>"
    exit 1
fi

src="$1"
dst="$2"
echo "คัดลอก $src → $dst"
```

---

## 🔀 2. If-Else & Conditions

### เปรียบเทียบ String

```bash
name="joe"

if [[ "$name" == "joe" ]]; then
    echo "Found Joe!"
elif [[ "$name" == "admin" ]]; then
    echo "Found Admin!"
else
    echo "Unknown user"
fi
```

### เปรียบเทียบตัวเลข

```bash
age=25

if (( age >= 18 )); then
    echo "Adult"
else
    echo "Minor"
fi

# ⚠️ อย่าใช้ [[ "$a" -gt "$b" ]] — ใช้ (( )) แทน อ่านง่ายกว่า
```

### ⭐ Flag detection — ตรวจว่า flag ถูกส่งมาหรือไม่

```bash
#!/bin/bash
# === demo_detect_flag.sh ===

# วิธี 1: ตรวจ argc
if (( $# == 0 )); then
    echo "ไม่มี argument!"
    exit 1
fi

# วิธี 2: ตรวจ string ว่ามี flag นี้อยู่ใน "$@" หรือไม่
has_flag() {
    local flag="$1"
    shift
    for arg in "$@"; do
        [[ "$arg" == "$flag" ]] && return 0
    done
    return 1
}

if has_flag "--verbose" "$@"; then
    echo "Verbose mode ON"
fi

if has_flag "--debug" "$@"; then
    echo "Debug mode ON"
fi
```

### ⭐ ตรวจว่าคำสั่ง/ไฟล์มีอยู่

```bash
# ตรวจว่า command มีอยู่
if command -v git &>/dev/null; then
    echo "git version: $(git --version)"
else
    echo "❌ git ไม่ได้ติดตั้ง"
fi

# ตรวจว่าไฟล์มีอยู่
if [[ -f "/etc/passwd" ]]; then
    echo "passwd มีอยู่"
fi

# ตรวจว่า directory มีอยู่
if [[ -d "/tmp" ]]; then
    echo "/tmp มีอยู่"
fi

# ตรวจว่า variable มีค่า (ไม่ว่าง)
if [[ -n "${MY_VAR:-}" ]]; then
    echo "MY_VAR = $MY_VAR"
else
    echo "MY_VAR ว่าง"
fi
```

### ⭐ Pattern: default value

```bash
# ${VAR:-default} ถ้า VAR ว่าง/null ใช้ default
name="${1:-anonymous}"
port="${PORT:-8080}"
verbose="${VERBOSE:-false}"

echo "name=$name  port=$port  verbose=$verbose"
```

---

## 🔄 3. Loops

### For Loop — วน list

```bash
#!/bin/bash
# === demo_for.sh ===

# วน string list
for color in red green blue; do
    echo "🎨 $color"
done

# วน number range
for i in $(seq 1 5); do
    echo "Number: $i"
done

# C-style for (มักใช้บ่อยกว่า)
for (( i=0; i<5; i++ )); do
    echo "Index: $i"
done

# วนไฟล์ใน directory
for f in *.sh; do
    echo "📄 $f"
done
```

### While Loop — วนจนเงื่อนไขเป็น false

```bash
#!/bin/bash
# === demo_while.sh ===

# นับถอยหลัง
count=5
while (( count > 0 )); do
    echo "⏳ $count..."
    sleep 1
    (( count-- ))
done
echo "🚀 Go!"

# อ่าน stdin ทีละบรรทัด
while IFS= read -r line; do
    echo "Line: $line"
done < input.txt
```

### Until Loop — วนจนเงื่อนไขเป็น true (สลับกับ while)

```bash
#!/bin/bash
# === demo_until.sh ===

# รอจนกว่าไฟล์จะมี
until [[ -f "/tmp/ready.flag" ]]; do
    echo "⏳ รอ ready.flag..."
    sleep 2
done
echo "✅ Found!"
```

### ⭐ Break & Continue

```bash
for i in $(seq 1 10); do
    (( i == 3 )) && continue   # ข้าม 3
    (( i == 7 )) && break      # หยุดที่ 7
    echo "$i"
done
# ผล: 1 2 4 5 6
```

---

## 🧩 4. ตัวอย่างงานจริง 2-3 อย่าง

### งานที่ 1: Simple CLI tool — ค้นหาไฟล์

```bash
#!/bin/bash
# === find_files.sh ===
# Usage: bash find_files.sh <directory> <extension>

# ── Guard: ต้องมี 2 args ──
if (( $# < 2 )); then
    echo "❌ Usage: $0 <directory> <extension>"
    echo "   Example: $0 /home .sh"
    exit 1
fi

dir="$1"
ext="$2"

# ── Guard: directory ต้องมีอยู่ ──
if [[ ! -d "$dir" ]]; then
    echo "❌ Directory '$dir' ไม่มีอยู่"
    exit 1
fi

# ── ค้นหา ──
count=0
echo "🔍 ค้นหา *.$ext ใน $dir ..."

for f in "$dir"/*."$ext"; do
    # glob ไม่ match จะคืน string เดิม ต้อง check
    [[ ! -f "$f" ]] && continue

    (( count++ ))
    size=$(wc -c < "$f")
    echo "  📄 $(basename "$f")  (${size} bytes)"
done

echo "✅ พบ $count ไฟล์"
```

**รัน:**
```bash
bash find_files.sh /home/usercivenz/ssot sh
```

---

### งานที่ 2: Config parser — อ่าน key=value แล้ว set เป็น variable

```bash
#!/bin/bash
# === parse_config.sh ===
# รับไฟล์ config แล้ว parse เป็น variable

CONFIG_FILE="${1:-config.txt}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config file '$CONFIG_FILE' ไม่มีอยู่"
    exit 1
fi

echo "📖 Parsing $CONFIG_FILE ..."

while IFS= read -r line; do
    # ── Skip บรรทัดว่างและ comment ──
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # ── แยก key=value ──
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]}"

        # ── ตัด quote ออก ──
        val="${val#\"}"
        val="${val%\"}"
        val="${val#\'}"
        val="${val%\'}"

        # ── Set variable ──
        printf -v "$key" '%s' "$val"
        echo "  ✅ $key = ${!key}"
    else
        echo "  ⚠️ Skip: $line"
    fi
done < "$CONFIG_FILE"

echo ""
echo "── Result ──"
echo "DB_HOST=${DB_HOST:-<unset>}"
echo "DB_PORT=${DB_PORT:-<unset>}"
echo "DB_NAME=${DB_NAME:-<unset>}"
```

**สร้าง config.txt ทดสอบ:**
```
# Database config
DB_HOST=localhost
DB_PORT=3306
DB_NAME=myapp
DB_USER='admin'
DB_PASS="secret123"
```

**รัน:**
```bash
bash parse_config.sh config.txt
```

---

### งานที่ 3: Health checker — เช็ค service หลายตัว

```bash
#!/bin/bash
# === health_check.sh ===
# ตรวจว่า service หลายตัว alive ไหม

# ── Default services ──
services=("google.com:443" "github.com:443" "localhost:22")

# ── ถ้ามี args → ใช้ args แทน ──
if (( $# > 0 )); then
    services=("$@")
fi

echo "🏥 Health Check — $(date '+%Y-%m-%d %H:%M')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

up=0
down=0

for target in "${services[@]}"; do
    host="${target%%:*}"
    port="${target##*:}"

    # ── Timeout 3 วินาที ──
    if timeout 3 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        echo "  ✅ $target — UP"
        (( up++ ))
    else
        echo "  ❌ $target — DOWN"
        (( down++ ))
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ UP: $up  |  ❌ DOWN: $down"

# ── Exit code: ถ้ามีตัวไหน down → exit 1 ──
(( down > 0 )) && exit 1
exit 0
```

**รัน:**
```bash
bash health_check.sh google.com:443 github.com:443 localhost:22
```

---

## 📋 Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│  ARGS                                                    │
│  $#         = จำนวน argv                                 │
│  $@         = argv ทั้งหมด (แยกตัว)                       │
│  $*         = argv ทั้งหมด (รวม string)                  │
│  $0         = ชื่อ script                                │
│  $1, $2,... = argv ตัวที่ 1, 2, ...                      │
│  shift      = เลื่อน argv ซ้าย ($2→$1, $3→$2, ...)       │
│  shift N    = เลื่อน N ขั้น                               │
│                                                         │
│  DEFAULTS                                                │
│  ${VAR:-default}  = ถ้า VAR ว่าง ใช้ default              │
│  ${VAR:=default}  = ถ้า VAR ว่าง set VAR=default          │
│  ${VAR:+replacement} = ถ้า VAR มีค่า ใช้ replacement      │
│  ${VAR:?error msg}   = ถ้า VAR ว่าง print error + exit    │
│                                                         │
│  CONDITIONS                                              │
│  [[ -f file ]]   = file มีอยู่                           │
│  [[ -d dir ]]    = directory มีอยู่                       │
│  [[ -n "$var" ]] = var ไม่ว่าง                           │
│  [[ -z "$var" ]] = var ว่าง                              │
│  [[ "$a" == "$b" ]] = string เท่ากัน                     │
│  (( a > b ))     = numeric comparison                     │
│  (( $# == 0 ))   = ไม่มี argv                             │
│  cmd &>/dev/null = suppress all output                    │
│  command -v cmd  = ตรวจว่า cmd มีอยู่                     │
│                                                         │
│  LOOPS                                                   │
│  for x in list; do ... done                              │
│  for (( i=0; i<n; i++ )); do ... done                    │
│  while cond; do ... done                                 │
│  until cond; do ... done                                 │
│  break    = ออกจาก loop                                  │
│  continue = ข้ามไปรอบถัดไป                               │
│                                                         │
│  PATTERN: flag parsing                                    │
│  while (( $# > 0 )); do                                  │
│      case "$1" in                                        │
│          -v) VERBOSE=true ;;                              │
│          -o) OUTPUT="$2"; shift ;;                       │
│          -h) usage; exit 0 ;;                            │
│          *)  echo "Unknown: $1"; exit 1 ;;               │
│      esac                                                │
│      shift                                               │
│  done                                                    │
└─────────────────────────────────────────────────────────┘
```

---

## 💡 Tips สำหรับพี่โจ

1. **`[[ ]]` ดีกว่า `[ ]`** — ปลอดภัยกว่า ไม่ต้อง quote ตัวแปร
2. **`(( ))` สำหรับตัวเลข** — อ่านง่ายกว่า `-gt -lt -eq`
3. **`$(( ))` สำหรับคำนวณ** — `result=$(( a + b ))`
4. **`set -euo pipefail`** — ใส่บรรทัดบนสุด script จริงจัง เพื่อ abort ทันทีถ้ามี error
5. **`shift` คือเพื่อน** — ใช้กับ flag parsing แล้วจะรัก
6. **`${1:-default}`** — ใช้ default value ทุกครั้งที่รับ input
