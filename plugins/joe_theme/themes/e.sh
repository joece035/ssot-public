#!/usr/bin/env bash
# ============================================================
# Theme E: MIST
# Minimal 2 บรรทัด — ไม่มี border, ไม่มี env · user@host · git
# สีทุกจุดมาจาก core/01-colors.sh ผ่าน psc (PS1-safe)
#   ● = status dot (เขียว=สำเร็จ / แดง=ล้มเหลว)
#   path = ฟ้าเทาจาง ๆ | caret = น้ำแข็งอ่อน
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "source-only"; exit 1; }

# shared lib: width / border / cursor lifecycle (จาก _lib.sh)
_joe_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib.sh"
source "$_joe_lib" 2>/dev/null
if ! command -v psc >/dev/null 2>&1 || ! command -v _joe_ctx >/dev/null 2>&1; then
    printf '[joe_theme] cannot load %s\n' "$_joe_lib" >&2
    return 1
fi

# MIST ไม่ใช้ _joe_ctx → ไม่ถาม cursor position → prompt ขึ้นทันที ไม่มี delay
_sp_mist() {
    local exit_code=$?
    local cwd="${PWD/#$HOME/\~}"

    # status dot — มีแค่จุดเดียว ไม่มีอย่างอื่นมาแย่งสายตา
    local dot err=""
    if (( exit_code == 0 )); then
        dot="$(psc 114 b '●')"
    else
        dot="$(psc 203 b '●')"
        err="$(psc 203 d "  ${exit_code}")"   # exit code จาง ๆ ท้ายแถว เฉพาะตอนพัง
    fi

    local PS1_=""
    PS1_+=" ${dot}$(psc 146 '' "$cwd")${err}\n"
    PS1_+=" $(psc 81 '' '›')  "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_sp_mist
