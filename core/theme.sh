#!/bin/bash
# ======================================================
# 🎨 JOE'S TERMINAL THEME & PROMPT (WSL Ubuntu Edition)
# ======================================================

# 1. Colors loaded from 01-colors.sh via joe.sh (no redefinition needed)
if ! command -v rc >/dev/null 2>&1; then
   _check -f "$SSOT/core/random-color.sh"  "source" 2>/dev/null 
fi
# 2. ฟังก์ชันตรวจสอบ Git Branch แบบไม่หน่วงเครื่อง (Lightweight Git Status)
_git_prompt() {
    if command -v git >/dev/null 2>&1; then
        local branch
        branch=$(git branch --show-current 2>/dev/null)
        if [ -n "$branch" ]; then
            # ตรวจสอบว่ามีข้อมูลค้างยังไม่ได้ commit หรือไม่
            if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
                c 226 b " 🌿 ${branch}*"
            else
                c 82 b " 🌿 ${branch}"
            fi
        fi
    fi
}


# 3. ฟังก์ชันเช็คสถานะคำสั่งล่าสุด (Exit Code Status)
_exit_status() {
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        c lg b "SUCCESS 🟢"
    else
        c 9 b "FAILED 🔴"
    fi
}


# 4. ประกอบร่างเป็น Dynamic PS1 (Prompt)
# [ Exit Code ] [ ENV ] [ User@Host ] [ Path ] [ Git ]
# ──>
# V4 SSOT: use _c/_b/_r helpers (raw escape emitters from 01-colors.sh).
# PS1 needs literal escape codes wrapped in \[ \] (bash non-printing marker).
# c()/cn() output text + escape — use them for plain text segments; use
# _c/_b/_r directly for PS1 where bash will re-interpret \u, \w, etc.
_set_prompt() {

    local exit_code=$?
    local last_status_c last_status_s last_status_raw last_status
    if [ $exit_code -eq 0 ]; then
        last_status_c="lg"
        last_status_s="b"
        last_status_raw="▏▎▍▌▋▊▉█"
    else
        last_status_c="1"
        last_status_s="b"
        last_status_raw="▏▎▍▌▋▊▉█"
    fi
    last_status="$(c "$last_status_c" "$last_status_s" "$last_status_raw")"
    # -- environment / current shell
    local env_tag_label="$(c 198 b "${JOE_ENV:-$MY_DEVICE}")"
    local shell_tag_label="$(c ora b "${_SHELL:-}")"
    local env_tag=$(printf "< %s : %s >" "${env_tag_label}" "${shell_tag_label}")
    # -- USER@HOST
    local user_="$(c 51 b "$(id -un)")"
    local host_="$(c 226 b "$NODE_HOST")"
    
    local user_host=$(printf "${user_} @ ${host_}")
    local current_dir="\[$(_c 242)\]\w\[$(_r)\]"
    local git_info="$(_git_prompt)"
    local arrow="\[$(_b)\]──>\[$(_r)\]"

    # -- dynamic border
    local RC_="no"   # yes or no (just for testing)
    local term_w=$(tput cols)
    local last_status_len=$(( ${#last_status_raw} ))
    local env_tag_len=$(( ${#JOE_ENV} + 3 + ${#_SHELL} + 4 ))
    local user_host_len=$(( ${#_USER} + 3 + ${#NODE_HOST} ))
    local current_dir_len=$(( ${#PWD} ))
    local git_info_len=$(( ${#git_len} ))
    
    # -- border configuration
    local BN_BORDER_CHAR="┈"          # --   ┈ ━  ▨  ▬ ━ ▭ 
    local BN_BORDER_COLOR="235"        # --  agument2 = สี จาก cn() ใน 01-colors.sh 
    local BN_BORDER_STYLE="d"         # --  agument3 = สไตล์ จาก cn() ใน 01-colors.sh  
    # ───────────────  end border configuration ───────────────

    local lens=$(( last_status_len + 1 + env_tag_len + 1 + user_host_len + 1 + current_dir_len + 1 + git_info_len ))

    # -- ปรับความยาวเส้นกรอบ อัตโนมัติ
    (( lens > term_w )) && lens=$term_w
    (( term_w >= 80 )) && lens=80

    
    if [[ -n "$RC_" && "$RC_" == "yes" ]]; then

    # -- กรอบ prompt แบบ random สี
        local borde=$(rc "${BN_BORDER_STYLE}" "$(draw_ "${BN_BORDER_CHAR}" "$lens")")
    else
    # -- กรอบ prompt แบบกำหนดสี
        local borde=$(cn "${BN_BORDER_COLOR}" "${BN_BORDER_STYLE}" "$(draw_ "${BN_BORDER_CHAR}" "$lens")")
    fi
    
    # -- ประกอบร่างเป็น Dynamic PS1 (Prompt)
    local PS1_="" 
    PS1_+="${borde}\n"
    PS1_+="${last_status} ${env_tag} ${user_host} in ${current_dir}${git_info}\n"
    PS1_+="${borde}\n"
    PS1_+=" ❯-❤️-> "
    

    export PS1=$PS1_

}

# สั่งให้ Bash รันฟังก์ชันนี้ทุกครั้งก่อนแสดง Prompt
if [[ -z "${ZSH_VERSION:-}" ]]; then PROMPT_COMMAND=_set_prompt; fi

# 5. Show Fastfetch (only in interactive WSL shells with logo)
if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
    if [ "$JOE_ENV" = "WSL" ]; then
        clear
        fastfetch --logo ubuntu
    fi
fi


draw_() {
   
   printf "%*s" "$2" "" | sed "s/ /$1/g"  
}
alias d_='draw_'






