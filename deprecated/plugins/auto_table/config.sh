#!/bin/bash
# --- 1. Config & Defaults ---
 config_def() {
  # --- 1. Config & Defaults ---
  # -- setup color mode
    set_ "COLOR_MODE"                 "yes"          # auto / manual
    set_ "BN_TITLE"                 "SUPERBOOM PATH"
    set_ "BN_TITLE_COLOR"           "11"       # ส้ม
    set_ "BN_TITLE_STYLE"           "b"         # bold

    set_ "BN_BORDER_CHAR"           "━"         # ม
    set_ "BN_BORDER_COLOR"          "92"
    set_ "BN_BORDER_STYLE"          "b"

    set_ "BN_LABEL_COLOR"           "198"       # เทาสว่าง
    set_ "BN_LABEL_STYLE"           "d"         # dim
    set_ "BN_VAL_COLOR"             "206"       # 202
    set_ "BN_VAL_STYLE"             "b"
   set_ "BN_SEP"                   " : "
}
# --- 2 Config & rc ---
config_rc(){
  
    set_ "COLOR_MODE"                 "no"          # auto / manual
    set_ "BN_TITLE"                 "SUPERBOOM PATH"
    set_ "BN_TITLE_COLOR"           "118"       # ส้ม
    set_ "BN_TITLE_STYLE"           "b"         # bold

    set_ "BN_BORDER_CHAR"           "━"         # ม
    set_ "BN_BORDER_COLOR"          "92"
    set_ "BN_BORDER_STYLE"          "b"

    set_ "BN_LABEL_COLOR"           "190 "       # เทาสว่าง
    set_ "BN_LABEL_STYLE"           "d"         # dim
    set_ "BN_VAL_COLOR"             "82"       # 202
    set_ "BN_VAL_STYLE"             "b"
   set_ "BN_SEP"                   " : "
}




