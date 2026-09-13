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


