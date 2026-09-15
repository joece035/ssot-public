#!/usr/bin/env bash
# ============================================================
# 🔗 mesh-regen.sh — SSOT Lightweight SSH Mesh Config Generator
# ============================================================
# Purpose: Regenerate ~/.ssh/config mesh block ONLY.
#          No ssh-agent, no clipboard, no key generation —
#          safe to run anywhere, never hangs.
#
# Why separate from ssh_audit.sh --fix:
#   ssh_audit --fix does permissions + keys + agent + clipboard
#   which can hang on WSL (clip.exe / ssh-add prompts).
#   This script does ONE thing: write the mesh block.
#
# Usage:
#   bash bootstrap/script/mesh-regen.sh              # MagicDNS hostnames
#   bash bootstrap/script/mesh-regen.sh --localhost-wsl
#       # window (mirrored netns): wsl/wsl2 via 127.0.0.1
#       # (MagicDNS TCP via DERP times out from Windows host,
#       #  but mirrored localhost:2222/2223 works)
#
# Ports come from bootstrap/nodes/*.node.env
#   (wsl=2222, wsl2=2223 after 2026-09-15 separation).
# ============================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSOT="${SSOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
export SSOT

LOCALHOST_WSL=false
[[ "${1:-}" == "--localhost-wsl" ]] && LOCALHOST_WSL=true

# ── Load node registry (best-effort, defaults if missing) ──
if [[ -f "$SSOT/bootstrap/nodes/loader.sh" ]]; then
    # shellcheck source=/dev/null
    source "$SSOT/bootstrap/nodes/loader.sh" 2>/dev/null || true
fi

# Defaults (mirror ssh_audit.sh fallbacks + separated ports)
NODE_WSL_HOST="${NODE_WSL_HOST:-wsl}"
NODE_WSL_USER="${NODE_WSL_USER:-usercivenz}"
NODE_WSL_PORT="${NODE_WSL_PORT:-2222}"
NODE_WSL2_HOST="${NODE_WSL2_HOST:-wsl2}"
NODE_WSL2_USER="${NODE_WSL2_USER:-joez}"
NODE_WSL2_PORT="${NODE_WSL2_PORT:-2223}"
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

# window (mirrored): route wsl/wsl2 via localhost
WSL_HOST_OUT="$NODE_WSL_HOST"
WSL2_HOST_OUT="$NODE_WSL2_HOST"
if [[ "$LOCALHOST_WSL" == "true" ]]; then
    WSL_HOST_OUT="127.0.0.1"
    WSL2_HOST_OUT="127.0.0.1"
fi

SSH_DIR="$HOME/.ssh"
CONFIG_FILE="$SSH_DIR/config"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
[[ -f "$CONFIG_FILE" ]] && cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"

_KEX="curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521"
_HKA="ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256,ssh-rsa,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521"
_PKA="ssh-ed25519,rsa-sha2-512,rsa-sha2-256,ssh-rsa"
_CIPHERS="chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr"
_MACS="hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256"

entry() {
    local alias="$1" hostname="$2" user="$3" port="$4"
    cat <<EOF
Host $alias
    HostName $hostname
    User $user
    Port $port
    IdentityFile ~/.ssh/id_ed25519_node
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 5
    PreferredAuthentications publickey

EOF
}

{
    echo "# >>> JOE_SSOT_MESH_START >>>"
    echo "# SSOT Mesh — Multi-Node Topology"
    echo "# Managed by bootstrap/script/mesh-regen.sh"
    echo "# Generated: $(date +'%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "# Global Modern Cryptography Settings"
    echo "Host *"
    echo "    KexAlgorithms ${_KEX}"
    echo "    HostKeyAlgorithms ${_HKA}"
    echo "    PubkeyAcceptedAlgorithms ${_PKA}"
    echo "    Ciphers ${_CIPHERS}"
    echo "    MACs ${_MACS}"
    echo ""
    entry "wsl"    "$WSL_HOST_OUT"  "$NODE_WSL_USER"    "$NODE_WSL_PORT"
    entry "wsl2"   "$WSL2_HOST_OUT" "$NODE_WSL2_USER"   "$NODE_WSL2_PORT"
    entry "oppo"   "$NODE_OPPO_HOST"   "$NODE_OPPO_USER"   "$NODE_OPPO_PORT"
    entry "mumu"   "$NODE_MUMU_HOST"   "$NODE_MUMU_USER"   "$NODE_MUMU_PORT"
    entry "termux" "$NODE_TERMUX_HOST" "$NODE_TERMUX_USER" "$NODE_TERMUX_PORT"
    entry "acodex" "$NODE_ACODEX_HOST" "$NODE_ACODEX_USER" "$NODE_ACODEX_PORT"
    entry "window" "$NODE_WIN_HOST"    "$NODE_WIN_USER"    "$NODE_WIN_PORT"
    echo "# <<< JOE_SSOT_MESH_END <<<"
} > "$CONFIG_FILE"

chmod 600 "$CONFIG_FILE"
echo "mesh-regen: wrote $CONFIG_FILE (localhost-wsl=$LOCALHOST_WSL)"
grep -E "^Host |HostName |    Port " "$CONFIG_FILE"
