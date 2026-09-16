#!/usr/bin/env bash
# ============================================================
# 🔑 SSOT Pubkey Corrector — Vault-Strategy Key Collector
# ============================================================
# File: bootstrap/nodes/pubkey-corrector.sh
# Purpose: Repair + collect + distribute mesh SSH pubkeys via
#          encrypted vault (core/pubkeys.enc) without
#          last-writer-wins overwrites.
#
# Why this exists (vs pubkey-manager.sh):
#   - Dedup by FINGERPRINT (ssh-keygen -lf), not by comment.
#     Multiple nodes share comment "node" — comment dedup
#     skips wrong keys / adds duplicates.
#   - Repairs split lines ("node" + "-win" on two lines) and
#     CRLF before validating — the exact failure seen on wsl.
#   - collect merges (git pull + decrypt + merge + encrypt),
#     never starts from local-only state.
#   - install validates every key with ssh-keygen before append.
#   - Windows Administrators: also syncs to
#     ProgramData/ssh/administrators_authorized_keys (best-effort).
#
# Workflow (run on each machine):
#   1. Every node:  corrector fix-local   (repair authorized_keys)
#   2. Every node:  cat ~/.ssh/id_ed25519_node.pub   (hand to collector)
#   3. Collector:   vault pubkey-collect --add "<key>"  (per key,
#                   after git pull — repeat for each node)
#   4. Collector:   git add core/pubkeys.enc && git commit && git push
#   5. Every node:  git pull && vault pubkey-sync
#   6. Every node:  ssh-keygen -R <node>; ssh -o BatchMode=yes <node> "echo ok"
#
# Usage:
#   bash bootstrap/nodes/pubkey-corrector.sh audit        # read-only check
#   bash bootstrap/nodes/pubkey-corrector.sh fix-local    # repair this node
#   bash bootstrap/nodes/pubkey-corrector.sh collect [--add <key>] [--from <host>] [--scan-mesh]
#   bash bootstrap/nodes/pubkey-corrector.sh install      # decrypt vault -> authorized_keys
#   bash bootstrap/nodes/pubkey-corrector.sh status       # vault + local overview
#
# Non-interactive: export SSOT_VAULT_PASS="<passphrase>"
# ============================================================
set -uo pipefail

# ── 1. Resolve SSOT root (mirror ssh_audit.sh — never source joe.sh) ──
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_SSOT_ROOT="${SSOT:-$_SCRIPT_DIR}"
[[ -d "$_SSOT_ROOT" ]] || _SSOT_ROOT="$_SCRIPT_DIR"
export SSOT="$_SSOT_ROOT"

# ── 2. Color engine (SSOT canonical API only) ──
if [[ -f "$SSOT/core/01-colors.sh" ]]; then
    # shellcheck source=/dev/null
    source "$SSOT/core/01-colors.sh" 2>/dev/null || true
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
_KEY_TYPES='^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com)[[:space:]]'

_banner() {
    echo ""
    c 45 b "╔══════════════════════════════════════════════════════════╗" && echo ""
    c 45 b "║   🔑  SSOT Pubkey Corrector (vault strategy)            ║" && echo ""
    c 45 b "╚══════════════════════════════════════════════════════════╝" && echo ""
    echo ""
}

_get_pass() {
    local prompt="${1:-Enter Vault Passphrase: }"
    if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
        printf "%s" "$SSOT_VAULT_PASS"
    else
        local pass=""
        read -r -s -p "$prompt" pass < /dev/tty
        echo "" >&2
        printf "%s" "$pass"
    fi
}

_ensure_openssl() {
    if ! command -v openssl >/dev/null 2>&1; then
        cn 196 b "❌ openssl not installed (apt install openssl / pkg install openssl)"
        return 1
    fi
}

# Fingerprint of ONE key line (empty when unparsable)
_fingerprint_of_key() {
    local key="${1:-}"
    [[ -z "$key" ]] && return 1
    printf "%s\n" "$key" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}'
}

_key_comment() {
    printf "%s" "${1:-}" | awk '{print $NF}'
}

# Windows Administrators auth file (empty when N/A)
_admin_auth_path() {
    local candidates=()
    [[ -n "${PROGRAMDATA:-}" ]] && candidates+=("$PROGRAMDATA/ssh/administrators_authorized_keys")
    candidates+=("/c/ProgramData/ssh/administrators_authorized_keys")
    candidates+=("C:/ProgramData/ssh/administrators_authorized_keys")
    candidates+=("/mnt/c/ProgramData/ssh/administrators_authorized_keys")
    local p=""
    for p in "${candidates[@]}"; do
        if [[ -f "$p" ]]; then
            printf "%s" "$p"
            return 0
        fi
    done
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*) printf "%s" "C:/ProgramData/ssh/administrators_authorized_keys"; return 0 ;;
    esac
    return 1
}

# Join split continuation lines + strip CR.
# Reads $1 (file), writes repaired key lines to stdout (comments/blank dropped).
_repaired_key_lines() {
    local src="${1:-}"
    [[ -f "$src" ]] || return 0
    local line buf=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(printf "%s" "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$line" || "$line" == \#* ]] && continue
        if [[ "$line" =~ $_KEY_TYPES ]]; then
            [[ -n "$buf" ]] && printf "%s\n" "$buf"
            buf="$line"
        else
            # Continuation of a split key (e.g. "node" + "-win") — join raw.
            if [[ -n "$buf" ]]; then
                buf="${buf}${line}"
            else
                printf "%s\n" "$line"
            fi
        fi
    done < "$src"
    [[ -n "$buf" ]] && printf "%s\n" "$buf"
}

# Fingerprints present in a key-lines file (one per line, via stdin file $1)
_existing_fingerprints() {
    local src="${1:-}"
    [[ -f "$src" ]] || return 0
    ssh-keygen -lf "$src" 2>/dev/null | awk '{print $2}'
}

_git_pull_best_effort() {
    if command -v git >/dev/null 2>&1 && git -C "$SSOT" rev-parse --git-dir >/dev/null 2>&1; then
        if git -C "$SSOT" pull --ff-only >/dev/null 2>&1; then
            cn 82 b "  ✅ git pull (fast-forward)"
        else
            cn 226 b "  ⚠️  git pull failed — continuing with local vault (run git pull manually)"
        fi
    fi
}

# ── AUDIT (read-only) ──
cmd_audit() {
    _banner
    local issues=0
    echo "🔍 Auditing: $AUTH_KEYS"
    echo ""

    if [[ ! -d "$SSH_DIR" ]]; then
        cn 196 b "  ❌ ~/.ssh missing"
        issues=$((issues+1))
    else
        local dperm
        dperm="$(stat -c "%a" "$SSH_DIR" 2>/dev/null || stat -f "%Lp" "$SSH_DIR" 2>/dev/null || echo "?")"
        if [[ "$dperm" == "700" ]]; then
            echo "  ✅ ~/.ssh perms 700"
        else
            cn 226 b "  ⚠️  ~/.ssh perms $dperm (want 700)"
            issues=$((issues+1))
        fi
    fi

    if [[ ! -f "$AUTH_KEYS" ]]; then
        cn 226 b "  ⚠️  authorized_keys missing (fix-local will create)"
        issues=$((issues+1))
    else
        local fperm
        fperm="$(stat -c "%a" "$AUTH_KEYS" 2>/dev/null || stat -f "%Lp" "$AUTH_KEYS" 2>/dev/null || echo "?")"
        [[ "$fperm" == "600" ]] && echo "  ✅ authorized_keys perms 600" || { cn 226 b "  ⚠️  authorized_keys perms $fperm (want 600)"; issues=$((issues+1)); }

        if grep -qU $'\r' "$AUTH_KEYS" 2>/dev/null; then
            cn 226 b "  ⚠️  CRLF line endings present"
            issues=$((issues+1))
        else
            echo "  ✅ LF line endings"
        fi

        local splits=0
        splits="$(_repaired_key_lines "$AUTH_KEYS" | grep -c '^ssh-' 2>/dev/null || true)"
        local raw_keys=0
        raw_keys="$(grep -cE '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp|sk-ssh-ed25519@|sk-ecdsa-sha2-nistp256@)' "$AUTH_KEYS" 2>/dev/null || true)"
        if [[ "$splits" != "$raw_keys" ]]; then
            cn 226 b "  ⚠️  possible split lines (key-starts: $raw_keys, repaired: $splits)"
            issues=$((issues+1))
        else
            echo "  ✅ no split lines"
        fi

        local tmp_rep=""
        tmp_rep="$(mktemp)"
        _repaired_key_lines "$AUTH_KEYS" > "$tmp_rep"
        local bad=0 total=0
        while IFS= read -r k || [[ -n "$k" ]]; do
            total=$((total+1))
            [[ -z "$(_fingerprint_of_key "$k")" ]] && bad=$((bad+1))
        done < "$tmp_rep"
        if (( bad > 0 )); then
            cn 196 b "  ❌ $bad/$total key line(s) fail ssh-keygen parse"
            issues=$((issues+1))
        else
            echo "  ✅ all $total key line(s) parse ($(_existing_fingerprints "$tmp_rep" | wc -l | tr -d ' ') fingerprints)"
        fi

        local dupes=""
        dupes="$(ssh-keygen -lf "$tmp_rep" 2>/dev/null | awk '{print $2}' | sort | uniq -d | tr '\n' ' ')"
        if [[ -n "$dupes" ]]; then
            cn 226 b "  ⚠️  duplicate fingerprints: $dupes"
            issues=$((issues+1))
        else
            echo "  ✅ no duplicate fingerprints"
        fi
        rm -f "$tmp_rep"

        if [[ -f "$LOCAL_KEY" ]]; then
            local self_fp=""
            self_fp="$(_fingerprint_of_key "$(cat "$LOCAL_KEY")")"
            if [[ -n "$self_fp" ]] && _existing_fingerprints "$AUTH_KEYS" 2>/dev/null | grep -qF "$self_fp"; then
                echo "  ✅ self key installed ($(_key_comment "$(cat "$LOCAL_KEY")"))"
            else
                cn 226 b "  ⚠️  self key missing from authorized_keys"
                issues=$((issues+1))
            fi
        else
            cn 226 b "  ⚠️  no local $LOCAL_KEY"
            issues=$((issues+1))
        fi
    fi

    echo ""
    if [[ -f "$VAULT_FILE" ]]; then
        echo "  ✅ vault $VAULT_FILE ($(wc -c < "$VAULT_FILE" | tr -d ' ') bytes)"
    else
        cn 226 b "  ⚠️  vault not found: $VAULT_FILE"
        issues=$((issues+1))
    fi

    local admin_path=""
    admin_path="$(_admin_auth_path || true)"
    if [[ -n "$admin_path" ]]; then
        echo "  ℹ️  Windows admin auth file: $admin_path"
    fi

    echo ""
    if (( issues == 0 )); then
        cn 82 b "✅ AUDIT CLEAN"
    else
        cn 226 b "⚠️  AUDIT: $issues issue(s) — run: vault pubkey-fix"
        return 1
    fi
}

# ── FIX-LOCAL (repair this node) ──
cmd_fix_local() {
    _banner
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$AUTH_KEYS"

    local backup="${AUTH_KEYS}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$AUTH_KEYS" "$backup" 2>/dev/null || true
    chmod 600 "$backup" 2>/dev/null || true
    echo "  📦 backup: $backup"

    local tmp_rep tmp_clean
    tmp_rep="$(mktemp)"
    tmp_clean="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$tmp_rep' '$tmp_clean'" EXIT

    _repaired_key_lines "$AUTH_KEYS" > "$tmp_rep"

    # Dedup by fingerprint + drop unparsable
    declare -A _seen_fp=()
    local kept=0 dropped_bad=0 dropped_dup=0
    while IFS= read -r k || [[ -n "$k" ]]; do
        [[ -z "$k" ]] && continue
        local fp=""
        fp="$(_fingerprint_of_key "$k" || true)"
        if [[ -z "$fp" ]]; then
            dropped_bad=$((dropped_bad+1))
            continue
        fi
        if [[ -n "${_seen_fp[$fp]:-}" ]]; then
            dropped_dup=$((dropped_dup+1))
            continue
        fi
        _seen_fp[$fp]=1
        printf "%s\n" "$k" >> "$tmp_clean"
        kept=$((kept+1))
    done < "$tmp_rep"

    # Ensure self key
    local self_added=0
    if [[ -f "$LOCAL_KEY" ]]; then
        local self_key self_fp=""
        self_key="$(cat "$LOCAL_KEY" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        self_fp="$(_fingerprint_of_key "$self_key" || true)"
        if [[ -n "$self_fp" && -z "${_seen_fp[$self_fp]:-}" ]]; then
            printf "%s\n" "$self_key" >> "$tmp_clean"
            kept=$((kept+1))
            self_added=1
        fi
    else
        cn 226 b "  ⚠️  no local key: $LOCAL_KEY (generate: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_node -N '')"
    fi

    cp "$tmp_clean" "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    trap - EXIT
    rm -f "$tmp_rep" "$tmp_clean"

    echo "  ✅ repaired: $kept key(s) kept | splits joined | bad dropped: $dropped_bad | dup dropped: $dropped_dup | self added: $self_added"
    echo "  📄 $AUTH_KEYS"
    echo ""
}

# Fetch one remote pubkey (best-effort, short timeout)
_fetch_remote_pubkey() {
    local host="${1:-}" user="${2:-}" port="${3:-22}"
    local opts=(-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR)
    [[ -n "$user" ]] && opts+=(-l "$user")
    [[ "$port" != "22" ]] && opts+=(-p "$port")
    ssh "${opts[@]}" "$host" "cat ~/.ssh/id_ed25519_node.pub 2>/dev/null" 2>/dev/null | tr -d '\r' | head -1
}

# ── COLLECT (merge into vault — run on collector) ──
cmd_collect() {
    _banner
    _ensure_openssl || return 1

    local add_key="" fetch_host="" fetch_user="" fetch_port="22" scan_mesh=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --add) add_key="${2:-}"; shift 2 ;;
            --from) fetch_host="${2:-}"; shift 2 ;;
            --user) fetch_user="${2:-}"; shift 2 ;;
            --port) fetch_port="${2:-}"; shift 2 ;;
            --scan-mesh) scan_mesh=true; shift ;;
            --local-only) scan_mesh=false; shift ;;
            --help|-h)
                echo "Usage: $(basename "$0") collect [--add <key>] [--from <host> --user <u> --port <p>] [--scan-mesh]"
                echo "  Default: merge LOCAL key only (no SSH — safe when mesh is down)."
                echo "  --scan-mesh: also try every node in bootstrap/nodes/*.node.env."
                return 0 ;;
            *) cn 196 b "Unknown option: $1"; return 1 ;;
        esac
    done

    _git_pull_best_effort
    echo ""

    local tmp_merge=""
    tmp_merge="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$tmp_merge'" EXIT

    if [[ -f "$VAULT_FILE" ]]; then
        local cur_pass=""
        cur_pass="$(_get_pass "Current Vault Passphrase: ")"
        if echo "$cur_pass" | openssl enc -d -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" \
            -in "$VAULT_FILE" -out "$tmp_merge" -pass stdin 2>/dev/null; then
            cn 82 b "  ✅ loaded vault ($(grep -c '^ssh-' "$tmp_merge" 2>/dev/null || echo 0) key(s))"
        else
            cn 196 b "  ❌ vault decrypt failed — aborting (nothing overwritten)"
            trap - EXIT; rm -f "$tmp_merge"; return 1
        fi
    else
        { echo "# SSOT Pubkeys — $(date +%Y-%m-%d)"; echo "# One public key per line (managed by pubkey-corrector.sh)"; } > "$tmp_merge"
    fi

    # Candidate collector (fingerprint dedup against vault content)
    _merge_one_key() {
        local key="${1:-}" origin="${2:-local}"
        key="$(printf "%s" "$key" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ "$key" =~ $_KEY_TYPES ]] || { cn 226 b "  ⚠️  skip ($origin): not a key line"; return 0; }
        local fp=""
        fp="$(_fingerprint_of_key "$key" || true)"
        [[ -z "$fp" ]] && { cn 226 b "  ⚠️  skip ($origin): unparsable"; return 0; }
        if grep -q '^ssh-' "$tmp_merge" 2>/dev/null && _existing_fingerprints "$tmp_merge" | grep -qF "$fp"; then
            echo "  ⏭️  skip ($origin): already in vault [$fp]"
        else
            printf "%s\n" "$key" >> "$tmp_merge"
            cn 82 b "  ✅ merged ($origin): $(_key_comment "$key") [$fp]"
        fi
    }

    if [[ -n "$add_key" ]]; then
        _merge_one_key "$add_key" "--add"
    elif [[ -f "$LOCAL_KEY" ]]; then
        _merge_one_key "$(cat "$LOCAL_KEY")" "local"
    else
        cn 226 b "  ⚠️  no local key: $LOCAL_KEY"
    fi

    if [[ -n "$fetch_host" ]]; then
        local rk=""
        rk="$(_fetch_remote_pubkey "$fetch_host" "$fetch_user" "$fetch_port" || true)"
        [[ -n "$rk" ]] && _merge_one_key "$rk" "$fetch_host" || cn 196 b "  ❌ fetch failed: $fetch_host"
    fi

    if [[ "$scan_mesh" == "true" ]]; then
        echo ""
        cn 226 b "  🔍 scanning mesh nodes (best-effort)…"
        for node_file in "$SSOT/bootstrap/nodes"/*.node.env; do
            [[ -f "$node_file" ]] || continue
            # shellcheck source=/dev/null
            source "$node_file" 2>/dev/null || true
            local node_name="${node_file##*/}"
            node_name="${node_name%.node.env}"
            local upper
            upper="$(echo "$node_name" | tr '[:lower:]' '[:upper:]')"
            local host_var="NODE_${upper}_HOST" user_var="NODE_${upper}_USER" port_var="NODE_${upper}_PORT"
            local host="${!host_var:-}" user="${!user_var:-}" port="${!port_var:-22}"
            [[ "$node_name" == "window" && -z "$host" ]] && { host="${NODE_WIN_HOST:-}"; user="${NODE_WIN_USER:-}"; port="${NODE_WIN_PORT:-22}"; }
            [[ -z "$host" ]] && continue
            local rk2=""
            rk2="$(_fetch_remote_pubkey "$host" "$user" "$port" || true)"
            if [[ -n "$rk2" ]]; then
                _merge_one_key "$rk2" "$node_name"
            else
                echo "  ○ $node_name offline"
            fi
        done
    fi

    local total=0
    total="$(grep -c '^ssh-' "$tmp_merge" 2>/dev/null || echo 0)"
    if (( total == 0 )); then
        cn 196 b "❌ nothing to encrypt"
        trap - EXIT; rm -f "$tmp_merge"; return 1
    fi

    echo ""
    local new_pass=""
    new_pass="$(_get_pass "New Vault Passphrase: ")"
    if echo "$new_pass" | openssl enc -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" -salt \
        -in "$tmp_merge" -out "$VAULT_FILE" -pass stdin 2>/dev/null; then
        chmod 644 "$VAULT_FILE"
        trap - EXIT; rm -f "$tmp_merge"
        cn 82 b "✅ vault locked: $total key(s) → $VAULT_FILE"
        echo "  💡 next: git add core/pubkeys.enc && git commit && git push"
    else
        cn 196 b "❌ encrypt failed"
        trap - EXIT; rm -f "$tmp_merge"; return 1
    fi
}

# ── INSTALL (vault -> authorized_keys, fingerprint merge) ──
cmd_install() {
    _banner
    _ensure_openssl || return 1
    if [[ ! -f "$VAULT_FILE" ]]; then
        cn 196 b "❌ vault not found: $VAULT_FILE (collector must run collect + git push first)"
        return 1
    fi

    local pass tmp_keys=""
    pass="$(_get_pass "Vault Passphrase: ")"
    tmp_keys="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$tmp_keys'" EXIT
    if ! echo "$pass" | openssl enc -d -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" \
        -in "$VAULT_FILE" -out "$tmp_keys" -pass stdin 2>/dev/null; then
        cn 196 b "❌ decrypt failed — wrong passphrase?"
        trap - EXIT; rm -f "$tmp_keys"; return 1
    fi

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$AUTH_KEYS"
    local backup="${AUTH_KEYS}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$AUTH_KEYS" "$backup" 2>/dev/null || true
    chmod 600 "$backup" 2>/dev/null || true

    # Start from repaired local state, merge vault keys by fingerprint
    local tmp_base tmp_out=""
    tmp_base="$(mktemp)"
    tmp_out="$(mktemp)"
    _repaired_key_lines "$AUTH_KEYS" > "$tmp_base"
    cp "$tmp_base" "$tmp_out"
    declare -A _have_fp=()
    while IFS= read -r k || [[ -n "$k" ]]; do
        local fp=""
        fp="$(_fingerprint_of_key "$k" || true)"
        [[ -n "$fp" ]] && _have_fp[$fp]=1
    done < "$tmp_base"

    local added=0 skipped=0 bad=0
    while IFS= read -r key || [[ -n "$key" ]]; do
        key="$(printf "%s" "$key" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$key" || "$key" == \#* ]] && continue
        local fp2=""
        fp2="$(_fingerprint_of_key "$key" || true)"
        if [[ -z "$fp2" ]]; then
            bad=$((bad+1))
            continue
        fi
        if [[ -n "${_have_fp[$fp2]:-}" ]]; then
            skipped=$((skipped+1))
        else
            printf "%s\n" "$key" >> "$tmp_out"
            _have_fp[$fp2]=1
            added=$((added+1))
        fi
    done < "$tmp_keys"

    cp "$tmp_out" "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    rm -f "$tmp_base" "$tmp_out"
    trap - EXIT; rm -f "$tmp_keys"

    # Windows Administrators mirror (best-effort — needs elevation)
    local admin_path=""
    admin_path="$(_admin_auth_path || true)"
    if [[ -n "$admin_path" ]]; then
        if cp "$AUTH_KEYS" "$admin_path" 2>/dev/null; then
            echo "  ✅ mirrored to $admin_path"
        else
            cn 226 b "  ⚠️  cannot write $admin_path (run shell as Administrator to mirror)"
        fi
    fi

    echo ""
    cn 82 b "✅ installed: +$added | skipped: $skipped | bad in vault: $bad"
    echo "  📄 $AUTH_KEYS (backup: $backup)"
    echo ""
}

cmd_status() {
    _banner
    echo "📦 Vault:"
    if [[ -f "$VAULT_FILE" ]]; then
        echo "   EXISTS $VAULT_FILE ($(wc -c < "$VAULT_FILE" | tr -d ' ') bytes)"
    else
        echo "   NOT FOUND $VAULT_FILE"
    fi
    echo ""
    echo "🔑 Local:"
    if [[ -f "$LOCAL_KEY" ]]; then
        echo "   EXISTS $LOCAL_KEY [$(_key_comment "$(cat "$LOCAL_KEY")")]"
    else
        echo "   MISSING $LOCAL_KEY"
    fi
    if [[ -f "$AUTH_KEYS" ]]; then
        echo "   authorized_keys: $(grep -c '^ssh-' "$AUTH_KEYS" 2>/dev/null || echo 0) raw key-start line(s)"
    else
        echo "   authorized_keys: MISSING"
    fi
    echo ""
    echo "  next: audit | fix-local | collect | install"
    echo ""
}

case "${1:-}" in
    audit|check)            shift; cmd_audit "$@" ;;
    fix-local|fix|repair)   shift; cmd_fix_local "$@" ;;
    collect|lock|merge)     shift; cmd_collect "$@" ;;
    install|sync|distribute|unlock) shift; cmd_install "$@" ;;
    status)                 shift; cmd_status "$@" ;;
    *)
        _banner
        echo "Usage: $(basename "$0") <command>"
        echo ""
        echo "  audit       Read-only check (exit 1 when issues found)"
        echo "  fix-local   Repair this node's authorized_keys (backup + join splits + dedup by fingerprint + self key)"
        echo "  collect     Merge keys into vault (default: local only; --add <key> | --from <host> | --scan-mesh)"
        echo "  install     Install vault keys into authorized_keys (fingerprint merge)"
        echo "  status      Vault + local overview"
        echo ""
        echo "Vault workflow:"
        echo "  1. every node:  fix-local"
        echo "  2. collector:   collect --add \"<each pubkey>\"  (+ git push)"
        echo "  3. every node:  git pull + install"
        echo ""
        exit 0
        ;;
esac
