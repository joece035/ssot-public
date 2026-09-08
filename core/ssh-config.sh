#!/bin/bash
# ============================================================
# ssh-config.sh — Multi-node Infrastructure (SSH · CONFIGURATIONs)
# ============================================================
# -- helper ssh setp
cb_read() {
  if command -v powershell.exe &>/dev/null; then
    powershell.exe -NoProfile -Command "Get-Clipboard" 2>/dev/null | tr -d '\r'
  elif command -v xclip &>/dev/null; then 
    xclip -selection clipboard -o 2>/dev/null
  elif command -v xsel &>/dev/null; then 
    xsel --clipboard --output 2>/dev/null
  fi
}
cb_copy ()
{
    local input="$1";
    
    # 1. เช็ก clip.exe ก่อนเสมอ (ถ้าเจอจะใช้ตัวนี้แล้วจบเลย)
    if command -v clip.exe &> /dev/null; then
        printf '%s' "$input" | clip.exe;
        
    # 2. ถ้าไม่เจอ clip.exe (เช่น ไม่ได้อยู่ใน WSL) จะเข้านี้แทน
    elif command -v powershell.exe &> /dev/null; then
        printf '%s' "$input" | powershell.exe -NoProfile -Command "Set-Clipboard -Value \$input" 2> /dev/null;
        
    # 3. ถ้าอยู่ใน Linux เพียวๆ จะไปใช้ xclip หรือ xsel
    elif command -v xclip &> /dev/null; then
        printf '%s' "$input" | xclip -selection clipboard;
    elif command -v xsel &> /dev/null; then
        printf '%s' "$input" | xsel --clipboard --input;
    fi
}
ssh_kgen(){
  #-- สร้าง public/private key หากยังไม่มี
  local machine="${1:-}"
  local keyfile="$HOME/.ssh/id_ed25519_${machine}"
  
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  if [[ -f "$keyfile" ]]; then
    echo "SSH key already exists at $keyfile"
  else
    # ใส่ -N "" เพื่อสร้าง Key แบบไม่มี passphrase ทันที ป้องกัน Script ค้างถาม
    ssh-keygen -t ed25519 -C "${machine}" -f "${keyfile}" -N ""
    
  fi

  local pub_key
  pub_key=$(cat "${keyfile}.pub")
  
  # คัดลอกลง Clipboard และแสดงผล
  cb_copy "$pub_key"
  echo "Copied to clipboard:"
  echo "$pub_key"
}
ssh_kadd(){
  #-- เพิ่ม Public Key ลงใน authorized_keys ของเครื่องปลายทาง (ป้องกันการเพิ่มซ้ำ)
  local pub_key="${1:-$(cb_read)}"
  local auth_file="$HOME/.ssh/authorized_keys"

  # ตรวจสอบว่ามีค่า Public Key ส่งมาจริงหรือไม่
  if [[ -z "$pub_key" ]]; then
    echo "Error: No public key provided or clipboard is empty." >&2
    return 1
  fi

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  touch "$auth_file"
  chmod 600 "$auth_file"

  # ตรวจสอบ Key ซ้ำ
  if grep -qF "$pub_key" "$auth_file"; then
    echo "Key already exists in $auth_file"
  else
    echo "$pub_key" >> "$auth_file"
    echo "Done: Added SSH key to $auth_file"
  fi
}
#-- all device environment variable from 00-env.sh

# Helper สำหรับสั่ง Remote Command หรือ SSH เข้าเครื่องต่างๆ
ssh_() {
  local tar="$1"
  shift
    case "$tar" in
        t|tm|termux|TERMUX)         ssh termux    "$@" ;;
        w|tw|window|win|WINDOW)     ssh window    "$@" ;;
        gb|gitbash|GITBASH|g)       ssh window    "& '${WIN_GIT_BASH}' --login -i" "$@" ;;
        mm|mumu|MUMU|m)             ssh mumu      "$@" ;;
        wsl|WSL|WSL2)               ssh wsl       "$@" ;;
        op|oppo|OPPO|o)             ssh oppo      "$@" ;;
        ax|a|ACODEX|A)              ssh -p 8021 root@termux "bash" "$@" ;;
        *) cn r b "usage ssh_ <host>"; return 1 ;;
    esac     

}
## ============================================================
# Node Resolver Helper (ดึงค่า SSOT ตามชื่อเครื่อง/Alias)
# ============================================================
node_resolve() {
    local target="${1:-}"
    TARGET_HOST=""
    TARGET_PORT=""
    TARGET_USER=""

    case "$target" in
        t|tm|termux|TERMUX)
            TARGET_HOST="$NODE_TERMUX_HOST"
            TARGET_PORT="${NODE_TERMUX_PORT:-8022}"
            TARGET_USER="$NODE_TERMUX_USER"
            ;;
        w|win|window|WINDOW)
            TARGET_HOST="$NODE_WIN_HOST"
            TARGET_PORT="${NODE_WIN_PORT:-22}"
            TARGET_USER="$NODE_WIN_USER"
            ;;
        m|mm|mumu|MUMU)
            TARGET_HOST="$NODE_MUMU_HOST"
            TARGET_PORT="${NODE_MUMU_PORT:-8022}"
            TARGET_USER="$NODE_MUMU_USER"
            ;;
        wsl|WSL|WSL2)
            TARGET_HOST="$NODE_WSL_HOST"
            TARGET_PORT="${NODE_WSL_PORT:-22}"
            TARGET_USER="$NODE_WSL_USER"
            ;;
        o|op|oppo|OPPO)
            TARGET_HOST="$NODE_OPPO_HOST"
            TARGET_PORT="${NODE_OPPO_PORT:-8023}"
            TARGET_USER="$NODE_OPPO_USER"
            ;;
        *)
            cn r b "Error: Unknown node '$target'"
            echo "Usage: <termux|window|mumu|wsl> (or alias: t, w, m, wsl)" >&2
            return 1
            ;;
    esac
}

# ============================================================
# Push: ส่งไฟล์/โฟลเดอร์จากเครื่องนี้ (Local) -> Node ปลายทาง (Remote)
# Usage: push_cmd <node> [src_path] [dest_path]
# ============================================================
push_cmd() {
    local node="${1:-}"
    local src="${2:-${PWD}/}"
    local dest="${3:-}"

    if [[ -z "$node" ]]; then
        cn y b "Usage: push_cmd <node> [src_path] [dest_path]"
        return 1
    fi

    # ดึง Config ของปลายทาง
    node_resolve "$node" || return 1

    # ปลายทางเริ่มต้น: ถ้าไม่ระบุให้ลงที่ Path เดียวกันกับฝั่งต้นทาง
    dest="${dest:-$src}"

    cn 10 bi ">> Pushing to ${TARGET_HOST} (${TARGET_USER}@${TARGET_HOST}:${TARGET_PORT})..."
    
    # รัน rsync: แยก -e "ssh -p ..." ออกจาก source และ destination
    if [[ "${_SSOT_HAS_RSYNC:-0}" -eq 1 ]]; then
      rsync -avz --progress \
          -e "ssh -p ${TARGET_PORT}" \
          "${src}" \
          "${TARGET_USER}@${TARGET_HOST}:${dest}"
    else
      scp -P "${TARGET_PORT}" -r \
          "${src}" \
          "${TARGET_USER}@${TARGET_HOST}:${dest}"
    fi
}

# ============================================================
# Pull: ดึงไฟล์/โฟลเดอร์จาก Node ปลายทาง (Remote) -> เครื่องนี้ (Local)
# Usage: pull_cmd <node> <remote_src> [local_dest]
# ============================================================
pull_cmd() {
    local node="${1:-}"
    local remote_src="${2:-}"
    local local_dest="${3:-${PWD}/}"

    if [[ -z "$node" || -z "$remote_src" ]]; then
        cn y b "Usage: pull_cmd <node> <remote_src_path> [local_dest_path]"
        return 1
    fi

    # ดึง Config ของปลายทาง
    node_resolve "$node" || return 1

    cn 10 bi "<< Pulling from ${TARGET_HOST} (${TARGET_USER}@${TARGET_HOST}:${TARGET_PORT})..."

    if [[ "${_SSOT_HAS_RSYNC:-0}" -eq 1 ]]; then
      rsync -avz --progress \
          -e "ssh -p ${TARGET_PORT}" \
          "${TARGET_USER}@${TARGET_HOST}:${remote_src}" \
          "${local_dest}"
    else
      scp -P "${TARGET_PORT}" -r \
          "${TARGET_USER}@${TARGET_HOST}:${remote_src}" \
          "${local_dest}"
    fi
}


_rsync () {
    local src   =${1:-}
    local dest  =${2:-}
    local host  =${3:-$HOST_} # รับเป็นชื่อ alias เช่น mumu หรือ termux
    
    if [[ "${_SSOT_HAS_RSYNC:-0}" -eq 1 ]]; then
      rsync -avz "${src}" "${host}:${dest}" && cn 10 bi "DOWNLOAD DONE : ${src} ${dest}"
    else
      scp -r "${src}" "${host}:${dest}" && cn 10 bi "DOWNLOAD DONE (scp) : ${src} ${dest}"
    fi
}


 send(){
     local host=${1:-}
     local src_=${2:-}
     local dest_=${3:-}
     
     case "$host" in
        tm|termux|TERMUX|t)
                    HOST_=termux
                    ;;
        mumu|mm|MUMU)
                    HOST_=mumu  
                   ;;
        w|win|window|W|WINDOW)
                    HOST_=window
                    ;;
        wsl|WSL|WSL2)
                    HOST_=wsl
                    ;;
        *)          cn 198 b "UNNKOWN DEVICE"           
     esac                                   
                    
      _rsync "$HOST_" "${src_}" "${dest_}"            
 }

s(){
  ssh_ "$@"
}

# ============================================================
# SSOT: Windows PowerShell shared constants & helpers
# ============================================================
# These vars/functions are the canonical reference for any module that
# needs to talk to Windows PowerShell via SSH (3worlds.sh, plugins, etc).
# อย่า duplicate — ให้ source ssh-config.sh ก่อนแล้วเรียก helpers เหล่านี้
#
# Why constants:
#   - PS_BANNER_LINES  : จำนวนบรรทัด banner ที่ JoeMSI PowerShell profile.ps1
#                        เขียนออกมาทุกครั้ง (proven 2026-08-24) — ตัวกรอง output
#   - PS_REMOTE_CMD    : command line สำหรับ `ssh window` ที่:
#                        * bypass default OpenSSH PowerShell login shell (via cmd /c)
#                        * suppress profile.ps1 banner (-NoProfile)
#                        * suppress startup banner (-NoLogo)
#                        * run unsigned scripts (-ExecutionPolicy Bypass)
#                        * read script body from stdin (-Command -)
#   - PS_HOST          : SSH alias (resolves from ~/.ssh/config)
#
# Remote-side gotcha (see ps_remote comment):
#   - Multi-line PS with backtick continuation → broken through stdin pipe
#     (use single-line scripts only)
#   - Format-Table output drops through SSH pipe (use ConvertTo-Json -Compress)
#   - scp to JoeMSI fails (banner garbage) — always pipe stdin

PS_HOST="${PS_HOST:-window}"
PS_BANNER_LINES="${PS_BANNER_LINES:-5}"   # JoeMSI user profile.ps1 prints 5 lines
PS_REMOTE_CMD="${PS_REMOTE_CMD:-cmd /c \"powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -Command -\"}"

export PS_HOST PS_BANNER_LINES PS_REMOTE_CMD

# ps_strip_banner — strip leading banner lines from PowerShell output
#   Usage: ps_remote '...' | ps_strip_banner
#   Use when caller can't hardcode tail -n +N
ps_strip_banner() {
  tail -n +"$((PS_BANNER_LINES + 1))"
}

# ============================================================
# ps_remote — Run PowerShell on Windows (escape-safe)
# ============================================================
# ปัญหาเดิม (3 layers):
#   1) ssh window "powershell -Command \$_.Foo" → bash ตีความ $_ ก่อน
#   2) Windows PowerShell user profile.ps1 prints banner on every start
#      → ทุก non-interactive SSH command ได้ banner ปน output (~5KB noise)
#   3) scp พัง ("message too long 458960955") — binary garbage จาก profile
#
# วิธีนี้ (proven):
#   pipe PS script ผ่าน stdin → ssh window 'cmd /c "powershell -NoProfile -NoLogo -Command -"'
#   - cmd wrapper bypass default OpenSSH PowerShell login shell
#   - -NoProfile กัน user profile.ps1
#   - PowerShell อ่าน script จาก stdin (the trailing "-")
#   - ไม่ต้องสร้างไฟล์ชั่วคราว
#
# Usage:
#   ps_remote 'Get-Process | Select-Object -First 3 Name,Id'
#   ps_remote <<'PS'   # ใช้ <<'PS' (single-quoted) กัน bash expand
#     Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
#       Where-Object { $_.DisplayName -match 'CapCut' }
#   PS
ps_remote() {
  local script=""

  # Case 1: arguments mode — join all args with spaces
  if [[ $# -gt 0 ]]; then
    script="$*"
  # Case 2: stdin heredoc mode — read until EOF
  else
    script="$(cat)"
  fi

  [[ -z "$script" ]] && { echo "Usage: ps_remote '<ps_script>'  OR  ps_remote <<'PS' ... PS" >&2; return 1; }

  # Pipe script via stdin → ssh $PS_HOST "$PS_REMOTE_CMD" → PowerShell -Command -
  # Constants PS_HOST + PS_REMOTE_CMD live in ssh-config.sh (SSOT).
  printf '%s\n' "$script" | ssh "$PS_HOST" "$PS_REMOTE_CMD" 2>/dev/null \
    | sed 's/\r$//'
  return ${PIPESTATUS[1]}
}

# ps_remote_file <local.ps1> [args...]
#   → เหมือน ps_remote แต่รับ path ของ .ps1 (เหมาะ script ยาว)
#   ใช้ 'Get-Content -Raw | Invoke-Expression' ผ่าน stdin pipe
ps_remote_file() {
  local local_ps1="$1"; shift || { echo "Usage: ps_remote_file <local.ps1> [args...]" >&2; return 1; }
  [[ ! -f "$local_ps1" ]] && { echo "ps_remote_file: file not found: $local_ps1" >&2; return 1; }

  cat "$local_ps1" | ssh "$PS_HOST" "$PS_REMOTE_CMD" 2>/dev/null \
    | sed 's/\r$//'
  return ${PIPESTATUS[1]}
}

# win_programs [search_pattern]
#   → List installed programs on Windows (HKLM uninstall registry)
#   Default search: 'CapCut|Clipchamp|DaVinci|OBS|ShareX|VLC|ffmpeg'
#
# Implementation notes:
#   1) ConvertTo-Json -Compress (NOT Format-Table) → Format-Table's rich
#      formatting doesn't survive SSH stdin pipe (buffering drops output);
#      JSON is line-buffered and survives intact
#   2) Banner จาก JoeMSI PowerShell profile.ps1 ยังโผล่ (5 lines) — strip
#      ด้วย `tail -n +6` ก่อนส่งออก
#   3) **Single-line script only** — multi-line with backtick continuation
#      through SSH stdin pipe พัง (PowerShell -Command - รอ stdin ต่อจาก
#      backtick ที่บอกว่า "อ่านต่อ" แต่ stdin ปิดไปแล้ว → ไม่มี output)
#   4) Pattern ใส่ใน PowerShell **double-quoted** string ("...") — ไม่ต้อง
#      escape single-quote เพราะ pattern ของผู้ใช้คาดว่ามี pipe (|) ไม่มี quote
win_programs() {
  local pat="${1:-CapCut|Clipchamp|DaVinci|OBS|ShareX|VLC|ffmpeg}"
  # Single-line PowerShell — backtick continuation ใช้ไม่ได้ผ่าน SSH stdin
  printf 'Get-ItemProperty HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\* -EA SilentlyContinue | Where-Object { $_.DisplayName -match "%s" } | Select-Object DisplayName, DisplayVersion, Publisher | ConvertTo-Json -Compress\n' "${pat}" \
    | ps_remote | ps_strip_banner
}