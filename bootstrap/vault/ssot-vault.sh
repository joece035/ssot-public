#!/usr/bin/env bash
# ============================================================
# 🔐 SSOT Secret Vault Manager (AES-256 PBKDF2)
# ============================================================
# File: tools/ssot-vault.sh
# Purpose: Zero-dependency, military-grade credential vault
#          for syncing secret .env across multi-device SSOT
# Target: $SSOT/core/.env.enc <---> $HOME/.env ($SSOT/.env)
#
# Non-interactive mode: export SSOT_VAULT_PASS="<passphrase>"
# ============================================================

set -eo pipefail 2>/dev/null || true

# ── 1. SSOT Root & Environment Resolution ──
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
    cn() {
        local col="${1:-}" style="${2:-}"
        shift 2 2>/dev/null || shift $#
        echo "$*"
    }
    c() {
        local col="${1:-}" style="${2:-}"
        shift 2 2>/dev/null || shift $#
        printf "%s" "$*"
    }
fi

# ── 3. Paths & Configurations ──
VAULT_FILE="$SSOT/core/.env.enc"
EXAMPLE_FILE="$SSOT/.env.example"
LOCAL_ENV="$HOME/.env"
SSOT_ENV="$SSOT/.env"
PBKDF2_ITER=100000

# ── 4. Helper Functions ──
_banner() {
    echo ""
    c 39 b "╔══════════════════════════════════════════════════════════╗" && echo ""
    c 39 b "║   🔐  SSOT Secret Vault (AES-256-CBC PBKDF2)           ║" && echo ""
    c 39 b "╚══════════════════════════════════════════════════════════╝" && echo ""
    echo ""
}

_resolve_active_env() {
    if [[ -f "$LOCAL_ENV" ]]; then
        echo "$LOCAL_ENV"
    elif [[ -f "$SSOT_ENV" ]]; then
        echo "$SSOT_ENV"
    else
        echo ""
    fi
}

_ensure_openssl() {
    if ! command -v openssl >/dev/null 2>&1; then
        cn 196 b "❌ Error: 'openssl' is not installed."
        echo "Install: pkg install openssl / apt install openssl"
        exit 1
    fi
}

# ── 5. Core Commands ──

# --- LOCK / ENCRYPT ---
cmd_lock() {
    _banner
    _ensure_openssl

    local target_env="$(_resolve_active_env)"
    if [[ -z "$target_env" ]]; then
        cn 196 b "❌ No .env file found at $LOCAL_ENV or $SSOT_ENV"
        echo "Create one: cp .env.example ~/.env && edit ~/.env"
        exit 1
    fi

    cn 226 b "🔒 Locking secrets from: $target_env"
    mkdir -p "$(dirname "$VAULT_FILE")"

    # Get passphrase (non-interactive via env var, or prompt)
    local pass1 pass2
    if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
        pass1="$SSOT_VAULT_PASS"
    else
        read -r -s -p "Enter Vault Passphrase: " pass1 < /dev/tty
        echo ""
        if [[ -z "$pass1" ]]; then
            cn 196 b "❌ Passphrase cannot be empty."
            exit 1
        fi
        read -r -s -p "Confirm: " pass2 < /dev/tty
        echo ""
        if [[ "$pass1" != "$pass2" ]]; then
            cn 196 b "❌ Passphrases do not match!"
            exit 1
        fi
    fi

    # Encrypt
    if echo "$pass1" | openssl enc -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" -salt \
        -in "$target_env" -out "$VAULT_FILE" -pass stdin 2>/dev/null; then
        chmod 644 "$VAULT_FILE"
        echo ""
        cn 82 b "✅ Vault locked!"
        echo "📦 $VAULT_FILE ($(wc -c < "$VAULT_FILE" | tr -d ' ') bytes)"
        echo ""
        cn 214 b "💡 Next: git add $VAULT_FILE && git commit && git push"
        echo ""
    else
        cn 196 b "❌ Encryption failed."
        exit 1
    fi
}

# --- UNLOCK / DECRYPT ---
cmd_unlock() {
    _banner
    _ensure_openssl

    if [[ ! -f "$VAULT_FILE" ]]; then
        cn 196 b "❌ Vault not found: $VAULT_FILE"
        echo "Clone the repo first, or create .env manually."
        exit 1
    fi

    cn 226 b "🔓 Unlocking: $VAULT_FILE"

    # Get passphrase
    local pass
    if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
        pass="$SSOT_VAULT_PASS"
    else
        read -r -s -p "Enter Vault Passphrase: " pass < /dev/tty
        echo ""
    fi

    if [[ -z "$pass" ]]; then
        cn 196 b "❌ Passphrase cannot be empty."
        exit 1
    fi

    local tmp_out
    tmp_out="$(mktemp)"

    if echo "$pass" | openssl enc -d -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" \
        -in "$VAULT_FILE" -out "$tmp_out" -pass stdin 2>/dev/null; then
        if [[ ! -s "$tmp_out" ]]; then
            rm -f "$tmp_out"
            cn 196 b "❌ Decryption empty — wrong passphrase?"
            exit 1
        fi

        mv "$tmp_out" "$LOCAL_ENV"
        chmod 600 "$LOCAL_ENV"
        ln -sf "$LOCAL_ENV" "$SSOT_ENV"

        echo ""
        cn 82 b "✅ Vault unlocked!"
        echo "📄 $LOCAL_ENV (chmod 600)"
        echo "🔗 $SSOT_ENV → $LOCAL_ENV"
        echo ""
    else
        rm -f "$tmp_out"
        cn 196 b "❌ Decryption failed — wrong passphrase or corrupted vault."
        exit 1
    fi
}

# --- STATUS (unified: health + audit + diff) ---
cmd_status() {
    _banner

    # ── Vault file ──
    echo "📦 Vault:"
    if [[ -f "$VAULT_FILE" ]]; then
        local v_size v_time
        v_size="$(wc -c < "$VAULT_FILE" | tr -d ' ')"
        v_time="$(stat -c "%y" "$VAULT_FILE" 2>/dev/null || stat -f "%Sm" "$VAULT_FILE" 2>/dev/null || echo "?")"
        echo "   $(c 82 b "EXISTS") $VAULT_FILE ($v_size bytes, $v_time)"
    else
        echo "   $(c 196 b "NOT FOUND") $VAULT_FILE"
    fi

    # ── Active .env ──
    local active_env="$(_resolve_active_env)"
    echo ""
    echo "📄 Active .env:"
    if [[ -n "$active_env" ]]; then
        local e_size
        e_size="$(wc -c < "$active_env" | tr -d ' ')"
        echo "   $(c 82 b "EXISTS") $active_env ($e_size bytes)"
    else
        echo "   $(c 226 b "NOT FOUND") — Run: vault unlock"
    fi

    # ── Symlink ──
    echo ""
    echo "🔗 Symlink:"
    if [[ -L "$SSOT_ENV" ]]; then
        echo "   $(c 82 b "HEALTHY") $SSOT_ENV → $(readlink "$SSOT_ENV")"
    elif [[ -f "$SSOT_ENV" ]]; then
        echo "   $(c 226 b "REGULAR FILE") — Consider: ln -sf ~/.env $SSOT_ENV"
    else
        echo "   $(c 246 b "NONE")"
    fi

    # ── Secret Audit ──
    if [[ -n "$active_env" ]] && [[ -f "$EXAMPLE_FILE" ]]; then
        echo ""
        echo "🔍 Secret Audit (template vs actual):"
        local total=0 ok=0 empty=0 missing=0

        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)= ]]; then
                local var_name="${BASH_REMATCH[2]}"
                [[ "$var_name" == "JOE_ENV" || "$var_name" == "MY_DEVICE" ]] && continue
                total=$((total+1))

                if grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_env" 2>/dev/null; then
                    local raw_val
                    raw_val="$(grep -m 1 "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_env" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=//' | tr -d '"' | tr -d "'")"
                    if [[ -n "$raw_val" ]]; then
                        ok=$((ok+1))
                        local masked="${raw_val:0:4}..."
                        printf "   %-28s $(c 82 b "SET") %s\n" "$var_name" "$masked"
                    else
                        empty=$((empty+1))
                        printf "   %-28s $(c 226 b "EMPTY")\n" "$var_name"
                    fi
                else
                    missing=$((missing+1))
                    printf "   %-28s $(c 196 b "MISSING")\n" "$var_name"
                fi
            fi
        done < "$EXAMPLE_FILE"

        echo ""
        printf "   Total: %d | $(c 82 b "Set: %d") | $(c 226 b "Empty: %d") | $(c 196 b "Missing: %d")\n" \
            "$total" "$ok" "$empty" "$missing"

        # Exit code for CI/scripting
        if (( missing > 0 || empty > 0 )); then
            echo ""
            echo "   💡 Fix: edit ~/.env or run vault init"
            return 1
        fi
    fi
    echo ""
}

# --- INIT (interactive wizard) ---
cmd_init() {
    _banner
    local active_env="$(_resolve_active_env)"

    if [[ -z "$active_env" ]]; then
        if [[ -f "$EXAMPLE_FILE" ]]; then
            cp "$EXAMPLE_FILE" "$LOCAL_ENV"
            chmod 600 "$LOCAL_ENV"
            ln -sf "$LOCAL_ENV" "$SSOT_ENV"
            active_env="$LOCAL_ENV"
            cn 82 b "📄 Created ~/.env from .env.example"
        else
            cn 196 b "❌ .env.example not found"
            exit 1
        fi
    fi

    echo "🔧 Interactive Setup — $active_env"
    echo "   Press Enter to skip a value."
    echo ""

    local updated=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
            local var_name="${BASH_REMATCH[2]}"
            [[ "$var_name" == "JOE_ENV" || "$var_name" == "MY_DEVICE" ]] && continue

            # Check current value
            local current_val=""
            if grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_env" 2>/dev/null; then
                current_val="$(grep -m 1 "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_env" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=//' | tr -d '"' | tr -d "'")"
            fi

            if [[ -n "$current_val" ]]; then
                printf "   %-28s %s (set)\n" "$var_name" "${current_val:0:4}..."
                continue
            fi

            printf "   %-28s = " "$var_name"
            read -r new_val < /dev/tty
            new_val="${new_val:-}"

            if [[ -n "$new_val" ]]; then
                if grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_env" 2>/dev/null; then
                    sed -i "s|^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=.*|export ${var_name}=\"${new_val}\"|" "$active_env"
                else
                    printf 'export %s="%s"\n' "$var_name" "$new_val" >> "$active_env"
                fi
                updated=$((updated+1))
            fi
        fi
    done < "$EXAMPLE_FILE"

    echo ""
    cn 82 b "✅ Updated $updated secret(s)"
    echo "💡 Next: vault lock → git commit → git push"
    echo ""
}

# --- EXPORT (backup) ---
cmd_export() {
    _ensure_openssl
    local active_env="$(_resolve_active_env)"

    if [[ -z "$active_env" ]]; then
        cn 196 b "❌ No .env to export"
        exit 1
    fi

    local backup_dir="$SSOT/core/backups"
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/.env.$(date +%Y%m%d_%H%M%S).enc"

    cn 226 b "📦 Backing up to: $backup_file"

    local pass
    if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
        pass="$SSOT_VAULT_PASS"
    else
        read -r -s -p "Backup passphrase: " pass < /dev/tty
        echo ""
    fi

    if echo "$pass" | openssl enc -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" \
        -salt -in "$active_env" -out "$backup_file" -pass stdin 2>/dev/null; then
        chmod 600 "$backup_file"
        cn 82 b "✅ Backup created ($(wc -c < "$backup_file" | tr -d ' ') bytes)"
    else
        cn 196 b "❌ Backup failed"
        exit 1
    fi
}

# ── 6. CLI Dispatcher ──
case "${1:-}" in
    lock|encrypt)       cmd_lock ;;
    unlock|decrypt)     cmd_unlock ;;
    status)             cmd_status ;;
    init|setup)         cmd_init ;;
    export|backup)      cmd_export ;;
    verify|check)       cmd_status ;;   # alias: verify = status
    diff)               cmd_status ;;   # alias: diff = status
    audit)              cmd_status ;;   # alias: audit = status

    # Pubkey commands (pass-through to pubkey-manager.sh)
    lock_pubkey|unlock_pubkey|pubkey-status)
        _PUBKEY_SCRIPT="$SSOT/tools/pubkey-manager.sh"
        if [[ -f "$_PUBKEY_SCRIPT" ]]; then
            # Map vault command names to pubkey-manager names
            _pk_cmd="${1}"
            shift
            case "$_pk_cmd" in
                pubkey-status) bash "$_PUBKEY_SCRIPT" status "$@" ;;
                *)             bash "$_PUBKEY_SCRIPT" "$_pk_cmd" "$@" ;;
            esac
        else
            cn 196 b "❌ pubkey-manager.sh not found"
            exit 1
        fi
        ;;

    *)
        _banner
        echo "Usage: $(basename "$0") <command>"
        echo ""
        echo "Secret Commands:"
        echo "  lock    Encrypt ~/.env → core/.env.enc"
        echo "  unlock  Decrypt core/.env.enc → ~/.env"
        echo "  status  Vault health + secret audit (exit 1 if incomplete)"
        echo "  init    Interactive wizard to fill in secrets"
        echo "  export  Encrypted backup of ~/.env"
        echo ""
        echo "Pubkey Commands:"
        echo "  lock_pubkey [--add <key>] [--from <host>]"
        echo "              Collect + encrypt SSH pubkeys → core/pubkeys.enc"
        echo "  unlock_pubkey"
        echo "              Decrypt → install to ~/.ssh/authorized_keys"
        echo "  pubkey-status"
        echo "              Show vault + key installation status"
        echo ""
        echo "Aliases: verify, check, diff, audit → status"
        echo ""
        echo "Non-interactive:"
        echo "  export SSOT_VAULT_PASS='<pass>'  (skip passphrase prompts)"
        echo ""
        exit 0
        ;;
esac
