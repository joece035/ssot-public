#!/bin/bash  
# ============================================================  
# block_style.sh - Terminal Layout JOE_style_def
# ============================================================ 
set_(){
   _pvar "$1" '%s' "$2"
}
    
# ============================================================
# _style_default - Default style (SSOT moved from 01-JOE_BLOCK.sh)
# ============================================================
_style_default(){
    local random_pick="no"
    local color_modes_b=("no" "random" "yes")  
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #
        set_ _data_ROWS        ""  # -- data ที่จัดเตรียมไว้
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #

    if [[ "$random_pick" = "yes" ]]; then
        set_ BORDER_RANDOM_C    "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
        set_ FRAME_RANDOM_C     "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
        set_ MID_RANDOM_C       "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
    else
        set_ BORDER_RANDOM_C   "random"
        set_ FRAME_RANDOM_C    "no"
        set_ MID_RANDOM_C      "no"
    fi 
    
    # -- leyout constant
       set_ OFFSET            "-0.25"  

    # -- RANDOM COLOR OBJECT
       set_ BORDER_RANDOM      "▫▭▫"
       set_ FRAME_RANDOM       "⟬ ⟭"

    # -- SEPARATOR OBJECT
       set_ MID_LINE           "▫▭▫"
       set_ ROW_FRAME_L        "⟬▫⟭"
       set_ ROW_FRAME_R        "⟬▫⟭"
       set_ MID_FRAME_L        "⟬▫⟭"
       set_ MID_FRAME_R        "⟬▫⟭"
       set_ TOP_BORDER         "▮▭▮▭"
       set_ BOT_BORDER         "▭▮▭▮"
       set_ MD_SEP_            " : "
    
    # -- color config (ใช้ format: '<color> <style>' ไม่ต้องมี c นำหน้า)
       set_ MID_LINE_C        'gr ""'
       set_ ROW_FRAME_C       'gr ""'
       set_ MID_FRAME_C       'gr ""'
       set_ TOP_BORDER_C      'lb b'
       set_ BOT_BORDER_C      'lb b'
    
    # -- label & value
       set_ LABEL_C           '118 bi'   # -- label color
       set_ VALUE_C           '202 bi'    # -- value color

    
    
}
# ============================================================
# _style_a - Style A (rainbow mode)
# ============================================================
_style_a(){
    local random_pick="no"
    local color_modes_b=("no" "random" "yes")  
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #
        set_ _data_ROWS        ""  # -- data ที่จัดเตรียมไว้
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #

    if [[ "$random_pick" = "yes" ]]; then
        set_ BORDER_RANDOM_C    "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
        set_ FRAME_RANDOM_C     "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
        set_ MID_RANDOM_C       "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
    else
        set_ BORDER_RANDOM_C   "yes"
        set_ FRAME_RANDOM_C    "no"
        set_ MID_RANDOM_C      "no"
    fi 
    
    # -- leyout constant (bc_ อาจ fail ถ้าไม่ได้ source → fallback tp/4)
    set_ OFFSET            "0"    # 3/4ขวา
   
    # -- RANDOM COLOR OBJECT
    set_ BORDER_RANDOM      "◊ "
    set_ FRAME_RANDOM       "‖"

    # -- SEPARATOR OBJECT
    set_ MID_LINE           "┈"
    set_ ROW_FRAME_L        "⟬"
    set_ ROW_FRAME_R        "⟭"
    set_ MID_FRAME_L        "⟭"
    set_ MID_FRAME_R        "⟬"
    set_ TOP_BORDER         "◙"
    set_ BOT_BORDER         "◙"
    
    # -- color config (ใช้ format: '<color> <style>' ไม่ต้องมี c นำหน้า)
    set_ MID_LINE_C        'gr ""'     # -- --- เส้นคั่นกลาง   
    set_ ROW_FRAME_C       'gr ""'
    set_ MID_FRAME_C       'gr ""'
    set_ TOP_BORDER_C      'lg b'
    set_ BOT_BORDER_C      'lg b'
    
    # -- label & value
    set_ LABEL_C           'gr ""'  # -- label color
    set_ VALUE_C           'lcr bi'    # -- value color

   
}
_style_b(){
    local random_pick="no"
    local color_modes_b=("no" "random" "yes")  
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #
        set_ _data_ROWS        ""  # -- data ที่จัดเตรียมไว้
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #

    if [[ "$random_pick" = "yes" ]]; then
        set_ BORDER_RANDOM_C    "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
        set_ FRAME_RANDOM_C     "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
        set_ MID_RANDOM_C       "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
    else
        set_ BORDER_RANDOM_C   "random"
        set_ FRAME_RANDOM_C    "no"
        set_ MID_RANDOM_C      "no"
    fi 
    
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #
   
    # -- leyout constant (bc_ อาจ fail ถ้าไม่ได้ source → fallback tp/2)
    set_ OFFSET            "-1"   # ซ้าย 1/2 (halfway)

    # -- RANDOM COLOR OBJECT
    set_ BORDER_RANDOM      "▨"
    set_ FRAME_RANDOM       "‖"

    # -- SEPARATOR OBJECT
    set_ MID_LINE           "-"
    set_ ROW_FRAME_L        "|"
    set_ ROW_FRAME_R        "|"
    set_ MID_FRAME_L        "|"
    set_ MID_FRAME_R        "|"
    set_ TOP_BORDER         "▰"
    set_ BOT_BORDER         "▰"
    set_ MD_SEP_            " - "
    
    # -- color config (ใช้ format: '<color> <style>' ไม่ต้องมี c นำหน้า)
    set_ MID_LINE_C        '240 ""'
    set_ ROW_FRAME_C       '240 ""'
    set_ MID_FRAME_C       '240 ""'
    set_ TOP_BORDER_C      'lb b'
    set_ BOT_BORDER_C      'lb b'
    
    # -- label & value
    set_ LABEL_C           '248 bi '   # -- label color
    set_ VALUE_C           'lcr bi'    # -- value color

    
    
}
_style_c(){
    local random_pick="no"
    local color_modes_b=("no" "random" "yes")  
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #
        set_ _data_ROWS        "op_profile"  # -- data ที่จัดเตรียมไว้
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #

    if [[ "$random_pick" = "yes" ]]; then
        set_ BORDER_RANDOM_C    "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
        set_ FRAME_RANDOM_C     "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
        set_ MID_RANDOM_C       "${color_modes_b[$(( RANDOM % ${#color_modes_b[@]} ))]}"
    else
        set_ BORDER_RANDOM_C   "random"
        set_ FRAME_RANDOM_C    "random"
        set_ MID_RANDOM_C      "random"
    fi 
    
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #

    # -- leyout constant
     set_ OFFSET            "-0.5"   # 3/4ซ้าย
   
    # -- RANDOM COLOR OBJECT
    set_ BORDER_RANDOM      "▨"
    set_ FRAME_RANDOM       "‖"

    # -- SEPARATOR OBJECT
    set_ MID_LINE           "▱"
    set_ ROW_FRAME_L        "⟬"
    set_ ROW_FRAME_R        "⟭"
    set_ MID_FRAME_L        "⟬ "
    set_ MID_FRAME_R        "⟭"
    set_ TOP_BORDER         "▰"
    set_ BOT_BORDER         "▰"
    set_ MD_SEP_            " : "
    
    # -- color config (ใช้ format: '<color> <style>' ไม่ต้องมี c นำหน้า)
    set_ MID_LINE_C        'gr ""'
    set_ ROW_FRAME_C       'gr ""'
    set_ MID_FRAME_C       'gr ""'
    set_ TOP_BORDER_C      'gr b'
    set_ BOT_BORDER_C      'gr b'
    
    # -- label & value
    set_ LABEL_C           'lg ""'   # -- label color
    set_ VALUE_C           'ora bi'    # -- value color

    
}
# ============================================================
# _style_random() - สุ่ม object จาก title_() ประกอบร่าง style ใหม่
# ============================================================
_style_random() {
   
   set_ OFFSET            "0"
   
    # ── 1. แยก object ตาม category (refactored) ──

    # H_LINE  = แนวนอน สำหรับ border/midline (width ชัดเจน)
    # H_BLOCK = แนวนอน แบบ block pattern (ใช้กลางบรรทัด)
    # DOT     = จุด/วงกลม สำหรับ accent
    local H_LINE=("─" "━" "▬" "▭" "▱" "═" "–")
    local H_BLOCK=("─" "━" "▬" "▭" "▱" "▰" "▨" "–" "-")
    local DOT=("◌" "◙" "◓" "◍" "◚" "◪" "•" "⁕" "‣" "∐")

    # ROW_FRAMES = คู่เฟรมซ้ายขวาที่สมมาตรกัน (สัญลักษณ์ทุกตัวมีขนาด 1 คอลัมน์)
    local ROW_FRAMES=("| |" "¦ ¦" "‖ ‖" "║ ║" "∣ ∣" "⟨ ⟩" "⟬ ⟭" "⟦ ⟧" "⌈ ⌉" "⌊ ⌋")

    # ── 2. สุ่มเลือก object ──
    local pick_h1="${H_LINE[$(( RANDOM % ${#H_LINE[@]} ))]}"
    local pick_h2="${H_BLOCK[$(( RANDOM % ${#H_BLOCK[@]} ))]}"
    
    local pick_rf="${ROW_FRAMES[$(( RANDOM % ${#ROW_FRAMES[@]} ))]}"
    local pick_vL="${pick_rf% *}"
    local pick_vR="${pick_rf#* }"
    
    # จับคู่ mid frame ให้เข้ากับ row frame (และสลับทิศทางวงเล็บเพื่อให้เกิดเอวคอดที่สวยงาม)
    local pick_mL="$pick_vL"
    local pick_mR="$pick_vR"
    if [[ "$pick_vL" == "⟨" ]]; then pick_mL="⟩"; pick_mR="⟨"; fi
    if [[ "$pick_vL" == "⟬" ]]; then pick_mL="⟭"; pick_mR="⟬"; fi
    if [[ "$pick_vL" == "⟦" ]]; then pick_mL="⟧"; pick_mR="⟦"; fi
    if [[ "$pick_vL" == "⌈" ]]; then pick_mL="⌉"; pick_mR="⌈"; fi
    if [[ "$pick_vL" == "⌊" ]]; then pick_mL="⌋"; pick_mR="⌊"; fi
    
    local pick_dot="${DOT[$(( RANDOM % ${#DOT[@]} ))]}"

    # ── 3. ตั้งค่า border/frame/midline objects (L/R split) ──
    set_ TOP_BORDER         "$pick_h1"
    set_ BOT_BORDER         "$pick_h1"
    set_ MID_LINE           "$pick_h2"
    set_ ROW_FRAME_L        "$pick_vL"
    set_ ROW_FRAME_R        "$pick_vR"
    set_ MID_FRAME_L        "$pick_mL"
    set_ MID_FRAME_R        "$pick_mR"
    set_ MD_SEP_            " : "

    # ── 4. Random color mode (yes=rainbow, no=fixed, random=single random color) ──
    local color_modes=("yes" "no" "random")
    local frame_modes=("no" "random")
    set_ BORDER_RANDOM_C    "${color_modes[$(( RANDOM % ${#color_modes[@]} ))]}"
    set_ FRAME_RANDOM_C     "${frame_modes[$(( RANDOM % ${#frame_modes[@]} ))]}"
    set_ MID_RANDOM_C       "${frame_modes[$(( RANDOM % ${#frame_modes[@]} ))]}"
    set_ BORDER_RANDOM      "$pick_dot"
    set_ FRAME_RANDOM       "$pick_vL"

    # ── 5. สุ่ม color scheme ──
    local colors=("gr" "lg" "w" "lc" "lb" "lm")
    local styles_b=("b" "bi" "bl" "bd" "")
    local styles_l=("" "b" "bi" "bl")

    local c_mid="${colors[$(( RANDOM % ${#colors[@]} ))]}"
    local c_frame="${colors[$(( RANDOM % ${#colors[@]} ))]}"
    local c_border="${colors[$(( RANDOM % ${#colors[@]} ))]}"
    
    local style_b="${styles_b[$(( RANDOM % ${#styles_b[@]} ))]}"
    local style_l="${styles_l[$(( RANDOM % ${#styles_l[@]} ))]}"

    set_ MID_LINE_C        "${c_mid} ''"
    set_ ROW_FRAME_C       "${c_frame} ''"
    set_ MID_FRAME_C       "${c_frame} ''"
    set_ TOP_BORDER_C      "${c_border} ${style_b:-''}"
    set_ BOT_BORDER_C      "${c_border} ${style_b:-''}"
    set_ LABEL_C           "${colors[$(( RANDOM % ${#colors[@]} ))]} ${style_l:-''}"
    set_ VALUE_C           "w ${style_b:-''}"
    set_ MID_SEP_C         "${c_border} ${style_b:-''}"
}




