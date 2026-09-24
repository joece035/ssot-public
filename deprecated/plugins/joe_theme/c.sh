#!/usr/bin/env bash
# ======================================================
# 🎨 JOE'S TERMINAL THEME & PROMPT (WSL Ubuntu Edition)
# ======================================================
if [[ -n "${BASH_VERSION:-}" ]]; then

		_sp(){
	 #  -- Last status
	  local exit_code=$?
    local last_status_c last_status_s last_status_raw last_status
    if [ $exit_code -eq 0 ]; then
        last_status_c="lg"
        last_status_s="b"
        last_status_raw="> "
    else
        last_status_c="1"
        last_status_s="b"
        last_status_raw="> "
    fi
    last_status="$(c "$last_status_c" "$last_status_s" "$last_status_raw")"
        
   #  -- Directory
   local d_=$(printf ': 📂 %s ' "$(c 240 d "$PWD")")

	 #  -- Repository
	 local repo_name=$(echo $SSOT | xargs basename)
	 local rp_tag=$(printf 'REPO : %s\n' "$repo_name")
	 #  Render
    # -- ประกอบร่างเป็น Dynamic PS1 (Prompt)
    local PS1_=""
		PS1_+="$rp_tag\n"
		PS1_+="$(c 200 d "💻 $NODE_HOST ")"
		PS1_+="$d_\n"
		PS1_+="$last_status"

    # ห้าม export PS1 เข้า env เพราะจะ leak ไปยัง child shells (เช่น zsh)
    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
 		}

		# สั่งให้ Bash รันฟังก์ชันนี้ทุกครั้งก่อนแสดง Prompt (bash only)
		export -n PROMPT_COMMAND 2>/dev/null || true
		PROMPT_COMMAND=_sp
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # ZSH Guard: PROMPT_COMMAND เป็นของ Bash เท่านั้น ไม่ใช้ใน Zsh
    unset PROMPT_COMMAND
    export -n PROMPT_COMMAND 2>/dev/null || true
fi

# 5. Show Fastfetch (only in interactive WSL shells with logo)
if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
    if [ "$JOE_ENV" = "WSL" ]; then
        clear
        fastfetch --logo ubuntu
    fi
fi







