#!/bin/bash
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
#        TOOLS is LOADED BY 00-fm-loader.sh         #
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
# -- Library module (sourced by 00-fm-loader.sh).
# -- NOTE: treegu() + alias t ถูกย้ายไปเป็น canonical ที่
#    tools/merge.sh แล้ว (เดิมซ้ำกันทั้ง 2 ไฟล์)
# -- ฟังก์ชันทั่วไปใหม่ ๆ ใส่ตรงนี้ได้
#--check alias
# -- ลบ alias หรือ function ตาม shell environment
# --  usage: unbinding [-a|-f|-af] <target>
#      -a   ลบ alias เท่านั้น
#      -f   ลบ function เท่านั้น
#      -af  ลบ alias + function ทั้งคู่
#      (default) ลบตัวที่เจอตัวแรก
unbinding(){
    local mode=""
    local target=""

    # parse flags
    while [[ "${1:-}" == -* ]]; do
        case "$1" in
            -a|-f|-af) mode="${1#-}"; shift ;;
            *) break ;;
        esac
    done
    target="${1:-}"
    [ -z "$target" ] && return 0

    # ตรวจ binding type ตาม shell
    local has_alias=0 has_func=0
    case "${_SHELL}" in
        zsh)
            local wt
            wt=$(whence -w "$target" 2>/dev/null | cut -d" " -f2)
            [ "$wt" = "alias" ]    && has_alias=1
            [ "$wt" = "function" ] && has_func=1
            ;;
        bash)
            local tt
            tt=$(type -t "$target" 2>/dev/null)
            [ "$tt" = "alias" ]    && has_alias=1
            [ "$tt" = "function" ] && has_func=1
            ;;
        *)
            c 198 b "unknown SHELL: $_SHELL"; return 1
            ;;
    esac

    # ลบตาม mode
    local removed=0
    case "$mode" in
        a)
            if (( has_alias )); then
                unalias "$target" 2>/dev/null && removed=1
                c 45 b "done unalias"; cn 10 b "  $target"
            else
                cn 190 b "⚠ '$target' has no alias"; return 1
            fi
            ;;
        f)
            if (( has_func )); then
                unset -f "$target" 2>/dev/null && removed=1
                c 45 b "done unfunction"; cn 10 b "  $target"
            else
                cn 190 b "⚠ '$target' has no function"; return 1
            fi
            ;;
        af)
            if (( has_alias )); then
                unalias "$target" 2>/dev/null && removed=1
                c 45 b "done unalias"; cn 10 b "  $target"
            fi
            if (( has_func )); then
                unset -f "$target" 2>/dev/null && removed=1
                c 45 b "done unfunction"; cn 10 b "  $target"
            fi
            (( removed )) || { c 198 b "⚠ '$target' is not an alias/function"; return 1; }
            ;;
        *)
            # default: ลบตัวที่เจอตัวแรก
            if (( has_alias )); then
                unalias "$target" 2>/dev/null && removed=1
                c 45 b "done unalias"; cn 10 b "  $target"
            elif (( has_func )); then
                unset -f "$target" 2>/dev/null && removed=1
                c 45 b "done unfunction"; cn 10 b "  $target"
            else
                c 198 b "⚠ '$target' is not an alias/function"; return 1
            fi
            ;;
    esac
}
unbinding_all (){

    local target="${1:-}";
    [ -z "$target" ] && return 0;
    local binding_type;
    case "${_SHELL}" in
        zsh)
            binding_type=$(whence -w "$target" 2> /dev/null | cut -d" " -f2)
        ;;
        bash)
            binding_type=$(type -t "$target" 2> /dev/null)
        ;;
        *)
            c 198 b "unknown SHELL: $_SHELL";
            return 1
        ;;
    esac;
    local label;
    case "$binding_type" in
        alias)
            unalias "$target" 2> /dev/null && label="done unalias"
        ;;
        function)
            unset -f "$target" 2> /dev/null && label="done unfunction"
        ;;
        *)
            c 198 b "⚠ '$target' is not an alias/function (type: ${binding_type:-none})";
            return 1
        ;;
    esac;
    c 45 b "$label";
    cn 10 b "  $target"
}

# -- ฟังก์ชั่นหา Display Width ที่แท้จริง (รวม Emoji และตัด ANSI Code ออก)
get_w() {
    local text="$1"
    # ตัด ANSI escape code ออกก่อนนับ
    local plain_text=$(echo -e "$text" | sed 'r'%"$(printf '\033')"\%\%b%g | sed 's/\x1b\[[0-9;]*m//g')

    # ใช้ python3 นับความกว้างหน้าจอจริง
    python3 -c "import unicodeattr, sys; import unicodedata; print(sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in '''$plain_text'''))" 2>/dev/null || echo "${#plain_text}"
}
ew() {
    local text="$1"
    local width
    width=$(get_visible_width "$text")
    echo "$width"
}
get_visible_width2() {
    local text="$1"

    python3 - "$text" <<'PY' 2>/dev/null
    import sys
    import re
    from wcwidth import wcswidth

    text = sys.argv[1]

    # Remove ANSI CSI escape sequences
    text = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text)

    width = wcswidth(text)

    print(max(width, 0))
PY
}
we() {
    get_visible_width2 "$@"
}
#-- git tools
#   git_ [cmd]        — git shortcut ใน SSOT repo
#   Sub-cmds:
#     s | status      → git status
#     c | commit <msg> → git commit -m
#     a | add         → git add -A
#     p | push        → git push origin main
#     pl | pull       → git pull --rebase
#     pln | pulln     → git pull --no-rebase (no rebase)
#     d | diff        → git diff --stat
#     l | log         → git log --oneline -10
#     all <msg>       → add + commit + pull --rebase + push (one-shot)
#     <other>         → pass through to git
git_() {
  local repo=${SSOT:-"$HOME/ssot"}
  cd $repo &&
  if [[ -n "$1" ]]; then
     case "${1:-}" in
        s|status)  git status ;;
        c|commit)  [[ -z "${2:-}" ]] && { cn 196 b "✗ need message: git_ commit '<msg>'"; return 1; }; git commit -m "$2" ;;
        a|add)     git add -A ;;
        p|push)    git push origin main && cn 10 bi "DONE push" ;;
        pl|pull)   git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; } ;;
        pln|pulln) git pull --no-rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; } ;;
        d|diff)    git diff --stat ;;
        l|log)     git log --oneline -10 ;;
        all)       git add -A && \
                   git commit -m "${2:-$(date '+%Y-%m-%d %H:%M:%S')}" && \
                   (git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; }) && \
                   git push origin main && \
                   cn 10 bi "DONE push" ;;
        *)         git "$@" ;;
     esac
  else
    git status
  fi
}


idf_del(){

    local idf_dir=${1:-$SSOT}
    # ค้นหาไฟล์แล้วเก็บเข้าตัวแปร
    local idf_files
    idf_files=$(find "$idf_dir" -type f -iname "*Zone.Identifier*" -print0)

    # 1. เช็คว่าถ้าไม่พบไฟล์ ให้แจ้งเตือนแล้วจบการทำงานทันที
    if [[ -z "$idf_files" ]]; then
        c 198 bi "not found any Zone.Identifier files in "; c gr b " >> "; cn 10 b "$idf_dir"
        return 1
    fi

    # 2. นับจำนวนไฟล์จากตัวแปรที่มีอยู่แล้ว (ใช้วิธีนับจำนวนบรรทัด)
    local files_count
    files_count=$(wc -l <<< "$idf_files")

    c gr "" "found "; c 10 b "$files_count ";cn gr "" "files"
    echo ""
    cn 45 b "$idf_files" &&

    cn 227 bu "DELETE all ? (y/n)"
    read -r choice

    case "$choice" in
        y|Y|yes|YES)

            while IFS= read -r file; do
                 rm -f "$file"
            done <<< "$idf_files"

            c gr "" "all  "; c 45 bi "$files_count"; cn gr "" "  Zone.Identifier files are removed"
            ;;
        *)
            return 0
            ;;
    esac


}
con_del(){

    local conf_dir=${1:-$SSOT}

    # ค้นหาไฟล์แล้วเก็บเข้าตัวแปร
    local conf_files
    conf_files=$(find "$conf_dir" -type f -iname "*conflict*" -print0)

    # 1. เช็คว่าถ้าไม่พบไฟล์ ให้แจ้งเตือนแล้วจบการทำงานทันที
    if [[ -z "$conf_files" ]]; then
        c 198 bi "not found any conflict files in "; c gr b ">>"; cn 10 b " $conf_dir"
        return 1
    fi

    # 2. นับจำนวนไฟล์จากตัวแปรที่มีอยู่แล้ว (ใช้วิธีนับจำนวนบรรทัด)
    local files_count
    files_count=$(wc -l <<< "$conf_files")

    c gr "" "found "; c 10 b "$files_count ";cn gr "" "files"
    echo ""
    cn 45 b "$conf_files" &&

    cn 227 bu "DELETE all ? (y/n)"
    read -r choice

    case "$choice" in
        y|Y|yes|YES)

            while IFS= read -r file; do
                 rm -f "$file"
            done <<< "$conf_files"

            c gr "" "all  "; c 45 bi "$files_count"; cn gr "" "  conflict files are removed"
            ;;
        *)
            return 0
            ;;
    esac


}
del(){
    local t=${1:-i}
    shift
    case "${t}" in
        c|conf|conflict) conf_def "$@" ;;
        i|idf|indentify) idf_del "$@" ;;
        *) c 196 b "RUN";c 45 b "trash_del < c or i >" ;;
    esac

}
e(){
    local m=${1:-}
    shift
    case $m in
        -n)
            printf '%s\n' "$@" ;;
        *|' ')
            printf '%s ' "$@" ;;
    esac

}
#-- auto generate block code with text via CLI
#-- usage auto_write_file 'alias' "$SSOT/core/aliases.sh" <<'EOF'
#alias ssot='cd $SSOT'
#EOF
#outpt in $2
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
#                       alias                        #
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
#alias ssot='cd $SSOT'
#
 auto_write_file() {
    
    local HEAD_NAME=${1:-"FUNCTION"}
    local FILE_PATH=${2:-"$(fn 08-nexus.sh)"}
    local width=""
    local TEXT=${3:-"TYPE SOMETHING"}

    # ถ้าไม่มี $3 ให้อ่านจาก stdin (รองรับ heredoc สำหรับข้อความหลายบรรทัด/มีตัวแปร)
    if [[ -z "${3:-}" ]] && [[ ! -t 0 ]]; then
        TEXT=$(cat)
    fi

    # คลี่ Path ในกรณีที่มีตัวแปรเช่น $HOME หรือ ~
    FILE_PATH=$(eval echo "${FILE_PATH:-$PWD/output.txt}")

    local title=" $HEAD_NAME " # ใส่ช่องไฟซ้าย-ขวาให้ข้อความหัวเรื่อง
    local char_count
    char_count=$(printf "%s" "$title" | wc -m)

    # ดักกรณีถ้าข้อความยาวเกินความกว้างกล่องที่ตั้งไว้ ($width) ให้ขยายกล่องอัตโนมัติเพื่อไม่ให้เส้นพัง
    if [ "$char_count" -gt "$width" ]; then
        width=$((char_count + 4)) # ขยายขนาดกล่องให้กว้างกว่าข้อความ
    fi

    # คำนวณขอบซ้าย-ขวา เพื่อปูทางให้ความกว้างรวมออกมาคงที่เท่ากับ $width เป๊ะๆ
    local pad=$(( (width - char_count) / 2 ))
    local rem=$(( width - char_count - pad ))

    local left_space
    left_space=$(printf "%${pad}s" "")
    local right_space
    right_space=$(printf "%${rem}s" "")

    # ความยาวของเส้นใต้ จะเท่ากับจำนวนตัวหนาทั้งหมดรวมกัน (pad + ข้อความ + rem)
    # ซึ่งก็คือค่า $width พอดีเป๊ะ!
    local main_line
    main_line=$(printf "%${width}s" | sed 's/ /▬/g')

    # ประกอบร่าง Header & Footer Block
    # (ครอบด้วย # และปิดด้วย # ให้เหมือนกันทั้งบนและล่าง)
    local head_line_top="# ${main_line} #"
    local head_line_mid="# ${left_space}${title}${right_space} #"
    local head_line_bot="# ${main_line} #"

    {
        echo " "
        echo "$head_line_top"
        echo "$head_line_mid"
        echo "$head_line_bot"
        printf '%s\n' "$TEXT"
        echo " "
    } >> "${FILE_PATH}"



  c lg b "✅ Text Box Write '${TEXT}'  to : ${FILE_PATH}"
}

alias atype='auto_write_file'

find_ali() {
    local target="$1"

    # 1. ตรวจสอบก่อนว่ามีการส่งชื่อ alias มาหรือไม่
    if [ -z "$target" ]; then
        echo "❌ กรุณาระบุชื่อ alias ที่ต้องการเช็ค (เช่น: find_alias ll)"
        return 1
    fi

    # 2. ปรับการทำงานของ Shell ชั่วคราวกรณีใช้งานบน Bash ให้รู้จัก alias ใน script/function
    if [ -n "$BASH_VERSION" ]; then
        shopt -s expand_aliases 2>/dev/null
    fi

    # 3. เช็คว่าเป็น Alias หรือไม่ (ใช้ type -t ซึ่งรองรับทั้ง Bash และ Zsh)
    if [ "$(type -t "$target" 2>/dev/null)" = "alias" ]; then
        echo "✅ '$target' เป็น Alias"

        # แสดงคำสั่งเต็มของ Alias นั้น
        echo "📌 นิยาม: $(type "$target" 2>/dev/null)"
        echo "----------------------------------------"
        echo "🔍 กำลังค้นหาไฟล์ที่ตั้งค่า..."

             # 4. ค้นหาบรรทัด 'alias target=' ในไฟล์คอนฟิกหลัก และโฟลเดอร์ ssot
        local match_found=0

        # รายชื่อไฟล์หลักที่ต้องการเช็ค
        local search_files=(
            "$HOME/.bashrc"
            "$HOME/.zshrc"
            "$HOME/.bash_aliases"
            "$HOME/.zprofile"
            "$HOME/.bash_profile"
            "$HOME/.profile"
        )

        # 4.1 ค้นหาในไฟล์หลักรายไฟล์
        for file in "${search_files[@]}"; do
            if [ -f "$file" ]; then
                local result
                result=$(grep -HnE "^\s*alias\s+${target}=" "$file" 2>/dev/null)
                if [ -n "$result" ]; then
                    echo "📁 พบในไฟล์: $result"
                    match_found=1
                fi
            fi
        done

        # 4.2 ค้นหาทั้งโฟลเดอร์ $HOME/ssot (ถ้าโฟลเดอร์นี้มีอยู่จริง)
        if [ -d "$HOME/ssot" ]; then
            local folder_result
            # -r = ค้นหาในโฟลเดอร์ย่อยด้วย, -n = แสดงเลขบรรทัด, -H = แสดงชื่อไฟล์
            folder_result=$(grep -rHnE "^\s*alias\s+${target}=" "$HOME/ssot" 2>/dev/null)
            if [ -n "$folder_result" ]; then
                echo "📁 พบในโฟลเดอร์ ssot:\n$folder_result"
                match_found=1
            fi
        fi


        # ดึงรายชื่อไฟล์ใน ~/.config ที่ลงท้ายด้วย .sh, .zsh, .bash (ถ้ามี)
        local extra_files
        extra_files=$(find "$HOME/.config" -maxdepth 3 -type f \( -name "*.sh" -o -name "*.zsh" -o -name "*.bash" \) 2>/dev/null)

        # รวมไฟล์ทั้งหมดแล้วค้นหาด้วย grep
        local match_found=0
        for file in "${search_files[@]}"; do
            if [ -f "$file" ]; then
                # ค้นหาการตั้งค่า alias แบบตรงตัว เช่น alias ll= หรือ alias ll =
                local result
                result=$(grep -HnE "^\s*alias\s+${target}=" "$file" 2>/dev/null)
                if [ -n "$result" ]; then
                    echo "📁 พบในไฟล์: $result"
                    match_found=1
                fi
            fi
        done

        # ค้นหาในโฟลเดอร์ ~/.config เพิ่มเติมหากยังไม่เจอในไฟล์หลัก
        if [ $match_found -eq 0 ] && [ -n "$extra_files" ]; then
            while IFS= read -r file; do
                local result
                result=$(grep -HnE "^\s*alias\s+${target}=" "$file" 2>/dev/null)
                if [ -n "$result" ]; then
                    echo "📁 พบในไฟล์: $result"
                    match_found=1
                fi
            done <<< "$extra_files"
        fi

        if [ $match_found -eq 0 ]; then
            echo "⚠️ ไม่พบตำแหน่งในไฟล์ Config หลัก (อาจถูกโหลดมาจาก Plugin หรือ Session ชั่วคราว)"
        fi
    else
        echo "❌ '$target' ไม่ใช่ Alias"
    fi
}
#-- งาน compress video

mv_() {
    local src="${1:?กรุณาระบุ pattern}"
    local dest="${2:?กรุณาระบุ destination}"
    mkdir -p "$dest"
    mv $src "$dest/"
    echo "✅ ย้ายเสร็จ: $(ls "$dest" | wc -l) ไฟล์"
}


perm(){
    local target="${1:-$(cb_read)}"
    chmod +x "$target" && c 10 bi "ให้สิทธิ์รันไฟล์  ";c 45 b "$(basename "$target")  ";cn 10 bi "เรียบร้อย" 
}
pu(){
		bsc &&
    git add -A &&
	if [[ -z "$1" ]]; then
    git commit -m "$(date)" 
	else
		git commit -m "$@"
	fi	
    git pull && 
    cn 10 b "DONE PULL" 
}

