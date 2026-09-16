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

link_check(){

    for f in "${ssot_link[@]}"; do
        local link_to=$(readlink $f)
        if [[ -L $f ]]; then
            cn 250 b "$f -> $(cn lg "" "$link_to")"
        else
            cn 1 b "$f not a symlink"
        fi
    done
    
}




link_(){

    case "$1" in
        -r|relink) 
            for f in "${ssot_link[@]}"; do
               if [[ -f "$f" ]]; then
                    rm -f "$f" && cn 250 b "remove $f"
               else
                    cn 1 b "$f not found"
               fi
            done

            ln -sf "$SSOT/profiles/$NODE_HOST/.bashrc" "$HOME/.bashrc" && cn lg b "done symlink $SSOT/profiles/$NODE_HOST/.bashrc -> $HOME/.bashrc"
            ln -sf "$SSOT/profiles/$NODE_HOST/.zshrc" "$HOME/.zshrc" && cn lg b "done symlink $SSOT/profiles/$NODE_HOST/.zshrc -> $HOME/.zshrc"
            ln -sf "$SSOT/joe.sh" "$HOME/.local/bin/joe" && cn lg b "done symlink $SSOT/joe.sh -> $HOME/.local/bin/joe"
            ln -sf "$SSOT/bootstrap/nodes/node-status.sh" "$HOME/.local/bin/node-status" && cn lg b "done symlink $SSOT/bootstrap/nodes/node-status.sh -> $HOME/.local/bin/node-status"
            ln -sf "$SSOT/bootstrap/templates/env" "$HOME/.local/bin/env" && cn lg b "done symlink $SSOT/bootstrap/templates/env -> $HOME/.local/bin/env"
            ln -sf "$SSOT/.env" "$HOME/.env" && cn lg b "done symlink $SSOT/.env -> $HOME/.env"
            ;;
        -c|check)
                local directory="$2"
                local count=0
                for f in $(find "$directory" -maxdepth 1 -type l 2>/dev/null); do   
                    local file_to=$(readlink "$f")
                    if [[ $? -eq 0 ]]; then   
                        cn 250 b "$f -> $(cn 100 b "$file_to")" 
                        (( count++ ))
                    fi
                done
                if [ $count -eq 0 ]; then
                    echo "No links found in $directory"
                else
                    echo "Total links: $count"
                fi
            ;;

        -s|--show|-ssot|--ssot)  
            link_check
            ;;

        *) echo "$0 -r|relink| -c|check <directory> -s|--show|-ssot|--ssot"
            ;;
    esac
}


