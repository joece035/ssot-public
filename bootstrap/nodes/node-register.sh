#!/usr/bin/env bash
# ============================================================
# 🌐 Node Auto-Registration — SSH Device Identity Only
# ============================================================
# File: tools/node-register.sh
# Purpose: Auto-register this device's SSH identity into SSOT
#
# What it does:
#   1. Detects device identity (MY_DEVICE, JOE_ENV, hostname)
#   2. Creates nodes/<name>.node.env with SSH fields only
#   3. Updates MY_DEVICE in ~/.env
#
# Usage:
#   bash bootstrap/nodes/node-register.sh              # auto-detect & register
#   bash bootstrap/nodes/node-register.sh --auto        # non-interactive (used by install.sh)
#   bash bootstrap/nodes/node-register.sh --auto <name> # register with custom name
#   bash bootstrap/nodes/node-register.sh --dry-run    # show what would happen
#   node-register --auto <name>                         # post-install shortcut (~/.local/bin)
# ============================================================

set -euo pipefail 2>/dev/null || true

# ── 1. Resolve SSOT Root ──
_SSOT_ROOT="${SSOT:-$HOME/ssot}"
if [[ ! -d "$_SSOT_ROOT" ]]; then
    _SSOT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export SSOT="$_SSOT_ROOT"

# ── 2. Load Color Engine ──
if [[ -f "$SSOT/core/01-colors.sh" ]]; then
    source "$SSOT/core/01-colors.sh"
fi

if ! declare -f cn >/dev/null 2>&1; then
    cn() { local col="${1:-}" style="${2:-}"; shift 2 2>/dev/null || shift $#; echo "$*"; }
    c()  { local col="${1:-}" style="${2:-}"; shift 2 2>/dev/null || shift $#; printf "%s" "$*"; }
fi

# ── 3. Parse Arguments ──
DRY_RUN=false
CUSTOM_NAME=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help|-h) echo "Usage: $(basename "$0") [--dry-run] [name]"; exit 0 ;;
        --auto) ;; # default, skip
        *) CUSTOM_NAME="$arg" ;;
    esac
done

# ── 4b. Node registry dir (canonical: bootstrap/nodes/) ──
_nodes_dir() {
    if [[ -d "$SSOT/bootstrap/nodes" ]]; then
        echo "$SSOT/bootstrap/nodes"
    else
        echo "$SSOT/nodes"
    fi
}

# ── 4c. Banner ──
_banner() {
    echo ""
    c 39 b "╔══════════════════════════════════════════════════════════╗" && echo ""
    c 39 b "║   🌐  Node Auto-Registration (SSH)                      ║" && echo ""
    c 39 b "╚══════════════════════════════════════════════════════════╝" && echo ""
    echo ""
}

# ── 5. Detect Device Identity ──
_detect_identity() {
    local device_name="${MY_DEVICE:-}"
    local joe_env="${JOE_ENV:-}"

    # Auto-detect JOE_ENV if not set (mirrors _check_JOE_ENV order)
    if [[ -z "$joe_env" ]]; then
        if [[ -d "/data/data/com.termux" ]]; then
            if [[ -n "${MUMU_DEVICE:-}" ]] || [[ "$(getprop ro.product.model 2>/dev/null)" =~ (MuMu|vphone) ]]; then
                joe_env="MUMU"
            else
                joe_env="TERMUX"
            fi
        # ACODEX: must check before WSL — ACODEX runs on WSL filesystem
        elif command -v apk >/dev/null 2>&1; then
            joe_env="ACODEX"
        elif grep -qi microsoft /proc/version 2>/dev/null; then
            if [[ $(id -un 2>/dev/null) == "joez" ]]; then
                joe_env="WSL2"
            else
                joe_env="WSL"
            fi
        elif [[ -n "${MSYSTEM:-}" ]] || [[ "$OSTYPE" == "msys" ]]; then
            joe_env="GIT-BASH"
        else
            joe_env="LINUX"
        fi
    fi

    # Auto-detect device name if not set
    # NOTE: OPPO is never auto-detected (Termux dir matches first) —
    # pass it explicitly: node-register --auto oppo
    if [[ -z "$device_name" ]]; then
        case "$joe_env" in
            TERMUX)   device_name="termux" ;;
            MUMU)     device_name="mumu" ;;
            OPPO)     device_name="oppo" ;;
            WSL)      device_name="wsl" ;;
            WSL2)     device_name="wsl2" ;;
            ACODEX)   device_name="acodex" ;;
            GIT-BASH) device_name="git-bash" ;;
            *)        device_name="$(hostname 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "$joe_env" | tr '[:upper:]' '[:lower:]')" ;;
        esac
    fi

    echo "$device_name"
}

# ── 6. Detect SSH Details ──
_next_st_port() {
    local dir="$1" max=8387 p
    for f in "$dir"/*.node.env; do
        [[ -f "$f" ]] || continue
        p="$(grep -oE 'ST_PORT="[0-9]+"' "$f" 2>/dev/null | head -1 | grep -oE '[0-9]+')"
        if [[ -n "$p" && "$p" -gt "$max" ]]; then
            max="$p"
        fi
    done
    echo $((max + 1))
}

_detect_ssh_port() {
    local joe_env="${1:-}"
    case "$joe_env" in
        TERMUX)   echo "8022" ;;
        MUMU)     echo "8020" ;;
        OPPO)     echo "8023" ;;
        ACODEX)   echo "8021" ;;
        WSL)      echo "2222" ;;
        WSL2)     echo "2223" ;;
        *)        echo "22" ;;
    esac
}

_detect_ssh_user() {
    whoami 2>/dev/null || echo "root"
}

# ── 7. Create .node.env File (full NODE_* schema) ──
_create_node_env() {
    local name="$1"
    local host="$2"
    local user="$3"
    local port="$4"
    local upper
    upper="$(echo "${name}" | tr '[:lower:]' '[:upper:]')"

    local nodes_dir
    nodes_dir="$(_nodes_dir)"
    local node_file="$nodes_dir/${name}.node.env"

    if [[ -f "$node_file" ]]; then
        cn 226 b "⚠️  Already exists: $node_file"
        echo "  Edit manually or delete and rerun."
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        cn 214 b "[DRY RUN] Would create: $node_file"
        echo "  $name | $host | $user | port $port"
        return 0
    fi

    # Syncthing fields: ST_PORT auto-assigns max(existing)+1; ST_KEY comes
    # from ~/.env (vault), ST_ID is filled on first syncthing run / by hub.
    local st_port
    st_port="$(_next_st_port "$nodes_dir")"

    cat > "$node_file" << EOF
# --- Node Profile: ${name} (auto-registered $(date +%Y-%m-%d)) ---
export NODE_${upper}_HOST="${host}"
export NODE_${upper}_USER="${user}"
export NODE_${upper}_PORT="\${NODE_${upper}_PORT:-${port}}"
export NODE_${upper}_ST_PORT="${st_port}"
export NODE_${upper}_ST_KEY="\${NODE_${upper}_ST_KEY:-}"
export NODE_${upper}_ST_ID="\${NODE_${upper}_ST_ID:-}"
export NODE_${upper}_ST_URL="http://\${NODE_${upper}_HOST}:\${NODE_${upper}_ST_PORT}"
EOF

    cn 82 b "✅ Created: $node_file"
    echo "  Host: $host | User: $user | Port: $port | ST port: $st_port"
}

# ── 8. Update MY_DEVICE in ~/.env ──
_update_my_device() {
    local device_name="$1"
    local env_file="$HOME/.env"

    if [[ "$DRY_RUN" == "true" ]]; then
        cn 214 b "[DRY RUN] Would set MY_DEVICE=$device_name"
        return 0
    fi

    if grep -q "^export MY_DEVICE=" "$env_file" 2>/dev/null; then
        local current
        current=$(grep "^export MY_DEVICE=" "$env_file" | head -1 | sed 's/^export MY_DEVICE="//;s/"$//')
        if [[ "$current" == "$device_name" ]]; then
            cn 82 b "✅ MY_DEVICE already '$device_name'"
            return 0
        fi
        sed -i "s/^export MY_DEVICE=.*/export MY_DEVICE=\"$device_name\"/" "$env_file"
        cn 226 b "🔄 MY_DEVICE: $current → $device_name"
    else
        printf '\nexport MY_DEVICE="%s"\n' "$device_name" >> "$env_file"
        cn 82 b "✅ MY_DEVICE=$device_name"
    fi
}

# ── 9. Main ──
main() {
    _banner

    # Detect identity
    local device_name
    if [[ -n "$CUSTOM_NAME" ]]; then
        device_name="$CUSTOM_NAME"
    else
        device_name="$(_detect_identity)"
    fi
    cn 226 b "📱 Device: $device_name"

    # Update MY_DEVICE
    echo ""
    _update_my_device "$device_name"

    # Create node file if new
    local nodes_dir node_file
    nodes_dir="$(_nodes_dir)"
    node_file="$nodes_dir/${device_name}.node.env"
    if [[ -f "$node_file" ]]; then
        cn 82 b "✅ Node profile exists: $node_file"
    else
        echo ""
        cn 226 b "🆕 Creating SSH node profile..."
        local host="$device_name"
        local user port
        user="$(_detect_ssh_user)"
        port="$(_detect_ssh_port "${JOE_ENV:-}")"
        _create_node_env "$device_name" "$host" "$user" "$port"
        source "$node_file"
    fi

    # Summary
    echo ""
    cn 39 b "═══════════════════════════════════════════════════════════"
    cn 82 b "  ✅ Node registered: $device_name"
    echo ""
    echo "  Registered nodes:"
    local _nd
    _nd="$(_nodes_dir)"
    if [[ -d "$_nd" ]]; then
        for f in "$_nd"/*.node.env; do
            [[ -f "$f" ]] || continue
            local n="${f##*/}"
            n="${n%.node.env}"
            if [[ "$n" == "$device_name" ]]; then
                echo "    $(c 82 b "→ $n") (this device)"
            else
                echo "      $n"
            fi
        done
    fi
    echo ""
    cn 39 b "═══════════════════════════════════════════════════════════"
    echo ""
}

main
