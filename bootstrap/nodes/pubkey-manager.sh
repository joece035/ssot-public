#!/usr/bin/env bash
# ============================================================
# 🔑 SSOT Pubkey Manager — SSH Key Distribution via Vault
# ============================================================
# File: tools/pubkey-manager.sh
# Purpose: Manage SSH public keys across mesh nodes using
#          encrypted vault pattern (same as ssot-vault.sh)
#
# Workflow:
#   1. vault lock_pubkey    — collect + encrypt pubkeys → core/pubkeys.enc
#   2. git push             — sync encrypted pubkeys
#   3. vault unlock_pubkey  — decrypt + install to authorized_keys
#
# Rules:
#   - No overwrite if key already exists
#   - Dedup before encrypt
#   - Skip already-installed keys on unlock
#
# Usage:
#   vault lock_pubkey              # encrypt local pubkey
#   vault unlock_pubkey            # decrypt + install
#   vault lock_pubkey --add <key>  # add a specific pubkey
#   vault lock_pubkey --from <host> # fetch pubkey from remote node
#   vault pubkey-status            # show status
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

# ── 3. Paths ──
VAULT_FILE="$SSOT/core/pubkeys.enc"
SSH_DIR="$HOME/.ssh"
LOCAL_KEY="$SSH_DIR/id_ed25519_node.pub"
AUTH_KEYS="$SSH_DIR/authorized_keys"
PBKDF2_ITER=100000

# ── 4. Banner ──
_banner() {
    echo ""
    c 45 b "╔══════════════════════════════════════════════════════════╗" && echo ""
    c 45 b "║   🔑  SSOT Pubkey Manager                               ║" && echo ""
    c 45 b "╚══════════════════════════════════════════════════════════╝" && echo ""
    echo ""
}

# ── 5. Helper: Get passphrase ──
_get_pass() {
    local prompt="${1:-Enter Vault Passphrase: }"
    if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
        echo "$SSOT_VAULT_PASS"
    else
        read -r -s -p "$prompt" pass < /dev/tty
        echo ""
        echo "$pass"
    fi
}

# ── 6. Helper: Check if pubkey already in file ──
_key_exists_in_file() {
    local pubkey_file="$1"
    local target_key="$2"
    [[ ! -f "$pubkey_file" ]] && return 1
    # Extract the comment/label part of the key for comparison
    local target_comment
    target_comment=$(echo "$target_key" | awk '{print $NF}')
    grep -qF "$target_comment" "$pubkey_file" 2>/dev/null
}

# ── 7. Helper: Extract key comment (unique identifier) ──
_key_comment() {
    echo "$1" | awk '{print $NF}'
}

# ── 8. Helper: Fetch pubkey from remote node ──
_fetch_remote_pubkey() {
    local host="$1"
    local user="${2:-}"
    local port="${3:-22}"

    local ssh_opts="-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new"
    [[ -n "$user" ]] && ssh_opts="$ssh_opts -l $user"
    [[ "$port" != "22" ]] && ssh_opts="$ssh_opts -p $port"

    # Try to read remote pubkey
    local remote_key
    remote_key=$(ssh $ssh_opts "$host" "cat ~/.ssh/id_ed25519_node.pub 2>/dev/null" 2>/dev/null || echo "")

    if [[ -n "$remote_key" && "$remote_key" == "ssh-ed25519 "* ]]; then
        echo "$remote_key"
        return 0
    fi

    return 1
}

# ── 9. LOCK PUBKEY — Collect + Encrypt ──
cmd_lock_pubkey() {
    _banner

    # Parse arguments
    local add_key=""
    local fetch_host=""
    local fetch_user=""
    local fetch_port="22"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --add)      add_key="$2"; shift 2 ;;
            --from)     fetch_host="$2"; shift 2 ;;
            --user)     fetch_user="$2"; shift 2 ;;
            --port)     fetch_port="$2"; shift 2 ;;
            --help|-h)
                echo "Usage: $(basename "$0") lock_pubkey [--add <key>] [--from <host>]"
                echo ""
                echo "Options:"
                echo "  --add <key>      Add a specific public key"
                echo "  --from <host>    Fetch pubkey from remote node"
                echo "  --user <user>    SSH user for remote fetch"
                echo "  --port <port>    SSH port for remote fetch"
                echo ""
                echo "Without options: encrypts local ~/.ssh/id_ed25519_node.pub"
                return 0
                ;;
            *) cn 196 b "Unknown option: $1"; return 1 ;;
        esac
    done

    # Create temp file for collecting keys
    local tmp_keys
    tmp_keys="$(mktemp)"
    trap "rm -f '$tmp_keys'" EXIT

    # Load existing keys from vault (if exists and can decrypt)
    if [[ -f "$VAULT_FILE" ]]; then
        cn 226 b "📦 Loading existing vault..."
        local pass
        pass="$(_get_pass "Current Vault Passphrase: ")"
        if echo "$pass" | openssl enc -d -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" \
            -in "$VAULT_FILE" -out "$tmp_keys" -pass stdin 2>/dev/null; then
            local existing_count
            existing_count=$(wc -l < "$tmp_keys" | tr -d ' ')
            cn 82 b "  ✅ Loaded $existing_count existing key(s)"
        else
            cn 196 b "  ❌ Decryption failed — starting fresh"
            : > "$tmp_keys"
        fi
    else
        echo "# SSOT Pubkeys — $(date +%Y-%m-%d)" > "$tmp_keys"
        echo "# One public key per line" >> "$tmp_keys"
    fi

    # Add local pubkey
    if [[ -n "$add_key" ]]; then
        # Add specific key
        if _key_exists_in_file "$tmp_keys" "$add_key"; then
            cn 226 b "⏭️  Key already in vault: $(_key_comment "$add_key")"
        else
            echo "$add_key" >> "$tmp_keys"
            cn 82 b "✅ Added: $(_key_comment "$add_key")"
        fi
    elif [[ -f "$LOCAL_KEY" ]]; then
        # Add local key
        local local_key_content
        local_key_content=$(cat "$LOCAL_KEY")
        if _key_exists_in_file "$tmp_keys" "$local_key_content"; then
            cn 226 b "⏭️  Local key already in vault: $(_key_comment "$local_key_content")"
        else
            echo "$local_key_content" >> "$tmp_keys"
            cn 82 b "✅ Added local key: $(_key_comment "$local_key_content")"
        fi
    else
        cn 226 b "⚠️  No local key found: $LOCAL_KEY"
        echo "  Generate: ssh-keygen -t ed25519 -C 'node' -f $SSH_DIR/id_ed25519_node"
    fi

    # Fetch from remote node
    if [[ -n "$fetch_host" ]]; then
        echo ""
        cn 226 b "🔍 Fetching pubkey from: $fetch_host"
        local remote_key
        if remote_key="$(_fetch_remote_pubkey "$fetch_host" "$fetch_user" "$fetch_port")"; then
            if _key_exists_in_file "$tmp_keys" "$remote_key"; then
                cn 226 b "⏭️  Remote key already in vault: $(_key_comment "$remote_key")"
            else
                echo "$remote_key" >> "$tmp_keys"
                cn 82 b "✅ Added remote key: $(_key_comment "$remote_key")"
            fi
        else
            cn 196 b "  ❌ Could not fetch key from $fetch_host"
            echo "  Make sure SSH is accessible and node has id_ed25519_node.pub"
        fi
    fi

    # Also scan all known nodes for their pubkey files
    echo ""
    cn 226 b "🔍 Scanning known nodes..."
    if [[ -d "$SSOT/nodes" ]]; then
        for node_file in "$SSOT/nodes"/*.node.env; do
            [[ -f "$node_file" ]] || continue
            local node_name="${node_file##*/}"
            node_name="${node_name%.node.env}"
            local upper
            upper="$(echo "$node_name" | tr '[:lower:]' '[:upper:]')"

            local host_var="NODE_${upper}_HOST"
            local user_var="NODE_${upper}_USER"
            local port_var="NODE_${upper}_PORT"

            local host="${!host_var:-}"
            local user="${!user_var:-}"
            local port="${!port_var:-22}"

            [[ -z "$host" ]] && continue

            # Try to fetch key from this node
            local remote_key
            if remote_key="$(_fetch_remote_pubkey "$host" "$user" "$port")"; then
                if _key_exists_in_file "$tmp_keys" "$remote_key"; then
                    printf "   %-12s $(c 226 b "skip") (already in vault)\n" "$node_name"
                else
                    echo "$remote_key" >> "$tmp_keys"
                    printf "   %-12s $(c 82 b "added") %s\n" "$node_name" "$(_key_comment "$remote_key")"
                fi
            else
                printf "   %-12s $(c 244 "offline")\n" "$node_name"
            fi
        done
    fi

    # Count final keys (excluding comments)
    local total_keys
    total_keys=$(grep -c '^ssh-' "$tmp_keys" 2>/dev/null || echo 0)

    if (( total_keys == 0 )); then
        cn 196 b "❌ No keys to encrypt"
        return 1
    fi

    # Encrypt
    echo ""
    cn 226 b "🔒 Encrypting $total_keys key(s)..."
    local pass
    pass="$(_get_pass "New Vault Passphrase: ")"

    if echo "$pass" | openssl enc -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" -salt \
        -in "$tmp_keys" -out "$VAULT_FILE" -pass stdin 2>/dev/null; then
        chmod 644 "$VAULT_FILE"
        cn 82 b "✅ Vault locked!"
        echo "📦 $VAULT_FILE ($(wc -c < "$VAULT_FILE" | tr -d ' ') bytes, $total_keys key(s))"
        echo ""
        cn 214 b "💡 Next: git add core/pubkeys.enc && git commit && git push"
    else
        cn 196 b "❌ Encryption failed"
        return 1
    fi
}

# ── 10. UNLOCK PUBKEY — Decrypt + Install ──
cmd_unlock_pubkey() {
    _banner

    if [[ ! -f "$VAULT_FILE" ]]; then
        cn 196 b "❌ Vault not found: $VAULT_FILE"
        echo "  Run 'vault lock_pubkey' first to create it."
        return 1
    fi

    cn 226 b "🔓 Decrypting pubkeys..."

    local pass
    pass="$(_get_pass "Vault Passphrase: ")"

    local tmp_keys
    tmp_keys="$(mktemp)"
    trap "rm -f '$tmp_keys'" EXIT

    if ! echo "$pass" | openssl enc -d -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" \
        -in "$VAULT_FILE" -out "$tmp_keys" -pass stdin 2>/dev/null; then
        cn 196 b "❌ Decryption failed — wrong passphrase?"
        return 1
    fi

    if [[ ! -s "$tmp_keys" ]]; then
        cn 196 b "❌ Empty vault — nothing to install"
        return 1
    fi

    # Ensure authorized_keys exists
    mkdir -p "$SSH_DIR"
    touch "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"

    # Install keys (skip duplicates)
    local added=0 skipped=0
    while IFS= read -r key; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        [[ "$key" =~ ^ssh- ]] || continue

        local comment
        comment="$(_key_comment "$key")"

        if grep -qF "$comment" "$AUTH_KEYS" 2>/dev/null; then
            skipped=$((skipped + 1))
        else
            echo "$key" >> "$AUTH_KEYS"
            added=$((added + 1))
        fi
    done < "$tmp_keys"

    # Set correct permissions
    chmod 600 "$AUTH_KEYS"

    echo ""
    cn 82 b "✅ Pubkeys installed!"
    echo "📄 $AUTH_KEYS"
    echo "   Added: $added | Skipped (existing): $skipped"
    echo ""
}

# ── 11. PUBKEY STATUS ──
cmd_status() {
    _banner

    # Vault file
    echo "📦 Vault:"
    if [[ -f "$VAULT_FILE" ]]; then
        local size
        size=$(wc -c < "$VAULT_FILE" | tr -d ' ')
        echo "   $(c 82 b "EXISTS") $VAULT_FILE ($size bytes)"
    else
        echo "   $(c 196 b "NOT FOUND")"
    fi

    # Local key
    echo ""
    echo "🔑 Local Key:"
    if [[ -f "$LOCAL_KEY" ]]; then
        local comment
        comment="$(_key_comment "$(cat "$LOCAL_KEY")")"
        echo "   $(c 82 b "EXISTS") $LOCAL_KEY"
        echo "   Comment: $comment"
    else
        echo "   $(c 226 b "NOT FOUND") $LOCAL_KEY"
    fi

    # authorized_keys
    echo ""
    echo "📄 authorized_keys:"
    if [[ -f "$AUTH_KEYS" ]]; then
        local key_count
        key_count=$(grep -c '^ssh-' "$AUTH_KEYS" 2>/dev/null || echo 0)
        echo "   $(c 82 b "EXISTS") $AUTH_KEYS ($key_count key(s))"
    else
        echo "   $(c 226 b "NOT FOUND")"
    fi

    # Vault contents (if can decrypt)
    if [[ -f "$VAULT_FILE" ]]; then
        echo ""
        echo "📋 Vault Contents:"
        local tmp_keys
        tmp_keys="$(mktemp)"
        trap "rm -f '$tmp_keys'" EXIT

        if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
            if echo "$SSOT_VAULT_PASS" | openssl enc -d -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" \
                -in "$VAULT_FILE" -out "$tmp_keys" -pass stdin 2>/dev/null; then
                while IFS= read -r key; do
                    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
                    [[ "$key" =~ ^ssh- ]] || continue
                    local comment
                    comment="$(_key_comment "$key")"
                    local installed="no"
                    grep -qF "$comment" "$AUTH_KEYS" 2>/dev/null && installed="yes"
                    if [[ "$installed" == "yes" ]]; then
                        printf "   %-30s $(c 82 b "installed")\n" "$comment"
                    else
                        printf "   %-30s $(c 226 b "pending")\n" "$comment"
                    fi
                done < "$tmp_keys"
            fi
        else
            echo "   $(c 244 "(set SSOT_VAULT_PASS to preview)")"
        fi
    fi
    echo ""
}

# ── 12. CLI Dispatcher ──
case "${1:-}" in
    lock|lock_pubkey)   shift; cmd_lock_pubkey "$@" ;;
    unlock|unlock_pubkey) cmd_unlock_pubkey ;;
    status)             cmd_status ;;
    *)
        _banner
        echo "Usage: $(basename "$0") <command>"
        echo ""
        echo "Commands:"
        echo "  lock_pubkey [--add <key>] [--from <host>]"
        echo "              Collect pubkeys + encrypt → core/pubkeys.enc"
        echo ""
        echo "  unlock_pubkey"
        echo "              Decrypt → install to ~/.ssh/authorized_keys"
        echo ""
        echo "  status"
        echo "              Show vault + key status"
        echo ""
        echo "Workflow:"
        echo "  1. vault lock_pubkey        — collect + encrypt"
        echo "  2. git add -A && git push   — sync"
        echo "  3. vault unlock_pubkey      — install on each machine"
        echo ""
        exit 0
        ;;
esac
