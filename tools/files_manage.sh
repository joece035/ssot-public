#!/usr/bin/env bash
# ============================================================
# tools/files_manage.sh — Cross-Device File Management Helper
# ============================================================
# SSOT: All node vars come from bootstrap/00-env.sh (NODE_*)
# Transport: uses _rsync_to / _rsync_from / _rsync_to_delete
#            (defined in core/3worlds.sh)
#
# Nodes supported: termux | wsl | win | mumu | OPPO
#
# Public API (frozen signatures):
#   fm_send  <node> <local_src>   [remote_dst]  - push  local -> remote
#   fm_pull  <node> <remote_src>  [local_dst]   - pull  remote -> local
#   fm_sync  <node> <local_src>   [remote_dst]  - mirror local -> remote (--delete)
#   fm_mv    <node> <local_src>   <remote_dst>  - move  local -> remote (rm local after)
#   fm_ls    <node> [remote_path]               - list  remote path
#   fm_rm    <node> <remote_path>               - remove file/dir on remote
#   fm_exec  <node> <cmd...>                    - run arbitrary cmd on remote
#   fm_info                                     - show all node connection info
#   fm_check <node>                             - ping / connectivity test
#   fm       [action] [args...]                 - interactive dispatcher (main entry)
# ============================================================

# Guard: avoid double-load
[[ -n "${_FM_LOADED:-}" ]] && return 0
_FM_LOADED=1

# Dependency: if 3worlds transport not loaded, define stubs
if ! declare -f _rsync_to &>/dev/null; then
  _rsync_to() {
    local user="$1" host="$2" port="$3" src="$4" dst="$5"
    rsync -az --update --info=progress2 -e "ssh -p ${port}" "$src" "${user}@${host}:${dst}"
  }
  _rsync_to_delete() {
    local user="$1" host="$2" port="$3" src="$4" dst="$5"
    rsync -az --delete --info=progress2 -e "ssh -p ${port}" "$src" "${user}@${host}:${dst}"
  }
  _rsync_from() {
    local user="$1" host="$2" port="$3" src="$4" dst="$5"
    rsync -az --update --info=progress2 -e "ssh -p ${port}" "${user}@${host}:${src}" "$dst"
  }
fi

# ============================================================
# SECTION 0: INTERNAL NODE RESOLVER
# ============================================================
# _fm_node_vars <node_alias>
#   Sets: _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
#   _FM_PROTO = rsync | scp  (MUMU has no rsync)
_fm_node_vars() {
  local node="${1:-}"
  case "$node" in
    t|tm|termux|TERMUX)
      _FM_USER="${NODE_TERMUX_USER}"
      _FM_HOST="${NODE_TERMUX_HOST}"
      _FM_PORT="${NODE_TERMUX_PORT}"
      _FM_PROTO="rsync"
      _FM_TAG="TERMUX"
      ;;
    w|wsl|WSL)
      _FM_USER="${NODE_WSL_USER}"
      _FM_HOST="${NODE_WSL_HOST}"
      _FM_PORT="${NODE_WSL_PORT}"
      _FM_PROTO="rsync"
      _FM_TAG="WSL"
      ;;
    win|window|windows|WIN)
      _FM_USER="${NODE_WIN_USER}"
      _FM_HOST="${NODE_WIN_HOST}"
      _FM_PORT="${NODE_WIN_PORT:-22}"
      _FM_PROTO="scp"
      _FM_TAG="WIN"
      ;;
    m|mm|mumu|MUMU)
      _FM_USER="${NODE_MUMU_USER}"
      _FM_HOST="${NODE_MUMU_HOST}"
      _FM_PORT="${NODE_MUMU_PORT}"
      _FM_PROTO="rsync"
      _FM_TAG="MUMU"
      ;;
    o|op|oppo|OPPO)
      _FM_USER="${NODE_OPPO_USER}"
      _FM_HOST="${NODE_OPPO_HOST}"
      _FM_PORT="${NODE_OPPO_PORT}"
      _FM_PROTO="scp"
      _FM_TAG="OPPO"
      ;;
    *)
      cn 196 b "fm: unknown node '${node}'"
      cn 252   "  nodes: termux | wsl | win | mumu | oppo"
      return 1
      ;;
  esac
}

# Print transfer banner
_fm_banner() {
  local dir="$1" tag="$2" src="$3" dst="$4"
  c 226 b "${dir} "
  c 82 b "[${tag}]"
  printf " %s" "$src"
  c 245 " -> "
  cn 87 "$dst"
}

# ============================================================
# SECTION 1: PUBLIC API
# ============================================================

# fm_send <node> <local_src> [remote_dst]
#   Push local file/folder -> remote node (--update, no overwrite of newer)
fm_send() {
  local node="${1:-}" src="${2:-}" dst="${3:-.}"
  [[ -z "$node" || -z "$src" ]] && {
    cn 208 "Usage: fm_send <node> <local_src> [remote_dst]"
    return 1
  }
  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  _fm_banner "SEND" "$_FM_TAG" "$src" "${_FM_HOST}:${dst}"

  if [[ "$_FM_PROTO" == "rsync" ]]; then
    _rsync_to "$_FM_USER" "$_FM_HOST" "$_FM_PORT" "$src" "$dst"
  else
    scp -P "$_FM_PORT" -r "$src" "${_FM_USER}@${_FM_HOST}:${dst}"
  fi
}

# fm_pull <node> <remote_src> [local_dst]
#   Pull file/folder from remote -> local (--update, no overwrite of newer)
fm_pull() {
  local node="${1:-}" src="${2:-}" dst="${3:-.}"
  [[ -z "$node" || -z "$src" ]] && {
    cn 208 "Usage: fm_pull <node> <remote_src> [local_dst]"
    return 1
  }
  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  _fm_banner "PULL" "$_FM_TAG" "${_FM_HOST}:${src}" "$dst"

  if [[ "$_FM_PROTO" == "rsync" ]]; then
    _rsync_from "$_FM_USER" "$_FM_HOST" "$_FM_PORT" "$src" "$dst"
  else
    scp -P "$_FM_PORT" -r "${_FM_USER}@${_FM_HOST}:${src}" "$dst"
  fi
}

# fm_sync <node> <local_src> [remote_dst]
#   Mirror local -> remote (--delete: remote matches local exactly)
#   WARNING: Destructive on destination
fm_sync() {
  local node="${1:-}" src="${2:-}" dst="${3:-.}"
  [[ -z "$node" || -z "$src" ]] && {
    cn 208 "Usage: fm_sync <node> <local_src> [remote_dst]"
    cn 208 "  -- --delete: files on remote NOT in local_src will be removed"
    return 1
  }
  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  _fm_banner "SYNC" "$_FM_TAG" "$src" "${_FM_HOST}:${dst}"
  cn 208 "  -- mirror mode (destination will match source exactly)"

  if [[ "$_FM_PROTO" == "rsync" ]]; then
    _rsync_to_delete "$_FM_USER" "$_FM_HOST" "$_FM_PORT" "$src" "$dst"
  else
    cn 208 "  -- scp has no --delete; doing plain copy"
    scp -P "$_FM_PORT" -r "$src" "${_FM_USER}@${_FM_HOST}:${dst}"
  fi
}

# fm_mv <node> <local_src> <remote_dst>
#   Move: push then delete local (only deletes if transfer succeeded)
fm_mv() {
  local node="${1:-}" src="${2:-}" dst="${3:-}"
  [[ -z "$node" || -z "$src" || -z "$dst" ]] && {
    cn 208 "Usage: fm_mv <node> <local_src> <remote_dst>"
    return 1
  }
  fm_send "$node" "$src" "$dst" && {
    cn 226 "Removing local: $src"
    rm -rf -- "$src"
  }
}

# fm_ls <node> [remote_path]
#   List files on remote node
fm_ls() {
  local node="${1:-}" path="${2:-~}"
  [[ -z "$node" ]] && {
    cn 208 "Usage: fm_ls <node> [remote_path]"
    return 1
  }
  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  cn 75 b "[$_FM_TAG] ls ${path}"
  ssh -p "$_FM_PORT" "${_FM_USER}@${_FM_HOST}" "ls -lah '${path}' 2>/dev/null || ls -lah ~"
}

# fm_rm <node> <remote_path>
#   Remove a file or directory on remote (asks confirmation)
fm_rm() {
  local node="${1:-}" rpath="${2:-}"
  [[ -z "$node" || -z "$rpath" ]] && {
    cn 208 "Usage: fm_rm <node> <remote_path>"
    return 1
  }
  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  cn 196 b "REMOVE on [$_FM_TAG]: ${rpath}"
  read -rp "  Confirm? [y/N]: " _confirm
  [[ "$_confirm" =~ ^[Yy]$ ]] || { cn 252 "  Cancelled."; return 0; }

  ssh -p "$_FM_PORT" "${_FM_USER}@${_FM_HOST}" "rm -rf '${rpath}' && echo 'Removed: ${rpath}'"
}

# fm_exec <node> <cmd...>
#   Run arbitrary command on remote node
fm_exec() {
  local node="${1:-}"
  [[ -z "$node" ]] && {
    cn 208 "Usage: fm_exec <node> <command...>"
    return 1
  }
  shift
  [[ $# -eq 0 ]] && { cn 208 "fm_exec: no command given"; return 1; }

  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  cn 245 "[$_FM_TAG] exec: $*"
  ssh -p "$_FM_PORT" "${_FM_USER}@${_FM_HOST}" "$@"
}

# fm_check <node|all>
#   Connectivity test: SSH ping with 3s timeout
fm_check() {
  local node="${1:-}"
  [[ -z "$node" ]] && {
    cn 208 "Usage: fm_check <node>  (or: fm_check all)"
    return 1
  }

  _fm_ping_one() {
    local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
    _fm_node_vars "$1" 2>/dev/null || return 1
    printf "  %-10s %s@%s:%s  " "$_FM_TAG" "$_FM_USER" "$_FM_HOST" "$_FM_PORT"
    if ssh -o ConnectTimeout=3 -o BatchMode=yes \
           -p "$_FM_PORT" "${_FM_USER}@${_FM_HOST}" \
           "echo ok" &>/dev/null; then
      cn 82 "ONLINE"
    else
      cn 196 "OFFLINE"
    fi
  }

  if [[ "$node" == "all" ]]; then
    cn 226 b "-- Connectivity Check --"
    for n in termux wsl win mumu oppo; do
      _fm_ping_one "$n"
    done
  else
    _fm_ping_one "$node"
  fi
  unset -f _fm_ping_one
}

# fm_info
#   Show all node variables (from 00-env.sh SSOT)
fm_info() {
  cn 226 b "-- Node Registry (SSOT: 00-env.sh) --"
  printf "  %-8s %-20s %-20s %-6s %s\n" "NODE" "HOST" "USER" "PORT" "PROTO"
  printf "  %.0s-" {1..60}; echo
  printf "  %-8s %-20s %-20s %-6s %s\n" "TERMUX" "${NODE_TERMUX_HOST:-?}" "${NODE_TERMUX_USER:-?}" "${NODE_TERMUX_PORT:-?}" "rsync"
  printf "  %-8s %-20s %-20s %-6s %s\n" "WSL"    "${NODE_WSL_HOST:-?}"    "${NODE_WSL_USER:-?}"    "${NODE_WSL_PORT:-?}"    "rsync"
  printf "  %-8s %-20s %-20s %-6s %s\n" "WIN"    "${NODE_WIN_HOST:-?}"    "${NODE_WIN_USER:-?}"    "${NODE_WIN_PORT:-22}"   "scp"
  printf "  %-8s %-20s %-20s %-6s %s\n" "MUMU"   "${NODE_MUMU_HOST:-?}"   "${NODE_MUMU_USER:-?}"   "${NODE_MUMU_PORT:-?}"   "scp"
  printf "  %-8s %-20s %-20s %-6s %s\n" "OPPO" "${NODE_OPPO_HOST:-?}" "${NODE_OPPO_USER:-?}" "${NODE_OPPO_PORT:-?}" "rsync"
  printf "  %.0s-" {1..60}; echo
  cn 252 "  Source: \$SSOT/bootstrap/00-env.sh"
}

# ============================================================
# SECTION 2: INTERACTIVE DISPATCHER
# ============================================================
# fm [action] [args...]
#   One-stop entry point. Wraps all fm_* functions.
#
#   fm                            - show help
#   fm info                       - fm_info
#   fm check [node|all]           - fm_check
#   fm send  <node> <src> [dst]   - fm_send
#   fm pull  <node> <src> [dst]   - fm_pull
#   fm sync  <node> <src> [dst]   - fm_sync
#   fm mv    <node> <src> <dst>   - fm_mv
#   fm ls    <node> [path]        - fm_ls
#   fm rm    <node> <path>        - fm_rm
#   fm exec  <node> <cmd...>      - fm_exec
#   fm bkp   <file...>            - backup (calls bkp from backup.sh)
fn() {
  local action="${1:-}"
  [[ -z "$action" ]] && { _fm_help; return 0; }
  shift

  case "$action" in
    info)               fm_info        ;;
    check|ping)         fm_check "$@"  ;;
    send|push|up)       fm_send  "$@"  ;;
    pull|down|get)      fm_pull  "$@"  ;;
    sync|mirror)        fm_sync  "$@"  ;;
    mv|move)            fm_mv    "$@"  ;;
    ls|list)            fm_ls    "$@"  ;;
    rm|del|delete)      fm_rm    "$@"  ;;
    exec|run|cmd)       fm_exec  "$@"  ;;
    bkp|backup)
      if declare -f bkp &>/dev/null; then
        bkp "$@"
      else
        cn 208 "fm: bkp() not loaded -- source \$SSOT/functions/backup.sh first"
        return 1
      fi
      ;;
    help|-h|--help)     _fm_help       ;;
    *)
      cn 208 "fm: unknown action '${action}'"
      _fm_help
      return 1
      ;;
  esac
}

_fm_help() {
  cn 226 b "fm -- Cross-Device File Manager (SSOT)"
  echo ""
  cn 75  "  ACTIONS"
  printf "    %-28s %s\n"  "fm info"                      "Show all node connection info"
  printf "    %-28s %s\n"  "fm check [node|all]"          "Ping/connectivity test"
  printf "    %-28s %s\n"  "fm send  <node> <src> [dst]"  "Push local -> remote"
  printf "    %-28s %s\n"  "fm pull  <node> <src> [dst]"  "Pull remote -> local"
  printf "    %-28s %s\n"  "fm sync  <node> <src> [dst]"  "Mirror local -> remote (--delete)"
  printf "    %-28s %s\n"  "fm mv    <node> <src> <dst>"  "Move local -> remote (rm local)"
  printf "    %-28s %s\n"  "fm ls    <node> [path]"       "List remote directory"
  printf "    %-28s %s\n"  "fm rm    <node> <path>"       "Remove file/dir on remote"
  printf "    %-28s %s\n"  "fm exec  <node> <cmd...>"     "Run command on remote"
  printf "    %-28s %s\n"  "fm bkp   <file...>"           "Local backup (calls bkp)"
  echo ""
  cn 75  "  NODES"
  printf "    %-14s %s\n"  "termux | t | tm"   "\$NODE_TERMUX_*  (rsync)"
  printf "    %-14s %s\n"  "wsl    | w"        "\$NODE_WSL_*    (rsync)"
  printf "    %-14s %s\n"  "win    | window"   "\$NODE_WIN_*    (scp)"
  printf "    %-14s %s\n"  "mumu   | mm | m"   "\$NODE_MUMU_*   (scp)"
  printf "    %-14s %s\n"  "oppo | op | o"  "\$NODE_OPPO_* (rsync)"
  echo ""
  cn 245  "  Vars sourced from: \$SSOT/bootstrap/00-env.sh"
}
