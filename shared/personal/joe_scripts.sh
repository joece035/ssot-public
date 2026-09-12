#!/usr/bin/env bash
# ------------------------------------------------------------
# File: joe_scripts.sh
# ------------------------------------------------------------


reinstall() {
    local repo="${1:-ssot}"
    local device="${2:-}"
    local bsc_dir="$HOME/bashscripts"
    local ssot_dir="$HOME/ssot"
    local bk_dir="$HOME/.ssot-backups/installationbk"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"

    # ── Validate repo argument ──
    case "$repo" in
        bsc|bashscripts) 
            repo="bashscripts" 
            ;;
        ssot) 
            repo="ssot" 
            ;;
        all|both)   
            reinstall bashscripts "$device"
            reinstall ssot "$device"
            return $?
            ;;
        *)
            echo "Usage: reinstall [ssot|bashscripts|all] [device]"
            echo "  ssot         → reinstall ~/ssot only"
            echo "  bashscripts  → reinstall ~/bashscripts only"
            echo "  all          → reinstall both repos"
            return 1
            ;;
    esac

    # ── Determine which dir to backup (only the one being reinstalled) ──
    local target_dir=""
    local target_name=""
    if [[ "$repo" == "bashscripts" ]]; then
        target_dir="$bsc_dir"
        target_name="bashscripts"
    else
        target_dir="$ssot_dir"
        target_name="ssot"
    fi
    local link_list=("~/.bashrc" "~/.zshrc" "~/.local/bin/joe.sh" "~/.local/bin/env ")

    # ── Remove existing symlinks ──
    for link in "${link_list[@]}"; do
        if [[ -L "$link" ]]; then
            rm -f "$link"
        fi
    done


    # ── Backup if exists ──
    if [[ -d "$target_dir" ]]; then
        mkdir -p "$bk_dir"
        local bak_path="$bk_dir/${target_name}_${timestamp}"
        mv "$target_dir" "$bak_path"
        echo "📦 Backed up: $target_dir → $bak_path"
    fi

    # ── Clone fresh ──
    local clone_url=""
    if [[ "$repo" == "bashscripts" ]]; then
        clone_url="https://github.com/joece035/bashscripts-public.git"
    else
        clone_url="https://github.com/joece035/ssot-public.git"
    fi

    echo "🔄 Cloning $repo → $target_dir"
    if ! git clone --depth=1 "$clone_url" "$target_dir"; then
        echo "❌ git clone failed — restoring backup"
        [[ -d "$bak_path" ]] && mv "$bak_path" "$target_dir"
        return 1
    fi

    # ── Run install.sh ──
    if [[ -f "$target_dir/bootstrap/install.sh" ]]; then
        echo "🚀 Running install.sh..."
        if ! bash "$target_dir/bootstrap/install.sh" $device; then
            echo "⚠️  install.sh had warnings (check output above)"
        fi
    else
        echo "❌ install.sh not found in $target_dir"
        return 1
    fi

    echo "✅ Reinstall complete: $repo"
}


shell_setup(){
    
    local env_=${1:-$JOE_ENV}
    local pf=""

        case "$env_" in
                TERMUX)
                    if [[ ! -f "$HOME/.bashrc" ]]; then
                         pf="${SSOT}/profiles/termux/.bashrc"
                        if [[ -f "$pf" ]]; then
                            ln -s "$pf" "$HOME/.bashrc" && echo "symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"
                        else
                            echo "not found $pf"    
                        fi
                    else 
                        rm -rf $HOME/.bashrc &&
                        pf="${SSOT}/profiles/termux/.bashrc"    
                        ln -sf "$pf" "$HOME/.bashrc" && echo "ลบและสร้าง symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"    
                    fi     
                    if [[ ! -f "$HOME/.zshrc" ]]; then
                         pf="${SSOT}/profiles/termux/.zshrc"
                         if [[ -f "$pf" ]]; then
                             ln -s "$pf" "$HOME/.zshrc" && echo "symlink $pf >>> $HOME/.zshrc done" || echo "FAIL"
                         else
                             echo "not found $pf"
                         fi
                    else 
                        rm -rf $HOME/.zshrc &&
                        pf="${SSOT}/profiles/termux/.zshrc"    
                        ln -sf "$pf" "$HOME/.zshrc" && echo "ลบและสร้าง symlink $pf >>> $HOME/.zshrc done" || echo "FAIL"    
                    fi
                    ;;
                MUMU) 
                    if [[ ! -f "$HOME/.bashrc" ]]; then
                         pf="${SSOT}/profiles/mumu/.bashrc"
                         if [[ -f "$pf" ]]; then
                            ln -s "$pf" "$HOME/.bashrc" && echo "symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"
                         else
                            echo "not found $pf"
                         fi
                    else 
                        rm -rf $HOME/.bashrc &&
                        pf="${SSOT}/profiles/mumu/.bashrc"    
                        ln -sf "$pf" "$HOME/.bashrc" && echo "ลบและสร้าง symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"    
                    fi
                    if [[ ! -f "$HOME/.zshrc" ]]; then
                         pf="${SSOT}/profiles/mumu/.zshrc"
                         if [[ -f "$pf" ]]; then
                             ln -s "$pf" "$HOME/.zshrc" && echo "symlink $pf >>> $HOME/.zshrc done" || echo "FAIL"
                         else
                             echo "not found $pf"
                         fi
                    else 
                        rm -rf $HOME/.zshrc &&
                        pf="${SSOT}/profiles/mumu/.zshrc"    
                        ln -sf "$pf" "$HOME/.zshrc" && echo "ลบและสร้าง symlink $pf >>> $HOME/.zshrc done" || echo "FAIL"    
                    fi
                    ;;
                WSL)
                    if [[ ! -f "$HOME/.bashrc" ]]; then
                         pf="${SSOT}/profiles/wsl/.bashrc"
                         if [[ -f "$pf" ]]; then
                            ln -s "$pf" "$HOME/.bashrc" && echo "symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"
                         else
                            echo "not found $pf"
                         fi
                    else 
                        rm -rf $HOME/.bashrc &&
                        pf="${SSOT}/profiles/wsl/.bashrc"    
                        ln -sf "$pf" "$HOME/.bashrc" && echo "ลบและสร้าง symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"    
                    fi
                    if [[ ! -f "$HOME/.zshrc" ]]; then
                         pf="${SSOT}/profiles/wsl/.zshrc"
                         if [[ -f "$pf" ]]; then
                            ln -s "$pf" "$HOME/.zshrc" && echo "symlink $pf >>> $HOME/.zshrc done" || echo "FAIL"
                         else
                            echo "not found $pf"
                         fi
                    else 
                        rm -rf $HOME/.zshrc &&
                        pf="${SSOT}/profiles/wsl/.zshrc"    
                        ln -sf "$pf" "$HOME/.zshrc" && echo "ลบและสร้าง symlink $pf >>> $HOME/.zshrc done" || echo "FAIL"    
                    fi
                    ;;
                GIT-BASH )
                    if [[ ! -f "$HOME/.bashrc" ]]; then
                         pf="${SSOT}/profiles/git-bash/.bashrc"
                         if [[ -f "$pf" ]]; then
                            ln -sf "$pf" "$HOME/.bashrc" && echo "symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"
                         else
                         
                            echo "not found $pf"
                         fi
                    else 
                        rm -rf $HOME/.bashrc &&
                        ln -sf "$pf" "$HOME/.bashrc" && echo "ลบและสร้าง symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"
                        
                    fi
                    ;;
                OPPO)
                    if [[ ! -f "$HOME/.bashrc" ]]; then
                         pf="${SSOT}/profiles/oppo/.bashrc"
                        if [[ -f "$pf" ]]; then
                            ln -s "$pf" "$HOME/.bashrc" && echo "symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"
                        else
                            echo "not found $pf"    
                        fi
                    else 
                        rm -rf $HOME/.bashrc &&
                        pf="${SSOT}/profiles/oppo/.bashrc"    
                        ln -sf "$pf" "$HOME/.bashrc" && echo "symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"    
                    fi     
                    if [[ ! -f "$HOME/.zshrc" ]]; then
                         pf="${SSOT}/profiles/oppo/.zshrc"
                         if [[ -f "$pf" ]]; then
                             ln -s "$pf" "$HOME/.zshrc" && echo "symlink $pf >>> $HOME/.zshrc done" || echo "FAIL"
                         else
                             echo "not found $pf"
                         fi
                    else 
                        rm -rf $HOME/.zshrc &&
                        pf="${SSOT}/profiles/oppo/.zshrc"    
                        ln -sf "$pf" "$HOME/.zshrc" && echo "symlink $pf >>> $HOME/.zshrc done" || echo "FAIL"    
                    fi
                    ;;
                ACODEX)
                    if [[ ! -f "$HOME/.bashrc" ]]; then
                         pf="${SSOT}/profiles/acodex/.bashrc"
                        if [[ -f "$pf" ]]; then
                            ln -s "$pf" "$HOME/.bashrc" && echo "symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"
                        else
                            echo "not found $pf"    
                        fi
                    else 
                        rm -rf $HOME/.bashrc &&
                        pf="${SSOT}/profiles/acodex/.bashrc"    
                        ln -sf "$pf" "$HOME/.bashrc" && echo "symlink $pf >>> $HOME/.bashrc done" || echo "FAIL"    
                    fi     
                    if [[ ! -f "$HOME/.zshrc" ]]; then
                         pf="${SSOT}/profiles/acodex/.zshrc"
                         if [[ -f "$pf" ]]; then
                             ln -sf "$pf" "$HOME/.zshrc" && echo "symlink $pf >>> $HOME/.zshrc done" || echo "FAIL"
                         else
                             echo "not found $pf"
                         fi
                    else 
                        rm -rf $HOME/.zshrc &&
                        pf="${SSOT}/profiles/acodex/.zshrc"    
                        ln -sf "$pf" "$HOME/.zshrc" && echo "symlink $pf >>> $HOME/.zshrc done" || echo "FAIL"    
                    fi
                    ;;    
                *) echo unknow ;;    
         esac               
}

link_bin() {
    case "$1" in
        -c|--check)
            shift
            local check_dirs=("$@")
            if [[ ${#check_dirs[@]} -eq 0 ]]; then
                check_dirs=("${bin:-$HOME/.local/bin}" "$HOME")
            fi

            for dir in "${check_dirs[@]}"; do
                dir="${dir/#\~/$HOME}"
                if [[ ! -d "$dir" ]]; then
                    echo "⚠️  Directory not found: $dir"
                    continue
                fi

                echo "📁 Symlinks in: $dir"
                local found=0
                while IFS= read -r link; do
                    [[ -z "$link" ]] && continue
                    found=1
                    local base_name target_path status
                    base_name="${link##*/}"
                    target_path="$(readlink "$link" 2>/dev/null)"

                    if [[ -e "$link" ]]; then
                        status="[OK]"
                    else
                        status="[BROKEN]"
                    fi

                    printf "  %-25s → %-45s %s\n" "$base_name" "$target_path" "$status"
                done < <(find "$dir" -maxdepth 1 -type l 2>/dev/null | sort)

                if [[ $found -eq 0 ]]; then
                    echo "  (No symlinks found)"
                fi
                echo ""
            done
            return 0
            ;;

        *)
            [[ $# -ne 1 ]] && echo "Usage: link_bin <src> | link_bin -c [dir...]" && return 1
            local src="${1:?}"
            if [[ -d "$src" ]]; then
                echo "$src is a directory" && return 1
            fi
            local src_name="$(basename "$src")"
            local target_dir="${bin:-$HOME/.local/bin}"
            local target="$target_dir/$src_name"
            if [[ ! -d "$target_dir" ]]; then
                mkdir -p "$target_dir" && echo "Created directory $target_dir" || { echo "Failed to create directory $target_dir" ; return 1 ; }
            fi
            ln -sf "$src" "$target" && 
            if find "$target_dir" -maxdepth 1 -name "$src_name" -type l > /dev/null 2>&1; then
                echo "Symlinked $src >>> $target done" 
            else
                echo "FAIL"
            fi
            ;;
    esac
}

# ============================================================
# sync-shared — SSOT ↔ Bashscripts Shared Files CLI
# ============================================================
sync_shared() {
    local script="${SSOT:-$HOME/ssot}/tools/sync_shared.sh"
    if [[ ! -f "$script" ]]; then
        script="${HOME}/ssot/tools/sync_shared.sh"
    fi
    if [[ ! -f "$script" ]]; then
        script="${HOME}/bashscripts/tools/sync_shared.sh"
    fi

    if [[ -f "$script" ]]; then
        bash "$script" "$@"
    else
        echo "❌ sync_shared.sh not found in tools/" >&2
        return 1
    fi
}
alias sshare='sync_shared'
alias ssync='sync_shared'
