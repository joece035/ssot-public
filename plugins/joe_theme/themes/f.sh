#!/usr/bin/env bash
# ============================================================
# Theme F: RULE
# Minimal 3 บรรทัด — เส้นคั่นบาง ๆ ใต้บรรทัด info
# ไม่มี env · user@host · git (โชว์แค่ path + error เมื่อพัง)
# สีทุกจุดมาจาก core/01-colors.sh ผ่าน psc (PS1-safe)
#   path = ขาวนวล | เส้น = เทาจาง | caret = ทองอ่อน
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "source-only"; exit 1; }

# shared lib: width / border / cursor lifecycle (จาก _lib.sh)
_joe_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib.sh"
source "$_joe_lib" 2>/dev/null
if ! command -v psc >/dev/null 2>&1 || ! command -v _joe_ctx >/dev/null 2>&1; then
    printf '[joe_theme] cannot load %s\n' "$_joe_lib" >&2
    return 1
fi

_sp_rule() {
    local exit_code=$?

    # ── full (info + เส้น) หรือ mini (แค่ caret) ─────────────
    _joe_ctx _SSOT_RULE
    if (( _JOE_MINI == 1 )); then
        if (( exit_code == 0 )); then
            PS1=" $(psc 179 b '❯')  "
        else
            PS1=" $(psc 203 b '❯')  "
        fi
        return
    fi

    local cwd="${PWD/#$HOME/\~}"

    # ตอนสำเร็จ = เงียบ เห็นแค่ path / ตอนพัง = โชว์ err + code
    local status=""
    if (( exit_code != 0 )); then
        status="$(psc 203 b ' err')$(psc 203 d " ${exit_code}")"
    fi

    # ── content → วัดความกว้าง → เส้นคั่นพอดีเป๊ะ ──────────
    local content=" $(psc 252 '' "$cwd")${status}"
    local lens rule
    lens="$(_joe_fit "$content")"
    rule="$(_joe_border "$lens" '─' 238 d)"

    local PS1_=""
    PS1_+="${content}\n"
    PS1_+="${rule}\n"
    PS1_+=" $(psc 179 b '❯')  "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_sp_rule
