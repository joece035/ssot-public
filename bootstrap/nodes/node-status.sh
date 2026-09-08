#!/usr/bin/env bash
# ============================================================
# 🔍 SSOT Node Status Verifier
# ============================================================
# File: tools/node-status.sh
# Purpose: Verify all registered nodes — identity, connectivity,
#          SSH reachability, Syncthing status
#
# Usage:
#   node-status              # full report (all nodes)
#   node-status --ssh        # include live SSH ping test
#   node-status --json       # JSON output
#   node-status <name>       # single node only
#   node-status --this       # show this device's identity only
# ============================================================

set -o pipefail 2>/dev/null || true

# ── 1. Resolve SSOT Root ──
_SSOT="${SSOT:-$HOME/ssot}"
[[ ! -d "$_SSOT" ]] && _SSOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SSOT="$_SSOT"
NODES_DIR="$SSOT/bootstrap/nodes"

# ── 2. Color Engine ──
if [[ -f "$SSOT/core/01-colors.sh" ]]; then
    source "$SSOT/core/01-colors.sh" 2>/dev/null || true
fi

# Direct ANSI fallback for status indicators
_R='\033[0;31m'; _G='\033[0;32m'; _Y='\033[0;33m'
_C='\033[0;36m'; _B='\033[1m';    _D='\033[2m';   _Z='\033[0m'

# ── 3. Parse Arguments ──
_OPT_SSH=false
_OPT_JSON=false
_OPT_THIS=false
_FILTER=""

for _arg in "$@"; do
    case "${_arg}" in
        --ssh)   _OPT_SSH=true ;;
        --json)  _OPT_JSON=true ;;
        --this)  _OPT_THIS=true ;;
        --help|-h)
            cat <<EOF
Usage: node-status [OPTIONS] [<node_name>]

  (no args)    Full report — all registered nodes
  --ssh        Live SSH + Syncthing connectivity test
  --json       Machine-readable JSON output
  --this       Show only this device identity
  <name>       Filter to a single node (e.g. node-status wsl)

Examples:
  node-status
  node-status --ssh
  node-status termux --ssh
  node-status --json | jq .
EOF
            exit 0 ;;
        -*)  ;;
        *)   _FILTER="${_arg}" ;;
    esac
done

# ── 4. Detect this device before loading .env ──
_THIS_NODE="${MY_DEVICE:-}"
_THIS_ENV="${JOE_ENV:-}"
if [[ -z "$_THIS_NODE" || -z "$_THIS_ENV" ]]; then
    if [[ -d "/data/data/com.termux" ]]; then
        _THIS_NODE="${_THIS_NODE:-termux}"
        _THIS_ENV="${_THIS_ENV:-TERMUX}"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        _THIS_NODE="${_THIS_NODE:-wsl}"
        _THIS_ENV="${_THIS_ENV:-WSL}"
    elif [[ -n "${MSYSTEM:-}" ]]; then
        _THIS_NODE="${_THIS_NODE:-window}"
        _THIS_ENV="${_THIS_ENV:-WINDOW}"
    else
        _THIS_NODE="${_THIS_NODE:-$(hostname 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo 'unknown')}"
        _THIS_ENV="${_THIS_ENV:-UNKNOWN}"
    fi
    export JOE_ENV="${JOE_ENV:-$_THIS_ENV}"
    export MY_DEVICE="${MY_DEVICE:-$_THIS_NODE}"
fi

# ── 5. Load ~/.env safely ──
[[ -f "$HOME/.env" ]] && source "$HOME/.env" 2>/dev/null || true

# ── 6. SSH connectivity test ──
_ssh_check() {
    local ip="$1" port="$2" user="$3"
    [[ -z "$ip" || "$ip" == *"ts.local"* ]] && { echo "no_ip"; return; }
    local id_opts=()
    [[ -f "$HOME/.ssh/id_ed25519_node" ]] && id_opts=(-i "$HOME/.ssh/id_ed25519_node")
    if ssh -o BatchMode=yes \
           -o ConnectTimeout=3 \
           -o StrictHostKeyChecking=no \
           -o LogLevel=ERROR \
           "${id_opts[@]}" \
           -p "$port" \
           "${user}@${ip}" "echo ok" 2>/dev/null | grep -q "ok"; then
        echo "reachable"
    else
        echo "unreachable"
    fi
}

# ── 7. Syncthing REST ping ──
_st_check() {
    local ip="$1" port="$2" key="$3"
    [[ -z "$ip" || -z "$port" ]] && { echo "no_info"; return; }
    command -v curl >/dev/null 2>&1 || { echo "no_curl"; return; }
    local url="http://${ip}:${port}/rest/system/ping"
    local result
    if [[ -n "$key" ]]; then
        result=$(curl -sf --connect-timeout 2 -H "X-API-Key: ${key}" "$url" 2>/dev/null || echo "")
    else
        result=$(curl -sf --connect-timeout 2 "$url" 2>/dev/null || echo "")
    fi
    [[ "$result" == *"pong"* ]] && echo "online" || echo "offline"
}

# ── 8. Get node field via variable indirection ──
_get_node_field() {
    local upper="$1" field="$2"
    local varname="NODE_${upper}_${field}"
    printf '%s' "${!varname:-}"
}

# ── 9. JSON accumulator ──
_JSON_OUT=""
_json_add() {
    local entry
    entry="$(printf '{"name":"%s","ip":"%s","host":"%s","user":"%s","port":"%s","st_port":"%s","st_id":"%s","ssh":"%s","syncthing":"%s","status":"%s"}' \
        "$1" "$2" "$3" "$4" "$5" "$6" "${7:0:7}…" "$8" "$9" "${10}")"
    [[ -z "$_JSON_OUT" ]] && _JSON_OUT="$entry" || _JSON_OUT="${_JSON_OUT},${entry}"
}

# ── 10. Print banner ──
_banner() {
    printf '\n'
    printf "${_B}${_C}╔══════════════════════════════════════════════════════════╗${_Z}\n"
    printf "${_B}${_C}║   🔍  SSOT Node Status Dashboard                        ║${_Z}\n"
    printf "${_B}${_C}╚══════════════════════════════════════════════════════════╝${_Z}\n"
    printf '\n'
    printf "  ${_D}SSOT root : %s${_Z}\n"         "$SSOT"
    printf "  ${_D}This node : ${_B}%s${_Z} ${_D}(%s)${_Z}\n"  "$_THIS_NODE" "$_THIS_ENV"
    printf "  ${_D}Timestamp : %s${_Z}\n"         "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf '\n'
}

# ── 11. Print one node block ──
_print_node() {
    local name="$1"
    local node_file="$NODES_DIR/${name}.node.env"
    local upper
    upper="$(echo "$name" | tr '[:lower:]' '[:upper:]')"

    # Source the node env to resolve variable references
    [[ -f "$node_file" ]] && source "$node_file" 2>/dev/null || true

    # Extract identity fields
    local ip host user port st_port st_key st_id st_url
    ip="$(_get_node_field "$upper" "IP")"
    host="$(_get_node_field "$upper" "HOST")"
    user="$(_get_node_field "$upper" "USER")"
    port="$(_get_node_field "$upper" "PORT")"
    st_port="$(_get_node_field "$upper" "ST_PORT")"
    st_key="$(_get_node_field "$upper" "ST_KEY")"
    st_id="$(_get_node_field "$upper" "ST_ID")"
    st_url="$(_get_node_field "$upper" "ST_URL")"

    # window.node.env uses NODE_WIN_* — special alias
    if [[ "$name" == "window" && -z "$ip" ]]; then
        upper="WIN"
        ip="$(_get_node_field WIN "IP")"
        host="$(_get_node_field WIN "HOST")"
        user="$(_get_node_field WIN "USER")"
        port="$(_get_node_field WIN "PORT")"
        st_port="$(_get_node_field WIN "ST_PORT")"
        st_key="$(_get_node_field WIN "ST_KEY")"
        st_id="$(_get_node_field WIN "ST_ID")"
        st_url="$(_get_node_field WIN "ST_URL")"
    fi

    # Node type icon
    local icon
    case "$name" in
        wsl)    icon="🖥️ " ;;
        termux) icon="📱" ;;
        mumu)   icon="🤖" ;;
        window) icon="🪟" ;;
        oppo)   icon="📱" ;;
        acodex) icon="📟" ;;
        *)      icon="🔵" ;;
    esac

    # Is this device?
    local this_badge=""
    [[ "$name" == "$_THIS_NODE" ]] && this_badge="  ${_G}◀ THIS DEVICE${_Z}"

    # ── Header ──
    printf "${_B}  %s %-14s${_Z}%b\n" "$icon" "$name" "$this_badge"

    if [[ ! -f "$node_file" ]]; then
        printf "  ${_R}  ✗ .node.env not found: %s${_Z}\n\n" "$node_file"
        return
    fi

    # ── Identity ──
    printf "  ${_D}  ┌── Identity ──────────────────────────────────────────${_Z}\n"
    printf "  ${_D}  │${_Z}  %-16s ${_C}%s${_Z}\n"  "IP/Tailscale:" "${ip:-—}"
    printf "  ${_D}  │${_Z}  %-16s %s\n"             "Host alias:"  "${host:-—}"
    printf "  ${_D}  │${_Z}  %-16s %s\n"             "SSH user:"    "${user:-—}"
    printf "  ${_D}  │${_Z}  %-16s %s\n"             "SSH port:"    "${port:-—}"

    # ── Syncthing ──
    if [[ -n "$st_port" || -n "$st_id" ]]; then
        printf "  ${_D}  ├── Syncthing ─────────────────────────────────────────${_Z}\n"
        [[ -n "$st_port" ]] && printf "  ${_D}  │${_Z}  %-16s %s\n" "ST Port:"     "$st_port"
        [[ -n "$st_url"  ]] && printf "  ${_D}  │${_Z}  %-16s ${_D}%s${_Z}\n" "ST URL:" "$st_url"
        if [[ -n "$st_id" ]]; then
            printf "  ${_D}  │${_Z}  %-16s ${_D}%s${_Z}\n" "ST Device ID:" "${st_id:0:27}…"
        fi
        [[ -n "$st_key" ]] && printf "  ${_D}  │${_Z}  %-16s ${_G}✅ configured${_Z}\n" "ST API Key:" \
            || printf "  ${_D}  │${_Z}  %-16s ${_Y}— not set${_Z}\n" "ST API Key:"
    fi

    # ── Config completeness ──
    local missing=()
    [[ -z "$ip"    ]] && missing+=("IP")
    [[ -z "$user"  ]] && missing+=("USER")
    [[ -z "$port"  ]] && missing+=("PORT")
    [[ -z "$st_id" ]] && missing+=("ST_ID")

    printf "  ${_D}  ├── Health ────────────────────────────────────────────${_Z}\n"
    if [[ ${#missing[@]} -eq 0 ]]; then
        printf "  ${_D}  │${_Z}  %-16s ${_G}✅ All fields present${_Z}\n" "Config:"
    else
        printf "  ${_D}  │${_Z}  %-16s ${_Y}⚠️  Missing: %s${_Z}\n" "Config:" "${missing[*]}"
    fi

    # ── This device: pubkey check ──
    if [[ "$name" == "$_THIS_NODE" ]]; then
        local pub="$HOME/.ssh/id_ed25519_node.pub"
        local auth="$HOME/.ssh/authorized_keys"
        if [[ -f "$pub" ]]; then
            local fp
            fp=$(ssh-keygen -lf "$pub" 2>/dev/null | awk '{print $2}' || echo "?")
            printf "  ${_D}  │${_Z}  %-16s ${_G}✅ %s${_Z}\n" "Pubkey:" "$fp"
        else
            printf "  ${_D}  │${_Z}  %-16s ${_Y}⚠️  ~/.ssh/id_ed25519_node.pub missing${_Z}\n" "Pubkey:"
        fi
        local key_count=0
        [[ -f "$auth" ]] && key_count=$(grep -c '^ssh-' "$auth" 2>/dev/null || echo 0)
        printf "  ${_D}  │${_Z}  %-16s %s key(s) in authorized_keys\n" "Trusted keys:" "$key_count"
    fi

    # ── Live SSH test ──
    local ssh_status="skipped" st_status="skipped"
    if [[ "$_OPT_SSH" == "true" ]]; then
        if [[ "$name" == "$_THIS_NODE" ]]; then
            if ss -tln 2>/dev/null | grep -q ":${port:-22} " || pgrep -x sshd >/dev/null 2>&1; then
                ssh_status="reachable"
                printf "  ${_D}  │${_Z}  %-16s ${_G}✅ listening (local)${_Z}\n" "SSH daemon:"
            else
                ssh_status="unreachable"
                printf "  ${_D}  │${_Z}  %-16s ${_R}❌ stopped (local)${_Z}\n" "SSH daemon:"
            fi
        else
            if [[ -n "$ip" && -n "$user" && -n "$port" ]]; then
                printf "  ${_D}  │${_Z}  %-16s ${_D}testing…${_Z}\r" "SSH:"
                ssh_status="$(_ssh_check "$ip" "$port" "$user")"
                case "$ssh_status" in
                    reachable)   printf "  ${_D}  │${_Z}  %-16s ${_G}✅ reachable${_Z}       \n" "SSH:" ;;
                    unreachable) printf "  ${_D}  │${_Z}  %-16s ${_R}❌ unreachable${_Z}\n"       "SSH:" ;;
                    no_ip)       printf "  ${_D}  │${_Z}  %-16s ${_D}— no IP configured${_Z}\n"  "SSH:" ;;
                esac
            else
                printf "  ${_D}  │${_Z}  %-16s ${_D}— missing IP/user/port${_Z}\n" "SSH:"
            fi
        fi

        if [[ -n "$st_port" ]]; then
            local check_ip="$ip"
            [[ "$name" == "$_THIS_NODE" ]] && check_ip="127.0.0.1"
            if [[ -n "$check_ip" ]]; then
                printf "  ${_D}  │${_Z}  %-16s ${_D}testing…${_Z}\r" "Syncthing:"
                st_status="$(_st_check "$check_ip" "$st_port" "$st_key")"
                case "$st_status" in
                    online)   printf "  ${_D}  │${_Z}  %-16s ${_G}✅ online${_Z}          \n" "Syncthing:" ;;
                    offline)  printf "  ${_D}  │${_Z}  %-16s ${_R}❌ offline${_Z}\n"           "Syncthing:" ;;
                    no_curl)  printf "  ${_D}  │${_Z}  %-16s ${_D}— curl not found${_Z}\n"    "Syncthing:" ;;
                    no_info)  printf "  ${_D}  │${_Z}  %-16s ${_D}— no ST info${_Z}\n"        "Syncthing:" ;;
                esac
            fi
        fi
    fi

    # ── Overall status badge ──
    local health="✅ READY" health_col="$_G"
    [[ ${#missing[@]} -gt 0 ]] && { health="⚠️  INCOMPLETE"; health_col="$_Y"; }
    [[ "$ssh_status" == "unreachable" ]] && { health="❌ SSH FAIL"; health_col="$_R"; }

    printf "  ${_D}  └──${_Z}  %-16s ${health_col}${_B}%s${_Z}\n" "Status:" "$health"
    printf '\n'

    # JSON accumulate
    if [[ "$_OPT_JSON" == "true" ]]; then
        _json_add "$name" "$ip" "$host" "$user" "$port" "$st_port" "$st_id" \
            "$ssh_status" "$st_status" "$health"
    fi

    # Export health counters
    case "$health" in
        *READY*)      _COUNT_READY=$((_COUNT_READY + 1)) ;;
        *INCOMPLETE*) _COUNT_WARN=$((_COUNT_WARN + 1)) ;;
        *FAIL*)       _COUNT_FAIL=$((_COUNT_FAIL + 1)) ;;
    esac
}

# ── 12. Summary footer ──
_summary() {
    local total="$1"
    printf "${_B}${_C}════════════════════════════════════════════════════════════${_Z}\n"
    printf "  Nodes scanned : ${_B}%d${_Z}\n"       "$total"
    printf "  ${_G}✅ Ready${_Z}       : %d\n"        "$_COUNT_READY"
    [[ "$_COUNT_WARN" -gt 0 ]] && \
    printf "  ${_Y}⚠️  Incomplete${_Z}  : %d\n"       "$_COUNT_WARN"
    [[ "$_COUNT_FAIL" -gt 0 ]] && \
    printf "  ${_R}❌ SSH Fail${_Z}    : %d\n"        "$_COUNT_FAIL"
    printf '\n'
    if [[ "$_OPT_SSH" == "false" ]]; then
        printf "  ${_D}💡 Run with --ssh for live connectivity tests${_Z}\n"
    fi
    printf "${_B}${_C}════════════════════════════════════════════════════════════${_Z}\n"
    printf '\n'
}

# ── 13. Global counters ──
_COUNT_READY=0; _COUNT_WARN=0; _COUNT_FAIL=0

# ── 14. --this mode ──
if [[ "$_OPT_THIS" == "true" ]]; then
    _banner
    _print_node "$_THIS_NODE"
    exit 0
fi

# ── 15. Scan all node files ──
[[ ! -d "$NODES_DIR" ]] && {
    printf "${_R}ERROR: %s not found${_Z}\n" "$NODES_DIR" >&2; exit 1
}

# Read node names
_all_nodes=()
for _f in "$NODES_DIR"/*.node.env; do
    [[ -f "$_f" ]] || continue
    _n="${_f##*/}"
    _all_nodes+=("${_n%.node.env}")
done

# Filter
_nodes=()
for _n in "${_all_nodes[@]}"; do
    [[ -n "$_FILTER" && "$_n" != "$_FILTER" ]] && continue
    _nodes+=("$_n")
done

[[ ${#_nodes[@]} -eq 0 ]] && {
    printf "${_Y}No nodes found matching '%s'${_Z}\n" "${_FILTER:-*}" >&2; exit 0
}

# ── 16. Output ──
if [[ "$_OPT_JSON" == "false" ]]; then
    _banner
fi

for _n in "${_nodes[@]}"; do
    _print_node "$_n"
done

if [[ "$_OPT_JSON" == "true" ]]; then
    printf '{"generated":"%s","this_node":"%s","nodes":[%s]}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_THIS_NODE" "$_JSON_OUT"
else
    _summary "${#_nodes[@]}"
fi
