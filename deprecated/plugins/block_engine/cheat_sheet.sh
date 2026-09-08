#!/bin/bash
# ============================================================
# JOE BLOCK — Variable Cheat Sheet (Refactored)
# ============================================================
# Flow: entry.sh → theme.sh → layout.sh → renderer.sh
# ============================================================

cat << 'CHEAT'

╔══════════════════════════════════════════════════════════════╗
║  📦 CONSTANTS (utils.sh) — ค่าคงที่ที่ไม่เปลี่ยน            ║
╠══════════════════════════════════════════════════════════════╣
║  EMO_W    = 2     # ความกว้าง emoji (คอลัมน์)                ║
║  EMO_L    = 4     # พื้นที่ emoji ซ้าย (1 emoji + padding)    ║
║  EMO_R    = 5     # พื้นที่ emoji ขวา (1 emoji + padding)    ║
║  V2E_GAP  = 2     # ช่องว่างหลัง value ก่อน emoji ขวา      ║
║  PAD_X    = 2     # padding ในสุด ข้างละ 1                   ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║  📊 _LAYOUT[] (layout.sh) — ค่าที่คำนวณจากข้อมูล           ║
╠══════════════════════════════════════════════════════════════╣
║  label_w   = ความกว้าง label สูงสุด (จาก _blk_scan)         ║
║  value_w   = ความกว้าง value สูงสุด (จาก _blk_scan)         ║
║  block_w   = ความกว้างบล็อกรวม = EMO_L + label + sep +     ║
║              value + V2E_GAP + EMO_R + PAD_X                ║
║  indent    = ช่องว่างซ้าย (ใช้ center / offset)             ║
║  sep       = ตัวคั่น label:value (จาก theme)                ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║  🎨 _THEME[] (theme.sh) — ค่าจาก style function            ║
╠══════════════════════════════════════════════════════════════╣
║  --- Data Source ---                                        ║
║  data_rows    = "status_new" | "op_profile"                 ║
║                                                         ║
║  --- Positioning ---                                        ║
║  offset       = ค่า offset (ตัวเลข หรือ "NONE")             ║
║                >0 = เลื่อนซ้าย, <0 = เลื่อนขวา              ║
║                                                         ║
║  --- Border Characters ---                                  ║
║  top_border   = ตัวอักษรขอบบน (เช่น ▰, ▨, ◙)             ║
║  bot_border   = ตัวอักษรขอบล่าง                              ║
║  border_char  = ตัวอักษรสำหรับ random border                 ║
║  border_random = "yes" | "no"                               ║
║                                                         ║
║  --- Frame Characters ---                                   ║
║  row_frame_l/r = เฟรมซ้าย/ขวาของแต่ละ row                   ║
║  mid_frame_l/r = เฟรมซ้าย/ขวาของ mid-separator             ║
║  mid_line      = ตัวคั่นระหว่าง row (เช่น =, ▭)            ║
║  frame_char    = ตัวอักษรสำหรับ random frame                 ║
║  frame_random  = "yes" | "no"                               ║
║                                                         ║
║  --- Separator ---                                          ║
║  mid_sep       = ตัวคั่น label:value (เช่น " : ", " ⋮ ")   ║
║                                                         ║
║  --- Color Specs (format: "colorname style") ---            ║
║  label_c       = สี label (เช่น 'gr ""')                   ║
║  value_c       = สี value (เช่น 'w bi')                    ║
║  mid_sep_c     = สี separator                               ║
║  top_border_c  = สีขอบบน                                    ║
║  bot_border_c  = สีขอบล่าง                                  ║
║  mid_line_c    = สีเส้นคั่น                                  ║
║  row_frame_c   = สีเฟรม row                                 ║
║  mid_frame_c   = สีเฟรม mid                                 ║
║                                                         ║
║  --- Compiled (pre-rendered) ---                            ║
║  cc_brc   = colored random border char                      ║
║  cc_hrc   = colored random frame char                       ║
║  cc_ml    = colored mid-line char                           ║
║  cc_row_fl/fr = colored row frame L/R                       ║
║  cc_mid_fl/fr = colored mid frame L/R                       ║
║  cc_bt    = colored top border char                         ║
║  cc_bb    = colored bottom border char                      ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║  🔧 GLOBALS (misc)                                          ║
╠══════════════════════════════════════════════════════════════╣
║  TERM_WIDTH       = tput cols (แคชไว้ครั้งเดียว)             ║
║  _BLK_INITIALIZED = flag ป้องกัน init ซ้ำ                    ║
║  _BLK_STYLE_LOADED = flag ป้องกัน source style ซ้ำ          ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║  📐 BLOCK WIDTH FORMULA                                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  block_w = EMO_L + label_w + sep_len + value_w +            ║
║            V2E_GAP + EMO_R + PAD_X                          ║
║                                                              ║
║  ┌─────┬─────────┬─────┬─────────┬─────────┬─────┬─────┐   ║
║  │EMO_L│  label  │ sep │  value  │V2E_GAP  │EMO_R│PAD_X│   ║
║  │  4  │ label_w │ sep │ value_w │   2     │  5  │  2  │   ║
║  └─────┴─────────┴─────┴─────────┴─────────┴─────┴─────┘   ║
║                                                              ║
║  ถ้า block_w > TERM_WIDTH-2:                                 ║
║    block_w = TERM_WIDTH-2                                    ║
║    value_w = block_w - (EMO_L+sep+V2E_GAP+EMO_R+PAD_X)     ║
║              - label_w                                       ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║  📏 INDENT FORMULA (Centering + Offset)                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  indent = (TERM_WIDTH - block_w) / 2 - offset               ║
║                                                              ║
║  Clamp:                                                      ║
║    min = 1                    (ชิดซ้ายสุด ห่าง 1)           ║
║    max = TERM_WIDTH-block_w-1 (ชิดขวาสุด ห่าง 1)           ║
║                                                              ║
║  OFFSET=0    → indent = center     (กลางจอ)                  ║
║  OFFSET=500  → indent = min=1      (ชิดซ้าย)                ║
║  OFFSET=-500 → indent = max        (ชิดขวา)                 ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║  🔄 DATA FLOW                                                ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  1. m() called → _load_theme(style, offset)                 ║
║       ↓                                                      ║
║  2. _load_theme → sources block_style.sh → calls _style_X() ║
║       ↓            which uses set_() to write globals        ║
║  3. Harvests globals → _THEME[] associative array            ║
║       ↓                                                      ║
║  4. Dispatches data provider (status_new / op_profile)      ║
║       ↓                                                      ║
║  5. dashboard() receives rows via stdin                      ║
║       ↓                                                      ║
║  6. _blk_scan(rows) → _LAYOUT[label_w], _LAYOUT[value_w]   ║
║       ↓                                                      ║
║  7. _blk_build_layout(offset) → _LAYOUT[block_w,indent,sep]║
║       ↓                                                      ║
║  8. renderer.sh uses _LAYOUT + _THEME to draw each line     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║  🎯 STYLE EXAMPLES (block_style.sh)                         ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  _style_default:  OFFSET=0,  ⟨ ⟩ frames, ⋮ sep             ║
║  _style_a:        OFFSET=tp/4, ⇬ ⇬ frames, ◙ border        ║
║  _style_b:        OFFSET=500, ¦ ¦ frames, " + " sep         ║
║  _style_c:        OFFSET=-500, | | frames, op_profile data  ║
║                                                              ║
║  Usage:                                                      ║
║    m              → default (center)                         ║
║    m a            → style_a (tp/4 left)                      ║
║    m b            → style_b (full left)                      ║
║    m c            → style_c (full right)                     ║
║    m -500         → default shifted right                    ║
║    m a -500       → style_a shifted right                    ║
╚══════════════════════════════════════════════════════════════╝

CHEAT
