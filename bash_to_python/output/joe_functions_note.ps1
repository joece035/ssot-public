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
function git_ {  # ฟังก์ชัน bash -> function name {
    # bash: local repo=${SSOT:-"$HOME/ssot"}
    $repo = ($SSOT ?? "$HOME/ssot")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
    # bash: cd $repo &&
    cd $repo &&  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
    # bash: _guard_compat() {
    function _guard_compat {  # ฟังก์ชัน bash -> function name {
        # bash: if ! typeset -f _check_compat >/dev/null 2>&1 && [[ -f "$repo/shared/.bash_checker" ]]; then
        if ((-not (typeset -f _check_compat >/dev/null 2>&1) -and Test-Path "$repo/shared/.bash_checker" -PathType Leaf)) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
            # bash: source "$repo/shared/.bash_checker" 2>/dev/null
            source "$repo/shared/.bash_checker" 2>/dev/null  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
        # bash: if typeset -f _check_compat >/dev/null 2>&1; then
        if (typeset -f _check_compat >/dev/null 2>&1) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
            # bash: _check_compat "$repo"
            _check_compat "$repo"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: return $?
            return $?  # return เหมือนกัน
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
        # bash: return 0
        return 0  # return เหมือนกัน
    # bash: }
    # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
    }
    # bash: if [[ -n "$1" ]]; then
    if (-not [string]::IsNullOrEmpty($args[0])) {  # if ...; then -> if (...) {
        # bash: case "${1:-}" in
        switch -Wildcard (($args[0] ?? '')) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
            # bash: s|status)  git status ;;
            { $_ -eq 's' -or $_ -eq 'status' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                git status  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: c|commit)
            { $_ -eq 'c' -or $_ -eq 'commit' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                # bash: [[ -z "${2:-}" ]] && { cn 196 b "✗ need message: git_ commit '<msg>'"; return 1; }
                [[ -z "${2:-}" ]] && { cn 196 b "✗ need message: git_ commit '<msg>'"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
                return 1  # return เหมือนกัน
            # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
            }
            # bash: _guard_compat || { cn 196 b "✗ commit aborted: fix compatibility issues first"; return 1; }
            _guard_compat || { cn 196 b "✗ commit aborted: fix compatibility issues first"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
            return 1  # return เหมือนกัน
        # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
        }
        # bash: git commit -m "$2"
        git commit -m "$2"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
        break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: a|add)     git add -A ;;
            { $_ -eq 'a' -or $_ -eq 'add' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                git add -A  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: p|push)    git push origin main && cn 10 bi "DONE push" ;;
            { $_ -eq 'p' -or $_ -eq 'push' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                git push origin main && cn 10 bi "DONE push"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: pl|pull)   git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; } ;;
            { $_ -eq 'pl' -or $_ -eq 'pull' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
                return 1  # return เหมือนกัน
            # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
            }
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: pln|pulln) git pull --no-rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; } ;;
            { $_ -eq 'pln' -or $_ -eq 'pulln' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                git pull --no-rebase || { cn 9 b "PULL FAILED — resolve conflicts"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
                return 1  # return เหมือนกัน
            # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
            }
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: d|diff)    git diff --stat ;;
            { $_ -eq 'd' -or $_ -eq 'diff' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                git diff --stat  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: l|log)     git log --oneline -10 ;;
            { $_ -eq 'l' -or $_ -eq 'log' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                git log --oneline -10  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: all)
            'all' {  # pattern) -> "..." {
                # bash: _guard_compat || { cn 196 b "✗ commit aborted: fix compatibility issues first"; return 1; }
                _guard_compat || { cn 196 b "✗ commit aborted: fix compatibility issues first"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
                return 1  # return เหมือนกัน
            # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
            }
            # bash: git add -A &&              git commit -m "${2:-$(date '+%Y-%m-%d %H:%M:%S')}" &&              (git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"; return 1; }) &&              git push origin main &&              cn 10 bi "DONE push"
            git add -A &&              git commit -m "${2:-$(date '+%Y-%m-%d %H:%M:%S')}" &&              (git pull --rebase || { cn 9 b "PULL FAILED — resolve conflicts"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
            return 1  # return เหมือนกัน
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            '}' {  # pattern) -> "..." {
                &&              git push origin main &&              cn 10 bi "DONE push"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: *)         git "$@" ;;
            default {  # *) -> default
                git "$@"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
        # bash: esac
        # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
        }
    # bash: else
    } else {  # else -> } else {
        # bash: git status
        git status  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}


# bash: g() {
function g {  # ฟังก์ชัน bash -> function name {
    # bash: local repo="${SSOT:-$HOME/bashscripts}"
    $repo = ($SSOT ?? "$HOME/bashscripts")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
    # bash: [[ -d "$repo" ]] || { cn 196 b "✗ repo not found: $repo"; return 1; }
    [[ -d "$repo" ]] || { cn 196 b "✗ repo not found: $repo"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
    return 1  # return เหมือนกัน
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}
# bash: cd "$repo" || return 1
cd "$repo" || return 1  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)

# ถ้าไม่มี args → commit+push (ถ้ามี change) หรือ push only
# bash: if (( $# == 0 )); then
if (( $# == 0 )) {  # if ...; then -> if (...) {
    # bash: if ! git diff --quiet HEAD 2>/dev/null || [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
    if (-not (git diff --quiet HEAD 2>/dev/null) -or -not [string]::IsNullOrEmpty($(git ls-files --others --exclude-standard 2>/dev/null))) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
        # bash: c 11 b "? Working tree dirty — commit with $(c 220 b 'date')? [y/N] "
        c 11 b "? Working tree dirty — commit with $(c 220 b 'date')? [y/N] "  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: local ans; read -r ans
        ans  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        $ans = Read-Host  # read -> Read-Host
        # bash: [[ "$ans" =~ ^[Yy]$ ]] || { cn 220 b "→ cancelled"; return 0; }
        [[ "$ans" =~ ^[Yy]$ ]] || { cn 220 b "→ cancelled"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
        return 0  # return เหมือนกัน
    # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
    }
    # bash: git add -A && git commit -m "$(date '+%Y-%m-%d %H:%M:%S')"
    git add -A && git commit -m "$(date '+%Y-%m-%d %H:%M:%S')"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}
# bash: git_ push
git_ push  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: return $?
return $?  # return เหมือนกัน
# bash: else
} else {  # else -> } else {
    # bash: case "$1" in
    switch -Wildcard ($args[0]) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
        # bash: -pu|--pull--rebase)
        { $_ -eq '-pu' -or $_ -eq '--pull--rebase' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            # bash: git add -A
            git add -A  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: git commit -m "$(date)"
            git commit -m "$(date)"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: git_ "pl"
            git_ "pl"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: _C -s -d "exec zsh" "exec bash"
            _C -s -d "exec zsh" "exec bash"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: *)
        default {  # *) -> default
            # มี args → ส่งต่อไป git_ (ซึ่งรู้จัก s/c/a/all/push/pull ฯลฯ)

            # bash: git_ "$@"
            git_ "$@"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
    # bash: esac
    # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
    }

# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# bash: repository_remote_url(){
function repository_remote_url {  # ฟังก์ชัน bash -> function name {
    # bash: case $1 in
    switch -Wildcard ($args[0]) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
        # bash: url)
        'url' {  # pattern) -> "..." {
            # bash: git config --get remote.origin.url
            git config --get remote.origin.url  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: status)
        'status' {  # pattern) -> "..." {
            # bash: git status
            git status  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: bsc)
        'bsc' {  # pattern) -> "..." {
            # bash: cd ~/bashscripts && git remote set-url origin https://github.com/joece035/bashscripts-public.git
            cd ~/bashscripts && git remote set-url origin https://github.com/joece035/bashscripts-public.git  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: ssot)
        'ssot' {  # pattern) -> "..." {
            # bash: cd ~/ssot && git remote set-url origin https://github.com/joece035/ssot-public.git
            cd ~/ssot && git remote set-url origin https://github.com/joece035/ssot-public.git  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: *)
        default {  # *) -> default
            # bash: git remote -v
            git remote -v  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)

            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
    # bash: esac
    # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
    }
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}
# bash: alias gremote='repository_remote_url'
# TODO: 'alias' ไม่มีใน pwsh ตรงตัว: alias gremote='repository_remote_url'

# -- ฟังก์ชั่นหา Display Width ที่แท้จริง (รวม Emoji, Wide characters และตัด ANSI Code / PS1 delimiters ออก)

# bash: pwd(){
function pwd {  # ฟังก์ชัน bash -> function name {
    # bash: local op="${1:-}"
    $op = ($args[0] ?? '')  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
    # bash: if [[ -z "$op" ]]; then
    if ([string]::IsNullOrEmpty($op)) {  # if ...; then -> if (...) {
        # bash: builtin pwd
        builtin pwd  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
    # bash: else
    } else {  # else -> } else {
        # bash: case "$op" in
        switch -Wildcard ($op) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
            # bash: -b|--basename)
            { $_ -eq '-b' -or $_ -eq '--basename' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                # bash: basename "$(builtin pwd)"
                basename "$(builtin pwd)"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: -d|--dirname)
            { $_ -eq '-d' -or $_ -eq '--dirname' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                # bash: dirname "$(builtin pwd)"
                dirname "$(builtin pwd)"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: -s|--short)
            { $_ -eq '-s' -or $_ -eq '--short' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                # bash: echo "${PWD/#$HOME/\~}"
                Write-Output ($PWD -replace ('^' + [regex]::Escape($HOME)), '~')  # echo -> Write-Output
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: -a|--absolute)
            { $_ -eq '-a' -or $_ -eq '--absolute' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                # bash: realpath "$(builtin pwd)"
                realpath "$(builtin pwd)"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: *)
            default {  # *) -> default
                # bash: builtin pwd "$op"
                builtin pwd "$op"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
        # bash: esac
        # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
        }
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }


# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# bash: _b2p(){
function _b2p {  # ฟังก์ชัน bash -> function name {
    # bash: local f="${1:-}"
    $f = ($args[0] ?? '')  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
    # bash: if [[ -z "$f" ]]; then
    if ([string]::IsNullOrEmpty($f)) {  # if ...; then -> if (...) {
        # bash: cn y bi "Usage: _b2p <file> [.<ext>] [--clean|--no-notes]"
        cn y bi "Usage: _b2p <file> [.<ext>] [--clean|--no-notes]"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: cn y bi "  ext: .py | .ps1 | .sh  (default .py)"
        cn y bi "  ext: .py | .ps1 | .sh  (default .py)"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: cn y bi "  ex: _b2p demo.sh .ps1 | _b2p demo.ps1 .sh | _b2p demo.py .sh"
        cn y bi "  ex: _b2p demo.sh .ps1 | _b2p demo.ps1 .sh | _b2p demo.py .sh"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: return 1
        return 1  # return เหมือนกัน
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
    # bash: if [[ ! -f "$f" ]]; then
    if (-not (Test-Path $f -PathType Leaf)) {  # if ...; then -> if (...) {
        # bash: cn y bi "file $f not found"
        cn y bi "file $f not found"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: return 1
        return 1  # return เหมือนกัน
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
    # bash: shift
    # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift

    # --- parse: ext ปลายทาง (รับ .py หรือ py) + flags ส่งต่อให้ codetrans ---
    # bash: local ext=".py" flags=()
    $ext = '.py flags=()'  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local a
    a  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
    # bash: for a in "$@"; do
    foreach ($a in $args) {  # for..in -> foreach
        # bash: case "$a" in
        switch -Wildcard ($a) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
            # bash: --clean|--no-notes) flags+=("$a");;
            { $_ -eq '--clean' -or $_ -eq '--no-notes' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                $flags += "($a)"  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: .py|.ps1|.psm1|.sh|.bash|py|ps1|psm1|sh|bash)
            { $_ -eq '.py' -or $_ -eq '.ps1' -or $_ -eq '.psm1' -or $_ -eq '.sh' -or $_ -eq '.bash' -or $_ -eq 'py' -or $_ -eq 'ps1' -or $_ -eq 'psm1' -or $_ -eq 'sh' -or $_ -eq 'bash' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                # bash: ext=".${a#.}";;
                $ext = ".$(($a -replace ('^' + [regex]::Escape('.')), ''))"  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: *)
            default {  # *) -> default
                # bash: cn y bi "unknown arg: $a (want .py/.ps1/.sh or --clean/--no-notes)"
                cn y bi "unknown arg: $a (want .py/.ps1/.sh or --clean/--no-notes)"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                # bash: return 1;;
                return 1  # return เหมือนกัน
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
        # bash: esac
        # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
        }
    # bash: done
    # -> จบ loop — pwsh ปิดด้วย } แทน done
    }

    # bash: local dst=""
    $dst = ''  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: case "$ext" in
    switch -Wildcard ($ext) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
        # bash: .py) dst="python";;
        '.py' {  # pattern) -> "..." {
            $dst = 'python'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: .ps1|.psm1) dst="powershell";;
        { $_ -eq '.ps1' -or $_ -eq '.psm1' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $dst = 'powershell'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: .sh|.bash) dst="bash";;
        { $_ -eq '.sh' -or $_ -eq '.bash' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $dst = 'bash'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
    # bash: esac
    # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
    }

    # --- ภาษาต้นทาง: ดูจากนามสกุลก่อน, ไม่รู้จักค่อยดม shebang ---
    # bash: local src=""
    $src = ''  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: case ".${f##*.}" in
    switch -Wildcard (".$(($f -replace ('^' + [regex]::Escape('*.')), ''))") {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
        # bash: .sh|.bash|.zsh) src="bash";;
        { $_ -eq '.sh' -or $_ -eq '.bash' -or $_ -eq '.zsh' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $src = 'bash'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: .py) src="python";;
        '.py' {  # pattern) -> "..." {
            $src = 'python'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: .ps1|.psm1) src="powershell";;
        { $_ -eq '.ps1' -or $_ -eq '.psm1' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $src = 'powershell'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: *)
        default {  # *) -> default
            # bash: local head1=""; head1=$(head -n 1 "$f" 2>/dev/null)
            $head1 = ''  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
            $head1 = $(head -n 1 "$f" 2>/dev/null)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: case "$head1" in
            switch -Wildcard ($head1) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
                # bash: *python*) src="python";;
                '*python*' {  # pattern) -> "..." {
                    $src = 'python'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                    break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
                }
                # bash: *pwsh*|*powershell*) src="powershell";;
                { $_ -eq '*pwsh*' -or $_ -eq '*powershell*' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                    $src = 'powershell'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                    break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
                }
                # bash: *bash*|*zsh*|*/sh) src="bash";;
                { $_ -eq '*bash*' -or $_ -eq '*zsh*' -or $_ -eq '*/sh' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
                    $src = 'bash'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                    break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
                }
            # bash: esac
            # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
            }
        # bash: esac
        # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
        }
        # bash: if [[ -z "$src" ]]; then
        if ([string]::IsNullOrEmpty($src)) {  # if ...; then -> if (...) {
            # bash: cn y bi "cannot detect source language of $f (rename to .sh/.py/.ps1 or add shebang)"
            cn y bi "cannot detect source language of $f (rename to .sh/.py/.ps1 or add shebang)"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: return 1
            return 1  # return เหมือนกัน
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
        # bash: if [[ "$src" == "$dst" ]]; then
        if ($src -eq $dst) {  # if ...; then -> if (...) {
            # bash: cn y bi "same language ($src) — nothing to convert"
            cn y bi "same language ($src) — nothing to convert"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: return 1
            return 1  # return เหมือนกัน
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }

        # bash: local ssot_dir="${SSOT:-${SCRIPTS_PATH:-$HOME/ssot}}"
        $ssot_dir = "$(($SSOT ?? "`${SCRIPTS_PATH:-$HOME/ssot"))}"  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
        # bash: local tool="$ssot_dir/bash_to_python/codetrans.py"
        $tool = "$ssot_dir/bash_to_python/codetrans.py"  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: [[ -f "$tool" ]] || tool="$ssot_dir/codetrans/codetrans.py"  # fallback path เดิม
        [[ -f "$tool" ]] || tool="$ssot_dir/codetrans/codetrans.py"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
        # bash: if [[ ! -f "$tool" ]]; then
        if (-not (Test-Path $tool -PathType Leaf)) {  # if ...; then -> if (...) {
            # bash: cn r bi "tool not found: $tool"
            cn r bi "tool not found: $tool"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: return 1
            return 1  # return เหมือนกัน
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }

        # bash: local out_dir="$ssot_dir/bash_to_python/output"
        $out_dir = "$ssot_dir/bash_to_python/output"  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: local out="$out_dir/$(basename "${f%.*}")$ext"
        $out = "$out_dir/$(basename "${f%.*}")$ext"  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: mkdir -p "$out_dir"
        New-Item -ItemType Directory -Force $out_dir  # mkdir -p -> New-Item -ItemType Directory -Force

        # bash: if [[ -f "$out" ]]; then
        if (Test-Path $out -PathType Leaf) {  # if ...; then -> if (...) {
            # bash: cn y bi "file $out already exists"
            cn y bi "file $out already exists"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: return 1
            return 1  # return เหมือนกัน
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }

        # bash: if python3 "$tool" "$f" -f "$src" -t "$dst" -o "$out" "${flags[@]}"; then
        if (python3 "$tool" "$f" -f "$src" -t "$dst" -o "$out" "${flags[@]}") {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
            # bash: chmod +x "$out"
            chmod +x "$out"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: cn lg bi "save file in $out ($src -> $dst)"
            cn lg bi "save file in $out ($src -> $dst)"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: else
        } else {  # else -> } else {
            # bash: cn r bi "codetrans translation failed"
            cn r bi "codetrans translation failed"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: return 1
            return 1  # return เหมือนกัน
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
    # bash: }
    # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
    }
