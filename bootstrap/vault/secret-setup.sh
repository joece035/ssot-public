#!/usr/bin/env bash
# ============================================================
# 🔐 Secret Setup Wizard — Standalone Secret Configuration
# ============================================================
# File: bootstrap/secret-setup.sh
# Purpose: Interactive wizard for setting up secrets on new machines
#          or when adding new API keys to the ecosystem.
#
# Usage:
#   bash ~/ssot/bootstrap/secret-setup.sh          # Full wizard
#   bash ~/ssot/bootstrap/secret-setup.sh --unlock  # Unlock vault first
#   bash ~/ssot/bootstrap/secret-setup.sh --verify  # Quick check
#   bash ~/ssot/bootstrap/secret-setup.sh --diff    # Show what's missing
#
# Part of the 3-Layer Secret Architecture:
#   Layer 1: .env.example     (committed, shows all expected keys)
#   Layer 2: core/.env.enc    (committed, AES-256 encrypted vault)
#   Layer 3: ~/.env           (local only, chmod 600, gitignored)
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

# ── 3. Paths ──
VAULT_FILE="$SSOT/core/.env.enc"
VAULT_SCRIPT="$SSOT/bootstrap/vault/ssot-vault.sh"
EXAMPLE_FILE="$SSOT/.env.example"
LOCAL_ENV="$HOME/.env"
SSOT_ENV="$SSOT/.env"

# ── 4. Banner ──
_banner() {
    echo ""
    c 39 b "╔══════════════════════════════════════════════════════════╗" && echo ""
    c 39 b "║   🔐  Secret Setup Wizard                               ║" && echo ""
    c 39 b "╚══════════════════════════════════════════════════════════╝" && echo ""
    echo ""
}

# ── 5. Helper: Resolve active .env ──
_resolve_active_env() {
    if [[ -f "$LOCAL_ENV" ]]; then
        echo "$LOCAL_ENV"
    elif [[ -f "$SSOT_ENV" ]]; then
        echo "$SSOT_ENV"
    else
        echo ""
    fi
}

# ── 6. Helper: Check if secrets are populated ──
_secrets_populated() {
    local env_file="${1:-$LOCAL_ENV}"
    [[ ! -f "$env_file" ]] && return 1
    # Check if at least one non-template value exists
    grep -qE '^[^#]*=[^"'"'"'\s]+[^\s]' "$env_file" 2>/dev/null
}

# ── 7. Main Logic ──
main() {
    local mode="${1:-full}"

    case "$mode" in
        --unlock|-u)
            _do_unlock
            ;;
        --verify|-v)
            _do_verify
            ;;
        --diff|-d)
            _do_diff
            ;;
        --backup|-b)
            _do_backup
            ;;
        --help|-h)
            _show_help
            ;;
        *)
            _do_full_wizard
            ;;
    esac
}

# ── 8. Unlock vault ──
_do_unlock() {
    _banner

    if [[ ! -f "$VAULT_FILE" ]]; then
        cn 196 b "❌ No vault file found: $VAULT_FILE"
        echo "  The repository may not have an encrypted vault."
        echo "  Create secrets manually: cp .env.example ~/.env && edit ~/.env"
        exit 1
    fi

    if [[ -f "$VAULT_SCRIPT" ]]; then
        "$VAULT_SCRIPT" unlock
    else
        cn 196 b "❌ Vault script not found: $VAULT_SCRIPT"
        exit 1
    fi
}

# ── 9. Verify secrets ──
_do_verify() {
    _banner

    if [[ -f "$VAULT_SCRIPT" ]]; then
        "$VAULT_SCRIPT" verify
    else
        # Manual verify without vault script
        local active_env="$(_resolve_active_env)"
        if [[ -z "$active_env" ]]; then
            cn 196 b "❌ No .env file found"
            exit 1
        fi

        local missing=0 empty=0 total=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)= ]]; then
                local var_name="${BASH_REMATCH[2]}"
                [[ "$var_name" == "JOE_ENV" || "$var_name" == "MY_DEVICE" ]] && continue
                total=$((total+1))

                if grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_env" 2>/dev/null; then
                    local raw_val
                    raw_val="$(grep -m 1 "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_env" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=//' | tr -d '"' | tr -d "'")"
                    [[ -z "$raw_val" ]] && empty=$((empty+1))
                else
                    missing=$((missing+1))
                fi
            fi
        done < "$EXAMPLE_FILE"

        if (( missing > 0 || empty > 0 )); then
            cn 196 b "❌ Secrets incomplete: ${missing} missing, ${empty} empty (of ${total} expected)"
            exit 1
        else
            cn 82 b "✅ All ${total} secrets are set"
        fi
    fi
}

# ── 10. Show diff ──
_do_diff() {
    _banner

    if [[ -f "$VAULT_SCRIPT" ]]; then
        "$VAULT_SCRIPT" diff
    else
        local active_env="$(_resolve_active_env)"
        if [[ -z "$active_env" ]]; then
            cn 196 b "❌ No .env file found"
            exit 1
        fi

        echo "📋 Missing/empty secrets:"
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)= ]]; then
                local var_name="${BASH_REMATCH[2]}"
                [[ "$var_name" == "JOE_ENV" || "$var_name" == "MY_DEVICE" ]] && continue

                if ! grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_env" 2>/dev/null; then
                    cn 196 b "  MISSING: $var_name"
                fi
            fi
        done < "$EXAMPLE_FILE"
    fi
}

# ── 11. Backup vault ──
_do_backup() {
    _banner

    if [[ -f "$VAULT_SCRIPT" ]]; then
        "$VAULT_SCRIPT" export
    else
        cn 196 b "❌ Vault script not found"
        exit 1
    fi
}

# ── 12. Full interactive wizard ──
_do_full_wizard() {
    _banner

    # Step 1: Check vault
    if [[ -f "$VAULT_FILE" ]]; then
        cn 226 b "📦 Found encrypted vault: $VAULT_FILE"
        local active_env="$(_resolve_active_env)"

        if [[ -z "$active_env" ]] || ! _secrets_populated "$active_env"; then
            echo ""
            echo "  🔐 Secrets are not yet loaded."
            read -r -t 15 -p "   Unlock vault now? [Y/n] (default: Y): " _choice < /dev/tty || _choice="Y"
            if [[ "${_choice:-Y}" =~ ^[Yy]?$ ]]; then
                _do_unlock
            else
                echo "  ⏭️  Skipping vault unlock."
            fi
        else
            cn 82 b "  ✅ Secrets already loaded"
        fi
    else
        cn 226 b "📦 No encrypted vault found"
        echo "  ℹ️  You'll need to set up secrets manually."
    fi

    echo ""

    # Step 2: Check completeness
    local active_env="$(_resolve_active_env)"
    if [[ -n "$active_env" ]]; then
        cn 226 b "🔍 Checking secret completeness..."
        echo ""

        local missing_list=() empty_list=()
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)= ]]; then
                local var_name="${BASH_REMATCH[2]}"
                [[ "$var_name" == "JOE_ENV" || "$var_name" == "MY_DEVICE" ]] && continue

                if ! grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_env" 2>/dev/null; then
                    missing_list+=("$var_name")
                else
                    local raw_val
                    raw_val="$(grep -m 1 "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_env" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=//' | tr -d '"' | tr -d "'")"
                    [[ -z "$raw_val" ]] && empty_list+=("$var_name")
                fi
            fi
        done < "$EXAMPLE_FILE"

        if (( ${#missing_list[@]} > 0 || ${#empty_list[@]} > 0 )); then
            cn 226 b "  ⚠️  Found ${#missing_list[@]} missing, ${#empty_list[@]} empty secrets"
            echo ""
            read -r -t 10 -p "   Run interactive setup to fill them? [Y/n] (default: Y): " _setup_choice < /dev/tty || _setup_choice="Y"
            if [[ "${_setup_choice:-Y}" =~ ^[Yy]?$ ]]; then
                if [[ -f "$VAULT_SCRIPT" ]]; then
                    "$VAULT_SCRIPT" init
                else
                    _interactive_setup "$active_env"
                fi
            fi
        else
            cn 82 b "  ✅ All secrets are set — nothing to do!"
        fi
    else
        echo "  ℹ️  No .env file found."
        echo "  Creating from template..."
        if [[ -f "$EXAMPLE_FILE" ]]; then
            cp "$EXAMPLE_FILE" "$LOCAL_ENV"
            chmod 600 "$LOCAL_ENV"
            ln -sf "$LOCAL_ENV" "$SSOT_ENV"
            cn 82 b "📄 Created ~/.env from .env.example"
            echo ""
            _interactive_setup "$LOCAL_ENV"
        else
            cn 196 b "❌ .env.example not found"
            exit 1
        fi
    fi

    # Step 3: Final summary
    echo ""
    cn 39 b "═══════════════════════════════════════════════════════════"
    cn 82 b "  🎉 Secret setup complete!"
    echo ""
    echo "  Useful commands:"
    echo "    vault status    — Check vault health"
    echo "    vault verify    — Verify all secrets set"
    echo "    vault diff      — Show what's missing"
    echo "    vault lock      — Encrypt & sync to repo"
    echo "    vault export    — Create encrypted backup"
    cn 39 b "═══════════════════════════════════════════════════════════"
    echo ""
}

# ── 13. Interactive setup (fallback when vault script unavailable) ──
_interactive_setup() {
    local env_file="${1:-$LOCAL_ENV}"

    echo ""
    echo "🔧 Interactive Secret Setup"
    echo "   File: $env_file"
    echo "   Press Enter to skip a value."
    echo ""

    local updated=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
            local var_name="${BASH_REMATCH[2]}"
            [[ "$var_name" == "JOE_ENV" || "$var_name" == "MY_DEVICE" ]] && continue

            local current_val=""
            if grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$env_file" 2>/dev/null; then
                current_val="$(grep -m 1 "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$env_file" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=//' | tr -d '"' | tr -d "'")"
            fi

            if [[ -n "$current_val" ]]; then
                local masked="${current_val:0:4}..."
                printf "  %-30s = %s (set)\n" "$var_name" "$masked"
                continue
            fi

            printf "  %-30s = " "$var_name"
            read -r new_val < /dev/tty
            new_val="${new_val:-}"

            if [[ -n "$new_val" ]]; then
                if grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$env_file" 2>/dev/null; then
                    sed -i "s|^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=.*|export ${var_name}=\"${new_val}\"|" "$env_file"
                else
                    printf 'export %s="%s"\n' "$var_name" "$new_val" >> "$env_file"
                fi
                updated=$((updated+1))
            fi
        fi
    done < "$EXAMPLE_FILE"

    echo ""
    cn 82 b "✅ Updated $updated secret(s)"
}

# ── 14. Help ──
_show_help() {
    _banner
    echo "Usage: $(basename "$0") [option]"
    echo ""
    echo "Options:"
    echo "  (none)       Full interactive wizard"
    echo "  --unlock, -u Unlock encrypted vault"
    echo "  --verify, -v Verify all secrets are set"
    echo "  --diff,   -d Show what's missing/empty"
    echo "  --backup, -b Create encrypted backup"
    echo "  --help,   -h Show this help"
    echo ""
    echo "Architecture:"
    echo "  Layer 1: .env.example     (committed, shows all expected keys)"
    echo "  Layer 2: core/.env.enc    (committed, AES-256 encrypted vault)"
    echo "  Layer 3: ~/.env           (local only, chmod 600, gitignored)"
    echo ""
    echo "New Machine Workflow:"
    echo "  1. git clone <repo> ~/ssot"
    echo "  2. bash ~/ssot/bootstrap/install.sh"
    echo "     └─ Detects vault → prompts to unlock"
    echo "  3. bash ~/ssot/bootstrap/secret-setup.sh"
    echo "     └─ Verifies all secrets are populated"
    echo ""
    echo "Adding New Secrets:"
    echo "  1. Add key to .env.example (with empty value)"
    echo "  2. Add value to ~/.env"
    echo "  3. vault lock  (re-encrypt vault)"
    echo "  4. git commit + push"
    echo ""
}

# ── Run ──
main "${1:-full}"
