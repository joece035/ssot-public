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

reinstall() {
    local repo="${1:-pb}"
    local dep_dir="$HOME/ssot"
    local bk_dir="${BACKUP_DIR:-$HOME/.backup}/ssot_backup"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    # Backup โฟลเดอร์เดิมถ้ามีอยู่
    if [[ -d "${dep_dir}" ]]; then
        mkdir -p "${bk_dir}" &&
        mv "${dep_dir}" "${bk_dir}/ssot_${timestamp}" &&
        cn 5 y "" " done backup to ${bk_dir}/ssot_${timestamp} " && cd "$HOME"
    else    
        cn 5 y " ${dep_dir} not found in HOME " && cd "$HOME"
    fi

    case "$repo" in
        "pv"|"private")
            git clone "git@github.com:joece035/ssot.git" "$dep_dir" &&
            echo "Done cloning BASHSCRIPTS private" &&
            bash "$dep_dir/bootstrap/install.sh" "${2:-}"
        ;;
        "pb"|"public")
            git clone "https://github.com/joece035/ssot-public.git" "$dep_dir" &&
            echo "Done cloning BASHSCRIPTS public" &&
            bash "$dep_dir/bootstrap/install.sh" "${2:-}"
        ;;
        *)    
            cn 5 y " Invalid repo name (use: pb or pv) " 
            return 1
        ;;
    esac

    # Safe call pp if available
    
}

