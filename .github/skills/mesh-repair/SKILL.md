---
name: mesh-repair
description: 'Diagnose and repair SSOT SSH/Tailscale mesh (wsl, wsl2, termux, mumu, oppo, window). Use when SSH times out, tailscaled crash-loops (TUN busy), node-status shows offline, or after WSL reinstall.'
---

# Mesh Repair

## When to Use
- `ssh wsl|wsl2` times out but `tailscale ping` works (or vice versa)
- `tailscaled` crash-loop: `TUN device tailscale0 is busy`
- `node-status --ssh` shows nodes unreachable
- After WSL distro reinstall or `~/.ssh/config` corruption

## Background
`Ubuntu` (wsl) + `Ubuntu-22.04` (wsl2) share one WSL2 mirrored netns.
Separation (proven 2026-09-15): wsl = kernel TUN + UDP `41643` + sshd `2222`;
wsl2 = `--tun=userspace-networking --port=41642` + sshd `2223`.
`window` reaches both via `127.0.0.1` (MagicDNS TCP via DERP times out from host).
Full rationale: [tailscale-separate.sh](../../bootstrap/script/tailscale-separate.sh)

## Procedure
1. Diagnose: `tailscale status`, `tailscale ping --c=2 <node>`, `Test-NetConnection -Port <port>`, `sudo ss -tlnp | grep sshd`, `sudo journalctl -u tailscaled -n 20` inside each distro.
2. Re-apply separation (idempotent):
   `wsl -d Ubuntu -- bash ~/ssot/bootstrap/script/tailscale-separate.sh wsl`
   `wsl -d Ubuntu-22.04 -- bash ~/ssot/bootstrap/script/tailscale-separate.sh wsl2`
3. Regen configs (safe, no side-effects):
   `bash ~/ssot/bootstrap/script/mesh-regen.sh` (inside wsl/wsl2/termux),
   with `--localhost-wsl` for the `window` node only.
4. Refresh stale host keys: `ssh-keygen -R <node>`, reconnect with `StrictHostKeyChecking=accept-new`.
5. Verify both directions: `ssh -o BatchMode=yes wsl/wsl2/termux "echo ok"` from each node; `node-status --ssh`.
6. If repos diverged, commit/push/pull across `~/ssot` in wsl, wsl2, window (see AGENTS.md pitfalls on rebase conflicts over `SSH_PORT` values).
