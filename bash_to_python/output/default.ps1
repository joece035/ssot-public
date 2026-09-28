# bash: #!/bin/bash
#!/usr/bin/env pwsh
# ======================================================
# 🎨 JOE'S TERMINAL THEME & PROMPT (WSL Ubuntu Edition)
# ======================================================

# 1. Colors & escape helpers (PS1-safe: ทุก escape sequence ต้องหุ้มด้วย \[ ... \])
# รองรับ psc <color> [style] <text...> ตามมาตรฐาน SSOT Color Engine V3 (core/01-colors.sh)
# bash: if ! command -v psc >/dev/null 2>&1; then
if (-not (command -v psc >/dev/null 2>&1)) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
    # bash: _color_src="${SSOT:-${SCRIPTS_PATH:-$HOME/ssot}}/core/01-colors.sh"
    $_color_src = "$(($SSOT ?? "`${SCRIPTS_PATH:-$HOME/ssot"))}/core/01-colors.sh"  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
    # bash: [[ -f "$_color_src" ]] && source "$_color_src" 2>/dev/null
    [[ -f "$_color_src" ]] && source "$_color_src" 2>/dev/null  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# Fallback escape helper กรณีรันแยกเดี่ยวและยังไม่ได้ source 01-colors.sh
# bash: if ! command -v psc >/dev/null 2>&1; then
if (-not (command -v psc >/dev/null 2>&1)) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
    # bash: psc() {
    function psc {  # ฟังก์ชัน bash -> function name {
        # bash: local c="${1:-}" s="${2:-}" t="${3:-}"
        $c = "$(($args[0] ?? '')) s=$(($args[1] ?? '')) t=$(($args[2] ?? ''))"  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
        # bash: local num="$c"
        $num = $c  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: case "$c" in
        switch -Wildcard ($c) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
            # bash: r) num=196;; lr) num=203;; g) num=82;; lg) num=46;; y) num=226;;
            'r' {  # pattern) -> "..." {
                $num = 196  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            'lr' {  # pattern) -> "..." {
                $num = 203  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            'g' {  # pattern) -> "..." {
                $num = 82  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            'lg' {  # pattern) -> "..." {
                $num = 46  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            'y' {  # pattern) -> "..." {
                $num = 226  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            # bash: cr) num=51;; b) num=33;; ora) num=208;; gr) num=244;;
            'cr' {  # pattern) -> "..." {
                $num = 51  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            'b' {  # pattern) -> "..." {
                $num = 33  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            'ora' {  # pattern) -> "..." {
                $num = 208  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
            'gr' {  # pattern) -> "..." {
                $num = 244  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
            }
        # bash: esac
        # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
        }
        # bash: local st=""
        $st = ''  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: [[ "$s" =~ b ]] && st+="\e[1m"
        [[ "$s" =~ b ]] && st+="\e[1m"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
        # bash: [[ "$s" =~ d ]] && st+="\e[2m"
        [[ "$s" =~ d ]] && st+="\e[2m"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
        # bash: printf '\[\e[38;5;%sm%b\]%s\[\e[0m\]' "$num" "$st" "$t"
        Write-Host -NoNewline ("\[\e[38;5;{0}m%b\]{1}\[\e[0m\]" -f $num, $st, $t)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; เหลือ % แบบที่แปลงไม่ได้ (%q/%x/...) — ตรวจเอง; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
    # bash: }
    # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
    }
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# -- helper color
# bash: _gr(){
function _gr {  # ฟังก์ชัน bash -> function name {
    # bash: psc 235 d "$@"
    psc 235 d "$@"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}
# bash: _lw(){
function _lw {  # ฟังก์ชัน bash -> function name {
    # bash: psc 15 b "$@"
    psc 15 b "$@"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}
# 2. ฟังก์ชันตรวจสอบ Git Branch แบบไม่หน่วงเครื่อง (Lightweight Git Status)
# bash: _git_prompt() {
function _git_prompt {  # ฟังก์ชัน bash -> function name {
    # bash: if command -v git >/dev/null 2>&1; then
    if (command -v git >/dev/null 2>&1) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
        # bash: local branch
        branch  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: branch=$(git branch --show-current 2>/dev/null)
        $branch = $(git branch --show-current 2>/dev/null)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: if [ -n "$branch" ]; then
        if (-not [string]::IsNullOrEmpty($branch)) {  # if ...; then -> if (...) {
            # bash: if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            if (-not [string]::IsNullOrEmpty($(git status --porcelain 2>/dev/null))) {  # if ...; then -> if (...) {
                # bash: psc y b " 🌿 ${branch}*"
                psc y b " 🌿 ${branch}*"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: else
            } else {  # else -> } else {
                # bash: psc 82 b " 🌿 ${branch}"
                psc 82 b " 🌿 ${branch}"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: fi
            # -> จบ if — pwsh ปิดด้วย } แทน fi
            }
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# 3. ฟังก์ชันสร้างเส้นแบ่ง (Border line)
# bash: _draw_border() {
function _draw_border {  # ฟังก์ชัน bash -> function name {
    # bash: local char="${1:-┈}"
    $char = ($args[0] ?? '┈')  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
    # bash: local count="${2:-40}"
    $count = ($args[1] ?? 40)  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
    # bash: (( count < 1 )) && count=1
    (( count < 1 )) && count=1  # pwsh ไม่มี < (input redirect) — ใช้ Get-Content file | cmd แทน; &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
    # bash: printf '%.0s'"$char" $(seq 1 "$count")
    printf '%.0s'"$char" $(seq 1 "$count")  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# 4. ประกอบร่างเป็น Dynamic PS1 (Prompt) — BASH ONLY
# bash: if [[ -n "${BASH_VERSION:-}" ]]; then
if (-not [string]::IsNullOrEmpty(($BASH_VERSION ?? ''))) {  # if ...; then -> if (...) {

    # bash: _set_prompt() {
    function _set_prompt {  # ฟังก์ชัน bash -> function name {
        # bash: local exit_code=$?
        $exit_code = $?  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: local _cur_row=0
        $_cur_row = 0  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)

        # 1. อ่านตำแหน่ง Cursor ปัจจุบัน
        # bash: if [[ -t 0 ]] && [[ -t 1 ]]; then
        if ((-t 0 -and -t 1)) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
            # bash: local _old_stty
            _old_stty  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: _old_stty=$(stty -g 2>/dev/null)
            $_old_stty = $(stty -g 2>/dev/null)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: stty -echo 2>/dev/null
            stty -echo 2>/dev/null  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
            # bash: printf '\033[6n' >/dev/tty 2>/dev/null
            Write-Output -NoNewline ("\033[6n" -f '>/dev/tty', 2) > '/dev/null'  # redirect >/>> เหมือน bash (แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง)
            # bash: IFS='[;R' read -r -d 'R' _ _cur_row _ </dev/tty 2>/dev/null
            $IFS = '[;R read -r -d R _ _cur_row _ </dev/tty 2>/dev/null'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: stty "$_old_stty" 2>/dev/null
            stty "$_old_stty" 2>/dev/null  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }

        # bash: [[ "$_cur_row" =~ ^[0-9]+$ ]] || _cur_row=0
        [[ "$_cur_row" =~ ^[0-9]+$ ]] || _cur_row=0  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)

        # bash: local _prev_row=${_SSOT_LAST_ROW:-0}
        $_prev_row = ($_SSOT_LAST_ROW.Substring(-0))  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: _SSOT_LAST_ROW=$_cur_row
        $_SSOT_LAST_ROW = $_cur_row  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

        # bash: local _max_lines
        _max_lines  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: _max_lines=$(tput lines 2>/dev/null || echo "${LINES:-24}")
        $_max_lines = $(tput lines 2>/dev/null || echo "${LINES:-24}")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

        # คำสั่งถูกรันจริงไหม (Enter เปล่า HISTCMD ไม่เพิ่ม)
        # bash: local _ran=0
        $_ran = 0  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: [[ "$HISTCMD" != "${_SSOT_LAST_HIST:-}" ]] && _ran=1
        [[ "$HISTCMD" != "${_SSOT_LAST_HIST:-}" ]] && _ran=1  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
        # bash: _SSOT_LAST_HIST=$HISTCMD
        $_SSOT_LAST_HIST = $HISTCMD  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

        # _SSOT_USED = ระยะจากหัว full banner ถึง cursor ปัจจุบัน
        # bash: if (( _cur_row <= 1 || _cur_row < _prev_row )); then
        if ((( _cur_row <= 1 -or _cur_row < _prev_row ))) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
            # bash: _SSOT_USED=$_max_lines            # clear / cursor กระโดดขึ้น -> บังคับ full
            $_SSOT_USED = $_max_lines  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: else
        } else {  # else -> } else {
            # bash: local _d
            _d  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: if (( _cur_row < _max_lines )); then
            if (( $_cur_row < $_max_lines )) {  # if ...; then -> if (...) {
                # bash: _d=$(( _cur_row - _prev_row ))            # ยังไม่ชนขอบ วัดตรง
                $_d = ( $_cur_row - $_prev_row )  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: elif (( _prev_row < _max_lines )); then
            } elseif (( $_prev_row < $_max_lines )) {  # elif ...; then -> } elseif (...) {
                # bash: _d=$(( _max_lines - _prev_row ))          # เพิ่งชนขอบ
                $_d = ( $_max_lines - $_prev_row )  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: else
            } else {  # else -> } else {
                # bash: _d=1                                      # ติดขอบต่อเนื่อง (Enter 1 แถว)
                $_d = 1  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: fi
            # -> จบ if — pwsh ปิดด้วย } แทน fi
            }
            # bash: (( _cur_row >= _max_lines && _ran )) && _d=$(( _d + 1 ))  # เดา output ขั้นต่ำ 1 บรรทัด
            (( _cur_row >= _max_lines && _ran )) && _d=$(( _d + 1 ))  # TODO: นิพจน์ ((...)) แบบนี้ต้องตรวจเอง
            # bash: _SSOT_USED=$(( ${_SSOT_USED:-99999} + _d ))
            $_SSOT_USED = ( ${$_SSOT_USED:-99999} + $_d )  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }

        # bash: local show_mini=0
        $show_mini = 0  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: if (( _SSOT_USED < _max_lines )); then
        if (( $_SSOT_USED < $_max_lines )) {  # if ...; then -> if (...) {
            # bash: show_mini=1
            $show_mini = 1  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: else
        } else {  # else -> } else {
            # bash: _SSOT_USED=3                      # full สูง 4 แถว หัวอยู่เหนือ cursor 3 แถว
            $_SSOT_USED = 3  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }

        # ถ้าเข้าเงื่อนไข Mini Prompt: พิมพ์แค่ -→ แล้วจบฟังก์ชันทันที
        # bash: if (( show_mini == 1 )); then
        if (( $show_mini == 1 )) {  # if ...; then -> if (...) {
            # bash: if [ $exit_code -eq 0 ]; then
            if ($exit_code -eq 0) {  # if ...; then -> if (...) {
                # bash: PS1=" $(psc lg b "  -→  ") "
                $PS1 = " $(psc lg b "  -→  ") "  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: else
            } else {  # else -> } else {
                # bash: PS1=" $(psc lr b "  -→  ") "
                $PS1 = " $(psc lr b "  -→  ") "  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: fi
            # -> จบ if — pwsh ปิดด้วย } แทน fi
            }
            # bash: return
            return  # return เหมือนกัน
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }

        # bash: local last_status_raw='(ﾉ◕ .7oEz ◕)ﾉ*:･ﾟ✧'
        $last_status_raw = '(ﾉ◕ .7oEz ◕)ﾉ*:･ﾟ✧'  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: local last_status
        last_status  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: if [ $exit_code -eq 0 ]; then
        if ($exit_code -eq 0) {  # if ...; then -> if (...) {
            # bash: last_status="$(mc b "$last_status_raw")"
            $last_status = $(mc b "$last_status_raw")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: else
        } else {  # else -> } else {
            # bash: last_status="$(psc lr b "$last_status_raw")"
            $last_status = $(psc lr b "$last_status_raw")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
        # -- environment / current shell
        # bash: local cur_env="${JOE_ENV:-${MY_DEVICE:-WSL2}}"
        $cur_env = "$(($JOE_ENV ?? '${MY_DEVICE:-WSL2'))}"  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
        #local cur_shell="${_SHELL:-${SHELL##*/}}"
        # bash: local env_tag="< $(psc 202 d "$cur_env") : $(psc 240 d "$cur_shell") >"
        $env_tag = "< $(psc 202 d "$cur_env") : $(psc 240 d "$cur_shell") >"  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)

        # -- USER@HOST
        # bash: local cur_user="${USER:-$(id -un)}"
        $cur_user = ($USER ?? $(id -un))  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+); bash $USER ไม่มีใน pwsh ตรงๆ — ใช้ $env:USERNAME
        # bash: local cur_host="${NODE_HOST:-wsl2}"
        $cur_host = ($NODE_HOST ?? 'wsl2')  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)

        # -- Current Dir & Git
        # bash: local current_dir="$(psc 242 d "${PWD/#$HOME/\~}")"
        $current_dir = $(psc 242 d "${PWD/#$HOME/\~}")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: local git_info="$(_git_prompt)"
        $git_info = $(_git_prompt)  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)

        # ---ปิดแถวหัวท้ายทาสีเดียวกับขอบบนล่าง
        # bash: local c_box
        c_box  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: c_box=$(random_core roll border "$RC_PALETTE_DIM")
        $c_box = $(random_core roll border "$RC_PALETTE_DIM")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: local sep="$(psc "$c_box" "b" '|')"
        $sep = $(psc "$c_box" "b" '|')  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)

        # -- 1. รวมเนื้อหาของแถวกลางจริงที่จะแสดงผล
        # bash: local prompt_content="${sep} ${last_status} ${env_tag} ${user_host} in ${current_dir}${git_info} ${sep}"
        $prompt_content = "$sep $last_status $env_tag $user_host in $current_dir$git_info $sep"  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)

        # -- 2. Dynamic border calculation: ยิงวัดความกว้างรอบเดียว (One-Shot)
        # bash: local term_w
        term_w  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # bash: term_w=$(tput cols 2>/dev/null || echo $COLUMNS)
        $term_w = $(tput cols 2>/dev/null || echo $COLUMNS)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: (( term_w < 37 )) && term_w=37
        (( term_w < 37 )) && term_w=37  # pwsh ไม่มี < (input redirect) — ใช้ Get-Content file | cmd แทน; &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)

        # bash: local text_len
        text_len  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
        # -- วัด Width จริง ( ANSI escape codes ??? OSC sequences)
        # bash: text_len=$(_w "$prompt_content")
        $text_len = $(_w "$prompt_content")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

        # bash: local lens=$text_len
        $lens = $text_len  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: (( lens > (term_w - 2) )) && lens=$(( term_w - 2 ))
        (( lens > (term_w - 2) )) && lens=$(( term_w - 2 ))  # TODO: นิพจน์ ((...)) แบบนี้ต้องตรวจเอง

        # bash: local BN_BORDER_CHAR_TOP="${BOT_LINE:-$'\u2581'}"
        $BN_BORDER_CHAR_TOP = ($BOT_LINE ?? '$\u2581')  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
        # bash: local BN_BORDER_CHAR_BOT="${TOP_LINE:-$'\u2594'}"
        $BN_BORDER_CHAR_BOT = ($TOP_LINE ?? '$\u2594')  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)

        # bash: local _str_t="" _str_b=""
        $_str_t = ' _str_b='  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: for (( _i = 1; _i <= lens; _i++ )); do
        for ($_i = 1; $_i -le $lens; $_i++) {  # for ((;;)) -> for (;;) (< เป็น -lt)
            # bash: _str_t+="${BN_BORDER_CHAR_TOP}"
            $_str_t += $BN_BORDER_CHAR_TOP  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: _str_b+="${BN_BORDER_CHAR_BOT}"
            $_str_b += $BN_BORDER_CHAR_BOT  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: done
        # -> จบ loop — pwsh ปิดด้วย } แทน done
        }

        # Random border color (Single color for both top bottom and also sep)

        # bash: local border_top="$(psc "$c_box" "b" "${_str_t}")"
        $border_top = $(psc "$c_box" "b" "${_str_t}")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: local border_bot="$(psc "$c_box" "b" "${_str_b}")"
        $border_bot = $(psc "$c_box" "b" "${_str_b}")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)

        # -- 3. ประกอบร่าง Dynamic PS1 (Prompt)
        # bash: local PS1_=""
        $PS1_ = ''  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: PS1_+="${border_top}\n"
        $PS1_ += "$border_top\n"  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: PS1_+="${prompt_content}\n"
        $PS1_ += "$prompt_content\n"  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: PS1_+="${border_bot}\n"
        $PS1_ += "$border_bot\n"  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: PS1_+=" -→ "
        $PS1_ += ' -→ '  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

        # bash: export -n PS1 2>/dev/null || true
        -n PS1 2>/dev/null || true  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
        # bash: PS1="$PS1_"
        $PS1 = $PS1_  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: }
    # -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
    }

    # ✅ FIX 4: ลบ duplicate — เหลือแค่ชุดเดียว
    # bash: _SSOT_LAST_ROW=0
    $_SSOT_LAST_ROW = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: _SSOT_USED=99999      # ค่าสูง = prompt แรกได้ full เสมอ
    $_SSOT_USED = 99999  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: _SSOT_LAST_HIST=
    $_SSOT_LAST_HIST = ''  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: export -n PROMPT_COMMAND 2>/dev/null || true
    -n PROMPT_COMMAND 2>/dev/null || true  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
    # bash: PROMPT_COMMAND=_set_prompt
    $PROMPT_COMMAND = '_set_prompt'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# bash: elif [[ -n "${ZSH_VERSION:-}" ]]; then
} elseif (-not [string]::IsNullOrEmpty(($ZSH_VERSION ?? ''))) {  # elif ...; then -> } elseif (...) {
    # bash: unset PROMPT_COMMAND
    Remove-Variable PROMPT_COMMAND -ErrorAction SilentlyContinue  # unset -> Remove-Variable
    # bash: export -n PROMPT_COMMAND 2>/dev/null || true
    -n PROMPT_COMMAND 2>/dev/null || true  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# 5. Show Fastfetch (only in interactive WSL shells with logo)
# bash: if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
if (('$-' -like '*i*' -and command -v fastfetch >/dev/null 2>&1)) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
    # bash: if [ "$JOE_ENV" = "WSL" ]; then
    if ($JOE_ENV -eq 'WSL') {  # if ...; then -> if (...) {
        #clear
        # bash: fastfetch --logo ubuntu
        fastfetch --logo ubuntu  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# bash: echo
Write-Output ""

