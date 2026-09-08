# ============================================================
# AI PROFILE SWITCHER
# ============================================================
# Usage:   pf [mom|joe|1|2]      - switch API key profile
#          pf                    - show current profile + key status
#          stc                   - show full stats dashboard (with live API probe)
#
# SSOT: key lives in ~/ssot/00-env.sh
#   OC_KEY_MOM  - OpenCode Go sub, key แม่ (default, has credits)
#   OC_KEY_JOE  - OpenCode Go sub, key พี่โจ
#   OC_KEY_ZEN  - OpenCode Zen (Claude Sonnet 4.5) - joe only
#
# Default: mom (currently has credits). Pass joe to switch.
# ============================================================
ai_profile() {
    local target="${1:-${profile:-mom}}"

    # Normalize numeric aliases: 1 -> mom, 2 -> joe, main -> mom
    case "$target" in
        1|main) target=mom ;;
        2)      target=joe ;;
    esac

    case "$target" in
        mom)
            export profile=mom
            export email="kfsri2701@gmail.com"
            # Note: use ${VAR:-} (not ${VAR:?err}) to avoid bash 5.x
            # "pop_var_context" bug when sourced during .bashrc boot
            export OPENCODE_GO_API_KEY="${OC_KEY_MOM:-}"
            if [[ -z "$OPENCODE_GO_API_KEY" ]]; then
                printf "%s\n" "$(c 203 b 'x OC_KEY_MOM not set') $(c 244 d '— check 00-env.sh')" >&2
                return 1
            fi
            export OPENCODE_API_KEY="$OPENCODE_GO_API_KEY"
            export OPENCODE_GO_BASE_URL="${OC_BASE_URL:-https://opencode.ai/zen/go/v1}"
            export OPENCODE_ZEN_API_KEY=""  # mom ไม่มี Zen
            ;;

        joe)
            export profile=joe
            export email="absolute.basic@gmail.com"
            export OPENCODE_GO_API_KEY="${OC_KEY_JOE:-}"
            if [[ -z "$OPENCODE_GO_API_KEY" ]]; then
                printf "%s\n" "$(c 203 b 'x OC_KEY_JOE not set') $(c 244 d '— check 00-env.sh')" >&2
                return 1
            fi
            export OPENCODE_API_KEY="$OPENCODE_GO_API_KEY"
            export OPENCODE_GO_BASE_URL="${OC_BASE_URL:-https://opencode.ai/zen/go/v1}"
            export OPENCODE_ZEN_API_KEY="${OC_KEY_ZEN:-}"
            ;;

        *)
            printf "%s %s\n" "$(c 203 b 'x unknown profile:')" "$target" >&2
            printf "  usage: pf [mom|joe]\n" >&2
            return 1
            ;;
    esac

    local current_provider="OPENCODE_GO"  # local - ไม่ pollute global
    local key_len=${#OPENCODE_GO_API_KEY}
    local key_prefix="${OPENCODE_GO_API_KEY:0:8}...${OPENCODE_GO_API_KEY: -4}"

    printf "%s %s  " "$(c 46 b 'ok provider:')" "$current_provider"
    printf "%s %s  " "$(c 87 b 'profile:')" "$profile"
    printf "%s %s (len=%d)\n" "$(c 226 b 'key:')" "$key_prefix" "$key_len"
    printf "%s%s%s\n" "$(c 244 d '  -> type ')" "$(c w b 'cstats')" "$(c 244 d ' for full stats')"
}
pf() {
    ai_profile "$@"
}

# ============================================================
# CURRENT STATS - show full provider/key/model dashboard
# ============================================================
# Usage:   stc
# Live-probes the API (5s timeout) to show key status (active/no credits/etc).
# ============================================================
current_stats() {
    # Normalize alias-stored profile name to canonical (1/2 -> mom/joe)
    local p="$profile"
    case "$p" in
        1)   p=mom ;;
        2)   p=joe ;;
    esac

    local provider="OPENCODE_GO"
    local model_="${MODEL:--}"
    local agent="${PROFILE_NAME:--}"
    local key="${OPENCODE_GO_API_KEY:-}"
    local key_display="(not set)"
    local key_status="WARN EMPTY"

    if [[ -n "$key" ]]; then
        local key_len=${#key}
        key_display="${key:0:8}...${key: -4} (len=$key_len)"

        if [[ -n "$OPENCODE_GO_BASE_URL" ]]; then
            local probe
            probe=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 \
                -X POST "$OPENCODE_GO_BASE_URL/messages" \
                -H "x-api-key: $key" \
                -H "Content-Type: application/json" \
                -H "anthropic-version: 2023-06-01" \
                -d '{"model":"qwen3.7-plus","max_tokens":1,"messages":[{"role":"user","content":"."}]}' 2>/dev/null) || probe="000"
            case "$probe" in
                200) key_status="ok ACTIVE" ;;
                401) key_status="X INVALID / NO CREDITS" ;;
                402) key_status="$$ PAYMENT REQUIRED" ;;
                429) key_status="... RATE LIMITED" ;;
                *)   key_status="? HTTP $probe" ;;
            esac
        else
            key_status="? base URL unset"
        fi
    fi

    ROWS=(
        "💻| Provider         |${provider}|💻"
        "🤖| AI Model         |${model_}|🤖"
        "❤️| Agent Name       |${agent}|❤️"
        "📅| API Key Profile  |${p}|📅"
        "🔑| Key              |${key_display}|🔑"
        "📡| Key Status       |${key_status}|📡"
    )
    dashboard_array "${ROWS[@]}"
}
alias cstats='current_stats'

clear_cache(){
    # Clean system cache
    pkg clean
    rm -rf ~/.cache/* ~/.tmp/*

    # Clean SSH cache
    rm -rf ~/.ssh/known_hosts

    # Clean NPM cache
    npm cache clean --force

    # Clean Composer cache
    composer clear-cache

    # Clean Python cache
    find . -name "__pycache__" -exec rm -rf {} + 2>/dev/null

}

reinstall_pkg(){
    clear
    pkg reinstall $(pkg list-installed | grep -v ok | cut -d/ -f1)
}
alias rpkg="reinstall_pkg"