del_cache(){
    sudo apt-get clean
    sudo apt-get autoremove -y
    rm -rf ~/.cache/*
    sudo rm -rf /tmp/*
    echo "Done!"
    echo "Free space: $(df -h / | awk 'NR==2 {print $4}')"
    df -h /
}
alias cc='del_cache'

pgb(){
    if [[ "$#" -gt 0 ]]; then
        g "$@"
    fi
    
    rm -rf "$hpc/ssot/" && cn lg b "removed hpc/ssot " && \
    cp -r "$hwsl/ssot/" "$hpc" && cn 45 b "done copy ssot from wsl to hpc" 
}

alias ssh_ad="$SSOT/bootstrap/script/ssh_audit.sh"

bk_clean(){
		local tar=${1:-}
		local files f 
		files=$(find "$tar" -type f -iname "*bak*" | sort)
		for f in ${files[@]}; do
			echo $f
		done	
}

# รายการ Symlink ทั้งหมดภายใต้การจัดการของ SSOT
SSOT="${SSOT:-$HOME/ssot}"
ssot_link=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.local/bin/joe"
    "$HOME/.local/bin/node-status"
    "$HOME/.local/bin/shared"
    "$HOME/.local/bin/env"
    "$SSOT/.env"
    "$SSOT/.env.secret"
)

link_check(){
    local link_to=""
    for f in "${ssot_link[@]}"; do
        if [[ -L "$f" ]]; then
            link_to=$(readlink "$f" 2>/dev/null)
            if [[ -e "$f" ]]; then
                cn 250 b "$f -> $(cn lg "" "$link_to")"
            else
                cn 1 b "$f -> $(cn 1 "" "$link_to [BROKEN]")"
            fi
        elif [[ -e "$f" ]]; then
            cn 214 b "$f not a symlink (regular file)"
        else
            cn 240 b "$f not found"
        fi
    done
}

link_(){
    case "$1" in
        -r|relink)
            # ตรวจสอบความพร้อมของ Base Environment
            local ssot_dir="${SSOT:-$HOME/ssot}"
            local node_host="${NODE_HOST:-$(echo "${JOE_ENV:-wsl2}" | tr '[:upper:]' '[:lower:]')}"

            if [[ ! -d "$ssot_dir" ]]; then
                cn 1 b "SSOT directory not found: $ssot_dir"
                return 1
            fi

            # แมปปิ้ง Target (Symlink) -> Source (ไฟล์ต้นทาง) ตามมาตรฐาน SSOT Infrastructure
            local -A links=(
                ["$HOME/.bashrc"]="$ssot_dir/profiles/$node_host/.bashrc"
                ["$HOME/.zshrc"]="$ssot_dir/profiles/$node_host/.zshrc"
                ["$HOME/.local/bin/joe"]="$ssot_dir/joe.sh"
                ["$HOME/.local/bin/node-status"]="$ssot_dir/bootstrap/nodes/node-status.sh"
                ["$HOME/.local/bin/shared"]="$ssot_dir/tools/sync_shared.sh"
                ["$HOME/.local/bin/env"]="$ssot_dir/bootstrap/templates/env"
                ["$ssot_dir/.env"]="$HOME/.env"
                ["$ssot_dir/.env.secret"]="$HOME/.env.secret"
            )

            # 1. Clean State: บังคับลบเฉพาะ Target ที่เป็น Symlink เก่าทิ้งเพื่อเตรียมสร้างใหม่
            for target in "${!links[@]}"; do
                if [[ -L "$target" ]]; then
                    rm -f "$target"
                    cn 250 b "cleaned symlink: $target"
                elif [[ -e "$target" ]]; then
                    cn 214 b "skip non-symlink (preserving file): $target"
                fi
            done

            # 2. ป้องกันกรณีไดเรกทอรีปลายทางยังไม่ถูกสร้าง
            mkdir -p "$HOME/.local/bin"

            # 3. Re-link ใหม่ทั้งหมดจาก Clean State
            for target in "${!links[@]}"; do
                local source="${links[$target]}"
                if [[ -e "$source" ]]; then
                    ln -sf "$source" "$target" && cn lg b "done symlink $source -> $target"
                else
                    cn 1 b "source not found: $source"
                fi
            done
            ;;

        -c|check)
            local directory="$2"
            local file_to=""
            if [[ -z "$directory" || ! -d "$directory" ]]; then
                cn 1 b "Error: Please specify a valid directory. (e.g. link_ check /path/to/dir)"
                return 1
            fi

            local count=0
            while IFS= read -r -d '' f; do
                file_to=$(readlink "$f" 2>/dev/null)
                
                # ตรวจสอบว่า Target ปลายทางมีอยู่จริงหรือไม่
                if [[ -e "$f" ]]; then
                    cn 250 b "$f -> $(cn 45 b "$file_to")"
                else
                    cn 1 b "$f -> $(cn 1 b "$file_to [BROKEN]")"
                fi
                (( count++ ))
            done < <(find "$directory" -maxdepth 1 -type l -print0 2>/dev/null)

            if [[ $count -eq 0 ]]; then
                echo "No links found in $directory"
            else
                echo "Total links: $count"
            fi
            ;;

        -s|--show|-ssot|--ssot)  
            link_check
            ;;

        *) 
            echo "Usage: ${FUNCNAME[0]:-link_} {-r|relink | -c|check <directory> | -s|--show|-ssot|--ssot}"
            ;;
    esac
}