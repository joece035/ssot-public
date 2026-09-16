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
ssot_link=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.local/bin/joe"
    "$HOME/.local/bin/node-status"
    "$HOME/.local/bin/shared"
    "$HOME/.local/bin/env"
    "$HOME/.env"

)

link_check(){
    local link_to
    for f in "${ssot_link[@]}"; do
        if [[ -L "$f" ]]; then
            
            link_to=$(readlink "$f")
            if [[ -e "$f" ]]; then
                cn 250 b "$f -> $(cn lg "" "$link_to")"
            else
                cn 1 b "$f -> $(cn 1 "" "$link_to [BROKEN]")"
            fi
        else
            cn 1 b "$f not a symlink"
        fi
    done
}

link_(){
    case "$1" in
        -r|relink)
            # ตรวจสอบความพร้อมของ Base Environment
            if [[ -z "${SSOT:-}" || -z "${NODE_HOST:-}" ]]; then
                cn 1 b "SSOT or NODE_HOST variable is not defined"
                return 1
            fi

            # แมปปิ้ง Target -> Source ตามมาตรฐาน SSOT Infrastructure
            local -A links=(
                ["$HOME/.bashrc"]="$SSOT/profiles/$NODE_HOST/.bashrc"
                ["$HOME/.zshrc"]="$SSOT/profiles/$NODE_HOST/.zshrc"
                ["$HOME/.local/bin/joe"]="$SSOT/joe.sh"
                ["$HOME/.local/bin/node-status"]="$SSOT/bootstrap/nodes/node-status.sh"
                ["$HOME/.local/bin/shared"]="$SSOT/tools/sync_shared.sh"
                ["$HOME/.local/bin/env"]="$SSOT/bootstrap/templates/env"
                ["$HOME/.env"]="$SSOT/.env"
            )

            # 1. Clean State: บังคับลบ Target เก่าทิ้งทั้งหมดแบบ Unconditional (ลบเพื่อทำใหม่ ไม่สนสถานะเดิม)
            for target in "${!links[@]}"; do
                rm -rf "$target"
                cn 250 b "cleaned: $target"
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
            local file_to
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
            echo "Usage: ${FUNCNAME[0]} {-r|relink | -c|check <directory> | -s|--show|-ssot|--ssot}"
            ;;
    esac
}