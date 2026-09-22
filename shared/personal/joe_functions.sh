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
							git add -A 
							git commit -m "$(date)" 
					    git_ "pl"
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

