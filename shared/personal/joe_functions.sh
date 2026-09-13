#!/usr/bin/env bash
# ------------------------------------------------------------
# File: joe_functions.sh
# ------------------------------------------------------------
g() {
    local repo="${SSOT:-$HOME/bashscripts}"
    [[ -d "$repo" ]] || { cn 196 b "✗ repo not found: $repo"; return 1; }
    cd "$repo" || return 1

    # ถ้าไม่มี args → commit+push (ถ้ามี change) หรือ push only
    if (( $# == 0 )); then
        if ! git diff --quiet HEAD 2>/dev/null || [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
            c 11 b "? Working tree dirty — commit with $(c 220 b 'date')? [y/N] "
            local ans; read -r ans
            [[ "$ans" =~ ^[Yy]$ ]] || { cn 220 b "→ cancelled"; return 0; }
            git add -A && git commit -m "$(date '+%Y-%m-%d %H:%M:%S')"
        fi
        git_ push
        return $?
    elif (( $# == 1 )); then
        git_ all "$1"
    else
    # มี args → ส่งต่อไป git_ (ซึ่งรู้จัก s/c/a/all/push/pull ฯลฯ)
         git_ "$@"       
    fi

 
}

repository_remote_url(){
    case $1 in
           url)
            git config --get remote.origin.url
            ;;
        status)
            git status
            ;;
        bsc)  
            cd ~/bashscripts && git remote set-url origin git@github.com:joece035/bashscripts-public.git
            ;;
        ssot)
            cd ~/ssot && git remote set-url origin git@github.com:joece035/ssot-public.git
            ;;
        *)
            git remote -v

            ;;
    esac
}
alias gremote='repository_remote_url'



