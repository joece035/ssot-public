# /bin/bash

replace_w() {
    local old_name=${1:-}
    local new_name=${2:-}
    local target=${3:-$PWD}

    if [[ -z "$old_name" || -z "$new_name" ]]; then
        echo "Usage: change_word <old_name> <new_name> [target_folder]"
        return 1
    fi

    echo "Replacing '$old_name' with '$new_name' in $target..."

    # ครอบเครื่องหมายคำพูดซ้อนสไตล์นี้ปลอดภัยที่สุดครับ
    find "$target" -type f -exec sed -i "s/""$old_name""/""$new_name""/g" {} +

    echo "✨ All done "
}

rename_multi(){
    local target="${1:-$PWD}"
    # วนลูปอ่านทุกไฟล์
    for file in *; do
        # ตรวจสอบว่ามีไฟล์อยู่จริง (ป้องกันกรณีไม่มีไฟล์ .jpg)
        [ -e "$file" ] || continue
        # ดึงวันที่แก้ไขล่าสุดของไฟล์ในรูปแบบ YYYY-MM-DD_HHMMSS
        # Linux (Ubuntu/WSL):
        date_str=$(stat -c %y "$file" | awk '{print $1"_" $2}' | cut -d'.' -f1 | tr ':' '-')
        
        # แยกชื่อไฟล์เดิมและนามสกุล
        ext="${file##*.}"

        # กำหนดชื่อใหม่
        new_name="${date_str}.${ext}"

        # แสดงผลการทำงานก่อน (DRY RUN)
        echo "Renaming: '$file' -> '$new_name'"
        
        # หากต้องการให้เปลี่ยนชื่อจริง ให้เอา # ข้างหน้า mv ออก
        mv "$file" "$new_name"
    done
}

# `fpid()` v2

fpid() {
    # ============================================================
    # fpid <port> [process_pattern]
    #
    # Example:
    #   fpid 9119
    #   fpid 9119 node
    #   fpid 9119 hermes
    #   fpid 8080 "python.*server"
    # ============================================================

    local port="${1:-}"
    local proc_pattern="${2:-}"

    # ------------------------------------------------------------
    # 1. Validate
    # ------------------------------------------------------------
    if [ -z "$port" ]; then
        cn y bi "Usage: fpid <port> [process_pattern]"
        return 1
    fi

    local pid=""
    local os_type
    os_type="$(uname -s 2>/dev/null)"

    local use_sudo=""

    # ------------------------------------------------------------
    # 2. Sudo only when actually useful
    # ------------------------------------------------------------
    if [ -z "$TERMUX_VERSION" ] \
        && [ "$(id -u)" -ne 0 ] \
        && command -v sudo &>/dev/null
    then
        use_sudo="sudo"
    fi

    # ============================================================
    # 3. Find PID by PORT
    # ============================================================

    # ------------------------------------------------------------
    # Windows / Git Bash
    # ------------------------------------------------------------
    if [[ "$os_type" =~ ^(MINGW|MSYS|CYGWIN) ]]; then

        pid=$(
            netstat.exe -ano 2>/dev/null |
            grep -E "LISTENING.*:${port}[[:space:]]" |
            awk '{print $5}' |
            sort -u |
            xargs
        )

    # ------------------------------------------------------------
    # Linux / WSL / Termux
    # ------------------------------------------------------------
    else

        # ---- Method 1: lsof ------------------------------------
        if command -v lsof &>/dev/null; then
            pid=$(
                $use_sudo lsof -ti:"$port" 2>/dev/null |
                sort -u |
                xargs
            )
        fi

        # ---- Method 2: ss --------------------------------------
        if [ -z "$pid" ] && command -v ss &>/dev/null; then
            pid=$(
                $use_sudo ss -ltnp "sport = :$port" 2>/dev/null |
                grep -oP 'pid=\K[0-9]+' |
                sort -u |
                xargs
            )
        fi

        # ---- Method 3: netstat --------------------------------
        if [ -z "$pid" ] && command -v netstat &>/dev/null; then
            pid=$(
                $use_sudo netstat -tulpn 2>/dev/null |
                grep -E ":${port}[[:space:]]" |
                grep -oP '[0-9]+(?=/)' |
                sort -u |
                xargs
            )
        fi
    fi

    # ============================================================
    # 4. Termux fallback
    #
    # Android may allow us to see the port but not the PID.
    # If user supplied a process pattern, search process table.
    # ============================================================

    if [ -z "$pid" ] \
        && [ -n "$proc_pattern" ] \
        && [ -n "$TERMUX_VERSION" ]
    then

        if command -v pgrep &>/dev/null; then
            pid=$(
                pgrep -f "$proc_pattern" 2>/dev/null |
                sort -u |
                xargs
            )
        fi

        # pgrep fallback
        if [ -z "$pid" ]; then
            pid=$(
                ps -ef 2>/dev/null |
                grep -E "$proc_pattern" |
                grep -v grep |
                awk '{print $2}' |
                sort -u |
                xargs
            )
        fi
    fi

    # ============================================================
    # 5. Generic process-pattern fallback
    # ============================================================

    if [ -z "$pid" ] && [ -n "$proc_pattern" ]; then

        if command -v pgrep &>/dev/null; then
            pid=$(
                pgrep -f "$proc_pattern" 2>/dev/null |
                sort -u |
                xargs
            )
        fi

        if [ -z "$pid" ]; then
            pid=$(
                ps -ef 2>/dev/null |
                grep -E "$proc_pattern" |
                grep -v grep |
                awk '{print $2}' |
                sort -u |
                xargs
            )
        fi
    fi

    # ============================================================
    # 6. Nothing found
    # ============================================================

    if [ -z "$pid" ]; then

        if [ -n "$proc_pattern" ]; then
            cn r bi "No process found for port $port / pattern '$proc_pattern'"
        else
            cn r bi "No PID found for port $port"
            cn y "Tip: Termux may block socket → PID mapping."
            cn y "Try: fpid $port <process_name>"
        fi

        return 1
    fi

    # ============================================================
    # 7. Display
    # ============================================================

    cn 87 b "Found process on port $port"

    local p
    local proc_name

    for p in $pid; do

        proc_name=""

        proc_name=$(ps -p "$p" -o comm= 2>/dev/null | xargs)

        if [ -z "$proc_name" ]; then
            proc_name=$(cat "/proc/$p/comm" 2>/dev/null | xargs)
        fi

        printf "  PID: %-8s CMD: %s\n" "$p" "${proc_name:-unknown}"
    done

    # ============================================================
    # 8. Confirm kill
    # ============================================================

    printf "Do you want to kill process %s? (y/n): " "$pid"
    read -r answer

    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        cn y b "Process $pid not killed."
        return 0
    fi

    # ============================================================
    # 9. Kill
    # ============================================================

    # ------------------------------------------------------------
    # Windows
    # ------------------------------------------------------------
    if [[ "$os_type" =~ ^(MINGW|MSYS|CYGWIN) ]]; then

        local exe_name=""

        # Only safe for a single PID
        if [[ "$pid" != *" "* ]]; then

            exe_name=$(
                tasklist.exe //FI "PID eq $pid" //FO CSV 2>/dev/null |
                awk -F'","' 'NR==2{print $1}' |
                tr -d '"'
            )

            if [ -n "$exe_name" ]; then

                taskkill.exe //F //IM "$exe_name" //T 2>/dev/null &&
                    cn 10 b "Killed all instances of '$exe_name'."

            else

                taskkill.exe //F //T //PID "$pid" 2>/dev/null &&
                    cn 10 b "Process $pid killed."

            fi

        else

            # Multiple PIDs
            local p

            for p in $pid; do
                taskkill.exe //F //PID "$p" 2>/dev/null
            done

            cn 10 b "Killed processes: $pid"
        fi

    # ------------------------------------------------------------
    # Linux / WSL / Termux
    # ------------------------------------------------------------
    else

        local p

        for p in $pid; do

            if kill -9 "$p" 2>/dev/null; then
                cn 10 b "Killed PID $p."
            else
                cn r b "Failed to kill PID $p."
            fi

        done
    fi
}


# --video pattern 
f_video(){
    local target="${1:-$bk_boom}"
    local files=() v
    mapfile -t files < <(find "$target" -type f \( \
        -iname "*.mp4" -o \
        -iname "*.3gp" -o \
        -iname "*.flv" -o \
        -iname "*.avi" -o \
        -iname "*.mov" -o \
        -iname "*.mkv" -o \
        -iname "*.wmv" -o \
        -iname "*.FLV" -o \
        -iname "*.AVI" -o \
        -iname "*.MOV" -o \
        -iname "*.MKV" -o \
        -iname "*.WMV" -o \
        -iname "*_tmp" -o \
        -iname "*_TMP" -o \
        -iname "*_Tmp" -o \
        -iname "*_*" \
    \))
    if [[ -z "${files[@]}" ]]; then
        cn r bi "No files found"
        return 1
    fi
    for v in "${files[@]}"; do
        rc b "${v}"
    done
    cn gr d "found  $(cn 198 b "${#files[@]}")"
    
}


fexec(){
    local target pattern files count move_dir copy_dir
    target="${1:-$PWD}"
    pattern="${2:-*.sh}"
    count="$(find "$target" -type f -iname "${pattern}" 2>/dev/null | wc -l)"

    

    #เช็คว่ามีไฟล์
    files="$(find "$target" -type f -iname "${pattern}" 2>/dev/null | sort -u)"
    if [[ -z "$files" ]]; then
        cn r bi "No files found matching pattern "${pattern}" in directory "$target""; return 1
    fi
    
    #แสดง
    cn 45 b "$files"
    cn 10 b "$count files found "
    read -p "what do you want to do with these files? (rm/mv/cp/exit) : " answer

    if [[ "$answer" == "rm" ]]; then
        cn 45 b "Are you sure you want to delete these files? (y/n): "
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            local rm_files=($files)
            for file in "${rm_files[@]}"; do
                [[ -f "$file" ]] && cn y bi "$file" && rm -f "$file" || cn r bi "$file not found"
            done
            cn lg b "$count files done"
        else
            cn y b "Files not deleted."
        fi
    elif [[ "$answer" == "mv" ]]; then
        cn 45 b "Enter the directory to move the files to: "
        read -r move_dir
        if [[ ! -d "$move_dir" ]]; then
            mkdir -p "$move_dir" 
        fi    
        local rm_files=($files)
        for file in "${rm_files[@]}"; do
            if [[ -f "$file" ]]; then
                mv "$file" "$move_dir"/$(basename "$file") && 
                printf "%s %s >>> %s\n" \
                    "done move" \
                    "$(cn ora bi "$(basename "$file")")" \
                    "$(cn lg bi "$move_dir"/$(basename "$file"))"
            fi
        done
        cn lg b "$count files done"
    elif [[ "$answer" == "cp" ]]; then
        cn 45 b "Enter the directory to copy the files to: "
        read -r copy_dir
        if [[ -d "$copy_dir" ]] ; then
          find "$target" -type f  -iname "${pattern}" 2>/dev/null | xargs -p cp -v -t "$copy_dir"
        else
          cn r bi "Directory not found: $copy_dir"
          return 1
        fi
        find "$target" -type f  -iname "${pattern}" 2>/dev/null | xargs -p cp -v -t "$copy_dir"
    else
        cn y b "Invalid input."
    fi      
}

new() {
    local type="${1:-'-d'}"
    local target="${2:?"usage : $0 [type] [target] \n type: -d or -f"}"
    
    case $type in
        "-d")  
            mkdir -p "$target" && 
            cn y bi "✅ โฟลเดอร์ถูกสร้างเรียบร้อยที่: $target" ;;
        "-f") 
            mkdir -p "$(dirname "$target")" && 
            touch "$target" && 
            cn y bi "✅ ไฟล์ถูกสร้างเรียบร้อยที่: $target" ;;
        "-sh")  
            mkdir -p "$(dirname "$target")"  
            touch "$target" && 
            cn y bi "✅ ไฟล์ .sh ถูกสร้างเรียบร้อยที่: $target" &&
            chmod +x "$target" && c lg bi "ให้สิทธิ์รันไฟล์  ";c 45 b "$(basename "$target")  ";cn lg bi "เรียบร้อย"  && 
            cat << EOF > "$target"
#!/usr/bin/env bash
# ------------------------------------------------------------
# File: $(basename "$target")
# ------------------------------------------------------------




EOF
            ;;
        *)  cn y b "usage : -d or -f"; return 1 ;;
    esac

}

perm(){
    local target="${1:-$(cb_read)}"
    chmod +x "$target" && c 10 bi "ให้สิทธิ์รันไฟล์  ";c 45 b "$(basename "$target")  ";cn 10 bi "เรียบร้อย" 
}



    
    pack=(
        "git"
        "sshd"
        "tput"
        "curl"
        "micro"
        "which"
        "find"
        "openssl"
    )
    missing_pkgs=()
    
    for p in "${pack[@]}"; do
        if ! command -v "$p" >/dev/null 2>&1; then
            missing_pkgs+=("$p")
        fi
    done
    if [[ -n "${missing_pkgs[@]}" ]]; then
        echo "Missing packages: ${missing_pkgs[*]}"
        for p in "${missing_pkgs[@]}"; do
            echo "no $p"
        done
    fi

