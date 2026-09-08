#!/usr/bin/env bash
# ------------------------------------------------------------
# File: env_importor.sh
# ------------------------------------------------------------


rename_lgr(){
    local space="    "
    local name="${1:-$space}"
    
    cb_copy "$name"
    cn lg b "ชื่อใหม่ = $(cn 45 b "$name") ถูก cp ไว้ใน clipboard แล้ว"
}

