#!/usr/bin/env bash
# ============================================================
# 🛡️ ssh_audit.sh — SSOT SSH Audit & Self-Healing Utility
# ============================================================
# Infrastructure: ~/ssot/ (SSOT)
# Compatible: WSL2, Termux (Android/MuMu), Linux, Git-Bash
# Usage:
#   ./bootstrap/ssh_audit.sh          # รัน Audit ตรวจสอบอย่างเดียว (Read-only)
#   ./bootstrap/ssh_audit.sh --fix    # รัน Audit และแก้ไขให้อัตโนมัติ (Self-Healing)
#   ./bootstrap/ssh_audit.sh --test   # ทดสอบการเชื่อมต่อ SSH Mesh เบื้องต้น
#   ./bootstrap/ssh_audit.sh --help   # แสดงคู่มือการใช้งาน
# ============================================================

set -uo pipefail

# ────────────────────────────────────────────────────────────
# [1] SSOT BOOTSTRAP & DEPENDENCY LOADER
# ────────────────────────────────────────────────────────────
# ค้นหาตำแหน่ง Root ของโปรเจกต์ (SSOT) อย่างแม่นยำ ไม่ว่ารันจากที่ไหน
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSOT="${SSOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export SSOT

# ── Detect JOE_ENV ก่อน source 00-env.sh (00-env.sh ต้องการ $JOE_ENV ก่อนเสมอ) ──
# 00-env.sh ใช้ case "$JOE_ENV" ที่บรรทัดแรก → ต้อง set ก่อน
if [[ -z "${JOE_ENV:-}" ]]; then
    if [[ -d "/data/data/com.termux" ]]; then
        if getprop ro.product.model 2>/dev/null | grep -qiE '(MuMu|vphone)'; then
            export JOE_ENV="MUMU"
        else
            export JOE_ENV="TERMUX"
        fi
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        export JOE_ENV="WSL"
    elif [[ -n "${MSYSTEM:-}" ]] || [[ "${OSTYPE:-}" == "msys" ]]; then
        export JOE_ENV="GIT-BASH"
    else
        export JOE_ENV="WSL"
    fi
fi

# ── ตั้งค่า SSOT path vars inline (mirror joe.sh Step 1 เฉพาะ path เท่านั้น)  ──
# เหตุผล: source joe.sh เต็มจะ trigger ssh-agent eval, sshd start, ssot_load ──
# ซึ่ง side-effect ไม่ต้องการตอน audit แบบ standalone
# ── ตั้งค่า path vars ที่ 00-env.sh ต้องการ (mirror joe.sh Step 1+global) ──
# เหตุผล: 00-env.sh ใช้ $msync, $DASHBOARD_DIR, $hpc, $hwsl — ต้อง set ก่อน
# ทำ inline แทน source joe.sh เพื่อกัน side-effects (ssh-agent, sshd, ssot_load)
case "$JOE_ENV" in
    TERMUX|MUMU)
        export SSOT="/data/data/com.termux/files/home/ssot"
        export DASHBOARD_DIR="$HOME/dashboard"
        export MAIN_SYNC_DIR="$HOME/main_sync"
        export SSH_MUMU_PORT=8020
        export SSH_TERMUX_PORT=8022
        export SSH_WSL_PORT=22
        export SSH_WIN_PORT=22
        export SSH_PORT=8022
        ;;
    WSL)
        export SSOT="${SSOT:-$HOME/ssot}"
        export hpc="${hpc:-/mnt/c/Users/User}"
        export hwsl="${hwsl:-$HOME}"
        export DASHBOARD_DIR="${DASHBOARD_DIR:-$HOME/dashboard}"
        export MAIN_SYNC_DIR="${MAIN_SYNC_DIR:-$HOME/main_sync}"
        export SSH_MUMU_PORT=8020
        export SSH_TERMUX_PORT=8022
        export SSH_WSL_PORT=22
        export SSH_WIN_PORT=22
        export SSH_PORT=22
        ;;
    GIT-BASH)
        export SSOT="${SSOT:-$HOME/ssot}"
        export hpc="${hpc:-$HOME}"
        export hwsl="${hwsl:-//wsl.localhost/Ubuntu/home/usercivenz}"
        export DASHBOARD_DIR="${DASHBOARD_DIR:-$HOME/dashboard}"
        export MAIN_SYNC_DIR="${MAIN_SYNC_DIR:-$HOME/DESKTOP/main_sync}"
        export SSH_MUMU_PORT=8020
        export SSH_TERMUX_PORT=8022
        export SSH_WSL_PORT=22
        export SSH_WIN_PORT=22
        export SSH_PORT=22
        ;;
    *)
        export SSOT="${SSOT:-$HOME/ssot}"
        export DASHBOARD_DIR="${DASHBOARD_DIR:-$HOME/dashboard}"
        export MAIN_SYNC_DIR="${MAIN_SYNC_DIR:-$HOME/main_sync}"
        export SSH_MUMU_PORT=8020
        export SSH_TERMUX_PORT=8022
        export SSH_WSL_PORT=22
        export SSH_WIN_PORT=22
        export SSH_PORT=22
        ;;
esac
# Global derived vars (mirror joe.sh global section)
# Global derived vars (mirror joe.sh global section)
export SCRIPTS_PATH="$SSOT"
export COLOR_PATH="$SSOT"
export msync="$MAIN_SYNC_DIR"
export htm="/data/data/com.termux/files/home"
export OP_DIR="${HOME}"
export home="${HOME}"
# Other vars that 00-env.sh references from joe.sh
export nexus_vault="${nexus_vault:-$HOME/nexus_vault}"
export OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-$HOME/obsidian}"

# โหลด Environment Variables (SSOT) — หลัง path vars
# ใช้ set +u เพื่อกัน 00-env.sh crash จากตัวแปรที่ปกติ set ใน joe.sh
# (00-env.sh ถูก design ให้ source หลัง joe.sh เสมอ)
if [[ -f "$SSOT/bootstrap/00-env.sh" ]]; then
    set +u
    # shellcheck source=/dev/null
    source "$SSOT/bootstrap/00-env.sh" || true
    set -u
elif [[ -f "$HOME/ssot/bootstrap/00-env.sh" ]]; then
    set +u
    # shellcheck source=/dev/null
    source "$HOME/ssot/bootstrap/00-env.sh" || true
    set -u
fi




# โหลด Color Engine V3/V4 (SSOT)
if [[ -f "$SSOT/core/01-colors.sh" ]]; then
    # shellcheck source=/dev/null
    source "$SSOT/core/01-colors.sh"
fi

# Fallback สำหรับระบบสี กรณีรันแยกเดี่ยวและไม่ได้โหลด 01-colors.sh
if ! declare -f cn >/dev/null 2>&1; then
    cn() { echo "$*"; }
    c()  { printf "%s" "$*"; }
fi

# โหลด SSH Toolkit Helper (Universal Clipboard & Key Helpers)
if [[ -f "$SSOT/core/ssh_toolkit.sh" ]]; then
    # shellcheck source=/dev/null
    source "$SSOT/core/ssh_toolkit.sh"
fi

# ────────────────────────────────────────────────────────────
# [2] SSOT PATHS & NODE MAPPING
# ────────────────────────────────────────────────────────────
SSH_DIR="${HOME}/.ssh"
KEY_NODE="${KEY_NODE:-${SSH_DIR}/id_ed25519_node}"
CONFIG_FILE="${SSH_DIR}/config"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

# กำหนดตัวแปร Node Registry จาก SSOT (00-env.sh) พร้อม Fallback ป้องกันค่าว่าง
NODE_WSL_HOST="${NODE_WSL_HOST:-wsl}"
NODE_WSL_USER="${NODE_WSL_USER:-usercivenz}"
NODE_WSL_PORT="${NODE_WSL_PORT:-22}"

NODE_OPPO_HOST="${NODE_OPPO_HOST:-oppo}"
NODE_OPPO_USER="${NODE_OPPO_USER:-u0_a88}"
NODE_OPPO_PORT="${NODE_OPPO_PORT:-8023}"

NODE_MUMU_HOST="${NODE_MUMU_HOST:-mumu}"
NODE_MUMU_USER="${NODE_MUMU_USER:-u0_a62}"
NODE_MUMU_PORT="${NODE_MUMU_PORT:-8020}"

NODE_TERMUX_HOST="${NODE_TERMUX_HOST:-termux}"
NODE_TERMUX_USER="${NODE_TERMUX_USER:-u0_a331}"
NODE_TERMUX_PORT="${NODE_TERMUX_PORT:-8022}"

NODE_ACODEX_HOST="${NODE_ACODEX_HOST:-termux}"
NODE_ACODEX_USER="${NODE_ACODEX_USER:-root}"
NODE_ACODEX_PORT="${NODE_ACODEX_PORT:-8021}"

NODE_WIN_HOST="${NODE_WIN_HOST:-window}"
NODE_WIN_USER="${NODE_WIN_USER:-User}"
NODE_WIN_PORT="${NODE_WIN_PORT:-22}"

# ตัวนับผลลัพธ์การ Audit
AUDIT_ERRORS=0
AUDIT_WARNINGS=0
AUDIT_PASSED=0

# Helper แสดงสถานะตามมาตรฐาน V4 (ใช้ cn จาก 01-colors.sh)
log_pass() {
    c 46 b "[PASS] "
    cn 252 "$1"
    AUDIT_PASSED=$((AUDIT_PASSED + 1))
}

log_warn() {
    c 226 b "[WARN] "
    cn 226 "$1"
    AUDIT_WARNINGS=$((AUDIT_WARNINGS + 1))
}

log_fail() {
    c 196 b "[FAIL] "
    cn 196 "$1"
    AUDIT_ERRORS=$((AUDIT_ERRORS + 1))
}

log_info() {
    c 75 b "[INFO] "
    cn 252 "$1"
}

log_section() {
    echo
    c 45 b "── "
    c 255 b "$1"
    cn 45 b " ──"
}

# ────────────────────────────────────────────────────────────
# [3] HELPER: PERMISSION GETTER (CROSS-PLATFORM)
# ────────────────────────────────────────────────────────────
# อ่าน Permission ตัวเลข 3-4 หลัก (เช่น 700, 600) รองรับทั้ง Linux และ macOS
get_file_perm() {
    local target="$1"
    if [[ ! -e "$target" ]]; then
        echo "000"
        return
    fi
    if stat -c "%a" "$target" 2>/dev/null; then
        return
    fi
    stat -f "%Lp" "$target" 2>/dev/null || echo "000"
}

# ────────────────────────────────────────────────────────────
# [4] AUDIT FUNCTIONS
# ────────────────────────────────────────────────────────────

audit_permissions() {
    log_section "1. SSH Directory & File Permissions Audit"

    # 1.1 เช็คไดเรกทอรี ~/.ssh
    if [[ -d "$SSH_DIR" ]]; then
        local perm
        perm="$(get_file_perm "$SSH_DIR")"
        if [[ "$perm" == "700" ]]; then
            log_pass "~/.ssh directory exists with secure permissions ($perm)"
        else
            log_fail "~/.ssh permission is $perm (Required: 700)"
        fi
    else
        log_fail "~/.ssh directory does not exist!"
    fi

    # 1.2 เช็ค authorized_keys
    if [[ -f "$AUTH_KEYS" ]]; then
        local perm
        perm="$(get_file_perm "$AUTH_KEYS")"
        if [[ "$perm" == "600" || "$perm" == "644" ]]; then
            log_pass "~/.ssh/authorized_keys exists with permissions ($perm)"
        else
            log_warn "~/.ssh/authorized_keys permission is $perm (Recommended: 600)"
        fi
    else
        log_warn "~/.ssh/authorized_keys not found (OK if this node accepts no incoming SSH)"
    fi

    # 1.3 เช็ค SSH config
    if [[ -f "$CONFIG_FILE" ]]; then
        local perm
        perm="$(get_file_perm "$CONFIG_FILE")"
        if [[ "$perm" == "600" ]]; then
            log_pass "~/.ssh/config exists with secure permissions ($perm)"
        else
            log_warn "~/.ssh/config permission is $perm (Recommended: 600)"
        fi
    else
        log_warn "~/.ssh/config does not exist yet"
    fi

    # 1.4 เช็ค Private Keys permissions (ต้องเป็น 600 เสมอ)
    if [[ -d "$SSH_DIR" ]]; then
        local priv_key
        while IFS= read -r priv_key; do
            [[ -z "$priv_key" ]] && continue
            local perm
            perm="$(get_file_perm "$priv_key")"
            if [[ "$perm" == "600" ]]; then
                log_pass "Private key $(basename "$priv_key") has permission ($perm)"
            else
                log_fail "Private key $(basename "$priv_key") has insecure permission ($perm) - Required: 600"
            fi
        done < <(find "$SSH_DIR" -maxdepth 1 -type f -name "id_*" ! -name "*.pub" 2>/dev/null)
    fi
}

audit_keys() {
    log_section "2. Node Identity Key Audit (KEY_NODE)"

    if [[ -f "$KEY_NODE" ]]; then
        log_pass "Node Identity private key found: $KEY_NODE"
        if [[ -f "${KEY_NODE}.pub" ]]; then
            log_pass "Node Identity public key found: ${KEY_NODE}.pub"
        else
            log_warn "Public key missing for ${KEY_NODE} (Self-heal can regenerate it)"
        fi
    else
        log_fail "Node Identity private key NOT found: $KEY_NODE (Required for Mesh connection)"
    fi
}

audit_agent() {
    log_section "3. SSH-Agent & Key Loading Audit"

    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
        log_warn "SSH_AUTH_SOCK environment variable is not set (ssh-agent is not running)"
        return
    fi

    if ! ssh-add -l &>/dev/null; then
        local exit_code=$?
        if [[ $exit_code -eq 1 ]]; then
            log_warn "ssh-agent is running but has no loaded identities"
        else
            log_fail "ssh-agent is unresponsive or unreachable"
        fi
        return
    fi

    log_pass "ssh-agent is active and responding"

    # ตรวจสอบว่า KEY_NODE ถูกโหลดเข้า Agent หรือยัง
    if [[ -f "$KEY_NODE" ]]; then
        local fp
        fp="$(ssh-keygen -lf "$KEY_NODE" 2>/dev/null | awk '{print $2}')"
        if [[ -n "$fp" ]] && ssh-add -l 2>/dev/null | grep -qF "$fp"; then
            log_pass "KEY_NODE ($fp) is loaded in ssh-agent"
        else
            log_warn "KEY_NODE is NOT loaded in ssh-agent"
        fi
    fi
}

audit_config() {
    log_section "4. SSH Config Mesh Audit (~/.ssh/config)"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_fail "SSH config file ($CONFIG_FILE) is missing"
        return
    fi

    # เช็คว่ามี Block Mesh หรือไม่
    if grep -q "JOE_SSOT_MESH_START" "$CONFIG_FILE" 2>/dev/null; then
        log_pass "Managed SSOT Mesh block marker found"
    elif grep -q "id_ed25519_node" "$CONFIG_FILE" 2>/dev/null; then
        log_pass "Legacy SSH mesh configuration found (recommend upgrade to managed block)"
    else
        log_warn "No SSOT mesh configuration detected in $CONFIG_FILE"
    fi

    # เช็ครายชื่อ Host ใน Mesh ทีละ Node
    local nodes=("wsl" "oppo" "mumu" "termux" "acodex" "window")
    for host_alias in "${nodes[@]}"; do
        if grep -qE "^Host[[:space:]]+.*\\b${host_alias}\\b" "$CONFIG_FILE" 2>/dev/null; then
            log_pass "Host alias '${host_alias}' is defined in config"
        else
            log_warn "Host alias '${host_alias}' is MISSING from config"
        fi
    done

    # ตรวจสอบ Duplicate Host entries
    local dupes
    dupes=$(grep -E "^Host[[:space:]]+" "$CONFIG_FILE" | awk '{print $2}' | sort | uniq -d)
    if [[ -n "$dupes" ]]; then
        log_warn "Duplicate Host definitions found in config: $(echo "$dupes" | tr '\n' ' ')"
    else
        log_pass "No duplicate Host definitions found"
    fi
}

audit_service() {
    log_section "5. Local SSH Service Audit"

    local current_env="${JOE_ENV:-}"
    if [[ -z "$current_env" ]]; then
        if grep -qi microsoft /proc/version 2>/dev/null; then
            current_env="WSL"
        elif [[ -d "/data/data/com.termux" ]]; then
            current_env="TERMUX"
        else
            current_env="LINUX"
        fi
    fi

    log_info "Detected OS Environment: $current_env"

    if [[ "$current_env" == "WSL" ]]; then
        if service ssh status >/dev/null 2>&1; then
            log_pass "WSL OpenSSH service is running"
        else
            log_warn "WSL OpenSSH service is stopped (Start with: sudo service ssh start)"
        fi
    elif [[ "$current_env" == "TERMUX" || "$current_env" == "MUMU" ]]; then
        local ssh_port="${SSH_PORT:-8022}"
        if pgrep -f "sshd.*-p.*${ssh_port}" >/dev/null 2>&1 || pgrep -x sshd >/dev/null 2>&1; then
            log_pass "Termux sshd daemon is running on port ${ssh_port}"
        else
            log_warn "Termux sshd daemon is not running (Start with: sshd -p ${ssh_port})"
        fi
    else
        log_info "Skipping local daemon check for $current_env"
    fi
}

# ────────────────────────────────────────────────────────────
# [5] SELF-HEALING / FIX FUNCTIONS
# ────────────────────────────────────────────────────────────

fix_all() {
    log_section "🔧 Running SSOT SSH Self-Healing (Fix Mode)"

    # 1. ซ่อมสิทธิ์ไดเรกทอรีและไฟล์
    log_info "Fixing directory and file permissions..."
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    if [[ -f "$AUTH_KEYS" ]]; then
        chmod 600 "$AUTH_KEYS"
    else
        touch "$AUTH_KEYS"
        chmod 600 "$AUTH_KEYS"
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        chmod 600 "$CONFIG_FILE"
    fi

    # ปรับสิทธิ์ Private keys เป็น 600 และ Public keys เป็น 644
    find "$SSH_DIR" -maxdepth 1 -type f -name "id_*" ! -name "*.pub" -exec chmod 600 {} + 2>/dev/null || true
    find "$SSH_DIR" -maxdepth 1 -type f -name "*.pub" -exec chmod 644 {} + 2>/dev/null || true
    log_pass "File permissions healed (700 for dir, 600 for keys/config, 644 for pub)"

    # 2. สร้าง Key ถ้ายังไม่มี
    if [[ ! -f "$KEY_NODE" ]]; then
        log_info "Generating missing node key: $KEY_NODE"
        if declare -f ssh_kgen >/dev/null 2>&1; then
            ssh_kgen node
        else
            ssh-keygen -t ed25519 -C "node" -f "$KEY_NODE" -N ""
            chmod 600 "$KEY_NODE"
            chmod 644 "${KEY_NODE}.pub"
        fi
        log_pass "Generated $KEY_NODE successfully"
    else
        # Self-heal: สร้าง public key ใหม่ถ้าทำหาย
        if [[ ! -f "${KEY_NODE}.pub" ]]; then
            log_info "Regenerating missing public key from private key..."
            ssh-keygen -y -f "$KEY_NODE" > "${KEY_NODE}.pub" 2>/dev/null || true
            chmod 644 "${KEY_NODE}.pub"
            log_pass "Restored ${KEY_NODE}.pub"
        fi
    fi

    # 3. จัดการ ssh-agent และโหลด Key
    if [[ -z "${SSH_AUTH_SOCK:-}" ]] || ! ssh-add -l &>/dev/null; then
        log_info "Starting new ssh-agent session..."
        eval "$(ssh-agent -s)" >/dev/null 2>&1
    fi
    if [[ -f "$KEY_NODE" ]]; then
        ssh-add "$KEY_NODE" 2>/dev/null || true
        log_pass "Added $KEY_NODE to ssh-agent"
    fi

    # 4. อัปเดต ~/.ssh/config แบบ Idempotent Managed Block
    log_info "Updating ~/.ssh/config with SSOT Mesh..."
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"

    # Backup config เดิมไว้เสมอ
    local backup_config="${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$backup_config"
    log_info "Backup created: $backup_config"

    # เตรียมเนื้อหา Block SSOT Mesh (ดึงค่าจากตัวแปร SSOT ทั้งหมด ไม่ Hardcode)
    # Pre-define crypto strings เป็น local vars ก่อน เพื่อกัน CRLF/line-wrap ตัดบรรทัดยาว
    local _kex _hka _pka _ciphers _macs
    _kex="curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521"
    _hka="ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256,ssh-rsa,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521"
    _pka="ssh-ed25519,rsa-sha2-512,rsa-sha2-256,ssh-rsa"
    _ciphers="chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr"
    _macs="hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256"

    local mesh_block
    mesh_block=$(cat <<EOF
# >>> JOE_SSOT_MESH_START >>>
# SSOT Mesh — Multi-Node Topology
# Managed automatically by bootstrap/ssh_audit.sh
# Generated: $(date +'%Y-%m-%d %H:%M:%S')

# Global Modern Cryptography Settings
Host *
    KexAlgorithms ${_kex}
    HostKeyAlgorithms ${_hka}
    PubkeyAcceptedAlgorithms ${_pka}
    Ciphers ${_ciphers}
    MACs ${_macs}

Host wsl
    HostName ${NODE_WSL_HOST}
    User ${NODE_WSL_USER}
    Port ${NODE_WSL_PORT}
    IdentityFile ~/.ssh/id_ed25519_node
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 5
    PreferredAuthentications publickey

Host oppo
    HostName ${NODE_OPPO_HOST}
    User ${NODE_OPPO_USER}
    Port ${NODE_OPPO_PORT}
    IdentityFile ~/.ssh/id_ed25519_node
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 5
    PreferredAuthentications publickey

Host mumu
    HostName ${NODE_MUMU_HOST}
    User ${NODE_MUMU_USER}
    Port ${NODE_MUMU_PORT}
    IdentityFile ~/.ssh/id_ed25519_node
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 5
    PreferredAuthentications publickey

Host termux
    HostName ${NODE_TERMUX_HOST}
    User ${NODE_TERMUX_USER}
    Port ${NODE_TERMUX_PORT}
    IdentityFile ~/.ssh/id_ed25519_node
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 5
    PreferredAuthentications publickey

Host acodex
    HostName ${NODE_ACODEX_HOST}
    User ${NODE_ACODEX_USER}
    Port ${NODE_ACODEX_PORT}
    IdentityFile ~/.ssh/id_ed25519_node
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 5
    PreferredAuthentications publickey

Host window
    HostName ${NODE_WIN_HOST}
    User ${NODE_WIN_USER}
    Port ${NODE_WIN_PORT}
    IdentityFile ~/.ssh/id_ed25519_node
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 5
    PreferredAuthentications publickey
# <<< JOE_SSOT_MESH_END <<<
EOF
)

    # เขียน SSOT Mesh block เป็น config ทั้งหมด (idempotent — backup ไว้แล้วข้างบน)
    # หมายเหตุ: ไม่เก็บ content เดิมเพราะ:
    #   1. Backup ถูกสร้างไว้ก่อนทุกครั้ง
    #   2. ทุก host entry ใน Mesh ถูก define ครบใน SSOT block แล้ว
    #   3. ป้องกัน duplicate Host entries จาก legacy blocks
    printf '%s\n' "$mesh_block" > "$CONFIG_FILE"


    chmod 600 "$CONFIG_FILE"
    log_pass "SSH config updated successfully"

    # 5. Copy Public Key ไปยัง Clipboard อัตโนมัติ (ถ้ามี Helper)
    if [[ -f "${KEY_NODE}.pub" ]]; then
        local pub_content
        pub_content="$(cat "${KEY_NODE}.pub")"
        if declare -f cb_copy >/dev/null 2>&1; then
            if cb_copy "$pub_content" 2>/dev/null; then
                log_info "Public key copied to clipboard via cb_copy"
            fi
        fi
        log_info "Public key: $pub_content"
    fi

    echo
    c 46 b "✨ Self-healing completed successfully!"
    echo
}

# ────────────────────────────────────────────────────────────
# [6] TEST REACHABILITY FUNCTION
# ────────────────────────────────────────────────────────────

test_mesh() {
    log_section "🌐 Testing Mesh Reachability (Non-blocking)"
    local nodes=("wsl" "oppo" "mumu" "termux" "acodex" "window")

    for node in "${nodes[@]}"; do
        c 252 "  Testing connection to "
        c 81 b "${node}"
        c 252 "... "
        if ssh -o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=accept-new "$node" exit 2>/dev/null; then
            cn 46 b "[ONLINE - AUTH OK]"
        elif nc -z -w 1 "$node" 22 2>/dev/null || nc -z -w 1 "$node" 8022 2>/dev/null || nc -z -w 1 "$node" 8023 2>/dev/null; then
            cn 226 b "[PORT OPEN - AUTH PENDING]"
        else
            cn 244 "[OFFLINE / UNREACHABLE]"
        fi
    done
}

# ────────────────────────────────────────────────────────────
# [7] MAIN CLI DISPATCHER
# ────────────────────────────────────────────────────────────

show_help() {
    echo "Usage: $(basename "$0") [OPTION]"
    echo
    echo "Options:"
    echo "  (no options)   Run non-destructive SSH audit and generate report"
    echo "  --fix, -f      Audit and automatically self-heal permissions, keys, and config"
    echo "  --test, -t     Quick reachability check to all configured mesh nodes"
    echo "  --help, -h     Show this help message"
    echo
}

main() {
    local action="${1:-audit}"

    case "$action" in
        --help|-h|help)
            show_help
            return 0
            ;;
        --fix|-f|fix)
            fix_all
            echo
            # รัน Audit ซ้ำหลังแก้ไข เพื่อยืนยันผลลัพธ์
            main audit
            return 0
            ;;
        --test|-t|test)
            test_mesh
            return 0
            ;;
        audit|--check|-c|"")
            audit_permissions
            audit_keys
            audit_agent
            audit_config
            audit_service

            echo
            c 255 b "═══════════════════════════════════════════════════════"
            echo
            c 255 b " 📊 AUDIT SUMMARY: "
            c 46 b "PASSED: ${AUDIT_PASSED}  "
            c 226 b "WARNINGS: ${AUDIT_WARNINGS}  "
            cn 196 b "ERRORS: ${AUDIT_ERRORS}"
            c 255 b "═══════════════════════════════════════════════════════"
            echo

            if [[ $AUDIT_ERRORS -gt 0 || $AUDIT_WARNINGS -gt 0 ]]; then
                c 226 "💡 Tip: Run "
                c 81 b "./bootstrap/ssh_audit.sh --fix"
                cn 226 " to automatically heal all issues."
            else
                cn 46 b "🎉 SSH configuration is in perfect state!"
            fi
            ;;
        *)
            cn 196 b "Unknown option: $action"
            show_help
            return 1
            ;;
    esac
}

main "$@"
