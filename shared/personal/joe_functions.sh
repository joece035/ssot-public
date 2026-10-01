#!/usr/bin/env bash
# ------------------------------------------------------------
# File: joe_functions.sh
# ------------------------------------------------------------
#-- git tools
#   git_ [cmd]        — git shortcut ใน SSOT repo
#   Sub-cmds:
#     s | status      → git status
#     c | commit <msg> → git commit -m
#     a | add         → git add -A
#     p | push        → git push origin main
#     pl | pull       → git pull --rebase
#     pln | pulln     → git pull --no-rebase (no rebase)
#     d | diff        → git diff --stat
#     l | log         → git log --oneline -10
#     all <msg>       → add + commit + pull --rebase + push (one-shot)
#     <other>         → pass through to git
git_() {
  local repo=${SSOT:-"$HOME/ssot"}
  cd $repo &&
  _guard_compat() {
      if ! typeset -f _check_compat >/dev/null 2>&1 && [[ -f "$repo/shared/.bash_checker" ]]; then
          source "$repo/shared/.bash_checker" 2>/dev/null
      fi
      if typeset -f _check_compat >/dev/null 2>&1; then
          _check_compat "$repo"
          return $?
      fi
      return 0
  }
  if [[ -n "$1" ]]; then
     case "${1:-}" in
        s|status)  git status ;;
        c|commit)
            [[ -z "${2:-}" ]] && { cn 196 b "✗ need message: git_ commit '<msg>'"; return 1; }
            _guard_compat || { cn 196 b "✗ commit aborted: fix compatibility issues first"; return 1; }
            git commit -m "$2"
            ;;
        a|add)     git add -A ;;
        p|push)    git push origin main && cn 10 bi "DONE push" ;;
        pl|pull)   git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; } ;;
        pln|pulln) git pull --no-rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; } ;;
        d|diff)    git diff --stat ;;
        l|log)     git log --oneline -10 ;;
        all)
            _guard_compat || { cn 196 b "✗ commit aborted: fix compatibility issues first"; return 1; }
            git add -A && \
            git commit -m "${2:-$(date '+%Y-%m-%d %H:%M:%S')}" && \
            (git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; }) && \
            git push origin main && \
            cn 10 bi "DONE push"
            ;;
        *)         git "$@" ;;
     esac
  else
    git status
  fi
}


g() {
    local repo="${SSOT:-$HOME/bashscripts}"
    [[ -d "$repo" ]] || { cn 196 b "✗ repo not found: $repo"; return 1; }
    cd "$repo" || return 1

    # ถ้าไม่มี args → commit+push (ถ้ามี change) หรือ push only
    if (( $# == 0 )); then
        if ! git diff --quiet HEAD 2>/dev/null || [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
            c 11 b "? Working tree dirty — commit with $(c 220 b 'date')? [y/N] "
            local ans; read -r ans
            [[ "$ans" =~ ^[Yy]$ ]] || { cn 220 b "→ cancelled"; return 0; }
            git add -A && git commit -m "$(date '+%Y-%m-%d %H:%M:%S')"
        fi
        git_ push
        return $?
    else
		  	case "$1" in
					-pu|--pull--rebase)
							git add -A &&
							git commit -m "$(date)" && 
					        git_ "pl" &&
                            _C -s -d "exec zsh" "exec bash"
							;;
			  	*)		
    # มี args → ส่งต่อไป git_ (ซึ่งรู้จัก s/c/a/all/push/pull ฯลฯ)
							
         			git_ "$@"
							;;
				esac			
							
    fi

}

repository_remote_url(){
    case $1 in
           url)
            git config --get remote.origin.url
            ;;
        status)
            git status
            ;;
        bsc)  
            cd ~/bashscripts && git remote set-url origin https://github.com/joece035/bashscripts-public.git
            ;;
        ssot)
            cd ~/ssot && git remote set-url origin https://github.com/joece035/ssot-public.git
            ;;
        *)
            git remote -v

            ;;
    esac
}
alias gremote='repository_remote_url'

# -- ฟังก์ชั่นหา Display Width ที่แท้จริง (รวม Emoji, Wide characters และตัด ANSI Code / PS1 delimiters ออก)

pwd(){
    local op="${1:-}"
    if [[ -z "$op" ]]; then
        builtin pwd
    else
        case "$op" in
            -b|--basename)
        basename "$(builtin pwd)"
        ;;
        -d|--dirname)
        dirname "$(builtin pwd)"
        ;;
        -s|--short) 
            echo "${PWD/#$HOME/\~}"
        ;;
        -a|--absolute)
        realpath "$(builtin pwd)"
        ;;
        *)
        builtin pwd "$op"
        ;;
    esac
 fi
 

}

_b2p(){
    local f="${1:-}"
    if [[ -z "$f" ]]; then
        cn y bi "Usage: _b2p <file> [.<ext>] [--clean|--no-notes]"
        cn y bi "  ext: .py | .ps1 | .sh  (default .py)"
        cn y bi "  ex: _b2p demo.sh .ps1 | _b2p demo.ps1 .sh | _b2p demo.py .sh"
        return 1
    fi
    if [[ ! -f "$f" ]]; then
        cn y bi "file $f not found"
        return 1
    fi
    shift

    # --- parse: ext ปลายทาง (รับ .py หรือ py) + flags ส่งต่อให้ codetrans ---
    local ext=".py" flags=()
    local a
    for a in "$@"; do
        case "$a" in
            --clean|--no-notes) flags+=("$a");;
            .py|.ps1|.psm1|.sh|.bash|py|ps1|psm1|sh|bash)
                ext=".${a#.}";;
            *)
                cn y bi "unknown arg: $a (want .py/.ps1/.sh or --clean/--no-notes)"
                return 1;;
        esac
    done

    local dst=""
    case "$ext" in
        .py) dst="python";;
        .ps1|.psm1) dst="powershell";;
        .sh|.bash) dst="bash";;
    esac

    # --- ภาษาต้นทาง: ดูจากนามสกุลก่อน, ไม่รู้จักค่อยดม shebang ---
    local src=""
    case ".${f##*.}" in
        .sh|.bash|.zsh) src="bash";;
        .py) src="python";;
        .ps1|.psm1) src="powershell";;
        *)
            local head1=""; head1=$(head -n 1 "$f" 2>/dev/null)
          	  case "$head1" in
                *python*) src="python";;
                *pwsh*|*powershell*) src="powershell";;
                *bash*|*zsh*|*/sh) src="bash";;
            	esac
            ;;
    esac
    if [[ -z "$src" ]]; then
        cn y bi "cannot detect source language of $f (rename to .sh/.py/.ps1 or add shebang)"
        return 1
    fi
    if [[ "$src" == "$dst" ]]; then
        cn y bi "same language ($src) — nothing to convert"
        return 1
    fi

    local ssot_dir="${SSOT:-${SCRIPTS_PATH:-$HOME/ssot}}"
    local tool="$ssot_dir/bash_to_python/codetrans.py"
    [[ -f "$tool" ]] || tool="$ssot_dir/codetrans/codetrans.py"  # fallback path เดิม
    if [[ ! -f "$tool" ]]; then
        cn r bi "tool not found: $tool"
        return 1
    fi

    local out_dir="$ssot_dir/bash_to_python/output"
    local out="$out_dir/$(basename "${f%.*}")$ext"
    mkdir -p "$out_dir"

    if [[ -f "$out" ]]; then
        cn y bi "file $out already exists"
        return 1
    fi

    if python3 "$tool" "$f" -f "$src" -t "$dst" -o "$out" "${flags[@]}"; then
        chmod +x "$out"
        cn lg bi "save file in $out ($src -> $dst)"
    else
        cn r bi "codetrans translation failed"
        return 1
    fi
}		
		