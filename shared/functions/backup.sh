# ============================================================
# bkp — Backup files / folders into $BACKUP_DIR (timestamped)
# ============================================================
# Usage:
#   bkp <file-or-folder> [more ...]
#   bkp ~/projects/important.txt
#   bkp /etc/nginx /var/log/app
# Features:
#   - Creates $BACKUP_DIR/<basename>_YYYYMMDD_HHMMSS/ (folder)
#                $BACKUP_DIR/<basename>_YYYYMMDD_HHMMSS.ext (single file)
#   - Multiple targets → each gets its own timestamp slot
#   - No overwrite: timestamp prevents collision
#   - $BACKUP_DIR comes from 00-env.sh (override with: export BACKUP_DIR=...)
# ============================================================
bkp() {
    : "${BACKUP_DIR:=$HOME/backups}"
    mkdir -p "$BACKUP_DIR" || { echo "❌ bkp: cannot create $BACKUP_DIR" >&2; return 1; }

    if [[ $# -eq 0 ]]; then
        echo "Usage: bkp <file-or-folder> [more ...]" >&2
        echo "       (uses \$BACKUP_DIR = $BACKUP_DIR)" >&2
        return 1
    fi

    local ts
    ts="$(date +%Y%m%d_%H%M%S)"

    local target
    for target in "$@"; do
        if [[ ! -e "$target" ]]; then
            echo "❌ bkp: not found → $target" >&2
            continue
        fi

        local base
        base="$(basename -- "$target")"

        if [[ -d "$target" ]]; then
            local dest="$BACKUP_DIR/${base}_${ts}"
            if cp -r "$target" "$dest"; then
                echo "✅ folder  $target  →  $dest"
            else
                echo "❌ bkp: failed → $target" >&2
            fi
        else
            # File: keep original name + append _ts (restore = strip _ts)
            # Same shape as bkpl produces for .tar.gz, and bkpi uses for snapshots
            local dest="$BACKUP_DIR/${base}_${ts}"
            if cp -p "$target" "$dest"; then
                echo "✅ file    $target  →  $dest"
            else
                echo "❌ bkp: failed → $target" >&2
            fi
        fi
    done
}


# ============================================================
# bkpi — Incremental backup (rsync-style, hardlink-friendly)
# ============================================================
# Usage:
#   bkpi <source-folder>
# Behavior:
#   Creates $BACKUP_DIR/<basename>/<timestamp>/ with the contents.
#   - If `rsync` is available → uses --link-dest for space-efficient snapshots
#   - Otherwise → falls back to cp -r
# ============================================================
bkpi() {
    : "${BACKUP_DIR:=$HOME/backups}"

    if [[ $# -eq 0 ]]; then
        echo "Usage: bkpi <source-folder> [more ...]" >&2
        return 1
    fi

    local src
    for src in "$@"; do
        if [[ ! -d "$src" ]]; then
            echo "❌ bkpi: not a folder → $src" >&2
            continue
        fi

        local base ts target
        base="$(basename -- "$src")"
        ts="$(date +%Y%m%d_%H%M%S)"
        target="$BACKUP_DIR/${base}/${ts}"

        if command -v rsync >/dev/null 2>&1; then
            local latest=""
            [[ -d "$BACKUP_DIR/$base" ]] && latest="$(ls -1 "$BACKUP_DIR/$base" 2>/dev/null | sort | tail -1)"
            local link_dest=""
            [[ -n "$latest" ]] && link_dest="--link-dest=$BACKUP_DIR/$base/$latest"

            # rsync needs parent dir to exist
            mkdir -p "$target"
            if rsync -a --delete $link_dest "$src/" "$target/"; then
                echo "✅ incremental  $src  →  $target  (base: $latest)"
            else
                echo "❌ bkpi: rsync failed → $src" >&2
            fi
        else
            mkdir -p "$target"
            if cp -r "$src/." "$target/" 2>/dev/null || cp -r "$src/." "$target/"; then
                echo "✅ snapshot  $src  →  $target  (no rsync, full copy)"
            else
                echo "❌ bkpi: cp failed → $src" >&2
            fi
        fi
    done
}


# ============================================================
# bkpl — Backup + tar.gz compress
# ============================================================
# Usage:
#   bkpl <file-or-folder> [more ...]
# Output: $BACKUP_DIR/<basename>_YYYYMMDD_HHMMSS.tar.gz
# ============================================================
bkpl() {
    : "${BACKUP_DIR:=$HOME/backups}"
    mkdir -p "$BACKUP_DIR" || { echo "❌ bkpl: cannot create $BACKUP_DIR" >&2; return 1; }

    if [[ $# -eq 0 ]]; then
        echo "Usage: bkpl <file-or-folder> [more ...]" >&2
        return 1
    fi

    if ! command -v tar >/dev/null 2>&1; then
        echo "❌ bkpl: tar not found" >&2
        return 1
    fi

    local ts
    ts="$(date +%Y%m%d_%H%M%S)"

    local target
    for target in "$@"; do
        if [[ ! -e "$target" ]]; then
            echo "❌ bkpl: not found → $target" >&2
            continue
        fi

        local base parent
        base="$(basename -- "$target")"
        parent="$(dirname -- "$target")"
        local archive="$BACKUP_DIR/${base}_${ts}.tar.gz"

        if tar -czf "$archive" -C "$parent" "$base" 2>/dev/null; then
            local size
            size="$(du -h "$archive" | cut -f1)"
            echo "✅ compressed  $target  →  $archive  ($size)"
        else
            echo "❌ bkpl: tar failed → $target" >&2
        fi
    done
}


# ============================================================
# bkls — List backups in $BACKUP_DIR (with size + age)
# ============================================================
# Usage:
#   bkls            → all
#   bkls <pattern>  → filter (e.g. bkls "nginx_*")
# ============================================================
bkls() {
    : "${BACKUP_DIR:=$HOME/backups}"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "❌ bkls: \$BACKUP_DIR not found → $BACKUP_DIR" >&2
        return 1
    fi

    local pat="${1:-*}"
    echo "📦 Backups in: $BACKUP_DIR  (filter: $pat)"
    echo "------------------------------------------------------------"

    local found=0
    # Top-level only (avoid recursing into every backup)
    while IFS= read -r -d '' entry; do
        local size age
        size="$(du -sh -- "$entry" 2>/dev/null | cut -f1)"
        age="$(( ( $(date +%s) - $(stat -c %Y -- "$entry" 2>/dev/null || stat -f %m -- "$entry") ) / 60 ))"
        if [[ $age -lt 60 ]]; then
            age="${age}m ago"
        elif [[ $age -lt 1440 ]]; then
            age="$((age / 60))h ago"
        else
            age="$((age / 1440))d ago"
        fi
        # Show relative path under BACKUP_DIR
        local rel="${entry#$BACKUP_DIR/}"
        # For incremental-style (bkpi) paths, show the timestamp too
        printf "  %-12s  %-8s  %s\n" "$age" "$size" "$rel"
        found=1
    done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 \( -name "$pat" -o -path "*/$pat" \) -print0 2>/dev/null)

    [[ $found -eq 0 ]] && echo "  (no matches)"
}


# ============================================================
# bkrm — Remove old backups (keep N most recent per basename)
# ============================================================
# Usage:
#   bkrm <basename-pattern> [keep-count]
#   bkrm nginx_* 5     → keep newest 5
#   bkrm "*" 3         → keep newest 3 of every basename
# ============================================================
bkrm() {
    : "${BACKUP_DIR:=$HOME/backups}"

    local keep="${2:-5}"
    local pat="${1:-*}"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "❌ bkrm: \$BACKUP_DIR not found → $BACKUP_DIR" >&2
        return 1
    fi

    local removed=0
    # Match both files (bkp/bkpl) and directories (bkpi snapshots)
    while IFS= read -r old; do
        rm -rf -- "$old" && {
            echo "🗑️  removed: ${old#$BACKUP_DIR/}"
            ((removed++))
        }
    done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 2 \( -name "$pat" -o -path "*/$pat" \) 2>/dev/null \
             | sort -r \
             | awk -v k="$keep" 'NR>k')

    echo "✅ bkrm: removed $removed item(s), kept newest $keep matching '$pat'"
}


# ============================================================
# backup — Interactive menu (one-stop backup interface)
# ============================================================
# Usage:
#   backup          → interactive menu
#   backup quick    → same as bkp (simple copy)
#   backup comp     → same as bkpl (compressed tar.gz)
#   backup incr     → same as bkpi (incremental rsync)
#   backup list     → same as bkls
#   backup clean    → same as bkrm
# ============================================================
backup() {
    : "${BACKUP_DIR:=$HOME/backups}"

    # ── Quick shortcuts (skip menu) ──
    case "${1:-}" in
        q|quick)  shift; bkp "$@"; return $? ;;
        c|comp)   shift; bkpl "$@"; return $? ;;
        i|incr)   shift; bkpi "$@"; return $? ;;
        l|list)   shift; bkls "$@"; return $? ;;
        rm|clean) shift; bkrm "$@"; return $? ;;
        h|help)
            c 46 b "backup"; cn 255 " — One-stop backup interface"
            cn 255 ""
            cn 255 "Quick commands (skip menu):"
            cn 255 "  backup quick <path..>   — Simple copy backup"
            cn 255 "  backup comp  <path..>   — Compress (tar.gz)"
            cn 255 "  backup incr  <folder>   — Incremental (rsync)"
            cn 255 "  backup list  [pat]      — List backups"
            cn 255 "  backup clean [pat] [n]  — Remove old (keep n)"
            cn 255 ""
            cn 255 "  backup                   — Interactive menu"
            return 0
            ;;
    esac

    # ── Colors (V3 — using _c/_b/_r for inline) ──
    local _H="${_c 46}${_b}"   # header = bright green bold
    local _O="${_c 208}"       # option = orange
    local _G="${_c 252}"       # normal = light gray
    local _Y="${_c 226}"       # highlight = yellow
    local _R="${_r}"           # reset
    local _D="${_d}"           # dim

    # ── Helpers ──
    _bm_line() {
        printf '%s' "$_D"
        printf '%.0s─' {1..50}
        printf '%s\n' "$_R"
    }
    _bm_header() {
        _bm_line
        printf "${_H}  %s${_R}\n" "$1"
        _bm_line
    }
    _bm_info() {
        printf "  ${_Y}%s${_G} %s${_R}\n" "$1" "$2"
    }

    # ── Count existing backups ──
    local _count=0
    [[ -d "$BACKUP_DIR" ]] && _count=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)

    # ── Main loop ──
    while true; do
        echo ""
        _bm_header "📦  BACKUP MENU"
        _bm_info "📁  Backup dir:" "$BACKUP_DIR"
        _bm_info "📊  Stored:"     "$_count item(s)"
        echo ""

        printf "  ${_O}1)${_R}  ${_G}Simple copy backup${_R}     ${_D}— copy files/folders${_R}\n"
        printf "  ${_O}2)${_R}  ${_G}Compress & backup${_R}      ${_D}— tar.gz archive${_R}\n"
        printf "  ${_O}3)${_R}  ${_G}Incremental backup${_R}     ${_D}— rsync snapshots${_R}\n"
        echo ""
        printf "  ${_O}4)${_R}  ${_G}List backups${_R}           ${_D}— view stored backups${_R}\n"
        printf "  ${_O}5)${_R}  ${_G}Remove old backups${_R}     ${_D}— cleanup by pattern${_R}\n"
        printf "  ${_O}6)${_R}  ${_G}Change backup dir${_R}      ${_D}— \$BACKUP_DIR${_R}\n"
        echo ""
        printf "  ${_O}0)${_R}  ${_D}Exit${_R}\n"
        echo ""

        local choice
        read -rp "  Choose [0-6]: " choice
        echo ""

        case "$choice" in
            0)
                cn 252 "  👋 Bye!"
                return 0
                ;;
            1)
                _bm_header "📋  Simple Copy Backup"
                cn 255 "  Enter paths to backup (space-separated):"
                read -rp "  > " _paths
                if [[ -z "$_paths" ]]; then
                    cn 208 "  ⚠  No paths entered"
                    continue
                fi
                # shellcheck disable=SC2086
                bkp $_paths
                ;;
            2)
                _bm_header "🗜️   Compress & Backup (tar.gz)"
                cn 255 "  Enter paths to compress & backup:"
                read -rp "  > " _paths
                if [[ -z "$_paths" ]]; then
                    cn 208 "  ⚠  No paths entered"
                    continue
                fi
                # shellcheck disable=SC2086
                bkpl $_paths
                ;;
            3)
                _bm_header "🔄  Incremental Backup (rsync)"
                cn 255 "  Enter source folder(s) to incrementally sync:"
                read -rp "  > " _paths
                if [[ -z "$_paths" ]]; then
                    cn 208 "  ⚠  No paths entered"
                    continue
                fi
                # shellcheck disable=SC2086
                bkpi $_paths
                ;;
            4)
                _bm_header "📋  Existing Backups"
                cn 255 "  Filter pattern (Enter = all):"
                read -rp "  > " _pat
                if [[ -z "$_pat" ]]; then
                    bkls
                else
                    bkls "$_pat"
                fi
                echo ""
                read -rp "  Press Enter to continue... " _
                ;;
            5)
                _bm_header "🗑️   Remove Old Backups"
                cn 255 "  Pattern to match (e.g. nginx_* or * for all):"
                read -rp "  > " _pat
                if [[ -z "$_pat" ]]; then
                    cn 208 "  ⚠  No pattern entered"
                    continue
                fi
                cn 255 "  How many to keep (newest)? [default: 5]:"
                read -rp "  > " _keep
                _keep="${_keep:-5}"
                echo ""
                # Confirm
                cn 255 "  ${_Y}⚠  This will remove backups matching '$_pat' (keep $_keep newest)${_R}"
                read -rp "  Confirm? [y/N]: " _confirm
                if [[ "$_confirm" =~ ^[Yy]$ ]]; then
                    bkrm "$_pat" "$_keep"
                else
                    cn 252 "  Cancelled."
                fi
                ;;
            6)
                _bm_header "📁  Change Backup Directory"
                cn 255 "  Current: ${_Y}$BACKUP_DIR${_R}"
                cn 255 "  New path (Enter = keep current):"
                read -rp "  > " _newdir
                if [[ -n "$_newdir" ]]; then
                    mkdir -p "$_newdir" 2>/dev/null
                    if [[ -d "$_newdir" ]]; then
                        export BACKUP_DIR="$_newdir"
                        cn 252 "  ✅  Backup dir changed to: $_newdir"
                    else
                        cn 196 "  ❌  Cannot create: $_newdir"
                    fi
                fi
                ;;
            *)
                cn 208 "  ⚠  Invalid option: $choice"
                ;;
        esac

        # Refresh count
        _count=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    done
}
