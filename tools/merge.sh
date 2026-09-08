#!/bin/bash

treegu() {
    local lv=${1:-a}
    # ดึงตัวแปรแรกออกไป เพื่อให้ $2 เดิม เลื่อนมาเป็น $1 (เอาไว้ใช้ในเคส c)
    shift 2>/dev/null 

    case "$lv" in
        a)
            # ใช้ -mindepth 1 เพื่อข้ามจุด "." ตัวแรกไป จะได้นับชั้นง่ายๆ
            find . -mindepth 1 -type d | sort | while read -r d; do
                # ตัด "./" ออกจากข้างหน้าก่อนนับความลึก
                local clean_path="${d#./}"
                
                # นับจำนวนเครื่องหมาย /
                local slashes="${clean_path//[^\/]/}"
                local depth=${#slashes}

                # สร้างย่อหน้า (ชั้นแรกสุด depth=0 จะชิดซ้ายพอดี)
                local indent=$(printf '%*s' $((depth * 3)) '')
                local name="${d##*/}"

                # พ่นผลลัพธ์ส่งให้ฟังก์ชันแสดงสีของคุณ
                cn lg b "${indent}├── ${name}"
            done
            ;;

        b)
            # ส่งผลลัพธ์ผ่าน Pipe ไปยังคำสั่งแสดงสีตรงๆ (Clean & Fast)
            find . -print 2>/dev/null | sed -e 's;[^/]*/;|____;g;s;____|; |;g' | while read -r line; do
                cn gr b "$line"
            done
            ;;

        c)
            # ตอนนี้หลังจาก shift แล้ว $1 จะหมายถึงชื่อไฟล์เอาต์พุต
            local out_file="${1:-"./tree.txt"}"
            
            # สร้างโฟลเดอร์ปลายทางให้อัตโนมัติถ้ายังไม่มี
            mkdir -p "$(dirname "$out_file")"
            
            # รัน tree เซฟลงไฟล์
            tree -I "node_modules|.git" -a > "$out_file"
            echo "📝 โครงสร้างโปรเจกต์ถูกบันทึกลงในไฟล์เรียบร้อย: $out_file"
            ;;
        *)
            echo "❌ ไม่พบรูปแบบที่คุณเลือก (เลือกได้แค่: a, b, c)"
            ;;
    esac
}
alias t='treegu'

# ============================================================
# merge_functions — Scan for duplicate function definitions
# ============================================================
# เรียกผ่าน:  merge   (alias ใน 02-aliases.sh)
# อ่านอย่างเดียว (read-only) — รายงานฟังก์ชันที่ถูกนิยามซ้ำ
# มากกว่า 1 ไฟล์ เพื่อให้รู้ว่าต้อง merge ที่ไหน
# ============================================================
merge_functions() {
    local root="${SSOT:-$HOME/ssot}"
    echo "🔍 Scanning duplicate function definitions in $root ..."
    # เก็บ: ชื่อฟังก์ชัน -> ไฟล์ที่นิยาม
    grep -rnE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{' "$root" --include="*.sh" 2>/dev/null \
        | grep -v lessons \
        | sed -E 's/^([^:]+):[0-9]+:([a-zA-Z_][a-zA-Z0-9_]*)\(\)/\2\t\1/' \
        | sort \
        | awk -F'\t' '{
            if ($1 == prev) {
                if (first != "") print "  DUP: " first;
                print "  DUP: " $2;
                dup=1
            } else {
                prev=$1; first=$2; dup=0
            }
        } END { if (dup==0) print "  (no duplicates)" }'
}
