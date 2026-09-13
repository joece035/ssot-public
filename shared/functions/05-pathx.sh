#!/usr/bin/env bash
# ============================================================
# 🧭 PATHX & P() — Universal Path Explorer & Normalizer
# ============================================================
# Part of SSOT Infrastructure (~/ssot/)
# Compatible: WSL (Ubuntu), Termux, Git-Bash, Linux, macOS
# Supported Shells: Bash 4+, Zsh
# ============================================================

pathx() {
    local input_path
    local target_format="wsl" # Default target format

    # Handle smart flags
    if [[ "$1" == "win" ]]; then
        target_format="win"
        shift
    elif [[ "$1" == "wsl" ]]; then
        target_format="wsl"
        shift
    elif [[ "$1" == "git" ]]; then
        target_format="git"
        shift
    fi

    # Handle argument or clipboard input
    if [[ -n "$1" ]]; then
        input_path="$1"
    else
        # Read from Windows clipboard
        if command -v cb_read >/dev/null 2>&1; then
            input_path="$(cb_read)"
        elif command -v powershell.exe >/dev/null 2>&1; then
            input_path="$(powershell.exe -NoProfile -Command "Get-Clipboard" 2>/dev/null | tr -d '\r')"
        fi
    fi

    if [[ -z "$input_path" ]]; then
        echo "Error: No path provided and clipboard is empty." >&2
        return 1
    fi

    local detected_source_format=""
    local common_path=""

    # Auto-detect source format and convert to a common internal format (e.g., C:/Users/User)
    if [[ "$input_path" =~ ^[A-Za-z]:\\ ]]; then
        # Windows path (e.g., C:\Users\User)
        detected_source_format="win"
        common_path="$(printf '%s' "$input_path" | tr '\\' '/')" # Convert backslashes to forward slashes safely
    elif [[ "$input_path" =~ ^/mnt/[A-Za-z]/ ]]; then
        # WSL path (e.g., /mnt/c/Users/User)
        detected_source_format="wsl"
        common_path="$(printf '%s' "$input_path" | sed 's/^\/mnt\/\([A-Za-z]\)/\U\1:/')" # /mnt/c/ -> C:
    elif [[ "$input_path" =~ ^/[A-Za-z]/ ]]; then
        # Git Bash path (e.g., /c/Users/User)
        detected_source_format="git"
        common_path="$(printf '%s' "$input_path" | sed 's/^\/\([A-Za-z]\)/\U\1:/')" # /c/ -> C:
    else
        echo "Error: Could not detect source path format for: $input_path" >&2
        return 1
    fi

    local output_path=""

    # Convert from common_path to target_format
    if [[ "$target_format" == "win" ]]; then
        output_path="$(printf '%s' "$common_path" | sed 's/^\([A-Za-z]\):/\1:/' | tr '/' '\\')" # C:/ -> C: and / -> \
    elif [[ "$target_format" == "wsl" ]]; then
        output_path="$(printf '%s' "$common_path" | sed 's/^\([A-Za-z]\):/\/mnt\/\L\1/')" # C: -> /mnt/c
    elif [[ "$target_format" == "git" ]]; then
        output_path="$(printf '%s' "$common_path" | sed 's/^\([A-Za-z]\):/\/\L\1/')" # C: -> /c
    fi

    # Output to stdout
    printf '%s\n' "$output_path"

    # Copy to clipboard
    if command -v cb_copy >/dev/null 2>&1; then
        cb_copy "$output_path" >/dev/null 2>&1
    elif command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -Command "Set-Clipboard -Value \"$output_path\"" 2>/dev/null
    fi
}

# ─────────────────────────────────────────────
# p() — Universal Path Compatibility Layer
# Drop into ~/.bashrc / ~/.zshrc (WSL / Git Bash)
# ─────────────────────────────────────────────

# ── p() v3 — JOE_ENV-aware, handles Windows + WSL UNC paths ──

WSL_DISTRO="Ubuntu"   # ← Default distro fallback

p() {
  if ! command -v cb_read >/dev/null 2>&1; then
    if command -v _check >/dev/null 2>&1; then
      _check -f "${SSOT:-$HOME/ssot}/core/ssh_toolkit.sh" "source" 2>/dev/null
    elif [[ -f "${SSOT:-$HOME/ssot}/core/ssh_toolkit.sh" ]]; then
      source "${SSOT:-$HOME/ssot}/core/ssh_toolkit.sh" 2>/dev/null
    fi
  fi
  local raw converted drive rest distro

  # 1. Input: $1 หรือ clipboard
  if [[ -n "${1:-}" ]]; then
    raw="$1"
  elif command -v cb_read >/dev/null 2>&1; then
    raw="$(cb_read)"
  elif command -v powershell.exe >/dev/null 2>&1; then
    raw="$(powershell.exe -NoProfile -Command "Get-Clipboard" 2>/dev/null | tr -d '\r')"
  fi

  [[ -z "$raw" ]] && { echo "[p] No input." >&2; return 1; }

  # 2. Normalize whitespace, quotes, and backslashes (avoid echo to prevent Zsh escape corruption)
  raw="$(printf '%s' "$raw" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  raw="${raw//\"/}"   # ลบ double quote
  raw="${raw//\'/}"   # ลบ single quote
  raw="$(printf '%s' "$raw" | tr '\\' '/')"  # normalize backslash → forward slash

  # Normalize WSL UNC prefix: //wsl.localhost/ or //wsl$/ or /wsl.localhost/ or wsl.localhost/ or wsl$/
  raw="$(printf '%s' "$raw" | sed -E 's#^/*(wsl\.localhost|wsl\$)/#//wsl.localhost/#')"

  # 3. Detect + convert
  # ── Case A: WSL UNC path  //wsl.localhost/Ubuntu/home/... ──
  if [[ "$raw" =~ ^//wsl\.localhost/([^/]+)(/.*)$ ]]; then
    # Portable regex match extraction (bash: BASH_REMATCH, zsh: match, fallback: parameter expansion)
    if [[ -n "${BASH_REMATCH[1]:-}" ]]; then
      distro="${BASH_REMATCH[1]}"
      rest="${BASH_REMATCH[2]}"
    elif [[ -n "${match[1]:-}" ]]; then
      distro="${match[1]}"
      rest="${match[2]}"
    else
      distro="${raw#//wsl.localhost/}"
      distro="${distro%%/*}"
      rest="${raw#//wsl.localhost/$distro}"
    fi

    case "${JOE_ENV:-WSL}" in
      WSL)      converted="$rest" ;;
      GIT-BASH) converted="//wsl.localhost/${distro}${rest}" ;;
      WIN)      converted="\\\\wsl.localhost\\${distro}$(printf '%s' "$rest" | tr '/' '\\')" ;;
      *)        converted="$rest" ;;
    esac

  # ── Case B: Windows drive path  C:/Users/... ──
  elif [[ "$raw" =~ ^([A-Za-z]):(/.*)$ ]]; then
    if [[ -n "${BASH_REMATCH[1]:-}" ]]; then
      drive="${BASH_REMATCH[1]}"
      rest="${BASH_REMATCH[2]}"
    elif [[ -n "${match[1]:-}" ]]; then
      drive="${match[1]}"
      rest="${match[2]}"
    else
      drive="${raw%%:*}"
      rest="${raw#*:}"
    fi
    drive="$(printf '%s' "$drive" | tr '[:upper:]' '[:lower:]')"

    case "${JOE_ENV:-WSL}" in
      WSL)      converted="/mnt/${drive}${rest}" ;;
      GIT-BASH) converted="/${drive}${rest}" ;;
      WIN)      converted="$(printf '%s' "$drive" | tr '[:lower:]' '[:upper:]'):$(printf '%s' "$rest" | tr '/' '\\')" ;;
      *)        converted="/mnt/${drive}${rest}" ;;
    esac

  # ── Case C: Already a valid Linux/WSL /home or /mnt or / path ──
  elif [[ "$raw" =~ ^/ ]]; then
    converted="$raw"

  else
    echo "[p] Unrecognized path format: $raw" >&2
    return 1
  fi

  # 4. Output + clipboard
  printf '%s\n' "$converted"
  if command -v cb_copy >/dev/null 2>&1; then
    cb_copy "$converted" >/dev/null 2>&1
  fi
}

imma_jump_to_the_fucking_god_damn_windows_path_from_wsl_by_typing_only_fuckin_j() {
   cdc "$(p)"
}
alias j='imma_jump_to_the_fucking_god_damn_windows_path_from_wsl_by_typing_only_fuckin_j'
