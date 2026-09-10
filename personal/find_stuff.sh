#!/bin/bash
fexport(){

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
}
# ==========================================
# Helper Check Shell Type
# ==========================================
_is_func_loaded() {
    local func_name="$1"
    if [ -n "$ZSH_VERSION" ]; then
        # สำหรับ Zsh
        typeset -f "$func_name" >/dev/null 2>&1
    else
        # สำหรับ Bash และ POSIX Shell อื่นๆ
        declare -F "$func_name" >/dev/null 2>&1
    fi
}

# ==========================================
# Main Functions
# ==========================================

# find_unsource_func — ค้นหาไฟล์ที่มี function นั้น
# รองรับ: single result (return path) / multi result (interactive picker)
# Usage: find_unsource_func <func_name> [search_dir]
find_unsource_func() {
    local func_name="$1"
    local search_dir="${2:-${SSOT:-$repository}}"

    if [ -z "$func_name" ]; then
        echo "Usage: find_unsource_func <function_name> [directory]" >&2
        return 1
    fi

    echo "🔍 Searching for function '$func_name' in '$search_dir'..." >&2

    # รวบรวมทุก match
    local -a matches
    mapfile -t matches < <(
        grep -rnlE "^\s*(function\s+${func_name}|${func_name}\s*\(\))" "$search_dir" 2>/dev/null
    )

    case "${#matches[@]}" in
        0)
            echo "❌ Function '$func_name' not found in '$search_dir'" >&2
            return 1
            ;;
        1)
            # พบแค่ 1 ไฟล์ → return ทันที (behavior เดิม)
            echo "${matches[0]}"
            ;;
        *)
            # พบหลายไฟล์ → ให้ user เลือก
            echo "⚠️  Found ${#matches[@]} files containing '$func_name':" >&2
            if command -v fzf >/dev/null 2>&1; then
                # fzf interactive picker (ถ้ามี)
                local selected
                selected=$(printf '%s\n' "${matches[@]}" | \
                    fzf --prompt="Source which file? > " \
                        --height=40% \
                        --border \
                        --preview="grep -n '${func_name}' {}" \
                        --preview-window=down:5)
                [[ -n "$selected" ]] && echo "$selected" || return 1
            else
                # Fallback: numbered select (built-in, zero dependency)
                local choice
                select choice in "${matches[@]}" "Cancel"; do
                    [[ "$choice" == "Cancel" || -z "$choice" ]] && return 1
                    echo "$choice"
                    return 0
                done
            fi
            ;;
    esac
}
alias fusf='find_unsource_func'
auto_source() {
    local func="${1:-}"

    [[ -n "$func" ]] || {
        echo "Error: Please provide function name" >&2
        return 1
    }

    # ตรวจสอบว่าฟังก์ชันถูกโหลดไว้แล้วหรือยัง (รองรับทั้ง Bash/Zsh)
    _is_func_loaded "$func" && return 0

    local script_path
    script_path="$(find_unsource_func "$func" "${2:-${SSOT:-$repository}}")" || return 1

    [[ -n "$script_path" ]] || {
        echo "Error: Function '$func' not found" >&2
        return 1
    }

    # สั่ง source ไฟล์สคริปต์ที่เจอ
    if source "$script_path"; then
        echo "✅ Sourced ($CURRENT_SHELL): $script_path"
    else
        echo "❌ Failed to source: $script_path" >&2
        return 1
    fi
}
alias ausf='auto_source'

# ==========================================
# _guard_func — Error guard สำหรับใช้ใน scripts
# ตรวจสอบว่า function พร้อมใช้ก่อนเรียก — ถ้ายังไม่โหลดให้ auto-load
# Usage: _guard_func <func_name> [search_dir] && <func_name> "$@"
# Examples:
#   _guard_func "fm_cp" && fm_cp "$src" "$dst"
#   _guard_func "my_func" || exit 1
# ==========================================
_guard_func() {
    local func="$1"
    local context="${2:-${SSOT:-$repository}}"

    if [[ -z "$func" ]]; then
        echo "❌ _guard_func: No function name provided" >&2
        return 1
    fi

    if _is_func_loaded "$func"; then
        return 0
    fi

    echo "⚠️  '$func' not loaded — attempting auto_source..." >&2
    auto_source "$func" "$context" || {
        echo "❌ Cannot proceed: '$func' unavailable" >&2
        return 1
    }
}