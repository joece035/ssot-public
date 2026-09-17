#!/bin/bash
fvar() {
    local search_dir="."
    local custom_pattern=""
    local match_mode="export"   # export (default) | all | word | custom
    local ignore_case=0
    local exclude_git=1
    local targets=()

    # 1. แยกแยะ Argument และ Options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                search_dir="${2:-.}"
                shift 2
                ;;
            -p|--pattern)
                custom_pattern="${2:-}"
                match_mode="custom"
                shift 2
                ;;
            -a|--all)
                match_mode="all"
                shift
                ;;
            -w|--word)
                match_mode="word"
                shift
                ;;
            -i|--ignore-case)
                ignore_case=1
                shift
                ;;
            --git)
                exclude_git=0
                shift
                ;;
            -h|--help)
                echo "วิธีใช้งาน: fvar [options] <คำค้นหา1> [คำค้นหา2 ...]"
                echo ""
                echo "Options (เทียบเท่าปุ่มค้นหาบน GUI Text Editor / Ctrl+H):"
                echo "  -d, --dir <path>      ระบุโฟลเดอร์ค้นหา (default: .)"
                echo "  -p, --pattern <pat>   กำหนด regex pattern เอง (%s แทนคำค้น)"
                echo "                        ตัวอย่าง: -p \"%s=\" หรือ -p \"(export|local)\s+%s\""
                echo "  -a, --all             หาทุกการประกาศตัวแปร: export, local หรือ VAR="
                echo "  -w, --word            ค้นหาแบบ Whole Word (\b<word>\b)"
                echo "  -i, --ignore-case     ไม่สนใจตัวพิมพ์เล็ก/ใหญ่ (Match Case OFF)"
                echo "  --git                 รวมโฟลเดอร์ .git (ปกติจะ exclude ออก)"
                echo ""
                echo "ตัวอย่าง:"
                echo "  fvar -d \$SSOT MY_DEVICE               # ค่าเริ่มต้น: หา export MY_DEVICE"
                echo "  fvar -d \$SSOT -a MY_DEVICE            # หาการกำหนดค่าทั้งหมด (export/local/VAR=)"
                echo "  fvar -d \$SSOT -w MY_DEVICE            # หาคำว่า MY_DEVICE ทุกที่ (Whole Word)"
                echo "  fvar -d \$SSOT -p \"%s=\" MY_DEVICE     # หาเฉพาะที่มีเครื่องหมาย ="
                echo "  fvar -d \$SSOT -p \"export.*MY_DEVICE\" # ใส่ custom regex ตรงๆ"
                return 0
                ;;
            *)
                targets+=("$1")
                shift
                ;;
        esac
    done

    # กรณีส่ง -p มาโดยไม่มีเป้าหมายคำค้น ให้ค้นหา pattern นั้นตรงๆ
    if [[ "$match_mode" == "custom" && ${#targets[@]} -eq 0 && -n "$custom_pattern" ]]; then
        targets=("$custom_pattern")
    fi

    # ตรวจสอบคำค้นหา
    if [[ ${#targets[@]} -eq 0 ]]; then
        echo "❌ กรุณาระบุคำค้นหา (พิมพ์ fvar -h เพื่อดูวิธีใช้)"
        return 1
    fi

    # ตรวจสอบโฟลเดอร์
    if [[ ! -d "$search_dir" ]]; then
        echo "❌ error: ไม่พบโฟลเดอร์ '$search_dir'"
        return 1
    fi

    echo "=========================================="
    echo " 🔍 กำลังค้นหาใน: $search_dir"
    echo "=========================================="

    local grep_flags=(-rnEI)
    [[ $ignore_case -eq 1 ]] && grep_flags+=(-i)
    [[ $exclude_git -eq 1 ]] && grep_flags+=(--exclude-dir=.git)

    for item in "${targets[@]}"; do
        local regex=""
        local label=""

        case "$match_mode" in
            export)
                regex="export\s+${item}\b"
                label="export ${item}"
                ;;
            all)
                # Matches: export VAR=, local VAR=, or VAR=
                regex="(export\s+|local\s+)?\b${item}\s*="
                label="assignment: ${item}="
                ;;
            word)
                # Whole word match like VS Code [|ab|]
                regex="\b${item}\b"
                label="whole word: ${item}"
                ;;
            custom)
                if [[ "$custom_pattern" == *"%s"* ]]; then
                    regex="${custom_pattern//%s/$item}"
                elif [[ "$custom_pattern" == *"{}"* ]]; then
                    regex="${custom_pattern//\{\}/$item}"
                elif [[ -n "$custom_pattern" && "$item" != "$custom_pattern" ]]; then
                    regex="${custom_pattern}${item}"
                else
                    regex="${item}"
                fi
                label="pattern: ${regex}"
                ;;
        esac

        echo ""
        cn lg b " [+] ผลการค้นหาสำหรับ: $item ($label) " --bg 240
        echo "------------------------------------------"

        local results
        results=$(grep "${grep_flags[@]}" -e "$regex" "$search_dir" 2>/dev/null)

        if [[ -n "$results" ]]; then
            echo "$results"
        else
            echo "❌ ไม่พบข้อความที่ตรงกับ '$label'"
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
            echo "${matches[1]:-${matches[0]}}"
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

replace_w() {
    # 1. เช็กว่ามีการส่ง Parameter มาอย่างน้อย 1 ตัวไหม
    if [[ $# -lt 1 ]]; then
        echo "Usage: replace_w <old1=new1> [old2=new2 ...] [target_folder]"
        echo "Example: replace_w \"cat=dog\" \"apple=banana\" ./my_folder"
        return 1
    fi

    local pairs=()
    local target="$PWD"

    # 2. แยกแยะระหว่าง "คู่คำ" กับ "target_folder"
    # ถ้า Parameter ตัวสุดท้ายไม่ใช่รูป pattern "X=Y" และเป็นโฟลเดอร์/ไฟล์ที่มีอยู่จริง ให้ถือว่าเป็น target
    local last_arg="${!#}"
    if [[ ! "$last_arg" =~ = ]] && [[ -e "$last_arg" ]]; then
        target="$last_arg"
        pairs=("${@:1:$#-1}") # เอา Parameter ทุกตัวยกเว้นตัวสุดท้าย
    else
        pairs=("$@")         # เอา Parameter ทั้งหมดเป็นคู่คำ
    fi

    # 3. ตรวจสอบรูปแบบ Input ของคู่คำ
    local old_words=()
    local new_words=()

    for pair in "${pairs[@]}"; do
        if [[ ! "$pair" =~ = ]]; then
            echo "❌ Error: Invalid format '$pair'. Must be 'old=new'"
            return 1
        fi
        old_words+=("${pair%%=*}") # ดึงข้อความหน้าเครื่องหมาย =
        new_words+=("${pair#*=}")  # ดึงข้อความหลังเครื่องหมาย =
    done

    echo "🔍 Target Directory: $target"
    echo "📋 Replacement Pairs:"
    for i in "${!old_words[@]}"; do
        echo "   - '${old_words[$i]}' ➡️ '${new_words[$i]}'"
    done
    echo "------------------------------------------------"

    # 4. ค้นหาไฟล์ที่มีคำใดคำหนึ่งในรายการ
    local matched_files=()
    local grep_pattern=""

    # สร้าง pattern สำหรับ grep เช่น "word1\|word2"
    for word in "${old_words[@]}"; do
        grep_pattern+="${word}\|"
    done
    grep_pattern="${grep_pattern%\|}" # ตัด \| ตัวสุดท้ายออก

    while IFS= read -r -d '' file; do
        matched_files+=("$file")
    done < <(find "$target" -type f -exec grep -l "$grep_pattern" {} + 2>/dev/null)

    # 5. เช็กว่าเจอไฟล์หรือไม่
    if [[ ${#matched_files[@]} -eq 0 ]]; then
        echo "❌ No matching files found."
        return 0
    fi

    # 6. แสดงรายการไฟล์ที่ค้นพบ
    echo "Found '${#matched_files[@]}' file(s):"
    for file in "${matched_files[@]}"; do
        echo "  - $file"
    done
    echo "------------------------------------------------"

    # 7. ถามยืนยัน Y/N
    local confirm
    read -rp "Proceed with replacement in these files? (y/N): " confirm

    # 8. ทำการเปลี่ยนคำทุกคู่ในไฟล์ที่เจอ
    case "$confirm" in
        [yY]|[yY][eE][sS])
            echo "🚀 Replacing..."
            for file in "${matched_files[@]}"; do
                for i in "${!old_words[@]}"; do
                    # ใช้ # เป็น Delimiter แทน / ป้องกันปัญหาเรื่อง path/URL
                    sed -i "s#${old_words[$i]}#${new_words[$i]}#g" "$file"
                done
            done
            echo "✨ All done!"
            ;;
        *)
            echo "🛑 Operation cancelled."
            return 0
            ;;
    esac
}


fword() {
    local word="${1:?"Please provide a word to search for"}"
    shift
    grep -rnii "$word" "${@:-.}:?"
}

