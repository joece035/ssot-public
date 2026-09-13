#!/usr/bin/env bash
# ============================================================
# sync_shared.sh — SSOT ↔ Bashscripts Shared Files Synchronizer
# ============================================================
# Synchronizes shared libraries (.bash_helper, .bash_checker, etc.)
# between ~/ssot and ~/bashscripts to prevent version drift.
# Supports recursive synchronization of subfolders within shared/.
#
# Usage:
#   sync_shared.sh status       # Show status & hash match for all shared files
#   sync_shared.sh diff [file]  # Show diff between ssot and bashscripts
#   sync_shared.sh push         # Sync active SSOT -> sibling repo
#   sync_shared.sh pull         # Sync sibling repo -> active SSOT
#   sync_shared.sh auto         # Auto-sync (newer timestamp wins, with backup)
#   sync_shared.sh check        # Silent exit code 0=in-sync, 1=drift
# ============================================================

# ── 1. Determine Repositories ──
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_THIS_REPO="$(cd "$_SCRIPT_DIR/.." 2>/dev/null && pwd)"
_PARENT_DIR="$(cd "$_THIS_REPO/.." 2>/dev/null && pwd)"

_find_repo() {
    local name="$1"
    # 1. Sibling directory relative to this script
    if [[ -d "$_PARENT_DIR/$name" ]]; then
        echo "$_PARENT_DIR/$name"
    # 2. Active SSOT environment variable
    elif [[ -n "${SSOT:-}" && -d "${SSOT}" && "${SSOT##*/}" == "$name" ]]; then
        echo "$SSOT"
    # 3. User HOME directory
    elif [[ -d "$HOME/$name" ]]; then
        echo "$HOME/$name"
    elif [[ -d "/mnt/c/Users/User/$name" ]]; then
        echo "/mnt/c/Users/User/$name"
    elif [[ -d "C:/Users/User/$name" ]]; then
        echo "C:/Users/User/$name"
    else
        echo "$HOME/$name"
    fi
}

_SSOT_PRIMARY="$(_find_repo ssot)"
_BS_PRIMARY="$(_find_repo bashscripts)"

_REPO_A="$_SSOT_PRIMARY"
_REPO_B="$_BS_PRIMARY"

if [[ "${SSOT:-}" == "$_BS_PRIMARY" ]]; then
    _ACTIVE_REPO="$_BS_PRIMARY"
    _SIBLING_REPO="$_SSOT_PRIMARY"
else
    _ACTIVE_REPO="$_SSOT_PRIMARY"
    _SIBLING_REPO="$_BS_PRIMARY"
fi

# ── 2. Color Support (SSOT style or ANSI fallback) ──
if command -v c >/dev/null 2>&1; then
    _c_green() { c 46 b "$*"; }
    _c_red()   { c 196 b "$*"; }
    _c_yellow(){ c 220 b "$*"; }
    _c_cyan()  { c 45 b "$*"; }
    _c_dim()   { c 245 b "$*"; }
else
    _c_green() { printf "\033[1;32m%s\033[0m" "$*"; }
    _c_red()   { printf "\033[1;31m%s\033[0m" "$*"; }
    _c_yellow(){ printf "\033[1;33m%s\033[0m" "$*"; }
    _c_cyan()  { printf "\033[1;36m%s\033[0m" "$*"; }
    _c_dim()   { printf "\033[2m%s\033[0m" "$*"; }
fi

# ── 3. Hash & Stat Helpers ──
_get_hash() {
    local file="$1"
    if [[ ! -f "$file" ]]; then echo "missing"; return 1; fi
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d" " -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d" " -f1
    elif command -v md5sum >/dev/null 2>&1; then
        md5sum "$file" | cut -d" " -f1
    else
        cksum "$file" | cut -d" " -f1
    fi
}

_get_mtime() {
    local file="$1"
    if [[ ! -f "$file" ]]; then echo 0; return 1; fi
    # Try stat options across Linux / macOS / BSD
    stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || date -r "$file" +%s 2>/dev/null || echo 0
}

# ── 4. Collect List of Shared Files (Recursive) ──
_get_shared_files() {
    local -a files=()
    local -A seen=()

    _scan_dir() {
        local base_dir="$1"
        [[ ! -d "$base_dir" ]] && return 0
        local rel
        while IFS= read -r rel; do
            [[ -z "$rel" ]] && continue
            local fname="${rel##*/}"
            [[ "$fname" == *".bak"* || "$fname" == *~ || "$fname" == ".DS_Store" ]] && continue
            if [[ -z "${seen["$rel"]:-}" ]]; then
                seen["$rel"]=1
                files+=("$rel")
            fi
        done < <(cd "$base_dir" 2>/dev/null && find . -mindepth 1 -type f | sed 's|^\./||' | LC_ALL=C sort)
    }

    _scan_dir "$_SSOT_PRIMARY/shared"
    _scan_dir "$_BS_PRIMARY/shared"

    # Fallback to standard core files if folder was empty
    if [[ ${#files[@]} -eq 0 ]]; then
        files=(".bash_checker" ".bash_helper" ".zsh-bash-compat.sh" "00-env.sh")
    fi

    printf "%s\n" "${files[@]}" | LC_ALL=C sort
}

# ── 5. Subcommands ──

sync_status() {
    echo "$(_c_cyan "=== SSOT Shared Files Synchronization Status ===")"
    echo "$(_c_dim "Repo A (SSOT):        $_SSOT_PRIMARY")"
    echo "$(_c_dim "Repo B (Bashscripts): $_BS_PRIMARY")"
    echo ""

    if [[ ! -d "$_SSOT_PRIMARY" || ! -d "$_BS_PRIMARY" ]]; then
        echo "$(_c_red "Error: One of the repositories does not exist on this machine.")"
        [[ ! -d "$_SSOT_PRIMARY" ]] && echo "  Missing: $_SSOT_PRIMARY"
        [[ ! -d "$_BS_PRIMARY" ]] && echo "  Missing: $_BS_PRIMARY"
        return 1
    fi

    local shared_files=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && shared_files+=("$f")
    done < <(_get_shared_files)

    local drift_count=0

    printf "%-35s %-12s %-12s %-10s %s\n" "FILE" "SSOT HASH" "BS HASH" "STATUS" "ACTION"
    printf "%-35s %-12s %-12s %-10s %s\n" "-----------------------------------" "------------" "------------" "----------" "------"

    for file in "${shared_files[@]}"; do
        local path_a="$_SSOT_PRIMARY/shared/$file"
        local path_b="$_BS_PRIMARY/shared/$file"
        local hash_a="$(_get_hash "$path_a")"
        local hash_b="$(_get_hash "$path_b")"
        local short_a="${hash_a:0:8}"
        local short_b="${hash_b:0:8}"

        local status_str=""
        local note=""

        if [[ ! -f "$path_a" ]]; then
            status_str="$(_c_red "MISSING A")"
            note="Run 'sync-shared pull' or copy from bashscripts"
            drift_count=$((drift_count + 1))
        elif [[ ! -f "$path_b" ]]; then
            status_str="$(_c_red "MISSING B")"
            note="Run 'sync-shared push' to populate bashscripts"
            drift_count=$((drift_count + 1))
        elif [[ "$hash_a" == "$hash_b" ]]; then
            status_str="$(_c_green "MATCH")"
            note="$(_c_dim "In Sync")"
        else
            drift_count=$((drift_count + 1))
            status_str="$(_c_yellow "DRIFT")"
            local mtime_a="$(_get_mtime "$path_a")"
            local mtime_b="$(_get_mtime "$path_b")"
            if (( mtime_a > mtime_b )); then
                note="$(_c_cyan "SSOT is newer") → run 'sync-shared push'"
            elif (( mtime_b > mtime_a )); then
                note="$(_c_yellow "Bashscripts is newer") → run 'sync-shared pull'"
            else
                note="Different hashes, same timestamp"
            fi
        fi

        printf "%-35s %-12s %-12s %-18b %b\n" "$file" "$short_a" "$short_b" "$status_str" "$note"
    done

    echo ""
    if (( drift_count == 0 )); then
        echo "$(_c_green "✓ All shared files are in sync across both repositories.")"
        return 0
    else
        echo "$(_c_yellow "⚠️  Found $drift_count file(s) with drift between ssot and bashscripts.")"
        echo "$(_c_dim "Commands: sync-shared push | sync-shared pull | sync-shared auto | sync-shared diff <file>")"
        return 1
    fi
}

sync_diff() {
    local target="${1:-}"
    local shared_files=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && shared_files+=("$f")
    done < <(_get_shared_files)

    if [[ -z "$target" ]]; then
        echo "$(_c_cyan "Comparing all drifting shared files:")"
        for file in "${shared_files[@]}"; do
            local path_a="$_SSOT_PRIMARY/shared/$file"
            local path_b="$_BS_PRIMARY/shared/$file"
            local hash_a="$(_get_hash "$path_a")"
            local hash_b="$(_get_hash "$path_b")"
            if [[ "$hash_a" != "$hash_b" && -f "$path_a" && -f "$path_b" ]]; then
                echo "──────────────────────────────────────────────"
                echo "$(_c_yellow "Diff for $file: [SSOT (-) vs Bashscripts (+)]")"
                diff -u "$path_a" "$path_b" | head -n 30
            fi
        done
        return 0
    fi

    local matched_file=""
    for file in "${shared_files[@]}"; do
        if [[ "$file" == "$target" || "${file##*/}" == "$target" ]]; then
            matched_file="$file"
            break
        fi
    done
    [[ -z "$matched_file" ]] && matched_file="$target"

    local path_a="$_SSOT_PRIMARY/shared/$matched_file"
    local path_b="$_BS_PRIMARY/shared/$matched_file"
    if [[ ! -f "$path_a" || ! -f "$path_b" ]]; then
        echo "$(_c_red "File '$matched_file' does not exist in both shared folders.")"
        return 1
    fi
    diff -u "$path_a" "$path_b"
}

sync_push() {
    echo "$(_c_cyan "Syncing: SSOT → Bashscripts...")"
    mkdir -p "$_BS_PRIMARY/shared"

    local shared_files=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && shared_files+=("$f")
    done < <(_get_shared_files)
    local copied=0

    for file in "${shared_files[@]}"; do
        local src="$_SSOT_PRIMARY/shared/$file"
        local dst="$_BS_PRIMARY/shared/$file"
        if [[ -f "$src" ]]; then
            mkdir -p "$(dirname "$dst")"
            if [[ -f "$dst" ]]; then
                # Backup if different
                local h_src h_dst
                h_src="$(_get_hash "$src")"
                h_dst="$(_get_hash "$dst")"
                if [[ "$h_src" != "$h_dst" ]]; then
                    cp "$dst" "${dst}.bak.$(date +%s)" 2>/dev/null
                fi
            fi
            cp -p "$src" "$dst" && {
                echo "  $(_c_green "✓") $file"
                copied=$((copied + 1))
            }
        fi
    done
    echo "$(_c_green "Done! Updated $copied file(s) in $_BS_PRIMARY/shared")"
}

sync_pull() {
    echo "$(_c_cyan "Syncing: Bashscripts → SSOT...")"
    mkdir -p "$_SSOT_PRIMARY/shared"

    local shared_files=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && shared_files+=("$f")
    done < <(_get_shared_files)
    local copied=0

    for file in "${shared_files[@]}"; do
        local src="$_BS_PRIMARY/shared/$file"
        local dst="$_SSOT_PRIMARY/shared/$file"
        if [[ -f "$src" ]]; then
            mkdir -p "$(dirname "$dst")"
            if [[ -f "$dst" ]]; then
                local h_src h_dst
                h_src="$(_get_hash "$src")"
                h_dst="$(_get_hash "$dst")"
                if [[ "$h_src" != "$h_dst" ]]; then
                    cp "$dst" "${dst}.bak.$(date +%s)" 2>/dev/null
                fi
            fi
            cp -p "$src" "$dst" && {
                echo "  $(_c_green "✓") $file"
                copied=$((copied + 1))
            }
        fi
    done
    echo "$(_c_green "Done! Updated $copied file(s) in $_SSOT_PRIMARY/shared")"
}

sync_auto() {
    echo "$(_c_cyan "Running auto-sync (newer modification timestamp wins)...")"
    mkdir -p "$_SSOT_PRIMARY/shared" "$_BS_PRIMARY/shared"

    local shared_files=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && shared_files+=("$f")
    done < <(_get_shared_files)
    local synced=0

    for file in "${shared_files[@]}"; do
        local path_a="$_SSOT_PRIMARY/shared/$file"
        local path_b="$_BS_PRIMARY/shared/$file"

        if [[ ! -f "$path_a" && -f "$path_b" ]]; then
            mkdir -p "$(dirname "$path_a")"
            cp -p "$path_b" "$path_a" && echo "  $(_c_green "✓") $file (copied to SSOT)"
            synced=$((synced + 1))
            continue
        fi

        if [[ -f "$path_a" && ! -f "$path_b" ]]; then
            mkdir -p "$(dirname "$path_b")"
            cp -p "$path_a" "$path_b" && echo "  $(_c_green "✓") $file (copied to Bashscripts)"
            synced=$((synced + 1))
            continue
        fi

        local hash_a="$(_get_hash "$path_a")"
        local hash_b="$(_get_hash "$path_b")"

        if [[ "$hash_a" == "$hash_b" ]]; then
            continue
        fi

        local mtime_a="$(_get_mtime "$path_a")"
        local mtime_b="$(_get_mtime "$path_b")"

        if (( mtime_a >= mtime_b )); then
            mkdir -p "$(dirname "$path_b")"
            cp "$path_b" "${path_b}.bak.$(date +%s)" 2>/dev/null
            cp -p "$path_a" "$path_b" && echo "  $(_c_green "✓") $file (SSOT newer → Bashscripts updated)"
            synced=$((synced + 1))
        else
            mkdir -p "$(dirname "$path_a")"
            cp "$path_a" "${path_a}.bak.$(date +%s)" 2>/dev/null
            cp -p "$path_b" "$path_a" && echo "  $(_c_green "✓") $file (Bashscripts newer → SSOT updated)"
            synced=$((synced + 1))
        fi
    done

    if (( synced == 0 )); then
        echo "$(_c_green "✓ Everything is already in sync.")"
    else
        echo "$(_c_green "Auto-sync completed for $synced file(s).")"
    fi
}

sync_check_silent() {
    if [[ ! -d "$_SSOT_PRIMARY/shared" || ! -d "$_BS_PRIMARY/shared" ]]; then
        return 0
    fi
    local shared_files=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && shared_files+=("$f")
    done < <(_get_shared_files)
    for file in "${shared_files[@]}"; do
        local path_a="$_SSOT_PRIMARY/shared/$file"
        local path_b="$_BS_PRIMARY/shared/$file"
        if [[ ! -f "$path_a" || ! -f "$path_b" ]]; then
            return 1
        fi
        local hash_a="$(_get_hash "$path_a")"
        local hash_b="$(_get_hash "$path_b")"
        if [[ "$hash_a" != "$hash_b" ]]; then
            return 1
        fi
    done
    return 0
}

# ── 6. Main Dispatcher ──
case "${1:-status}" in
    status|-s|--status)
        sync_status
        ;;
    diff|-d|--diff)
        shift
        sync_diff "$@"
        ;;
    push)
        sync_push
        ;;
    pull)
        sync_pull
        ;;
    auto)
        sync_auto
        ;;
    check|-c|--check)
        if ! sync_check_silent; then
            echo "$(_c_yellow "⚠️  [SSOT Drift] Shared files out of sync between ssot and bashscripts! Run 'sync-shared' to update.")" >&2
            exit 1
        fi
        exit 0
        ;;
    -h|--help|help)
        echo "Usage: sync-shared [status|diff|push|pull|auto|check]"
        echo "  status  — Show sync status table (default)"
        echo "  diff    — Show diff of drifting files"
        echo "  push    — Sync active SSOT -> Bashscripts"
        echo "  pull    — Sync Bashscripts -> SSOT"
        echo "  auto    — Auto-sync by modification timestamp"
        echo "  check   — Silent check with 1-line warning if drift"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'sync-shared --help' for usage."
        exit 1
        ;;
esac
