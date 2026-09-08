# ============================================================
# 3worlds.sh — Multi-node Infrastructure (SSH · rsync · Syncthing)
# ============================================================
# Architecture (bottom → top):
#
#   Node Registry  (00-env.sh, NODE_* vars)
#        ↓
#   Compatibility Layer  (00-env.sh, legacy vars re-exported)
#        ↓
#   Transport Layer      (_ssh_node · _rsync_to · _rsync_from)
#        ↓
#   Service Layer        (_st_fetch · _st_autostart · syncthing_auto)
#        ↓
#   Public API           (tm · tw · wsl · push · update · cpw2t …)
#
# Adding a new node = add NODE_* vars in 00-env.sh only.
# Public API signatures are frozen for backward compatibility.
# ============================================================

# Env from ~/ssot/00-env.sh

# ============================================================
# SECTION 0: WORLD DETECTION
# ============================================================
# _MY_WORLD: human-readable world tag (kept for backward compat).
# JOE_ENV is the authoritative env var set by .bashjoe.

_detect_world() {
  case "${JOE_ENV}" in
    TERMUX)   printf 'termux' ;;
    WSL)      printf 'wsl' ;;
    GIT-BASH) printf 'git-bash' ;;
    MUMU)     printf 'MUMU' ;;
    *)        printf 'unknown' ;;
  esac
}

# _MY_WORLD: plain text tag (ไม่มี ANSI/ขึ้นบรรทัดใหม่ — กัน prompt พัง)
export _MY_WORLD="$(_detect_world)"

# ============================================================
# SECTION 1: TRANSPORT LAYER
# ============================================================
# Generic helpers. Call these from the Service Layer and Public API.
# Never hardcode IPs or ports outside these functions.

unalias tac tm tw twpws wsl cpw2t cpt2w push 2>/dev/null

# _ssh_node <user> <host> <port> [extra_ssh_opts...] -- [cmd...]
#   → SSH into any node. Args before `--` go to ssh; after go to remote cmd.
#   Example:  _ssh_node "$USER" "$HOST" 22 -i ~/.ssh/id_ed25519 -- ls -la
#   (ถ้าไม่มี `--` ทุก arg ถือเป็น remote cmd — backward compat)
_ssh_node() {
  local user="$1" host="$2" port="$3"
  shift 3
  local ssh_opts=()
  # ถ้ามี `--` ใน args → แยก ssh_opts กับ remote cmd
  if [[ "$*" == *"--"* ]]; then
    while [[ $# -gt 0 && "$1" != "--" ]]; do
      ssh_opts+=("$1")
      shift
    done
    [[ "${1:-}" == "--" ]] && shift
  fi
  ssh "${ssh_opts[@]}" -p "$port" "${user}@${host}" "$@"
}



# ============================================================
# SECTION 1: PUBLIC SSH API
# ============================================================
# Signatures are frozen. Internal implementation uses Transport Layer.

# TM — SSH into Termux (Android)
# -- all device using the same name of key identity folders (id_ed25519_node)
# KEY_NODE="${HOME}/.ssh/id_ed25519_node"
KEY_NODE="${HOME}/.ssh/id_ed25519_node"

tw() {
  local shell="gb"
  if [[ "${1:-}" =~ ^(pw|gb)$ ]]; then
    shell="$1"
    shift
  fi

  local -a ssh_opts=(-o ConnectTimeout=5 -t)
  [[ -f "${KEY_NODE}" ]] && ssh_opts+=(-i "${KEY_NODE}")

  case "$shell" in
    pw)
      local cmd="pwsh"
      [[ $# -gt 0 ]] && cmd="pwsh -Command \"$*\"" || cmd="pwsh -NoExit"
      _ssh_node "${NODE_WIN_USER}" "${NODE_WIN_HOST}" "${NODE_WIN_PORT}" "${ssh_opts[@]}" -- "$cmd"
      ;;
    gb)
      local cmd="& '${WIN_GIT_BASH}' --login -i"
      [[ $# -gt 0 ]] && cmd="& '${WIN_GIT_BASH}' -c $(printf '%q' "$*")"
      _ssh_node "${NODE_WIN_USER}" "${NODE_WIN_HOST}" "${NODE_WIN_PORT}" "${ssh_opts[@]}" -- "$cmd"
      ;;
    *)
      echo "Unknown shell: $shell"
      ;;
  esac
}

mm() {
  local -a ssh_opts=(-o ConnectTimeout=5 -o BatchMode=yes)
  [[ -f "${KEY_NODE}" ]] && ssh_opts+=(-i "${KEY_NODE}")
  _ssh_node "${NODE_MUMU_USER}" "${NODE_MUMU_HOST}" "${NODE_MUMU_PORT}" "${ssh_opts[@]}" -- "$@"
}

tm() {
  local -a ssh_opts=(-o ConnectTimeout=5 -o BatchMode=yes)
  [[ -f "${KEY_NODE}" ]] && ssh_opts+=(-i "${KEY_NODE}")
  _ssh_node "${NODE_TERMUX_USER}" "${NODE_TERMUX_HOST}" "${NODE_TERMUX_PORT}" "${ssh_opts[@]}" -- "$@"
}

ax() {
  local -a ssh_opts=(-o ConnectTimeout=5 -o BatchMode=yes)
  [[ -f "${KEY_NODE}" ]] && ssh_opts+=(-i "${KEY_NODE}")
  _ssh_node "${NODE_ACODEX_USER}" "${NODE_ACODEX_HOST}" "${NODE_ACODEX_PORT}" "${ssh_opts[@]}" -- bash "$@"
}


wsl() {
  local -a ssh_opts=(-o ConnectTimeout=5 -o BatchMode=yes)
  [[ -f "${KEY_NODE}" ]] && ssh_opts+=(-i "${KEY_NODE}")
  _ssh_node "${NODE_WSL_USER}" "${NODE_WSL_HOST}" "${NODE_WSL_PORT}" "${ssh_opts[@]}" -- "$@"
}



# ============================================================
# Windows PowerShell helpers (shared with ssh-config.sh)
# ============================================================
# Ensure ssh-config.sh is sourced (provides PS_HOST / PS_REMOTE_CMD /
# ps_remote / ps_strip_banner). joe.sh may or may not have loaded it yet,
# depending on module load order — guard explicitly.
if ! declare -F ps_remote >/dev/null 2>&1; then
  # Resolve SSOT path robustly — $SSOT may not be set if 3worlds.sh was
  # sourced standalone (e.g. during testing).
  _ssh_cfg="${SSOT:-$(dirname "${BASH_SOURCE[0]}")}/core/ssh-config.sh"
  [[ -f "$_ssh_cfg" ]] || _ssh_cfg="/home/usercivenz/ssot/core/ssh-config.sh"
  if [[ -f "$_ssh_cfg" ]]; then
    source "$_ssh_cfg"
  fi
  unset _ssh_cfg
fi

# twpws — SSH into Windows PowerShell (default shell) for interactive use
#   Note: this opens an interactive PowerShell session — banner WILL appear
#   (by design). For non-interactive commands, prefer `ps_remote` or `twp`.
twpws() {
  _ssh_node "${NODE_WIN_USER}" "${NODE_WIN_HOST}" "${NODE_WIN_PORT:-22}" -- "$@"
}
alias Tw='twpws'

# twp — Thin wrapper around `ps_remote` for symmetry with `tm`/`tw`
#   Usage: twp '<ps_script>'  OR  twp <<'PS' ... PS
#   Same as `ps_remote` but named `twp` to fit the `t<m|w|p|...>` family.
#   Backed by shared SSOT constants in ssh-config.sh.
twp() {
  ps_remote "$@"
}

# ---Helper functions---  
# _rsync_to <user> <host> <port> <local_src> <remote_dst>
#   → Push local file/dir to remote node via rsync over SSH.
_rsync_to() {
  local user="$1" host="$2" port="$3" src="$4" dst="$5"
  rsync -az --update --info=progress2 -e "ssh -p ${port}"         "$src" "${user}@${host}:${dst}"
}

# _rsync_to_delete <user> <host> <port> <local_src> <remote_dst>
#   → Like _rsync_to but deletes destination files not in source.
_rsync_to_delete() {
  local user="$1" host="$2" port="$3" src="$4" dst="$5"
  rsync -az --delete --info=progress2 -e "ssh -p ${port}"         "$src" "${user}@${host}:${dst}"
}

# _rsync_from <user> <host> <port> <remote_src> <local_dst>
#   → Pull file/dir from remote node to local via rsync over SSH.
_rsync_from() {
  local user="$1" host="$2" port="$3" src="$4" dst="$5"
  rsync -az --update --info=progress2 -e "ssh -p ${port}"         "${user}@${host}:${src}" "$dst"
}
# ============================================================
# SECTION 3: FILE TRANSFER LAYER (WSL ↔ Termux)
# ============================================================

unalias managetm 2>/dev/null

# Tab-completion cache dir — platform-aware (WSL/Termux/MUMU = /tmp, Git-Bash = %TEMP%)
_T_CACHE_DIR="${TMPDIR:-${TEMP:-/tmp}}/.termux_completion_cache"
_T_CACHE_TTL=30

_t_usage() {
  printf '%s %s <source> <destination>\n' "$(cn 75 b 'Usage:')" "$1"
}

# Tab-completion helper: list remote Termux paths (cached)
_t_remote_paths() {
  local prefix="$1"
  local cache_key
  cache_key=$(echo "$prefix" | sed 's|/[^/]*$||; s|[^a-zA-Z0-9]|_|g')
  [[ -z "$cache_key" ]] && cache_key="root"
  local cache_file="$_T_CACHE_DIR/${cache_key}.cache"
  mkdir -p "$_T_CACHE_DIR"

  if [[ -f "$cache_file" ]]; then
    local age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
    [[ $age -lt $_T_CACHE_TTL ]] && grep "^$prefix" "$cache_file" 2>/dev/null && return
  fi

  local dir
  dir=$(dirname "$prefix")
  [[ "$dir" == "." ]] && dir="~"
  tm "ls -1dp ${prefix}* 2>/dev/null || ls -1dp ${dir}/ 2>/dev/null" 2>/dev/null | tee "$cache_file"
}

tclcache() { rm -f "$_T_CACHE_DIR"/*; echo "🗑️  Cache cleared"; }

# Tab completion registration
_comp_cpw2t() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ $COMP_CWORD -eq 1 ]]; then
    mapfile -t COMPREPLY < <(compgen -f -- "$cur")
    [[ ${#COMPREPLY[@]} -eq 1 && -d "${COMPREPLY[0]}" ]] && COMPREPLY[0]+="/"
  elif [[ $COMP_CWORD -eq 2 ]]; then
    mapfile -t COMPREPLY < <(_t_remote_paths "$cur")
  fi
}

_comp_cpt2w() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ $COMP_CWORD -eq 1 ]]; then
    mapfile -t COMPREPLY < <(_t_remote_paths "$cur")
  elif [[ $COMP_CWORD -eq 2 ]]; then
    mapfile -t COMPREPLY < <(compgen -f -- "$cur")
    [[ ${#COMPREPLY[@]} -eq 1 && -d "${COMPREPLY[0]}" ]] && COMPREPLY[0]+="/"
  fi
}

# ── Tab completion registration (bash + zsh) ──
if [[ -n "${ZSH_VERSION:-}" ]]; then
    # Zsh: define completion functions, register only if compdef available
    _cpw2t() {
        local cur="${words[CURRENT]}"
        if [[ $CURRENT -eq 2 ]]; then
            _files
        elif [[ $CURRENT -eq 3 ]]; then
            compadd -a -- $(_t_remote_paths "$cur")
        fi
    }
    _cpt2w() {
        local cur="${words[CURRENT]}"
        if [[ $CURRENT -eq 2 ]]; then
            compadd -a -- $(_t_remote_paths "$cur")
        elif [[ $CURRENT -eq 3 ]]; then
            _files
        fi
    }
    # compdef is only available in interactive zsh with oh-my-zsh
    if command -v compdef >/dev/null 2>&1; then
        compdef _cpw2t cpw2t
        compdef _cpt2w cpt2w
    fi
else
    complete -o nospace -F _comp_cpw2t cpw2t
    complete -o nospace -F _comp_cpt2w cpt2w
fi

managetm() {
  cn 141 b "--- 3-Worlds Commands ---"
  cn 226   "SSH:"   ; echo "   tm | tw | twpws | wsl | mumu | tdb"
  cn 82    "cpw2t"  ; echo " : Copy WSL → Termux (Tab Complete)"
  cn 82    "cpt2w"  ; echo " : Copy Termux → WSL (Tab Complete)"
  cn 82    "cpw2m"  ; echo " : Copy WSL → MUMU (scp)"
  cn 82    "cpm2w"  ; echo " : Copy MUMU → WSL (scp)"
  cn 82    "mvw2t"  ; echo " : Move WSL → Termux"
  cn 82    "mvt2w"  ; echo " : Move Termux → WSL"
  cn 82    "push"   ; echo "  : Push local file to Termux (no overwrite)"
  cn 82    "update" ; echo ": Pull file from Termux (no overwrite)"
  cn 82    "lst"    ; echo "   : List Termux files"
  cn 82    "tun"    ; echo "  : Run command on Termux"
  cn 82    "tclcache" ; echo " : Clear cache"
}

# cpw2t — Copy: WSL → Termux  (exact-delete rsync)
cpw2t() {
  [[ $# -ne 2 ]] && _t_usage "cpw2t" "cpw2t ~/file.txt /sdcard/Download/" && return 1
  local dst="$2"; [[ "$dst" == "~" ]] && dst="."
  echo "📤 WSL → Termux: $1 → $dst"
  _rsync_to_delete "${NODE_TERMUX_USER}" "${NODE_TERMUX_HOST}" "${NODE_TERMUX_PORT}" "$1" "$dst"
}

# cpt2w — Copy: Termux → WSL
cpt2w() {
  [[ $# -ne 2 ]] && _t_usage "cpt2w" "cpt2w /sdcard/Download/file.txt ~/Downloads/" && return 1
  local src="$1"; [[ "$src" == "~" ]] && src="."
  echo "📥 Termux → WSL: $src → $2"
  _rsync_from "${NODE_TERMUX_USER}" "${NODE_TERMUX_HOST}" "${NODE_TERMUX_PORT}" "$src" "$2"
}

# mvw2t — Move: WSL → Termux (copy then delete local)
mvw2t() {
  [[ $# -ne 2 ]] && _t_usage "mvw2t" "mvw2t ~/file.txt /sdcard/Download/" && return 1
  cpw2t "$1" "$2" && { echo "🗑️  Removing: $1"; rm -f "$1"; }
}

# mvt2w — Move: Termux → WSL (copy then delete remote)
mvt2w() {
  [[ $# -ne 2 ]] && _t_usage "mvt2w" "mvt2w /sdcard/file.txt ~/Downloads/" && return 1
  cpt2w "$1" "$2" && { echo "🗑️  Removing remote: $1"; tm "rm -f '$1'"; }
}

# ============================================================
# MUMU FILE TRANSFER (WSL ↔ MUMUPlayer Termux)
# Uses scp (MUMU has no rsync). Functions mirror cpw2t/cpt2w.
# ============================================================

# cpw2m — Copy: WSL → MUMU
cpw2m() {
  [[ $# -ne 2 ]] && { echo "Usage: cpw2m <local_src> <MUMU_dst>"; return 1; }
  echo "📤 WSL → MUMU: $1 → $2"
  scp -P "${NODE_MUMU_PORT}" "$1" "${NODE_MUMU_USER}@${NODE_MUMU_HOST}:$2"
}

# cpm2w — Copy: MUMU → WSL
cpm2w() {
  [[ $# -ne 2 ]] && { echo "Usage: cpm2w <MUMU_src> <local_dst>"; return 1; }
  echo "📥 MUMU → WSL: $1 → $2"
  scp -P "${NODE_MUMU_PORT}" "${NODE_MUMU_USER}@${NODE_MUMU_HOST}:$1" "$2"
}

# Aliases
alias w2m="cpw2m"
alias m2w="cpm2w"

# push — Push local file to Termux without overwriting newer remote
#   push <local_file> [remote_dest]    — safe rsync (--update)
#   push --delete <local> [remote]     — exact-delete rsync (mirror)
push() {
  local mode="update" src="" dst=""
  for arg in "$@"; do
    case "$arg" in
      --delete) mode="delete" ;;
      -h|--help) printf '%s\n' "Usage: push [--delete] <local_file> [remote_dest]"; return 0 ;;
      *) [[ -z "$src" ]] && src="$arg" || dst="$arg" ;;
    esac
  done
  [[ -z "$src" ]] && { printf '%s\n' "Usage: push [--delete] <local_file> [remote_dest]"; return 1; }
  dst="${dst:-.}"
  printf '%s %s %s → %s\n' "$(c 226 b '📤 Pushing to Termux:')" "$src" "$(c 226 b '')" "$dst"
  case "$mode" in
    delete) _rsync_to_delete "${NODE_TERMUX_USER}" "${NODE_TERMUX_HOST}" "${NODE_TERMUX_PORT}" "$src" "$dst" ;;
    *)      _rsync_to       "${NODE_TERMUX_USER}" "${NODE_TERMUX_HOST}" "${NODE_TERMUX_PORT}" "$src" "$dst" ;;
  esac
}

# update — Pull file from Termux without overwriting newer local
update() {
  local src="$1"
  local dst="${2:-.}"
  [[ -z "$src" ]] && echo "Usage: update <remote_file> [local_dest]" && return 1
  echo "🔄 Updating from Termux: $src → $dst"
  _rsync_from "${NODE_TERMUX_USER}" "${NODE_TERMUX_HOST}" "${NODE_TERMUX_PORT}" "$src" "$dst"
}

# Utils
lst()  { tm "ls -lah '${1:-~}'"; }
ssht() { tm; }
tun()  { [[ $# -eq 0 ]] && echo "Usage: tun <command>" && return 1; tm "$@"; }

# Aliases — backward compat
alias w2t="cpw2t"
alias t2w="cpt2w"

# Info
whichworld() {
  cn 226 b "🌏 Current world: ${_MY_WORLD}  (JOE_ENV: $JOE_ENV)"
  cn lb    "  WSL:        ${NODE_WSL_USER}@${NODE_WSL_HOST}"
  cn lg    "  Termux:     ${NODE_TERMUX_USER}@${NODE_TERMUX_HOST}"
  cn lm    "  Windows:    ${NODE_WIN_USER}@${NODE_WIN_HOST}"
  cn m     "  MUMUPlayer: ${NODE_MUMU_USER}@${NODE_MUMU_HOST} (key: id_ed25519_mumu)"
}

# ============================================================
# SECTION 4: SERVICE LAYER — SYNCTHING
# ============================================================

# _st_fetch <display_name> <st_url> <api_key>
#   → Core engine: ping one Syncthing instance.
#     HTTP 200 = ONLINE, else OFFLINE.
_st_fetch() {
  local name="$1" url="${2%/}" key="$3"
  local http_code
  if ! command -v curl &>/dev/null; then
    printf -v blk_l '%*s' "$(( 10 - ${#name} ))" ""
    printf -v st_stats "🔄  %s${blk_l}:   CURL MISSING 🔴\n" "${name}"
    echo "$st_stats"  
    return 1
  fi

  http_code=$(curl -sLk -o /dev/null -w "%{http_code}"                    --max-time 2 --connect-timeout 1                    -H "X-API-Key: ${key}"                    "${url}/rest/system/status" 2>/dev/null)


  if [[ "$http_code" -eq 200 ]]; then
    printf -v blk_l '%*s' "$(( 10-${#name} ))" ""
    printf -v st_stats "🔄  %s${blk_l}:    ONLINE  🟢\n" "${name}"
    echo "$st_stats"
    return 0
  else
    printf -v blk_l '%*s' "$(( 10-${#name} ))" ""
    printf -v st_stats "🔄  %s${blk_l}:    OFFLINE 🔴\n" "${name}"
    echo "$st_stats"  
    return 1
  fi
}

syncthing_check_all(){
  # Call _st_fetch once per node → strip ANSI/emoji, extract status after ":"
  # _st_fetch output format: "🔄  NAME<pad>:    STATUS 🟢\n"
  _st_fetch_status() {
    local raw
    raw=$(_st_fetch "$@")
    # strip ANSI, take everything after the first ":"
    printf '%s' "$raw" | sed 's/\x1b\[[0-9;]*m//g; s/.*://' | tr -d '\n' | xargs
  }

  local ROWS=(
    "🔄|TERMUX|$(_st_fetch_status "TERMUX" "${NODE_TERMUX_ST_URL}" "${NODE_TERMUX_ST_KEY}")|"
    "🔄|WSL|$(_st_fetch_status "WSL"    "${NODE_WSL_ST_URL}"    "${NODE_WSL_ST_KEY}"   )|"
    "🔄|WIN|$(_st_fetch_status "WIN"    "${NODE_WIN_ST_URL}"    "${NODE_WIN_ST_KEY}"   )|"
    "🔄|MUMU|$(_st_fetch_status "MUMU"   "${NODE_MUMU_ST_URL}"  "${NODE_MUMU_ST_KEY}"  )|"
  )
  dashboard_array "${ROWS[@]}"
}



# _st_autostart <display_name> <st_url> <api_key> <st_port>
#   → Check Syncthing; if offline, auto-start it.
#   GIT-BASH: Windows Scheduled Task "Syncthing" (boot-trigger, SYSTEM account)
#             is the canonical start path. nohup/disown from MSYS bash dies when
#             shell exits (process group cleanup). Detect task first; only fall
#             back to in-shell start if task is missing — and tell user to install it.
_st_autostart() {
  local name="$1" url="${2%/}" key="$3" port="$4"
  local http_code ts_val

  # Check Tailscale connectivity first
  if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
    ts_val="ONLINE"
  else
    ts_val="OFFLINE"
  fi

  if ! command -v curl &>/dev/null; then
    color y b " 🔄 ${name} : CURL MISSING"
    return
  fi

  http_code=$(curl -sLk -o /dev/null -w "%{http_code}"                    --max-time 2 --connect-timeout 1                    -H "X-API-Key: ${key}"                    "${url}/rest/system/status" 2>/dev/null)

  if [[ "$http_code" -eq 200 ]]; then
    # Print compact full-width status bar
    local _tw; _tw=$(tput cols 2>/dev/null || echo 80)
    local _line=" all SYNCTHINGs  🟢"
    local _pad=$((_tw - ${#_line}))
    (( _pad < 0 )) && _pad=0
    printf -v _full "%s%*s" "$_line" $_pad ""
    c 208 b "${_full}"
    return
  fi

  # ── OFFLINE branch ──
  color y b " 🔄 ${name} : OFFLINE 🔴"

  # Platform-specific recovery strategy
  if [[ "$JOE_ENV" == "GIT-BASH" ]]; then
    # Is there a Windows Scheduled Task installed?
    local _task_state
    _task_state=$(schtasks /query /tn "Syncthing" 2>/dev/null | grep -c "Ready\|Running" || true)

    if [[ "${_task_state:-0}" -gt 0 ]]; then
      # Task exists but syncthing not responding (maybe mid-startup, or GUI bound to 127.0.0.1)
      cn lm bu "TASK EXISTS — STARTING…"
      schtasks /run /tn "Syncthing" >/dev/null 2>&1
      cn lg b "SYNCTHING (task) STARTED 🟢"
    else
      # No task — install helper lives in ssot/tools/
      cn lr b " 🔌 NO TASK 'Syncthing' FOUND"
      cn lm bu "RUN ONCE:"
      c 220 b "     bash ~/ssot/tools/install-syncthing-service.sh"
      cn lg bi "FALLBACK (nohup — known to die on bash exit):"
      nohup syncthing serve --gui-address="0.0.0.0:${port}" >/dev/null 2>&1 &
      disown 2>/dev/null
      cn y b " ⚠️  may die when this shell closes"
    fi
  else
    # WSL / Termux / MuMu: tailscale + nohup + disown works fine
    [[ "$ts_val" == "OFFLINE" ]] && cn lr b " 🔌🚫 CHECK TAILSCALE FIRST"
    cn lm bu "THEN RESTART SYNCTHING WILL BE !"
    cn lg bi "STARTING AUTOMATICALLY 🔄"
    nohup syncthing serve --gui-address="0.0.0.0:${port}" >/dev/null 2>&1 &
    disown 2>/dev/null
    cn lg b "SYNCTHING STARTED 🟢"
  fi
}

# syncthing_auto — auto-start Syncthing for the current node on shell load.
# NOTE: Called once at bottom of file. Comment out if causing loop issues.
syncthing_auto() {
  case "$JOE_ENV" in
    TERMUX)   _st_autostart "TERMUX"   "${NODE_TERMUX_ST_URL}" "${NODE_TERMUX_ST_KEY}" "${NODE_TERMUX_ST_PORT}" ;;
    WSL)      _st_autostart "WSL"      "${NODE_WSL_ST_URL}"    "${NODE_WSL_ST_KEY}"    "${NODE_WSL_ST_PORT}"    ;;
    GIT-BASH) _st_autostart "GIT-BASH" "${NODE_WIN_ST_URL}"    "${NODE_WIN_ST_KEY}"    "${NODE_WIN_ST_PORT}"    ;;
    MUMU)     _st_autostart "MUMU"     "${NODE_MUMU_ST_URL}"   "${NODE_MUMU_ST_KEY}"   "${NODE_MUMU_ST_PORT}"   ;;
  esac
}

# syncthing_status_ — formatted status widget for current node (dashboard blocks)
syncthing_status_() {
  local target_url api_key label
  case "$JOE_ENV" in
    TERMUX)   label="ST TERMUX"; target_url="${NODE_TERMUX_ST_URL}"; api_key="${NODE_TERMUX_ST_KEY}" ;;
    WSL)      label="ST WSL";    target_url="${NODE_WSL_ST_URL}";    api_key="${NODE_WSL_ST_KEY}"    ;;
    GIT-BASH) label="ST WIN";    target_url="${NODE_WIN_ST_URL}";    api_key="${NODE_WIN_ST_KEY}"    ;;
    MUMU)     label="ST MUMU";   target_url="${NODE_MUMU_ST_URL}";   api_key="${NODE_MUMU_ST_KEY}"   ;;
    *)        echo "🔄 SYNCTHING : ❓ N/A"; return ;;
  esac

  if ! command -v curl &>/dev/null; then
    echo "🔄 SYNCTHING : 🔴 CURL MISSING"
    return
  fi

  local http_code
  http_code=$(curl -sLk -o /dev/null -w "%{http_code}"                    --max-time 2 --connect-timeout 1                    -H "X-API-Key: ${api_key}"                    "${target_url%/}/rest/system/status" 2>/dev/null)

  local spr5 em5
  if [[ "$http_code" -eq 200 ]]; then spr5="ONLINE";  em5="🟢"
  else                                 spr5="OFFLINE"; em5="🔴"
  fi

  local pad=15 emoji_point=15
  local spl5="🔄  SYNCTHING"
  local sl5; sl5=$(printf "%*s" $((pad - ${#spl5})) "")
  local sr5; sr5=$(printf "%*s" $((emoji_point - 1 - ${#spr5})) "")
  local open5;  open5=$(printf  " %s%s:"       "${spl5}" "${sl5}")
  local close5; close5=$(printf " %s%s%s%2s\n" "${spr5}" "${sr5}" "${em5}" "")
  local ct5; ct5="$(cn gr b " ${open5}$(cn w b "${close5}")")"
  printf '%s\n' "${ct5}"   # ใช้ printf แทน echo -e (กัน double-escape)


}

# check_syncthing — full mesh status panel (all 3 nodes)
check_syncthing() {

  _st_fetch "TERMUX"  "${NODE_TERMUX_ST_URL}" "${NODE_TERMUX_ST_KEY}"
  _st_fetch "WSL    " "${NODE_WSL_ST_URL}"    "${NODE_WSL_ST_KEY}"
  _st_fetch "WIN"     "${NODE_WIN_ST_URL}"    "${NODE_WIN_ST_KEY}"
  _st_fetch "MUMU"    "${NODE_MUMU_ST_URL}"   "${NODE_MUMU_ST_KEY}"

  
}

alias stck='check_syncthing'

# _get_syncthing_raw — backward compat for scripts that call this directly
# Returns "ONLINE|🟢" or "OFFLINE|🔴"
_get_syncthing_raw() {
  local target_url api_key
  case "$JOE_ENV" in
    TERMUX)   target_url="${NODE_TERMUX_ST_URL}"; api_key="${NODE_TERMUX_ST_KEY}" ;;
    WSL)      target_url="${NODE_WSL_ST_URL}";    api_key="${NODE_WSL_ST_KEY}"    ;;
    GIT-BASH) target_url="${NODE_WIN_ST_URL}";    api_key="${NODE_WIN_ST_KEY}"    ;;
    MUMU)     target_url="${NODE_MUMU_ST_URL}";   api_key="${NODE_MUMU_ST_KEY}"   ;;
    *)        echo "OFFLINE|🔴"; return ;;
  esac

  if ! command -v curl &>/dev/null; then echo "OFFLINE|🔴"; return; fi

  local http_code
  http_code=$(curl -sLk -o /dev/null -w "%{http_code}"                    --max-time 1 --connect-timeout 1                    -H "X-API-Key: ${api_key}"                    "${target_url%/}/rest/system/status" 2>/dev/null)

  [[ "$http_code" -eq 200 ]] && echo "ONLINE|🟢" || echo "OFFLINE|🔴"
}

# ============================================================
# BOOT — auto-start Syncthing for current node
# Commented out 2026-08-01: syncthing_auto at source-time caused shell hangs
# on Git Bash (start race / port conflict with Tailscale). Run manually:
#   syncthing_auto          # start syncthing if offline
#   check_syncthing         # show mesh status
# ============================================================
# syncthing_auto  ← intentionally NOT called on source

# ============================================================
# SYNCTHING SAFETY CONTROLS (เพิ่ม 2026-08-01)
# ============================================================
# ปัญหาที่เจอ: หลัง reinstall Termux, copy เก่าในเครื่องอื่นจะ revert
# การแก้ไฟล์ของ WSL (เจอใน 3worlds.sh / 11-bash-manager.sh)
# วิธีใช้:
#   st-pause              # pause โฟลเดอร์ ssot (กัน revert) — แล้วค่อยแก้ไฟล์
#   st-override           # บังคับให้ copy โลคอล (เครื่องนี้) เป็น master ผลักไปทุกเครื่อง (native syncthing)
#   st-push-tm            # (ทางเลือก) rsync copy ที่ถูกต้องไป Termux ตรง ๆ ก่อน resume
#   st-resume             # resume เมื่อพร้อม
#   st-status             # สถานะ folder + devices + pending items
# ============================================================

# ลำดับที่แนะนำ (เมื่อ Termux กลับมา online):
#   st-status    → เช็คว่า TERMUX 🟢 แล้ว
#   st-override  → ให้ WSL เป็น master (ผลักไฟล์ที่ถูกต้องไปทุกเครื่อง)
#   st-resume    → เปิด sync (เครื่องอื่นจะได้รับ copy ใหม่ ไม่ใช่เอาเก่ามาทับ)
# ============================================================

# เลือก API ของเครื่องตัวเอง (JOE_ENV-aware)
_st_api() {
  case "$JOE_ENV" in
    TERMUX)   _ST_API_URL="${NODE_TERMUX_ST_URL}"; _ST_API_KEY="${NODE_TERMUX_ST_KEY}" ;;
    WSL)      _ST_API_URL="${NODE_WSL_ST_URL}";    _ST_API_KEY="${NODE_WSL_ST_KEY}"    ;;
    GIT-BASH) _ST_API_URL="${NODE_WIN_ST_URL}";    _ST_API_KEY="${NODE_WIN_ST_KEY}"    ;;
    MUMU)     _ST_API_URL="${NODE_MUMU_ST_URL}";   _ST_API_KEY="${NODE_MUMU_ST_KEY}"   ;;
    *)        _ST_API_URL=""; _ST_API_KEY="" ;;
  esac
}

# ค้นหา folder ID จาก label/path (หลีกเลี่ยง hardcode folder id)
# ป้องกัน injection: ส่ง $want ผ่าน stdin (ไม่ใช่ string interpolation)
_st_folder_id() {
  local want="${1:-ssot}"
  _st_api
  [[ -z "$_ST_API_URL" ]] && { echo ""; return 1; }
  curl -s -H "X-API-Key: $_ST_API_KEY" "$_ST_API_URL/rest/config/folders" 2>/dev/null \
    | want="$want" python3 -c "
import json,sys,os
try:
    fs = json.load(sys.stdin)
except Exception:
    sys.exit(1)
want = os.environ.get('want','').lower()
for f in fs:
    label = (f.get('label') or '').lower()
    path  = (f.get('path')  or '').lower()
    if label == want or path.endswith(want):
        print(f['id'])
        break
"
}

# st_pause [folder-label] — pause โฟลเดอร์ที่ระบุ (default: ssot)
st_pause() {
  local label="${1:-ssot}"
  local fid
  fid=$(_st_folder_id "$label")
  [[ -z "$fid" ]] && { cn r b "❌ Syncthing offline หรือไม่เจอโฟลเดอร์ $label"; return 1; }
  _st_api
  curl -s -X PATCH -H "X-API-Key: $_ST_API_KEY" -d '{"paused":true}' \
    "$_ST_API_URL/rest/config/folders/$fid" >/dev/null
  cn lg b "⏸️  Paused โฟลเดอร์ $label — แก้ไฟล์ได้สบาย (ไม่มี revert)"
}

# st_resume [folder-label] — resume โฟลเดอร์
st_resume() {
  local label="${1:-ssot}"
  local fid
  fid=$(_st_folder_id "$label")
  [[ -z "$fid" ]] && { cn r b "❌ Syncthing offline หรือไม่เจอโฟลเดอร์ $label"; return 1; }
  _st_api
  curl -s -X PATCH -H "X-API-Key: $_ST_API_KEY" -d '{"paused":false}' \
    "$_ST_API_URL/rest/config/folders/$fid" >/dev/null
  cn lg b "▶️  Resumed โฟลเดอร์ $label — เริ่ม sync แล้ว"
}

# st_override [folder-label] — บังคับให้เครื่องนี้เป็น master
# POST /rest/db/override → syncthing ถือว่า local copy ถูกต้องที่สุด
# แล้วผลัก (push) ไปทุกเครื่องที่เชื่อม — ใช้เมื่อเครื่องอื่นมี copy เก่า
st_override() {
  local label="${1:-ssot}"
  local fid
  fid=$(_st_folder_id "$label")
  [[ -z "$fid" ]] && { cn r b "❌ Syncthing offline หรือไม่เจอโฟลเดอร์ $label"; return 1; }
  _st_api
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "X-API-Key: $_ST_API_KEY" \
    "$_ST_API_URL/rest/db/override?folder=$fid")
  if [[ "$code" == "200" ]]; then
    cn lg b "🔁 Override สำเร็จ — $label บนเครื่องนี้เป็น master แล้ว (จะผลักไปทุกเครื่องเมื่อเชื่อม)"
  else
    cn r b "❌ Override ล้มเหลว (HTTP $code) — เช็ค syncthing หรือรอให้เครื่องอื่นเชื่อมก่อน"
    return 1
  fi
}

# st_push_tm — rsync ssot WSL → Termux ตรง ๆ (ใช้ก่อน resume
# เพื่อให้ Termux ได้ copy ที่ถูกต้องเป็นหลัก แทนที่จะเอา copy เก่ามาทับ)
st_push_tm() {
  local src="${1:-$SSOT/}"
  cn y b "📤 Pushing $src → Termux:$SSOT/ ..."
  _rsync_to_delete "${NODE_TERMUX_USER}" "${NODE_TERMUX_HOST}" "${NODE_TERMUX_PORT}" "$src" "$SSOT/"
  cn lg b "✅ Pushed — ตอนนี้ Termux ควรมี copy ที่ถูกต้องแล้ว"
}

# ============================================================
# st_register_all — ทำให้ทุกเครื่องรู้จักกันเอง (FULL MESH)
# ============================================================
# เป้าหมาย: ทุกเครื่องเชื่อมหากันแบบอิสระ (P2P) ไม่ต้องผ่าน hub
# ใช้เมื่อ: เพิ่มเครื่องใหม่ / reinstall / device id เปลี่ยน
# วิธี:
#   1. อ่าน device map มาตรฐานจาก 00-env.sh (NODE_*_ST_ID — SSOT)
#   2. ยืนยันกับเครื่องที่ online ว่า myID ตรงกับ SSOT ไหม
#   3. push device list ที่ถูกต้องไปทุกเครื่องที่ online (PUT + ลบตัวเก่า)
#   4. รายงานเครื่องที่ offline (รอเปิดแล้ว rerun)
# ============================================================
st_register_all() {
  _st_api
  [[ -z "$_ST_API_URL" ]] && { cn r b "❌ syncthing ของเครื่องนี้ไม่รัน — รัน syncthing_auto ก่อน"; return 1; }

  printf '%s\n' "$(c 51 b '🔗 Mesh Registration — อ่าน device map จาก SSOT (00-env.sh)')"
  local MY_ID
  MY_ID=$(curl -s -H "X-API-Key: $_ST_API_KEY" "$_ST_API_URL/rest/system/status" 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('myID',''))" 2>/dev/null)
  cn lg b "  ตัวเอง (JOE_ENV=$JOE_ENV) = ${MY_ID:0:13}..."
  echo ""

  # device map: ชื่อ → (id, url, key) — อ่านจาก SSOT
  local -A NODES=(
    [wsl]="$NODE_WSL_ST_ID|$NODE_WSL_ST_URL|$NODE_WSL_ST_KEY"
    [WIN]="$NODE_WIN_ST_ID|$NODE_WIN_ST_URL|$NODE_WIN_ST_KEY"
    [TERMUX]="$NODE_TERMUX_ST_ID|$NODE_TERMUX_ST_URL|$NODE_TERMUX_ST_KEY"
    [MUMU]="$NODE_MUMU_ST_ID|$NODE_MUMU_ST_URL|$NODE_MUMU_ST_KEY"
  )

  # canonical device map: <id>:<name> (SSOT)
  local canonical=""
  for n in wsl WIN TERMUX MUMU; do
    canonical="$canonical ${NODES[$n]%%|*}:$n"
  done

  # วนไปทุกเครื่องที่ online
  for n in wsl WIN TERMUX MUMU; do
    local entry="${NODES[$n]}"
    local url="${entry#*|}"; url="${url%%|*}"
    local key="${entry##*|}"
    local id="${entry%%|*}"

    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 -H "X-API-Key: $key" "$url/rest/system/status" 2>/dev/null)
    if [[ "$code" != "200" ]]; then
      printf '  %s\n' "$(cn 244 "" "🔴 $n — offline (HTTP $code) รอเปิดแล้ว rerun")"
      continue
    fi

    # ตรวจ myID จริง — ถ้าไม่ตรง SSOT ใช้ของจริง (SSOT ต้องอัปเดตทีหลัง)
    local real_id
    real_id=$(curl -s -m 5 -H "X-API-Key: $key" "$url/rest/system/status" 2>/dev/null \
      | python3 -c "import json,sys; print(json.load(sys.stdin).get('myID',''))" 2>/dev/null)
    if [[ -n "$real_id" && "$real_id" != "$id" ]]; then
      printf '  %s\n' "$(cn 226 b "⚠️  $n — myID จริง ($(echo $real_id | cut -c1-13)...) ≠ SSOT ($(echo $id | cut -c1-13)...) ใช้ของจริง")"
      id="$real_id"
    fi

    # ---- ขั้น 1: ลบ device ที่ไม่อยู่ใน canonical (ของเก่า/ผิด) ----
    local tmp_cur
    tmp_cur=$(mktemp)
    curl -s -m 5 -H "X-API-Key: $key" "$url/rest/config/devices" 2>/dev/null > "$tmp_cur"
    local removed=0
    while read -r cur_id; do
      [[ -z "$cur_id" ]] && continue
      if ! echo "$canonical" | grep -q "$cur_id"; then
        curl -s -m 5 -X DELETE -H "X-API-Key: $key" "$url/rest/config/devices/$cur_id" >/dev/null 2>&1
        echo "    🗑️  ลบ device เก่า: $(echo $cur_id | cut -c1-13)..." >&2
        removed=$((removed + 1))
      fi
    done < <(python3 -c "
import json,sys
try:
    for d in json.load(open('$tmp_cur')):
        print(d['deviceID'])
except Exception:
    pass
")
    rm -f "$tmp_cur"

    # ---- ขั้น 2: PUT/rename ทุก device ใน canonical (ยกเว้นตัวเอง) ----
    local ok_count=0
    local did dname
    while read -r did dname; do
      [[ -z "$did" ]] && continue
      local body
      body=$(python3 - "$did" "$dname" << 'PYEOF'
import json, sys
did, name = sys.argv[1], sys.argv[2]
print(json.dumps({
    "deviceID": did, "name": name, "addresses": ["dynamic"],
    "compression": "metadata", "certName": "", "introducer": False,
    "skipIntroductionRemovals": False, "introducedBy": "", "paused": False,
    "allowedNetworks": [], "autoAcceptFolders": False,
    "maxSendKbps": 0, "maxRecvKbps": 0, "maxRequestKiB": 0,
    "untrusted": False, "remoteGUIPort": 0, "numConnections": 0,
    "pausedPending": False,
}))
PYEOF
)
      local r
      r=$(curl -s -m 10 -X PUT -H "X-API-Key: $key" -d "$body" \
        "$url/rest/config/devices/$did" 2>/dev/null)
      if [[ -z "$r" ]]; then
        ok_count=$((ok_count + 1))
      else
        echo "    ⚠️  PUT $dname ล้มเหลว: $(echo "$r" | head -c 80)" >&2
      fi
    done < <(python3 - "$canonical" "$id" << 'PYEOF'
import json, sys
canonical = sys.argv[1].split()
self_id = sys.argv[2]
for entry in canonical:
    did, name = entry.split(":", 1)
    if did == self_id:
        continue
    print(did, name)
PYEOF
)

    # ---- ขั้น 3: ตั้งชื่อตัวเองให้ถูกต้อง ----
    local self_name
    for e in $canonical; do
      [[ "${e%%:*}" == "$id" ]] && self_name="${e##*:}"
    done
    local body2
    body2=$(python3 - "$id" "$self_name" << 'PYEOF'
import json, sys
print(json.dumps({
    "deviceID": sys.argv[1], "name": sys.argv[2], "addresses": ["dynamic"],
    "compression": "metadata", "certName": "", "introducer": False,
    "skipIntroductionRemovals": False, "introducedBy": "", "paused": False,
    "allowedNetworks": [], "autoAcceptFolders": False,
    "maxSendKbps": 0, "maxRecvKbps": 0, "maxRequestKiB": 0,
    "untrusted": False, "remoteGUIPort": 0, "numConnections": 0,
    "pausedPending": False,
}))
PYEOF
)
    curl -s -m 10 -X PUT -H "X-API-Key: $key" -d "$body2" \
      "$url/rest/config/devices/$id" >/dev/null 2>&1

    printf '  %s\n' "$(cn 46 b "🟢 $n — register เสร็จ (ลบ $removed ตัวเก่า, PUT $ok_count ตัว, ชื่อตัวเอง = $self_name)")"
  done

  echo ""
  c 51 b "──────────"
  cn lg b "✅ เสร็จ — รอ ~10 วิ แล้วรัน st-status เพื่อดู mesh"
}

alias st_regis_all='st_register_all'

# st_status — สรุปสถานะ folder ที่สนใจ (default: ssot)
st_status() {
  local label="${1:-ssot}"
  local fid
  fid=$(_st_folder_id "$label")
  _st_api
  if [[ -z "$fid" || -z "$_ST_API_URL" ]]; then
    cn r b "❌ Syncthing offline (${_ST_API_URL:-no api}) — เช็ค: syncthing_auto"
    return 1
  fi
  printf '%s\n' "$(c 51 b "── Syncthing: $label ($fid) ──")"
  curl -s -H "X-API-Key: $_ST_API_KEY" "$_ST_API_URL/rest/db/status?folder=$fid" 2>/dev/null \
    | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    print('  (no data — syncthing ยังไม่พร้อม?)'); sys.exit()
print(f\"  state       : {d.get('state')}\")
print(f\"  local items : {d.get('localTotalItems')}  (files {d.get('localFiles')})\")
print(f\"  global items: {d.get('globalTotalItems')}  (files {d.get('globalFiles')})\")
print(f\"  need        : {d.get('needTotalItems')}  (deletes {d.get('needDeletes')})\")
print(f\"  inSync      : {d.get('inSyncFiles')} files / {d.get('inSyncBytes')} bytes\")
print(f\"  errors      : {d.get('errors')}  pullErrors: {d.get('pullErrors')}\")
"
  c 51 b "── Devices ──"
  curl -s -H "X-API-Key: $_ST_API_KEY" "$_ST_API_URL/rest/system/connections" 2>/dev/null \
    | python3 -c "
import json,sys
try:
    data=json.load(sys.stdin)
except Exception:
    sys.exit()
for devid, conn in data.get('connections', {}).items():
    mark='🟢' if conn.get('connected') else '🔴'
    print(f\"  {mark} {devid[:13]}... {conn.get('address','')}\")
"
}

alias st-pause='st_pause'
alias st-override='st_override'
alias st-resume='st_resume'
alias st-push-tm='st_push_tm'
alias st-status='st_status'
