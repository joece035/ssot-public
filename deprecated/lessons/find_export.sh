#!/bin/bash

# ค่าเริ่มต้น: ค้นหาในโฟลเดอร์ปัจจุบัน (.)
SEARCH_DIR="."

# 1. เช็คว่ามี Argument แรกเป็น -d หรือ --dir หรือไม่
if [ "$1" == "-d" ] || [ "$1" == "--dir" ]; then
    SEARCH_DIR="$2"
    shift 2  # เลื่อน Argument ออกไป 2 ตำแหน่ง เพื่อตัด -d และ Path โฟลเดอร์ออก
fi

# 2. ตรวจสอบว่าหลังจากเลื่อน Argument แล้ว ยังมีรายชื่อตัวแปรเหลืออยู่ไหม
if [ $# -eq 0 ]; then
    echo "วิธีใช้งาน:"
    echo "  แบบปกติ (หาในโฟลเดอร์ปัจจุบัน): $0 <ตัวแปร1> [ตัวแปร2 ...]"
    echo "  แบบระบุโฟลเดอร์:                $0 -d <path/to/dir> <ตัวแปร1> [ตัวแปร2 ...]"
    echo ""
    echo "ตัวอย่าง: $0 -d /etc PATH HOME"
    exit 1
fi

# 3. ตรวจสอบว่าโฟลเดอร์ที่ระบุมีอยู่จริงหรือไม่
if [ ! -d "$SEARCH_DIR" ]; then
    echo "❌ error: ไม่พบโฟลเดอร์ '$SEARCH_DIR'"
    exit 1
fi

echo "=========================================="
echo " 🔍 กำลังค้นหาใน: $SEARCH_DIR"
echo "=========================================="

# 4. วนลูปหาทีละตัวแปร
for var_name in "$@"; do
    echo ""
    echo "[+] ผลการค้นหาสำหรับตัวแปร: $var_name"
    echo "------------------------------------------"
    
    results=$(grep -rnEI "export\s+${var_name}\b" "$SEARCH_DIR" 2>/dev/null)
    
    if [ -n "$results" ]; then
        echo "$results"
    else
        echo "❌ ไม่พบการ export ตัวแปร '$var_name'"
    fi
done

echo ""
echo "=========================================="
