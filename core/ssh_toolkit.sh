#!/usr/bin/env bash
# ============================================================
# 🛠️ SSH TOOLKIT — Production Multi-Node & Key Management
# ============================================================
# Part of SSOT Infrastructure (~/ssot/)
# Compatible: WSL (Ubuntu), Termux (Android/MuMu), Linux, macOS, Git-Bash
# Supported Shells: Bash 4+, Zsh
#
# ------------------------------------------------------------
# 📖 OVERVIEW & FEATURES (ภาพรวมฟีเจอร์หลัก)
# ------------------------------------------------------------
# 1. 📋 Universal Clipboard (cb_copy / cb_read)
#    - คัดลอก/อ่าน Clipboard ข้าม Platform อัตโนมัติ (WSL, Termux, Linux, Mac)
#    - รองรับทั้ง Argument ตรงๆ และ Stdin Pipe (|)
#
# 2. 🔑 SSH Key Generator (ssh_kgen)
#    - สร้าง Ed25519 SSH Key สำหรับ GitHub/GitLab หรือ Server ทั่วไป
#    - Self-Healing: สร้าง Public Key (.pub) ให้อัตโนมัติถ้าทำหาย
#    - ปรับสิทธิ์โฟลเดอร์ ~/.ssh (700) และ Private Key (600) ให้ปลอดภัย
#    - อัปเดต ~/.ssh/config ให้อัตโนมัติแบบ Idempotent (ไม่เขียนซ้ำ)
#    - โหลด Key เข้า ssh-agent ทันที (ไม่เปิด Process ซ้ำซ้อน)
#    - Copy Public Key ลง OS Clipboard พร้อม Paste ใช้งาน
#
# 3. 📥 SSH Authorized Keys Installer (ssh_kadd)
#    - ติดตั้ง Public Key เข้า ~/.ssh/authorized_keys บนเครื่องเป้าหมาย
#    - รองรับ Input หลากหลาย: จาก Clipboard, String, File หรือ Stdin Pipe
#    - ตรวจสอบความถูกต้องของ Key (Ed25519, RSA, ECDSA, SK-Keys)
#    - ตรวจจับ Key ซ้ำผ่าน Fingerprint (แม้ Comment ต่างกันก็ไม่ใส่ซ้ำ)
#    - Auto-Backup: สำรอง authorized_keys.bak.YYYYMMDD_HHMMSS ก่อนแก้เสมอ
#    - Trailing Newline Guard: ป้องกัน Key บรรทัดติดกันจนพัง
#
# ------------------------------------------------------------
# 🚀 USAGE EXAMPLES (ตัวอย่างการใช้งาน)
# ------------------------------------------------------------
# [1] สร้าง Key สำหรับ GitHub (Default):
#     $ ssh_kgen dev-pc
#     -> ผลลัพธ์:
#        Key file: ~/.ssh/id_ed25519_dev-pc
#        Host alias: github-dev-pc (HostName github.com, User git)
#        Public key ถูกคัดลอกลง Clipboard เรียบร้อย นำไปวางใน GitHub ได้ทันที
#
# [2] สร้าง Key สำหรับ Server หรือ Remote Node ทั่วไป:
#     $ ssh_kgen my-vps 192.168.1.100 root
#     -> ผลลัพธ์:
#        Key file: ~/.ssh/id_ed25519_my-vps
#        Host alias: my-vps (HostName 192.168.1.100, User root)
#        เชื่อมต่อได้ทันทีด้วย: ssh my-vps
#
# [3] นำ Public Key ไปติดตั้งบนเครื่องปลายทาง (รันที่เครื่องเป้าหมาย):
#     - แบบที่ 1: ดึงจาก Clipboard โดยตรง (สะดวกที่สุด)
#       $ ssh_kadd
#
#     - แบบที่ 2: ระบุ String ของ Public Key
#       $ ssh_kadd "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@host"
#
#     - แบบที่ 3: ระบุ Path ของไฟล์ .pub
#       $ ssh_kadd /tmp/id_ed25519_dev.pub
#
#     - แบบที่ 4: ส่งผ่าน Stdin Pipe
#       $ cat id_ed25519.pub | ssh_kadd
#
# [4] Clipboard Helpers:
#     $ echo "hello world" | cb_copy
#     $ cb_copy "important-token"
#     $ token=$(cb_read)
# ============================================================

# ============================================================
# 1. Clipboard Helpers (Universal Cross-Platform)
# ============================================================
# Supports: Argument ($1) and Standard Input (stdin pipe)
# Platforms: WSL (clip.exe / powershell.exe), Termux, Wayland, X11, macOS

cb_copy() {
    local input="${1:-}"

    # Read from stdin if no argument provided
    if [[ -z "$input" ]]; then
        if [[ ! -t 0 ]]; then
            input="$(cat)"
        fi
    fi

    if [[ -z "$input" ]]; then
        return 1
    fi

    # 1. WSL / Windows native clip (Fastest for WSL)
    if command -v clip.exe &>/dev/null; then
        printf '%s' "$input" | clip.exe 2>/dev/null && return 0
    fi

    # 2. Termux (Android / MuMu)
    if command -v termux-clipboard-set &>/dev/null; then
        if command -v timeout &>/dev/null; then
            printf '%s' "$input" | timeout 1 termux-clipboard-set 2>/dev/null && return 0
        else
            ( printf '%s' "$input" | termux-clipboard-set 2>/dev/null ) &
            local _cb_pid=$!
            ( sleep 1 && kill -9 "$_cb_pid" 2>/dev/null ) &
            wait "$_cb_pid" 2>/dev/null && return 0
        fi
    fi

    # 3. Wayland (Linux)
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy &>/dev/null; then
        printf '%s' "$input" | wl-copy 2>/dev/null && return 0
    fi

    # 4. X11 (Linux)
    if command -v xclip &>/dev/null; then
        printf '%s' "$input" | xclip -selection clipboard 2>/dev/null && return 0
    elif command -v xsel &>/dev/null; then
        printf '%s' "$input" | xsel --clipboard --input 2>/dev/null && return 0
    fi

    # 5. macOS
    if command -v pbcopy &>/dev/null; then
        printf '%s' "$input" | pbcopy 2>/dev/null && return 0
    fi

    # 6. PowerShell fallback
    if command -v powershell.exe &>/dev/null; then
        printf '%s' "$input" |
            powershell.exe -NoProfile -Command \
            '$input = [Console]::In.ReadToEnd(); Set-Clipboard -Value $input' \
            2>/dev/null && return 0
    fi

    return 1
}

cb_read() {
    # 1. Termux (Android / MuMu)
    if command -v termux-clipboard-get &>/dev/null; then
        if command -v timeout &>/dev/null; then
            timeout 1 termux-clipboard-get 2>/dev/null && return 0
        else
            termux-clipboard-get 2>/dev/null &
            local _cbr_pid=$!
            ( sleep 1 && kill -9 "$_cbr_pid" 2>/dev/null ) &
            wait "$_cbr_pid" 2>/dev/null && return 0
        fi
    fi

    # 2. Wayland (Linux)
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-paste &>/dev/null; then
        wl-paste --no-newline 2>/dev/null && return 0
    fi

    # 3. WSL / Windows (PowerShell)
    if command -v powershell.exe &>/dev/null; then
        powershell.exe -NoProfile -Command "Get-Clipboard" 2>/dev/null |
            tr -d '\r'
        return 0
    fi

    # 4. X11 (Linux)
    if command -v xclip &>/dev/null; then
        xclip -selection clipboard -o 2>/dev/null && return 0
    elif command -v xsel &>/dev/null; then
        xsel --clipboard --output 2>/dev/null && return 0
    fi

    # 5. macOS
    if command -v pbpaste &>/dev/null; then
        pbpaste 2>/dev/null && return 0
    fi

    return 1
}

# ============================================================
# 2. SSH Key Generator
# ============================================================
# Usage:
#   ssh_kgen <machine_or_alias> [target_host] [ssh_user]
# ============================================================

ssh_kgen() {
    local machine="${1:-}"
    local target_host="${2:-github.com}"
    local target_user="${3:-}"

    # --------------------------------------------------------
    # 1. Validate argument
    # --------------------------------------------------------
    if [[ -z "$machine" ]]; then
        echo "Error: Please specify machine/identifier name." >&2
        echo "Usage: ssh_kgen <machine_name> [target_host] [ssh_user]" >&2
        return 1
    fi

    # Prevent path injection / malformed SSH config
    local name_regex='^[a-zA-Z0-9_-]+$'
    if [[ ! "$machine" =~ $name_regex ]]; then
        echo "Error: Invalid machine name '$machine'." >&2
        echo "Allowed characters: A-Z a-z 0-9 _ -" >&2
        return 1
    fi

    # Resolve default user and host alias based on target
    local host_alias
    if [[ "$target_host" == "github.com" ]]; then
        target_user="${target_user:-git}"
        host_alias="github-${machine}"
    elif [[ "$target_host" == "gitlab.com" ]]; then
        target_user="${target_user:-git}"
        host_alias="gitlab-${machine}"
    else
        target_user="${target_user:-${USER:-root}}"
        host_alias="${machine}"
    fi

    # --------------------------------------------------------
    # 2. Paths
    # --------------------------------------------------------
    local ssh_dir="$HOME/.ssh"
    local keyfile="$ssh_dir/id_ed25519_${machine}"
    local pubfile="${keyfile}.pub"
    local config_file="$ssh_dir/config"

    # --------------------------------------------------------
    # 3. Dependencies
    # --------------------------------------------------------
    if ! command -v ssh-keygen &>/dev/null; then
        echo "Error: ssh-keygen not found." >&2
        return 1
    fi

    if ! command -v ssh-add &>/dev/null; then
        echo "Error: ssh-add not found." >&2
        return 1
    fi

    # --------------------------------------------------------
    # 4. Prepare ~/.ssh
    # --------------------------------------------------------
    mkdir -p "$ssh_dir" || {
        echo "Error: Cannot create $ssh_dir" >&2
        return 1
    }
    chmod 700 "$ssh_dir"

    # --------------------------------------------------------
    # 5. Generate / repair key
    # --------------------------------------------------------
    if [[ -f "$keyfile" ]]; then
        echo "SSH private key already exists:"
        echo "  $keyfile"

        # Private key exists but public key doesn't
        if [[ ! -f "$pubfile" ]]; then
            echo "Public key missing. Rebuilding..."
            ssh-keygen -y -f "$keyfile" > "$pubfile" 2>/dev/null || {
                echo "Error: Failed to rebuild public key." >&2
                return 1
            }
        fi
    else
        echo "Generating new Ed25519 key..."
        ssh-keygen \
            -t ed25519 \
            -C "${machine}@$(hostname 2>/dev/null || echo 'local')" \
            -f "$keyfile" \
            -N "" || {
                echo "Error: Failed to generate SSH key." >&2
                return 1
            }

        echo "Generated:"
        echo "  $keyfile"
    fi

    # --------------------------------------------------------
    # 6. Secure permissions
    # --------------------------------------------------------
    chmod 600 "$keyfile"
    [[ -f "$pubfile" ]] && chmod 644 "$pubfile"

    # --------------------------------------------------------
    # 7. Validate public key
    # --------------------------------------------------------
    if [[ ! -s "$pubfile" ]]; then
        echo "Error: Public key is missing or empty." >&2
        return 1
    fi

    local pub_key
    pub_key="$(cat "$pubfile")"

    local ed25519_prefix_regex='^ssh-ed25519[[:space:]]+'
    if [[ ! "$pub_key" =~ $ed25519_prefix_regex ]]; then
        echo "Error: Invalid Ed25519 public key format." >&2
        return 1
    fi

    # --------------------------------------------------------
    # 8. Start / validate ssh-agent (Defensive & Idempotent)
    # --------------------------------------------------------
    local agent_status=0
    ssh-add -l >/dev/null 2>&1 || agent_status=$?

    if [[ -z "${SSH_AUTH_SOCK:-}" || $agent_status -ge 2 ]]; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || {
            echo "Warning: Could not start ssh-agent." >&2
        }
    fi

    # --------------------------------------------------------
    # 9. Add key to agent
    # --------------------------------------------------------
    if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
        ssh-add "$keyfile" 2>/dev/null || {
            echo "Warning: Failed to add key to ssh-agent." >&2
        }
    fi

    # --------------------------------------------------------
    # 10. SSH config
    # --------------------------------------------------------
    touch "$config_file"
    chmod 600 "$config_file"

    if ! grep -qE "^Host[[:space:]]+${host_alias}([[:space:]]|$)" "$config_file"; then
        if [[ -s "$config_file" ]] && [[ -n "$(tail -c 1 "$config_file")" ]]; then
            printf '\n' >> "$config_file"
        fi

        cat >> "$config_file" <<CONFIG_ENTRY

Host ${host_alias}
  HostName ${target_host}
  User ${target_user}
  IdentityFile ${keyfile}
  IdentitiesOnly yes
CONFIG_ENTRY
        echo "Added SSH Host entry: $host_alias"
    else
        echo "SSH Host entry already exists: $host_alias"
    fi

    # --------------------------------------------------------
    # 11. Copy public key
    # --------------------------------------------------------
    if cb_copy "$pub_key"; then
        echo
        echo "✓ Public key copied to clipboard."
    else
        echo
        echo "⚠️  Clipboard unavailable. Public key printed below."
    fi

    # --------------------------------------------------------
    # 12. Display result
    # --------------------------------------------------------
    echo
    echo "===================================================="
    echo " SSH KEY READY"
    echo "===================================================="
    echo "Machine  : $machine"
    echo "Host     : $target_host"
    echo "User     : $target_user"
    echo "Alias    : $host_alias"
    echo "Key      : $keyfile"
    echo "Config   : $config_file"
    echo
    echo "Public key:"
    echo "$pub_key"
    echo "===================================================="
    case "$target_host" in
        github.com|gitlab.com)
            echo
            echo "Remote URL:"
            echo "${target_user}@${host_alias}:username/repository.git"
            ;;
        *)
            echo
            echo "Connect command:"
            echo "ssh ${host_alias}"
            ;;
    esac
}

# ============================================================
# 3. SSH Authorized Keys Installer
# Run this function ON THE TARGET MACHINE
# ============================================================
# Usage:
#   ssh_kadd                       # Reads from clipboard
#   ssh_kadd "ssh-ed25519 AAAA..." # Direct public key string
#   ssh_kadd /path/to/key.pub      # Reads public key file
#   cat key.pub | ssh_kadd         # Reads from stdin pipe
# ============================================================

ssh_kadd() {
    local input="${1:-}"
    local auth_file="$HOME/.ssh/authorized_keys"
    local ssh_dir="$HOME/.ssh"

    # --------------------------------------------------------
    # 1. Read key (Priority: Argument -> Pipe/Stdin -> Clipboard)
    # --------------------------------------------------------
    local pub_key=""

    if [[ -n "$input" ]]; then
        if [[ -f "$input" ]]; then
            pub_key="$(cat "$input")"
        else
            pub_key="$input"
        fi
    elif [[ ! -t 0 ]]; then
        # Read from stdin pipe
        pub_key="$(cat)"
    else
        # Fallback to clipboard
        pub_key="$(cb_read)" || {
            echo "Error: No input provided and clipboard is unavailable." >&2
            echo "Usage: ssh_kadd [key_string | file_path]" >&2
            return 1
        }
    fi

    # --------------------------------------------------------
    # 2. Normalize
    # --------------------------------------------------------
    pub_key="$(
        printf '%s' "$pub_key" |
        tr -d '\r' |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    )"

    # --------------------------------------------------------
    # 3. Empty check
    # --------------------------------------------------------
    if [[ -z "$pub_key" ]]; then
        echo "Error: No public key provided or clipboard is empty." >&2
        return 1
    fi

    # --------------------------------------------------------
    # 4. Must be exactly one line
    # --------------------------------------------------------
    if [[ "$pub_key" == *$'\n'* ]]; then
        echo "Error: Public key must be a single line." >&2
        return 1
    fi

    # --------------------------------------------------------
    # 5. Validate SSH public key format
    # --------------------------------------------------------
    local valid_key_regex='^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$'
    if [[ ! "$pub_key" =~ $valid_key_regex ]]; then
        echo "Error: Invalid SSH public key format." >&2
        return 1
    fi

    # --------------------------------------------------------
    # 6. Verify key can actually be parsed by ssh-keygen
    # --------------------------------------------------------
    local fingerprint
    fingerprint="$(
        printf '%s\n' "$pub_key" |
        ssh-keygen -lf - 2>/dev/null |
        awk '{print $2}'
    )"

    if [[ -z "$fingerprint" ]]; then
        echo "Error: ssh-keygen could not parse the public key." >&2
        return 1
    fi

    # --------------------------------------------------------
    # 7. Prepare ~/.ssh
    # --------------------------------------------------------
    mkdir -p "$ssh_dir" || {
        echo "Error: Cannot create $ssh_dir" >&2
        return 1
    }
    chmod 700 "$ssh_dir"

    # --------------------------------------------------------
    # 8. Prepare authorized_keys
    # --------------------------------------------------------
    touch "$auth_file" || {
        echo "Error: Cannot create $auth_file" >&2
        return 1
    }
    chmod 600 "$auth_file"

    # --------------------------------------------------------
    # 9. Check duplicate by fingerprint
    # --------------------------------------------------------
    if ssh-keygen -lf "$auth_file" 2>/dev/null |
       awk '{print $2}' |
       grep -qF "$fingerprint"; then

        echo
        echo "Notice: Key already exists in authorized_keys."
        echo "File        : $auth_file"
        echo "Fingerprint : $fingerprint"
        return 0
    fi

    # --------------------------------------------------------
    # 10. Backup before modification
    # --------------------------------------------------------
    local backup_file
    backup_file="${auth_file}.bak.$(date +%Y%m%d_%H%M%S)"

    cp "$auth_file" "$backup_file" || {
        echo "Error: Failed to backup authorized_keys." >&2
        return 1
    }
    chmod 600 "$backup_file"

    # --------------------------------------------------------
    # 11. Ensure previous entry ends with newline
    # --------------------------------------------------------
    if [[ -s "$auth_file" ]] && [[ -n "$(tail -c 1 "$auth_file")" ]]; then
        printf '\n' >> "$auth_file"
    fi

    # --------------------------------------------------------
    # 12. Append key
    # --------------------------------------------------------
    printf '%s\n' "$pub_key" >> "$auth_file" || {
        echo "Error: Failed to append key." >&2
        # Restore backup
        cp "$backup_file" "$auth_file"
        return 1
    }

    # --------------------------------------------------------
    # 13. Final permissions
    # --------------------------------------------------------
    chmod 600 "$auth_file"

    # --------------------------------------------------------
    # 14. Success
    # --------------------------------------------------------
    echo
    echo "===================================================="
    echo " SSH KEY ADDED"
    echo "===================================================="
    echo "File        : $auth_file"
    echo "Fingerprint : $fingerprint"
    echo "Backup      : $backup_file"
    echo "===================================================="
}