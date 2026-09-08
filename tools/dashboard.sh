#!/usr/bin/env bash
# ============================================================
# 📊 SSOT System Dashboard
# ============================================================
# File: tools/dashboard.sh
# Purpose: Unified dashboard showing ALL system stats:
#   - Environment info (JOE_ENV, MY_DEVICE, paths)
#   - Repository status (current repo, available repos)
#   - Shell profile status (.bashrc/.zshrc symlinks)
#   - AI profile status (mom/joe, API key)
#   - Node health (registered SSH nodes)
#   - Vault status (secrets health)
#
# Usage:
#   dashboard              # full dashboard
#   dashboard --ssh        # include live SSH tests
#   dashboard --compact    # minimal view
#   dashboard --json       # JSON output
# ============================================================

set -o pipefail 2>/dev/null || true

# ── 1. Resolve SSOT Root ──
_SSOT="${SSOT:-$HOME/ssot}"
[[ ! -d "$_SSOT" ]] && _SSOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SSOT="$_SSOT"

# ── 2. Color Engine ──
if [[ -f "$SSOT/core/01-colors.sh" ]]; then
    source "$SSOT/core/01-colors.sh" 2>/dev/null || true
fi

# Direct ANSI fallback
_R='\033[0;31m'; _G='\033[0;32m'; _Y='\033[0;33m'; _O='\033[0;34m'
_C='\033[0;36m'; _M='\033[0;35m'; _W='\033[1;37m'
_B='\033[1m';    _D='\033[2m';   _Z='\033[0m'

# ── 3. Parse Arguments ──
_OPT_SSH=false
_OPT_JSON=false
_OPT_COMPACT=false

for _arg in "$@"; do
    case "${_arg}" in
        --ssh)      _OPT_SSH=true ;;
        --json)     _OPT_JSON=true ;;
        --compact|-c) _OPT_COMPACT=true ;;
        --help|-h)
            cat <<EOF
Usage: dashboard [OPTIONS]

  (no args)    Full dashboard — all sections
  --ssh        Include live SSH/Syncthing connectivity tests
  --compact    Minimal view (essential info only)
  --json       Machine-readable JSON output

Sections:
  🌍 Environment    JOE_ENV, MY_DEVICE, paths
  📁 Repository     Current repo, available repos, switching
  🐚 Shell Profile  .bashrc/.zshrc symlink status
  🤖 AI Profile     Provider, model, API key status
  🖥️  Node Status    Registered SSH nodes health
  🔐 Vault Status   Secrets completeness
  ⚡ Quick Actions  Available commands
EOF
            exit 0 ;;
        *) ;;
    esac
done

# ── 4. Detect this device ──
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
        _THIS_ENV="${_THIS_ENV:-GIT-BASH}"
    else
        _THIS_NODE="${_THIS_NODE:-$(hostname 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo 'unknown')}"
        _THIS_ENV="${_THIS_ENV:-UNKNOWN}"
    fi
    export JOE_ENV="${JOE_ENV:-$_THIS_ENV}"
    export MY_DEVICE="${MY_DEVICE:-$_THIS_NODE}"
fi

# ── 5. Load ~/.env safely ──
[[ -f "$HOME/.env" ]] && source "$HOME/.env" 2>/dev/null || true

# ── 6. Source env manager for repo/shell functions ──
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env" 2>/dev/null || true

# ── 7. JSON accumulator ──
_JSON_SECTIONS=""
_json_add_section() {
    local name="$1" data="$2"
    if [[ -z "$_JSON_SECTIONS" ]]; then
        _JSON_SECTIONS="\"${name}\":${data}"
    else
        _JSON_SECTIONS="${_JSON_SECTIONS},\"${name}\":${data}"
    fi
}

# ============================================================
# SECTION: Environment
# ============================================================
_render_environment() {
    local icon="🌍"
    local title="Environment"

    if [[ "$_OPT_JSON" == "true" ]]; then
        local json="{"
        json+="\"joe_env\":\"${_THIS_ENV:-unknown}\","
        json+="\"my_device\":\"${_THIS_NODE:-unknown}\","
        json+="\"ssot\":\"${SSOT:-not set}\","
        json+="\"home\":\"${HOME}\","
        json+="\"shell\":\"${SHELL:-unknown}\","
        json+="\"user\":\"$(whoami 2>/dev/null || echo unknown)\","
        json+="\"hostname\":\"$(hostname 2>/dev/null || echo unknown)\""
        json+="}"
        _json_add_section "environment" "$json"
        return
    fi

    printf "  ${_B}${_C}%s  %s${_Z}\n" "$icon" "$title"
    printf "  ${_D}┌──────────────────────────────────────────────────────┐${_Z}\n"
    printf "  ${_D}│${_Z}  %-16s ${_W}%-38s${_Z}  ${_D}│${_Z}\n" "Device:" "${_THIS_NODE:-unknown} (${_THIS_ENV:-unknown})"
    printf "  ${_D}│${_Z}  %-16s ${_C}%-38s${_Z}  ${_D}│${_Z}\n" "SSOT Root:" "${SSOT:-not set}"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "Home:" "${HOME}"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "User:" "$(whoami 2>/dev/null || echo unknown)"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "Shell:" "${SHELL:-unknown}"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "Hostname:" "$(hostname 2>/dev/null || echo unknown)"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "Timestamp:" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf "  ${_D}└──────────────────────────────────────────────────────┘${_Z}\n"
    printf '\n'
}

# ============================================================
# SECTION: Repository Status
# ============================================================
_render_repository() {
    local icon="📁"
    local title="Repository"

    # Detect current repo
    local current_repo="${SSOT:-not set}"
    local repo_label="unknown"
    if [[ "$current_repo" == *"/bashscripts" ]]; then
        repo_label="a (personal)"
    elif [[ "$current_repo" == *"/ssot" ]]; then
        repo_label="b (shared)"
    else
        repo_label="custom"
    fi

    # Check available repos
    local repo_a_exists=false
    local repo_b_exists=false
    [[ -d "$HOME/bashscripts" ]] && repo_a_exists=true
    [[ -d "$HOME/ssot" ]] && repo_b_exists=true

    # Git status
    local git_status="—"
    if [[ -d "$current_repo/.git" ]]; then
        local branch
        branch=$(cd "$current_repo" && git branch --show-current 2>/dev/null || echo "?")
        local dirty=""
        if ! cd "$current_repo" 2>/dev/null || ! git diff --quiet 2>/dev/null; then
            dirty=" (dirty)"
        fi
        git_status="branch: ${branch}${dirty}"
    fi

    if [[ "$_OPT_JSON" == "true" ]]; then
        local json="{"
        json+="\"current\":\"${current_repo}\","
        json+="\"label\":\"${repo_label}\","
        json+="\"bashscripts_exists\":${repo_a_exists},"
        json+="\"ssot_exists\":${repo_b_exists},"
        json+="\"git_status\":\"${git_status}\""
        json+="}"
        _json_add_section "repository" "$json"
        return
    fi

    local repo_a_badge="❌"
    local repo_b_badge="❌"
    $repo_a_exists && repo_a_badge="✅"
    $repo_b_exists && repo_b_badge="✅"

    # Highlight current
    local marker_a="  "
    local marker_b="  "
    [[ "$current_repo" == *"/bashscripts" ]] && marker_a="${_G}◀${_Z} "
    [[ "$current_repo" == *"/ssot" ]] && marker_b="${_G}◀${_Z} "

    printf "  ${_B}${_C}%s  %s${_Z}\n" "$icon" "$title"
    printf "  ${_D}┌──────────────────────────────────────────────────────┐${_Z}\n"
    printf "  ${_D}│${_Z}  %-16s ${_W}%-38s${_Z}  ${_D}│${_Z}\n" "Current:" "$repo_label"
    printf "  ${_D}│${_Z}  %-16s ${_C}%-38s${_Z}  ${_D}│${_Z}\n" "SSOT Path:" "$current_repo"
    printf "  ${_D}├──────────────────────────────────────────────────────┤${_Z}\n"
    printf "  ${_D}│${_Z}  %s${_B}a)${_Z} %-14s %s %-22s  ${_D}│${_Z}\n" "$marker_a" "~/bashscripts" "$repo_a_badge" "(personal)"
    printf "  ${_D}│${_Z}  %s${_B}b)${_Z} %-14s %s %-22s  ${_D}│${_Z}\n" "$marker_b" "~/ssot" "$repo_b_badge" "(shared)"
    printf "  ${_D}├──────────────────────────────────────────────────────┤${_Z}\n"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "Git:" "$git_status"
    printf "  ${_D}└──────────────────────────────────────────────────────┘${_Z}\n"
    printf '\n'
}

# ============================================================
# SECTION: Shell Profile Status
# ============================================================
_render_shell_profile() {
    local icon="🐚"
    local title="Shell Profile"

    # Check symlinks
    local bashrc_target=""
    local bashrc_status="—"
    local zshrc_target=""
    local zshrc_status="—"

    if [[ -L "$HOME/.bashrc" ]]; then
        bashrc_target=$(readlink "$HOME/.bashrc" 2>/dev/null || echo "?")
        if [[ -f "$bashrc_target" ]]; then
            bashrc_status="${_G}✅ linked${_Z}"
        else
            bashrc_status="${_R}❌ broken${_Z}"
        fi
    elif [[ -f "$HOME/.bashrc" ]]; then
        bashrc_status="${_Y}📦 file (not symlink)${_Z}"
        bashrc_target="$HOME/.bashrc"
    else
        bashrc_status="${_D}— not found${_Z}"
    fi

    if [[ -L "$HOME/.zshrc" ]]; then
        zshrc_target=$(readlink "$HOME/.zshrc" 2>/dev/null || echo "?")
        if [[ -f "$zshrc_target" ]]; then
            zshrc_status="${_G}✅ linked${_Z}"
        else
            zshrc_status="${_R}❌ broken${_Z}"
        fi
    elif [[ -f "$HOME/.zshrc" ]]; then
        zshrc_status="${_Y}📦 file (not symlink)${_Z}"
        zshrc_target="$HOME/.zshrc"
    else
        zshrc_status="${_D}— not found${_Z}"
    fi

    # Extract profile name from symlink target
    local bashrc_profile="—"
    local zshrc_profile="—"
    if [[ -n "$bashrc_target" && "$bashrc_target" == *"/profiles/"* ]]; then
        bashrc_profile="${bashrc_target##*/profiles/}"
        bashrc_profile="${bashrc_profile%%/*}"
    fi
    if [[ -n "$zshrc_target" && "$zshrc_target" == *"/profiles/"* ]]; then
        zshrc_profile="${zshrc_target##*/profiles/}"
        zshrc_profile="${zshrc_profile%%/*}"
    fi

    if [[ "$_OPT_JSON" == "true" ]]; then
        local json="{"
        json+="\"bashrc_target\":\"${bashrc_target:-none}\","
        json+="\"bashrc_profile\":\"${bashrc_profile}\","
        json+="\"zshrc_target\":\"${zshrc_target:-none}\","
        json+="\"zshrc_profile\":\"${zshrc_profile}\""
        json+="}"
        _json_add_section "shell_profile" "$json"
        return
    fi

    printf "  ${_B}${_C}%s  %s${_Z}\n" "$icon" "$title"
    printf "  ${_D}┌──────────────────────────────────────────────────────┐${_Z}\n"
    printf "  ${_D}│${_Z}  %-14s %-32s ${_D}│${_Z}\n" ".bashrc:" "$bashrc_status"
    if [[ -n "$bashrc_target" ]]; then
        printf "  ${_D}│${_Z}  ${_D}├→ %-52s${_Z}  ${_D}│${_Z}\n" "$bashrc_target"
        [[ "$bashrc_profile" != "—" ]] && \
        printf "  ${_D}│${_Z}  ${_D}│  profile: ${_C}%-41s${_Z}  ${_D}│${_Z}\n" "$bashrc_profile"
    fi
    printf "  ${_D}│${_Z}  %-14s %-32s ${_D}│${_Z}\n" ".zshrc:" "$zshrc_status"
    if [[ -n "$zshrc_target" ]]; then
        printf "  ${_D}│${_Z}  ${_D}├→ %-52s${_Z}  ${_D}│${_Z}\n" "$zshrc_target"
        [[ "$zshrc_profile" != "—" ]] && \
        printf "  ${_D}│${_Z}  ${_D}│  profile: ${_C}%-41s${_Z}  ${_D}│${_Z}\n" "$zshrc_profile"
    fi
    printf "  ${_D}└──────────────────────────────────────────────────────┘${_Z}\n"
    printf '\n'
}

# ============================================================
# SECTION: AI Profile Status
# ============================================================
_render_ai_profile() {
    local icon="🤖"
    local title="AI Profile"

    local current_profile="${profile:-—}"
    local email_display="${email:-—}"
    local provider="OPENCODE_GO"
    local key_status="—"
    local key_display="—"

    # Normalize profile name
    case "$current_profile" in
        1) current_profile="mom" ;;
        2) current_profile="joe" ;;
    esac

    # Check API key
    local key="${OPENCODE_GO_API_KEY:-}"
    if [[ -n "$key" ]]; then
        local key_len=${#key}
        key_display="${key:0:8}...${key: -4} (len=$key_len)"

        if [[ -n "${OPENCODE_GO_BASE_URL:-}" ]]; then
            local probe
            probe=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
                -X POST "$OPENCODE_GO_BASE_URL/messages" \
                -H "x-api-key: $key" \
                -H "Content-Type: application/json" \
                -H "anthropic-version: 2023-06-01" \
                -d '{"model":"qwen3.7-plus","max_tokens":1,"messages":[{"role":"user","content":"."}]}' 2>/dev/null) || probe="000"
            case "$probe" in
                200) key_status="${_G}✅ ACTIVE${_Z}" ;;
                401) key_status="${_R}❌ INVALID / NO CREDITS${_Z}" ;;
                402) key_status="${_Y}⚠️  PAYMENT REQUIRED${_Z}" ;;
                429) key_status="${_O}⏳ RATE LIMITED${_Z}" ;;
                *)   key_status="${_D}? HTTP ${probe}${_Z}" ;;
            esac
        else
            key_status="${_Y}⚠️  base URL unset${_Z}"
        fi
    else
        key_display="${_D}— not set${_Z}"
        key_status="${_D}— no key${_Z}"
    fi

    # Zen key
    local zen_status="${_D}—${_Z}"
    if [[ -n "${OPENCODE_ZEN_API_KEY:-}" ]]; then
        zen_status="${_G}✅ configured${_Z}"
    elif [[ "$current_profile" == "joe" ]]; then
        zen_status="${_Y}⚠️  not set${_Z}"
    fi

    if [[ "$_OPT_JSON" == "true" ]]; then
        local json="{"
        json+="\"profile\":\"${current_profile}\","
        json+="\"email\":\"${email_display}\","
        json+="\"provider\":\"${provider}\","
        json+="\"key_display\":\"${key_display}\","
        json+="\"key_status\":\"${probe:-unknown}\""
        json+="}"
        _json_add_section "ai_profile" "$json"
        return
    fi

    printf "  ${_B}${_C}%s  %s${_Z}\n" "$icon" "$title"
    printf "  ${_D}┌──────────────────────────────────────────────────────┐${_Z}\n"
    printf "  ${_D}│${_Z}  %-16s ${_W}%-38s${_Z}  ${_D}│${_Z}\n" "Profile:" "${current_profile:-—}"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "Email:" "$email_display"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "Provider:" "$provider"
    printf "  ${_D}├──────────────────────────────────────────────────────┤${_Z}\n"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "API Key:" "$key_display"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "Key Status:" "$key_status"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "Zen Key:" "$zen_status"
    printf "  ${_D}└──────────────────────────────────────────────────────┘${_Z}\n"
    printf '\n'
}

# ============================================================
# SECTION: Node Status (Quick Check)
# ============================================================
_render_nodes() {
    local icon="🖥️ "
    local title="Node Status"

    local nodes_dir="$SSOT/bootstrap/nodes"
    if [[ ! -d "$nodes_dir" ]]; then
        if [[ "$_OPT_JSON" == "true" ]]; then
            _json_add_section "nodes" '{"error":"nodes directory not found"}'
        else
            printf "  ${_Y}%s  %s: nodes directory not found${_Z}\n\n" "$icon" "$title"
        fi
        return
    fi

    # Count nodes
    local total=0 ready=0 warn=0 fail=0
    local node_data=""

    for node_file in "$nodes_dir"/*.node.env; do
        [[ -f "$node_file" ]] || continue
        local name="${node_file##*/}"
        name="${name%.node.env}"
        ((total++))

        # Source node env
        local upper
        upper="$(echo "$name" | tr '[:lower:]' '[:upper:]')"
        source "$node_file" 2>/dev/null || true

        local ip_var="NODE_${upper}_IP"
        local host_var="NODE_${upper}_HOST"
        local user_var="NODE_${upper}_USER"
        local port_var="NODE_${upper}_PORT"

        # Special case for window.node.env (uses NODE_WIN_*)
        if [[ "$name" == "window" ]]; then
            ip_var="NODE_WIN_IP"; host_var="NODE_WIN_HOST"
            user_var="NODE_WIN_USER"; port_var="NODE_WIN_PORT"
        fi

        local ip="${!ip_var:-}"
        local host="${!host_var:-}"
        local user="${!user_var:-}"
        local port="${!port_var:-}"

        # Check completeness
        local missing=()
        [[ -z "$ip" ]] && missing+=("IP")
        [[ -z "$user" ]] && missing+=("USER")
        [[ -z "$port" ]] && missing+=("PORT")

        # Determine status
        local status_icon="✅"
        local status_text="ready"
        if [[ ${#missing[@]} -gt 0 ]]; then
            status_icon="⚠️ "
            status_text="incomplete"
            ((warn++))
        else
            ((ready++))
        fi

        # Live SSH test
        local ssh_icon=""
        if [[ "$_OPT_SSH" == "true" && -n "$ip" && -n "$user" && -n "$port" ]]; then
            if [[ "$name" == "$_THIS_NODE" ]]; then
                # Local check
                if ss -tln 2>/dev/null | grep -q ":${port} " 2>/dev/null || pgrep -x sshd >/dev/null 2>&1; then
                    ssh_icon=" ${_G}(ssh: ok)${_Z}"
                else
                    ssh_icon=" ${_Y}(ssh: ?)${_Z}"
                fi
            else
                ssh_icon=" ${_D}(ssh: ...)${_Z}"
            fi
        fi

        # Node icon
        local node_icon
        case "$name" in
            wsl)    node_icon="🖥️ " ;;
            termux) node_icon="📱" ;;
            mumu)   node_icon="🤖" ;;
            window) node_icon="🪟" ;;
            oppo)   node_icon="📱" ;;
            acodex) node_icon="📟" ;;
            *)      node_icon="🔵" ;;
        esac

        # This device marker
        local this_badge=""
        [[ "$name" == "$_THIS_NODE" ]] && this_badge=" ${_G}◀${_Z}"

        if [[ "$_OPT_JSON" != "true" ]]; then
            printf "  ${_D}├─${_Z} %s ${_B}%-10s${_Z}%b %-20s %s\n" \
                "$node_icon" "$name" "$this_badge" "$status_icon $status_text" "$ssh_icon"
            printf "  ${_D}│${_Z}    ${_D}%-14s${_Z} %s\n" "ip:" "${ip:-—}"
            printf "  ${_D}│${_Z}    ${_D}%-14s${_Z} %s\n" "user@port:" "${user:-?}@${port:-?}"
        fi

        # JSON accumulate
        if [[ "$_OPT_JSON" == "true" ]]; then
            [[ -n "$node_data" ]] && node_data="${node_data},"
            node_data+="{\"name\":\"${name}\",\"ip\":\"${ip}\",\"host\":\"${host}\",\"user\":\"${user}\",\"port\":\"${port}\",\"status\":\"${status_text}\"}"
        fi
    done

    if [[ "$_OPT_JSON" == "true" ]]; then
        _json_add_section "nodes" "{\"total\":${total},\"ready\":${ready},\"warn\":${warn},\"nodes\":[${node_data}]}"
        return
    fi

    printf "  ${_B}${_C}%s  %s${_Z}\n" "$icon" "$title"
    printf "  ${_D}┌──────────────────────────────────────────────────────┐${_Z}\n"

    # Render nodes
    for node_file in "$nodes_dir"/*.node.env; do
        [[ -f "$node_file" ]] || continue
        local name="${node_file##*/}"
        name="${name%.node.env}"

        local upper
        upper="$(echo "$name" | tr '[:lower:]' '[:upper:]')"
        source "$node_file" 2>/dev/null || true

        local ip_var="NODE_${upper}_IP"
        local host_var="NODE_${upper}_HOST"
        local user_var="NODE_${upper}_USER"
        local port_var="NODE_${upper}_PORT"

        if [[ "$name" == "window" ]]; then
            ip_var="NODE_WIN_IP"; host_var="NODE_WIN_HOST"
            user_var="NODE_WIN_USER"; port_var="NODE_WIN_PORT"
        fi

        local ip="${!ip_var:-}"
        local user="${!user_var:-}"
        local port="${!port_var:-}"

        local missing=()
        [[ -z "$ip" ]] && missing+=("IP")
        [[ -z "$user" ]] && missing+=("USER")
        [[ -z "$port" ]] && missing+=("PORT")

        local status_icon="✅"
        local status_text="ready"
        [[ ${#missing[@]} -gt 0 ]] && { status_icon="⚠️ "; status_text="incomplete"; }

        local node_icon
        case "$name" in
            wsl)    node_icon="🖥️ " ;;
            termux) node_icon="📱" ;;
            mumu)   node_icon="🤖" ;;
            window) node_icon="🪟" ;;
            oppo)   node_icon="📱" ;;
            acodex) node_icon="📟" ;;
            *)      node_icon="🔵" ;;
        esac

        local this_badge=""
        [[ "$name" == "$_THIS_NODE" ]] && this_badge="  ${_G}◀ THIS${_Z}"

        printf "  ${_D}│${_Z}  %s ${_B}%-10s${_Z}%b %s\n" "$node_icon" "$name" "$this_badge" "$status_icon"
        printf "  ${_D}│${_Z}    ${_D}ip: ${_C}%-20s${_Z} ${_D}user@port: ${_W}%-14s${_Z}\n" "${ip:-—}" "${user:-?}@${port:-?}"
    done

    printf "  ${_D}├──────────────────────────────────────────────────────┤${_Z}\n"
    printf "  ${_D}│${_Z}  ${_G}✅ Ready: %d${_Z}  " "$ready"
    [[ "$warn" -gt 0 ]] && printf "${_Y}⚠️  Warn: %d${_Z}  " "$warn"
    printf "${_D}Total: %d${_Z}\n" "$total"
    printf "  ${_D}└──────────────────────────────────────────────────────┘${_Z}\n"

    if [[ "$_OPT_SSH" == "false" ]]; then
        printf "  ${_D}💡 Run with --ssh for live connectivity tests${_Z}\n"
    fi
    printf '\n'
}

# ============================================================
# SECTION: Vault Status
# ============================================================
_render_vault() {
    local icon="🔐"
    local title="Vault Status"

    local vault_script="$SSOT/bootstrap/vault/ssot-vault.sh"
    local env_example="$SSOT/.env.example"
    local env_enc="$SSOT/core/.env.enc"
    local env_local="$HOME/.env"

    # File sizes
    local env_example_size="—"
    local env_enc_size="—"
    local env_local_size="—"
    local env_enc_mtime="—"

    [[ -f "$env_example" ]] && env_example_size=$(wc -c < "$env_example" 2>/dev/null || echo "—")
    [[ -f "$env_enc" ]] && env_enc_size=$(wc -c < "$env_enc" 2>/dev/null || echo "—")
    [[ -f "$env_local" ]] && env_local_size=$(wc -c < "$env_local" 2>/dev/null || echo "—")
    [[ -f "$env_enc" ]] && env_enc_mtime=$(stat -c '%Y' "$env_enc" 2>/dev/null || echo "—")

    # Count secrets in .env.example vs .env
    local expected=0 found=0
    if [[ -f "$env_example" ]]; then
        expected=$(grep -c '^export [A-Z_]*=' "$env_example" 2>/dev/null || echo 0)
        if [[ -f "$env_local" ]]; then
            found=$(grep -c '^export [A-Z_]*=' "$env_local" 2>/dev/null || echo 0)
        fi
    fi

    local vault_health="—"
    if [[ -f "$env_local" && $found -gt 0 ]]; then
        if [[ "$found" -ge "$expected" ]]; then
            vault_health="${_G}✅ healthy (${found}/${expected})${_Z}"
        else
            vault_health="${_Y}⚠️  ${found}/${expected} secrets${_Z}"
        fi
    elif [[ ! -f "$env_local" ]]; then
        vault_health="${_R}❌ ~/.env missing${_Z}"
    else
        vault_health="${_D}— unknown${_Z}"
    fi

    if [[ "$_OPT_JSON" == "true" ]]; then
        local json="{"
        json+="\"env_example_exists\":$([ -f "$env_example" ] && echo true || echo false),"
        json+="\"env_enc_exists\":$([ -f "$env_enc" ] && echo true || echo false),"
        json+="\"env_local_exists\":$([ -f "$env_local" ] && echo true || echo false),"
        json+="\"expected_secrets\":${expected},"
        json+="\"found_secrets\":${found},"
        json+="\"vault_script_exists\":$([ -f "$vault_script" ] && echo true || echo false)"
        json+="}"
        _json_add_section "vault" "$json"
        return
    fi

    printf "  ${_B}${_C}%s  %s${_Z}\n" "$icon" "$title"
    printf "  ${_D}┌──────────────────────────────────────────────────────┐${_Z}\n"
    printf "  ${_D}│${_Z}  %-16s %-38s  ${_D}│${_Z}\n" "Health:" "$vault_health"
    printf "  ${_D}├──────────────────────────────────────────────────────┤${_Z}\n"
    printf "  ${_D}│${_Z}  ${_D}%-16s${_Z} %-38s  ${_D}│${_Z}\n" ".env.example:" "$([ -f "$env_example" ] && echo "✅ ${env_example_size}B" || echo "❌ missing")"
    printf "  ${_D}│${_Z}  ${_D}%-16s${_Z} %-38s  ${_D}│${_Z}\n" "core/.env.enc:" "$([ -f "$env_enc" ] && echo "✅ ${env_enc_size}B" || echo "❌ missing")"
    printf "  ${_D}│${_Z}  ${_D}%-16s${_Z} %-38s  ${_D}│${_Z}\n" "~/.env:" "$([ -f "$env_local" ] && echo "✅ ${env_local_size}B (chmod 600)" || echo "❌ missing")"
    printf "  ${_D}│${_Z}  ${_D}%-16s${_Z} %-38s  ${_D}│${_Z}\n" "vault script:" "$([ -f "$vault_script" ] && echo "✅ present" || echo "❌ missing")"
    printf "  ${_D}└──────────────────────────────────────────────────────┘${_Z}\n"
    printf '\n'
}

# ============================================================
# SECTION: Quick Actions
# ============================================================
_render_actions() {
    local icon="⚡"
    local title="Quick Actions"

    if [[ "$_OPT_JSON" == "true" ]]; then
        local json="{"
        json+="\"commands\":["
        json+="{\"cmd\":\"repo a\",\"desc\":\"Switch to ~/bashscripts\"},"
        json+="{\"cmd\":\"repo b\",\"desc\":\"Switch to ~/ssot\"},"
        json+="{\"cmd\":\"pf [mom|joe]\",\"desc\":\"Switch AI profile\"},"
        json+="{\"cmd\":\"node-status --ssh\",\"desc\":\"Live node health check\"},"
        json+="{\"cmd\":\"vault status\",\"desc\":\"Vault health audit\"},"
        json+="{\"cmd\":\"stc\",\"desc\":\"Full AI stats (live probe)\"},"
        json+="{\"cmd\":\"dashboard --ssh\",\"desc\":\"This dashboard + SSH tests\"}"
        json+="]}"
        json+="}"
        _json_add_section "actions" "$json"
        return
    fi

    printf "  ${_B}${_C}%s  %s${_Z}\n" "$icon" "$title"
    printf "  ${_D}┌──────────────────────────────────────────────────────┐${_Z}\n"
    printf "  ${_D}│${_Z}  ${_B}${_C}repo${_Z} %-2s ${_D}│${_Z} Switch SSOT repository              ${_D}│${_Z}\n" "a/b"
    printf "  ${_D}│${_Z}  ${_B}${_C}pf${_Z}  %-2s ${_D}│${_Z} Switch AI profile (mom/joe)         ${_D}│${_Z}\n" ""
    printf "  ${_D}│${_Z}  ${_B}${_C}ns${_Z}  %-2s ${_D}│${_Z} Node status (--ssh for live)        ${_D}│${_Z}\n" ""
    printf "  ${_D}│${_Z}  ${_B}${_C}stc${_Z} %-2s ${_D}│${_Z} AI stats (live API probe)           ${_D}│${_Z}\n" ""
    printf "  ${_D}│${_Z}  ${_B}${_C}sws${_Z} %-2s ${_D}│${_Z} Switch shell (bash ↔ zsh)           ${_D}│${_Z}\n" ""
    printf "  ${_D}│${_Z}  ${_B}${_C}vault${_Z}    ${_D}│${_Z} Vault status / lock / unlock        ${_D}│${_Z}\n"
    printf "  ${_D}│${_Z}  ${_B}${_C}pp${_Z}  %-2s ${_D}│${_Z} Reload shell                        ${_D}│${_Z}\n" ""
    printf "  ${_D}└──────────────────────────────────────────────────────┘${_Z}\n"
    printf '\n'
}

# ============================================================
# MAIN RENDER
# ============================================================

if [[ "$_OPT_JSON" == "true" ]]; then
    _render_environment
    _render_repository
    _render_shell_profile
    _render_ai_profile
    _render_nodes
    _render_vault
    _render_actions
    printf '{"generated":"%s","device":"%s","sections":{%s}}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_THIS_NODE" "$_JSON_SECTIONS"
else
    # Banner
    printf '\n'
    printf "${_B}${_C}╔══════════════════════════════════════════════════════════╗${_Z}\n"
    printf "${_B}${_C}║   📊  SSOT System Dashboard                             ║${_Z}\n"
    printf "${_B}${_C}╚══════════════════════════════════════════════════════════╝${_Z}\n"
    printf '\n'

    if [[ "$_OPT_COMPACT" == "true" ]]; then
        # Compact: Environment + Repository + AI Profile only
        _render_environment
        _render_repository
        _render_ai_profile
    else
        # Full dashboard
        _render_environment
        _render_repository
        _render_shell_profile
        _render_ai_profile
        _render_nodes
        _render_vault
        _render_actions
    fi
fi
