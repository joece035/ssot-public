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
        bsc|bashscripts) repo="bashscripts" ;;
        ssot)            ;;
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
        clone_url="https://github.com/joece035/ssot.git"
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



