---
name: ssot-node-onboard
description: 'Onboard a new device into the SSOT SSH/Tailscale mesh. Use when adding a new node, installing SSOT on a new device, registering node identity, distributing SSH keys via vault, or joining a device to the tailnet mesh.'
---

# SSOT Node Onboard

## When to Use
- New device (Termux, MuMu, WSL, WSL2, Git-Bash, AcodeX, OPPO)
- `node-status` does not list the device, or lists it as INCOMPLETE
- Fresh WSL distro / reinstalled phone needing mesh rejoin
- Adding a replacement node (new `.node.env` + key distribution)

## Procedure
1. Install SSOT (idempotent, auto-detects env):
   `bash ~/ssot/bootstrap/install.sh [termux|mumu|oppo|wsl|wsl2]` —
   stages: packages → clone → `~/.env` (+ pin `JOE_ENV` line 1) → vault unlock → node-register → pubkey install → profile symlink → `ssh_audit.sh --fix` → verify.
2. Register identity (creates `bootstrap/nodes/<name>.node.env`, sets `MY_DEVICE`):
   `bash ~/ssot/bootstrap/nodes/node-register.sh --dry-run` then without flag (or `<name>` for custom).
   Schema: `NODE_<NAME>_{HOST,USER,PORT,ST_PORT,ST_KEY,ST_ID,ST_URL}`; HOST = Tailscale MagicDNS short name; ports: `wsl=2222`, `wsl2=2223`, `termux=8022`, `mumu=8020`, `oppo=8023`, `acodex=8021`, `window=22`.
3. Node key: ensure `~/.ssh/id_ed25519_node` (+`.pub`, `600`/`644`) exists — `ssh_audit.sh --fix` generates it if missing. Never commit private keys.
4. Distribute pubkey via encrypted vault (no plaintext key exchange):
   on the new node: `vault lock_pubkey` (or `--from <host> --user <u> --port <p>` to pull a remote);
   commit + push `core/pubkeys.enc`; on every other node: `vault unlock_pubkey`; check with `vault pubkey-status`.
5. WSL special-case: if `Ubuntu`/`Ubuntu-22.04` share mirrored netns, re-apply separation (see `/mesh-repair`):
   `tailscale-separate.sh wsl|wsl2`, then `mesh-regen.sh` (plain inside distros, `--localhost-wsl` on `window` only).
6. Verify: `node-status` (config complete) → `node-status --ssh` (reachable) → bidirectional `ssh -o BatchMode=yes <node> "echo ok"` from new node and back. Refresh stale host keys with `ssh-keygen -R <node>` if verification fails after re-install.
7. Sync repos: commit/push/pull `~/ssot` on touched nodes so `*.node.env` + `pubkeys.enc` converge; resolve `SSH_PORT` rebase conflicts toward separated values (`2222`/`2223`).

## References
- Installer: [install.sh](../../bootstrap/install.sh) · Registrar: [node-register.sh](../../bootstrap/nodes/node-register.sh) · Keys: [pubkey-manager.sh](../../bootstrap/nodes/pubkey-manager.sh) · Mesh: [mesh-regen.sh](../../bootstrap/script/mesh-regen.sh) · Repair: [mesh-repair](../mesh-repair/SKILL.md)
