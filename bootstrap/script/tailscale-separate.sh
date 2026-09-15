#!/usr/bin/env bash
# ============================================================
# 🔀 tailscale-separate.sh — SSOT WSL/wsl2 Tailscale Separation
# ============================================================
# Problem: Ubuntu (wsl) + Ubuntu-22.04 (wsl2) share ONE WSL2
# mirrored network namespace → same TUN name + same UDP port
# fight → wsl2 crash-loop:
#   "TUN device tailscale0 is busy... device or resource busy"
#
# Fix (proven 2026-09-15):
#   wsl  (Ubuntu)        — kernel TUN tailscale0, UDP 41643
#                          (41641 collides with Windows host!)
#                          state /var/lib/tailscale/tailscaled.state
#                          sshd Port 2222 (22 collides w/ Windows)
#   wsl2 (Ubuntu-22.04)  — userspace-networking (NO TUN, no
#                          route-table fight), UDP 41642
#                          state /var/lib/tailscale/wsl2.state
#                          (own identity, preserved)
#                          sshd Port 2223
#
# Mesh result:
#   - Both daemons online simultaneously (100.80.195.120 + 100.93.45.16)
#   - External nodes (termux/mumu) reach both via MagicDNS:2222/2223
#   - window (mirrored netns) reaches both via 127.0.0.1:2222/2223
#     (MagicDNS TCP via DERP times out from Windows host)
#
# Usage:
#   Run from Windows PowerShell (re-applies after WSL reinstall):
#     wsl -d Ubuntu -- bash ~/ssot/bootstrap/script/tailscale-separate.sh wsl
#     wsl -d Ubuntu-22.04 -- bash ~/ssot/bootstrap/script/tailscale-separate.sh wsl2
#   Or auto-detect (uses hostname/user):
#     bash ~/ssot/bootstrap/script/tailscale-separate.sh --auto
#
# Idempotent — safe to re-run.
# ============================================================
set -uo pipefail

ROLE="${1:---auto}"

detect_role() {
    local user
    user="$(id -un 2>/dev/null || whoami)"
    if [[ "$user" == "joez" ]]; then
        echo "wsl2"
    else
        echo "wsl"
    fi
}

[[ "$ROLE" == "--auto" ]] && ROLE="$(detect_role)"

log() { echo "  [separate] $*"; }

apply_wsl() {
    log "Applying wsl (Ubuntu) — kernel TUN + UDP 41643 + sshd 2222"
    sudo mkdir -p /etc/systemd/system/tailscaled.service.d
    sudo tee /etc/systemd/system/tailscaled.service.d/override.conf > /dev/null <<'EOF'
[Service]
EnvironmentFile=
Environment=PORT=41643
EOF
    sudo sed -i 's/^#*Port .*/Port 2222/' /etc/ssh/sshd_config
    sudo mkdir -p /run/sshd
    sudo systemctl daemon-reload
    sudo systemctl restart tailscaled
    sudo systemctl restart ssh || sudo service ssh restart || true
    sleep 5
    log "wsl tailscale: $(tailscale ip -4 2>&1)"
    log "wsl sshd: $(sudo ss -tlnp 2>/dev/null | grep -E ':2222' | head -1)"
}

apply_wsl2() {
    log "Applying wsl2 (Ubuntu-22.04) — userspace + UDP 41642 + sshd 2223"
    sudo mkdir -p /etc/systemd/system/tailscaled.service.d
    sudo tee /etc/systemd/system/tailscaled.service.d/override.conf > /dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/sbin/tailscaled --state=/var/lib/tailscale/wsl2.state --socket=/run/tailscale/tailscaled.sock --port=41642 --tun=userspace-networking
EOF
    sudo sed -i 's/^#*Port .*/Port 2223/' /etc/ssh/sshd_config
    sudo mkdir -p /run/sshd
    sudo systemctl daemon-reload
    sudo systemctl restart tailscaled
    sudo systemctl restart ssh || sudo service ssh restart || true
    # Fallback: direct sshd if systemd unit still points at old binary path
    if ! sudo ss -tln 2>/dev/null | grep -q ':2223'; then
        log "systemd sshd not listening — starting /usr/sbin/sshd directly"
        sudo /usr/sbin/sshd 2>/dev/null || true
    fi
    sleep 5
    log "wsl2 tailscale: $(tailscale ip -4 2>&1)"
    log "wsl2 sshd: $(sudo ss -tlnp 2>/dev/null | grep -E ':2223' | head -1)"
}

case "$ROLE" in
    wsl)  apply_wsl ;;
    wsl2) apply_wsl2 ;;
    *) echo "Usage: $0 [wsl|wsl2|--auto]"; exit 1 ;;
esac

echo "  [separate] done ($ROLE)"
