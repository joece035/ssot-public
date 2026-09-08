#!/bin/bash

# รายชื่อไฟล์ที่ต้องการดึงมาแสดง
load_files=(
    "00-env.sh"
    "01-colors.sh"
    "ssh-config.sh"
    "00.1-function-tools.sh"
    "09-all_block_status.sh"
    "syncctl"
)

max_len=0

# ขั้นตอนที่ 1: วนลูปหาความยาวของชื่อไฟล์ที่ยาวที่สุด
for file in "${files[@]}"; do
    len=${#file} # ${#variable} คือคำสั่งนับจำนวนตัวอักษร
    if (( len > max_len )); then
        max_len=$len
    fi
done

# ขั้นตอนที่ 2: แสดงผลโดยใช้ printf จัดตำแหน่ง
for file in "${files[@]}"; do
    # %-${max_len}s คือการจองพื้นที่ตามความยาว max_len และชิดซ้าย (-)
    printf "source %-${max_len}s done\n" "$file"
done