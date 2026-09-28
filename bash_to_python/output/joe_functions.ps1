# bash: #!/usr/bin/env bash
#!/usr/bin/env pwsh
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
# bash: git_() {
function git_ {
    # bash: local repo=${SSOT:-"$HOME/ssot"}
    $repo = ($SSOT ?? "$HOME/ssot")
    # bash: cd $repo &&
    cd $repo &&
    # bash: _guard_compat() {
    function _guard_compat {
        # bash: if ! typeset -f _check_compat >/dev/null 2>&1 && [[ -f "$repo/shared/.bash_checker" ]]; then
        if ((-not (typeset -f _check_compat >/dev/null 2>&1) -and Test-Path "$repo/shared/.bash_checker" -PathType Leaf)) {
            # bash: source "$repo/shared/.bash_checker" 2>/dev/null
            source "$repo/shared/.bash_checker" 2>/dev/null
        # bash: fi
        }
        # bash: if typeset -f _check_compat >/dev/null 2>&1; then
        if (typeset -f _check_compat >/dev/null 2>&1) {
            # bash: _check_compat "$repo"
            _check_compat "$repo"
            # bash: return $?
            return $?
        # bash: fi
        }
        # bash: return 0
        return 0
    # bash: }
    }
    # bash: if [[ -n "$1" ]]; then
    if (-not [string]::IsNullOrEmpty($args[0])) {
        # bash: case "${1:-}" in
        switch -Wildcard (($args[0] ?? '')) {
            # bash: s|status)  git status ;;
            { $_ -eq 's' -or $_ -eq 'status' } {
                git status
                break
            }
            # bash: c|commit)
            { $_ -eq 'c' -or $_ -eq 'commit' } {
                # bash: [[ -z "${2:-}" ]] && { cn 196 b "✗ need message: git_ commit '<msg>'"; return 1; }
                [[ -z "${2:-}" ]] && { cn 196 b "✗ need message: git_ commit '<msg>'"
                return 1
            }
            # bash: _guard_compat || { cn 196 b "✗ commit aborted: fix compatibility issues first"; return 1; }
            _guard_compat || { cn 196 b "✗ commit aborted: fix compatibility issues first"
            return 1
        }
        # bash: git commit -m "$2"
        git commit -m "$2"
        break
            }
            # bash: a|add)     git add -A ;;
            { $_ -eq 'a' -or $_ -eq 'add' } {
                git add -A
                break
            }
            # bash: p|push)    git push origin main && cn 10 bi "DONE push" ;;
            { $_ -eq 'p' -or $_ -eq 'push' } {
                git push origin main && cn 10 bi "DONE push"
                break
            }
            # bash: pl|pull)   git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; } ;;
            { $_ -eq 'pl' -or $_ -eq 'pull' } {
                git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"
                return 1
            }
            break
            }
            # bash: pln|pulln) git pull --no-rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; } ;;
            { $_ -eq 'pln' -or $_ -eq 'pulln' } {
                git pull --no-rebase || { cn 9 b "PULL FAILED — resolve conflicts"
                return 1
            }
            break
            }
            # bash: d|diff)    git diff --stat ;;
            { $_ -eq 'd' -or $_ -eq 'diff' } {
                git diff --stat
                break
            }
            # bash: l|log)     git log --oneline -10 ;;
            { $_ -eq 'l' -or $_ -eq 'log' } {
                git log --oneline -10
                break
            }
            # bash: all)
            'all' {
                # bash: _guard_compat || { cn 196 b "✗ commit aborted: fix compatibility issues first"; return 1; }
                _guard_compat || { cn 196 b "✗ commit aborted: fix compatibility issues first"
                return 1
            }
            # bash: git add -A &&              git commit -m "${2:-$(date '+%Y-%m-%d %H:%M:%S')}" &&              (git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; }) &&              git push origin main &&              cn 10 bi "DONE push"
            git add -A &&              git commit -m "${2:-$(date '+%Y-%m-%d %H:%M:%S')}" &&              (git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"
            return 1
            break
            }
            '}' {
                &&              git push origin main &&              cn 10 bi "DONE push"
                break
            }
            # bash: *)         git "$@" ;;
            default {
                git "$@"
                break
            }
        # bash: esac
        }
    # bash: else
    } else {
        # bash: git status
        git status
    # bash: fi
    }
# bash: }
}


# bash: g() {
function g {
    # bash: local repo="${SSOT:-$HOME/bashscripts}"
    $repo = ($SSOT ?? "$HOME/bashscripts")
    # bash: [[ -d "$repo" ]] || { cn 196 b "✗ repo not found: $repo"; return 1; }
    [[ -d "$repo" ]] || { cn 196 b "✗ repo not found: $repo"
    return 1
}
# bash: cd "$repo" || return 1
cd "$repo" || return 1

# ถ้าไม่มี args → commit+push (ถ้ามี change) หรือ push only
# bash: if (( $# == 0 )); then
if (( $# == 0 )) {
    # bash: if ! git diff --quiet HEAD 2>/dev/null || [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
    if (-not (git diff --quiet HEAD 2>/dev/null) -or -not [string]::IsNullOrEmpty($(git ls-files --others --exclude-standard 2>/dev/null))) {
        # bash: c 11 b "? Working tree dirty — commit with $(c 220 b 'date')? [y/N] "
        c 11 b "? Working tree dirty — commit with $(c 220 b 'date')? [y/N] "
        # bash: local ans; read -r ans
        ans
        $ans = Read-Host
        # bash: [[ "$ans" =~ ^[Yy]$ ]] || { cn 220 b "→ cancelled"; return 0; }
        [[ "$ans" =~ ^[Yy]$ ]] || { cn 220 b "→ cancelled"
        return 0
    }
    # bash: git add -A && git commit -m "$(date '+%Y-%m-%d %H:%M:%S')"
    git add -A && git commit -m "$(date '+%Y-%m-%d %H:%M:%S')"
# bash: fi
}
# bash: git_ push
git_ push
# bash: return $?
return $?
# bash: else
} else {
    # bash: case "$1" in
    switch -Wildcard ($args[0]) {
        # bash: -pu|--pull--rebase)
        { $_ -eq '-pu' -or $_ -eq '--pull--rebase' } {
            # bash: git add -A
            git add -A
            # bash: git commit -m "$(date)"
            git commit -m "$(date)"
            # bash: git_ "pl"
            git_ "pl"
            # bash: _C -s -d "exec zsh" "exec bash"
            _C -s -d "exec zsh" "exec bash"
            break
        }
        # bash: *)
        default {
            # มี args → ส่งต่อไป git_ (ซึ่งรู้จัก s/c/a/all/push/pull ฯลฯ)

            # bash: git_ "$@"
            git_ "$@"
            break
        }
    # bash: esac
    }

# bash: fi
}

# bash: }
}

# bash: repository_remote_url(){
function repository_remote_url {
    # bash: case $1 in
    switch -Wildcard ($args[0]) {
        # bash: url)
        'url' {
            # bash: git config --get remote.origin.url
            git config --get remote.origin.url
            break
        }
        # bash: status)
        'status' {
            # bash: git status
            git status
            break
        }
        # bash: bsc)
        'bsc' {
            # bash: cd ~/bashscripts && git remote set-url origin https://github.com/joece035/bashscripts-public.git
            cd ~/bashscripts && git remote set-url origin https://github.com/joece035/bashscripts-public.git
            break
        }
        # bash: ssot)
        'ssot' {
            # bash: cd ~/ssot && git remote set-url origin https://github.com/joece035/ssot-public.git
            cd ~/ssot && git remote set-url origin https://github.com/joece035/ssot-public.git
            break
        }
        # bash: *)
        default {
            # bash: git remote -v
            git remote -v

            break
        }
    # bash: esac
    }
# bash: }
}
# bash: alias gremote='repository_remote_url'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias gremote='repository_remote_url'

# -- ฟังก์ชั่นหา Display Width ที่แท้จริง (รวม Emoji, Wide characters และตัด ANSI Code / PS1 delimiters ออก)

# bash: pwd(){
function pwd {
    # bash: local op="${1:-}"
    $op = ($args[0] ?? '')
    # bash: if [[ -z "$op" ]]; then
    if ([string]::IsNullOrEmpty($op)) {
        # bash: builtin pwd
        builtin pwd
    # bash: else
    } else {
        # bash: case "$op" in
        switch -Wildcard ($op) {
            # bash: -b|--basename)
            { $_ -eq '-b' -or $_ -eq '--basename' } {
                # bash: basename "$(builtin pwd)"
                basename "$(builtin pwd)"
                break
            }
            # bash: -d|--dirname)
            { $_ -eq '-d' -or $_ -eq '--dirname' } {
                # bash: dirname "$(builtin pwd)"
                dirname "$(builtin pwd)"
                break
            }
            # bash: -s|--short)
            { $_ -eq '-s' -or $_ -eq '--short' } {
                # bash: echo "${PWD/#$HOME/\~}"
                Write-Output ($PWD -replace ('^' + [regex]::Escape($HOME)), '~')
                break
            }
            # bash: -a|--absolute)
            { $_ -eq '-a' -or $_ -eq '--absolute' } {
                # bash: realpath "$(builtin pwd)"
                realpath "$(builtin pwd)"
                break
            }
            # bash: *)
            default {
                # bash: builtin pwd "$op"
                builtin pwd "$op"
                break
            }
        # bash: esac
        }
    # bash: fi
    }


# bash: }
}

# bash: _b2p(){
function _b2p {
    # bash: local f="${1:-}"
    $f = ($args[0] ?? '')
    # bash: if [[ -z "$f" ]]; then
    if ([string]::IsNullOrEmpty($f)) {
        # bash: cn y bi "Usage: _b2p <file> [.<ext>] [--clean|--no-notes]"
        cn y bi "Usage: _b2p <file> [.<ext>] [--clean|--no-notes]"
        # bash: cn y bi "  ext: .py | .ps1 | .sh  (default .py)"
        cn y bi "  ext: .py | .ps1 | .sh  (default .py)"
        # bash: cn y bi "  ex: _b2p demo.sh .ps1 | _b2p demo.ps1 .sh | _b2p demo.py .sh"
        cn y bi "  ex: _b2p demo.sh .ps1 | _b2p demo.ps1 .sh | _b2p demo.py .sh"
        # bash: return 1
        return 1
    # bash: fi
    }
    # bash: if [[ ! -f "$f" ]]; then
    if (-not (Test-Path $f -PathType Leaf)) {
        # bash: cn y bi "file $f not found"
        cn y bi "file $f not found"
        # bash: return 1
        return 1
    # bash: fi
    }
    # bash: shift
    # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift

    # --- parse: ext ปลายทาง (รับ .py หรือ py) + flags ส่งต่อให้ codetrans ---
    # bash: local ext=".py" flags=()
    $ext = '.py flags=()'
    # bash: local a
    a
    # bash: for a in "$@"; do
    foreach ($a in $args) {
        # bash: case "$a" in
        switch -Wildcard ($a) {
            # bash: --clean|--no-notes) flags+=("$a");;
            { $_ -eq '--clean' -or $_ -eq '--no-notes' } {
                $flags += "($a)"
                break
            }
            # bash: .py|.ps1|.psm1|.sh|.bash|py|ps1|psm1|sh|bash)
            { $_ -eq '.py' -or $_ -eq '.ps1' -or $_ -eq '.psm1' -or $_ -eq '.sh' -or $_ -eq '.bash' -or $_ -eq 'py' -or $_ -eq 'ps1' -or $_ -eq 'psm1' -or $_ -eq 'sh' -or $_ -eq 'bash' } {
                # bash: ext=".${a#.}";;
                $ext = ".$(($a -replace ('^' + [regex]::Escape('.')), ''))"
                break
            }
            # bash: *)
            default {
                # bash: cn y bi "unknown arg: $a (want .py/.ps1/.sh or --clean/--no-notes)"
                cn y bi "unknown arg: $a (want .py/.ps1/.sh or --clean/--no-notes)"
                # bash: return 1;;
                return 1
                break
            }
        # bash: esac
        }
    # bash: done
    }

    # bash: local dst=""
    $dst = ''
    # bash: case "$ext" in
    switch -Wildcard ($ext) {
        # bash: .py) dst="python";;
        '.py' {
            $dst = 'python'
            break
        }
        # bash: .ps1|.psm1) dst="powershell";;
        { $_ -eq '.ps1' -or $_ -eq '.psm1' } {
            $dst = 'powershell'
            break
        }
        # bash: .sh|.bash) dst="bash";;
        { $_ -eq '.sh' -or $_ -eq '.bash' } {
            $dst = 'bash'
            break
        }
    # bash: esac
    }

    # --- ภาษาต้นทาง: ดูจากนามสกุลก่อน, ไม่รู้จักค่อยดม shebang ---
    # bash: local src=""
    $src = ''
    # bash: case ".${f##*.}" in
    switch -Wildcard (".$(($f -replace ('^' + [regex]::Escape('*.')), ''))") {
        # bash: .sh|.bash|.zsh) src="bash";;
        { $_ -eq '.sh' -or $_ -eq '.bash' -or $_ -eq '.zsh' } {
            $src = 'bash'
            break
        }
        # bash: .py) src="python";;
        '.py' {
            $src = 'python'
            break
        }
        # bash: .ps1|.psm1) src="powershell";;
        { $_ -eq '.ps1' -or $_ -eq '.psm1' } {
            $src = 'powershell'
            break
        }
        # bash: *)
        default {
            # bash: local head1=""; head1=$(head -n 1 "$f" 2>/dev/null)
            $head1 = ''
            $head1 = $(head -n 1 "$f" 2>/dev/null)
            # bash: case "$head1" in
            switch -Wildcard ($head1) {
                # bash: *python*) src="python";;
                '*python*' {
                    $src = 'python'
                    break
                }
                # bash: *pwsh*|*powershell*) src="powershell";;
                { $_ -eq '*pwsh*' -or $_ -eq '*powershell*' } {
                    $src = 'powershell'
                    break
                }
                # bash: *bash*|*zsh*|*/sh) src="bash";;
                { $_ -eq '*bash*' -or $_ -eq '*zsh*' -or $_ -eq '*/sh' } {
                    $src = 'bash'
                    break
                }
            # bash: esac
            }
        # bash: esac
        }
        # bash: if [[ -z "$src" ]]; then
        if ([string]::IsNullOrEmpty($src)) {
            # bash: cn y bi "cannot detect source language of $f (rename to .sh/.py/.ps1 or add shebang)"
            cn y bi "cannot detect source language of $f (rename to .sh/.py/.ps1 or add shebang)"
            # bash: return 1
            return 1
        # bash: fi
        }
        # bash: if [[ "$src" == "$dst" ]]; then
        if ($src -eq $dst) {
            # bash: cn y bi "same language ($src) — nothing to convert"
            cn y bi "same language ($src) — nothing to convert"
            # bash: return 1
            return 1
        # bash: fi
        }

        # bash: local ssot_dir="${SSOT:-${SCRIPTS_PATH:-$HOME/ssot}}"
        $ssot_dir = "$(($SSOT ?? "`${SCRIPTS_PATH:-$HOME/ssot"))}"
        # bash: local tool="$ssot_dir/bash_to_python/codetrans.py"
        $tool = "$ssot_dir/bash_to_python/codetrans.py"
        # bash: [[ -f "$tool" ]] || tool="$ssot_dir/codetrans/codetrans.py"  # fallback path เดิม
        [[ -f "$tool" ]] || tool="$ssot_dir/codetrans/codetrans.py"
        # bash: if [[ ! -f "$tool" ]]; then
        if (-not (Test-Path $tool -PathType Leaf)) {
            # bash: cn r bi "tool not found: $tool"
            cn r bi "tool not found: $tool"
            # bash: return 1
            return 1
        # bash: fi
        }

        # bash: local out_dir="$ssot_dir/bash_to_python/output"
        $out_dir = "$ssot_dir/bash_to_python/output"
        # bash: local out="$out_dir/$(basename "${f%.*}")$ext"
        $out = "$out_dir/$(basename "${f%.*}")$ext"
        # bash: mkdir -p "$out_dir"
        New-Item -ItemType Directory -Force $out_dir

        # bash: if [[ -f "$out" ]]; then
        if (Test-Path $out -PathType Leaf) {
            # bash: cn y bi "file $out already exists"
            cn y bi "file $out already exists"
            # bash: return 1
            return 1
        # bash: fi
        }

        # bash: if python3 "$tool" "$f" -f "$src" -t "$dst" -o "$out" "${flags[@]}"; then
        if (python3 "$tool" "$f" -f "$src" -t "$dst" -o "$out" "${flags[@]}") {
            # bash: chmod +x "$out"
            chmod +x "$out"
            # bash: cn lg bi "save file in $out ($src -> $dst)"
            cn lg bi "save file in $out ($src -> $dst)"
        # bash: else
        } else {
            # bash: cn r bi "codetrans translation failed"
            cn r bi "codetrans translation failed"
            # bash: return 1
            return 1
        # bash: fi
        }
    # bash: }
    }
