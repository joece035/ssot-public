#!/usr/bin/env bash
# ------------------------------------------------------------
# File: visible_w.sh
# Purpose: Test script for calculating visible terminal width & dynamic borders
# ------------------------------------------------------------
set -e
SSOT="${SSOT:-$HOME/ssot}"
source "$HOME/.bashrc" 2>/dev/null || true

# Source color engine & functions if not already present
[[ -f "$SSOT/core/01-colors.sh" ]] && source "$SSOT/core/01-colors.sh" 2>/dev/null || true
[[ -f "$SSOT/shared/personal/joe_functions.sh" ]] && source "$SSOT/shared/personal/joe_functions.sh" 2>/dev/null || true

echo "============================================================"
echo " 🧪 TEST VISIBLE WIDTH & DYNAMIC BORDER (SSOT)"
echo "============================================================"

# Helper function to test and display width comparison
test_width() {
    local label="$1"
    local raw="$2"
    local raw_len="${#raw}"
    local vis_len
    vis_len=$(get_real_width "$raw")

    printf "\n📌 %s\n" "$label"
    printf "   Content     : %b\n" "$raw"
    printf "   Raw \${#t}   : %s (นับรวม ANSI / control characters)\n" "$raw_len"
    printf "   Real Width  : %s (ความกว้างจริงบนหน้าจอ Terminal)\n" "$vis_len"
}

# --- TEST CASES ---
# Case 1: ข้อความธรรมดา (Plain text)
test_width "Case 1: Plain Text" "WSL2"

# Case 2: ข้อความใส่สี ANSI (ANSI Color Sequences)
test_width "Case 2: ANSI Color (mc b \"\$JOE_ENV\")" "$(mc b "${JOE_ENV:-WSL2}")"

# Case 3: PS1 Format (สร้างจาก psc ซึ่งมี \[ และ \] หุ้ม escape codes)
test_width "Case 3: PS1 Prompt Escapes (psc 82 b \"WSL2\")" "$(psc 82 b "WSL2")"

# Case 4: Emojis & Wide Kaomoji (อักขระ CJK/Wide กว้าง 2 คอลัมน์)
test_width "Case 4: Kaomoji & Emoji" "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ 🌿"

# --- DEMO: DYNAMIC BORDER IN COMMAND PROMPT / THEME ---
echo -e "\n============================================================"
echo " 🎨 DEMO: DYNAMIC BORDER CALCULATION"
echo "============================================================"

# ตัวอย่างประกอบข้อความใน Prompt แถวกลาง
env_tag="$(psc 198 b "${JOE_ENV:-WSL2}")"
user_tag="$(psc cr b "${USER:-joez}")"
status_tag="$(mc b '(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧')"
content=" ${status_tag} < ${env_tag} > ${user_tag} in ~/ssot 🌿 "

# คำนวณความกว้างจริงของเนื้อหา
content_w=$(get_real_width "$content")

# สร้างเส้นกรอบบนและล่างตามขนาดจริง
border_top=""
border_bot=""
border_char_top="─"
border_char_bot="─"

for (( i=0; i<content_w; i++ )); do
    border_top+="${border_char_top}"
    border_bot+="${border_char_bot}"
done

# สำหรับ echo ออก terminal ทั่วไป: ถอด \[ และ \] ออก เพื่อให้ visual border ประกบพอดี
# (ถ้าอยู่ใน PS1 ของ Bash ไม่ต้องถอด เพราะ Readline จะจัดการให้เอง)
display_content="${content//\\[/}"
display_content="${display_content//\\]/}"

echo "Real content width: ${content_w} columns"
echo
echo "┌${border_top}┐"
echo "│${display_content}│"
echo "└${border_bot}┘"
echo
