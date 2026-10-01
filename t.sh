#!/usr/bin/env bash



link_(){
    case "$1" in
        -r|relink)
            # ตรวจสอบความพร้อมของ Base Environment
            local ssot_dir="${SSOT:-$HOME/ssot}"
            local node_host="${NODE_HOST:-$(echo "${JOE_ENV:-wsl2}" | tr '[:upper:]' '[:lower:]')}"

            if [[ ! -d "$ssot_dir" ]]; then
                echo "SSOT directory not found: $ssot_dir"
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
                local target_path="${target/#$HOME/\~}"
                if [[ -L "$target" ]]; then
                    rm -f "$target"
                    echo "cleaned symlink: $target_path"
                elif [[ -e "$target" ]]; then
                    echo "skip non-symlink (preserving file): $target_path"
                fi
            done

            # 2. ป้องกันกรณีไดเรกทอรีปลายทางยังไม่ถูกสร้าง
            mkdir -p "$HOME/.local/bin"

            # 3. Re-link ใหม่ทั้งหมดจาก Clean State
            for target in "${!links[@]}"; do
                local source="${links[$target]}"
                local source_path="${source/#$HOME/\~}"
                if [[ -e "$source" ]]; then
                    ln -sf "$source" "$target" && echo "done symlink $source_path -> ${target/#$HOME/\~}"
                else
                    echo "source not found: $source_path"
                fi
            done
            ;;

        -c|check)
            local directory="$2"
            local file_to=""
            if [[ -z "$directory" || ! -d "$directory" ]]; then
                echo "Error: Please specify a valid directory. (e.g. link_ check /path/to/dir)"
                return 1
            fi

            local count=0
            while IFS= read -r -d '' f; do
                file_to=$(readlink "$f" 2>/dev/null)
                
                # ตรวจสอบว่า Target ปลายทางมีอยู่จริงหรือไม่
                if [[ -e "$f" ]]; then
                   echo "${f/#$HOME/\~} -> ${file_to/#$HOME/\~}"
                else
                   echo "${f/#$HOME/\~} -> ${file_to/#$HOME/\~} [BROKEN]"
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

