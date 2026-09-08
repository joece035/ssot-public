#!/bin/bash

n_(){
    local border_len=83 term_w
    term_w=$(tput cols)
    ((border_len > term_w)) && border_len=$term_w
    local border="$(cn 92 b "$(draw_ '▬' "$border_len")")"
    local text="Current System Information"
    local head="$(cn 208 b "$text")"
    local banner=""
    local pad_=$(((border_len - ${#text})/2))

    banner+="${border}\n"
    banner+="$(printf " %*s$head%*s\n" "$pad_" ' ' "$pad_" ' ')\n"
    banner+="${border}\n"
    banner+="$(cn 250 d "Current Directory")         : $(cn lcr '' "${PWD}")\n"
    banner+="$(cn 250 d "Home Directory")            : $(cn lcr '' "${HOME}")\n"
    banner+="$(cn 250 d "Current User")              : $(cn lcr '' "${USER}")\n"
    banner+="$(cn 250 d "Current Shell")             : $(cn lcr '' "${SHELL}")\n"
    banner+="$(cn 250 d "Current Kernel")            : $(cn lcr '' "$(uname -r)")\n"
    banner+="$(cn 250 d "Current Architecture")      : $(cn lcr '' "$(uname -m)")\n"
    banner+="$(cn 250 d "Current OS")                : $(cn lcr '' "$(uname -o)")\n"
    banner+="$(cn 250 d "Current OS Version")        : $(cn lcr '' "$(uname -v)")\n"
    banner+="$(cn 250 d "Current OS Platform")       : $(cn lcr '' "$(uname -s)")\n"
    banner+="$(cn 250 d "Current OS Kernel Version") : $(cn lcr '' "$(uname -r)")\n"
    banner+="${border}\n"

    printf "%b\n" "${banner}"
}

# ============================================================
# Banner / Info Card Template (Reusable)
# ============================================================

# bn_3: Dynamic Auto-Width Table (ความกว้างพอดีตามเนื้อหา)
bn_2() {
    # --- 0. Config & Defaults ---
    if ! command -v config_rc &> /dev/null; then
        _check -f "$SSOT/lessons/auto_table/config.sh" "source" || return 1
    fi
    config_rc

    local title="${BN_TITLE:-Shortcuts folders}"
    local title_c="${BN_TITLE_COLOR:-208}"
    local title_s="${BN_TITLE_STYLE:-b}"

    local border_ch="${BN_BORDER_CHAR:-▬}"
    local border_c="${BN_BORDER_COLOR:-92}"
    local border_s="${BN_BORDER_STYLE:-b}"
    local border_len="${BN_BORDER_LEN:-}"

    local label_c="${BN_LABEL_COLOR:-250}"
    local label_s="${BN_LABEL_STYLE:-d}"
    local val_c="${BN_VAL_COLOR:-lcr}"
    local val_s="${BN_VAL_STYLE:-}"
    local sep="${BN_SEP:- : }"

    local term_w
    term_w=$(tput cols 2>/dev/null || echo 80)

    # --- 2. Scan หา max label & max value ---
    local item lbl val padded_lbl
    local max_label_len=0 max_val_len=0

    for item in "$@"; do
        lbl="${item%%|*}"
        val="${item#*|}"
        (( ${#lbl} > max_label_len )) && max_label_len=${#lbl}
        (( ${#val} > max_val_len )) && max_val_len=${#val}
    done

    # คำนวณความกว้าง Border อัตโนมัติถ้าไม่ได้ระบุ
    local content_w=$(( max_label_len + ${#sep} + max_val_len ))
    local title_len=${#title}

    if [[ -z "$border_len" || "$border_len" -eq 0 ]]; then
        border_len=$content_w
        (( title_len > border_len )) && border_len=$title_len
    fi

    (( border_len > term_w )) && border_len=$term_w
    (( border_len < 10 )) && border_len=10

    # --- 3. สร้าง Border & Header ---
    local border_raw="$(draw_ "$border_ch" "$border_len")"
    local border
    if [[ -n "$COLOR_MODE" && "$COLOR_MODE" == "yes" ]]; then
        border="$(rc "$border_s" "$border_raw")"
    else
        border="$(cn "$border_c" "$border_s" "$border_raw")"
    fi

    # คำนวณการจัดกึ่งกลาง Title
    local pad_left=$(( (border_len - title_len) / 2 ))
    (( pad_left < 0 )) && pad_left=0

    # พิมพ์หัวตาราง
    printf "%s\n" "$border"
    if [[ -n "$title" ]]; then
        printf "%*s%s\n" "$pad_left" "" "$(c "$title_c" "$title_s" "$title")"
        printf "%s\n" "$border"
    fi

    # --- 4. แสดงผลข้อมูลแต่ละแถว ---
    for item in "$@"; do
        lbl="${item%%|*}"
        val="${item#*|}"
        padded_lbl="$(printf "%-*s" "$max_label_len" "$lbl")"
        c "$label_c" "$label_s" "$padded_lbl"
        printf "%s" "$sep"
        cn "$val_c" "$val_s" "$val"
    done

    # --- 5. พิมพ์ปิดท้าย ---
    printf "%s\n" "$border"
    bn_3_=yes
}

# bn_2: Fixed Width Table (ความกว้างมาตรฐาน 80 ตัวอักษร)
bn_3() {
    # --- 0. Config & Defaults ---
    if ! command -v config_def &> /dev/null; then
        _check -f "$SSOT/lessons/auto_table/config.sh" "source" || return 1
    fi
    config_def

    local title="${BN_TITLE:-Shortcuts folders}"
    local title_c="${BN_TITLE_COLOR:-208}"
    local title_s="${BN_TITLE_STYLE:-b}"

    local border_ch="${BN_BORDER_CHAR:-▬}"
    local border_c="${BN_BORDER_COLOR:-92}"
    local border_s="${BN_BORDER_STYLE:-b}"
    local border_len="${BN_BORDER_LEN:-80}"

    local label_c="${BN_LABEL_COLOR:-250}"
    local label_s="${BN_LABEL_STYLE:-d}"
    local val_c="${BN_VAL_COLOR:-lcr}"
    local val_s="${BN_VAL_STYLE:-}"
    local sep="${BN_SEP:- : }"

    local item lbl val padded_lbl

    # --- 2. สร้าง Border & Header ---
    local term_w="$(tput cols)"
    local border_raw=""
    (( border_len > term_w )) && border_len="$term_w"
    border_raw="$(draw_ "$border_ch" "$border_len")"
    local border
    border="$(c "$border_c" "$border_s" "$border_raw")"
	 
    local title_len=${#title}
    local pad_left=$(( (border_len - title_len) / 2 ))
    (( pad_left < 0 )) && pad_left=0

    printf "%s\n" "$border"
    if [[ -n "$title" ]]; then
        printf "%*s%s\n" "$pad_left" "" "$(c "$title_c" "$title_s" "$title")"
        printf "%s\n" "$border"
    fi

    # --- 3. คำนวณความกว้าง Label อัตโนมัติ ---
    local max_label_len=0
    for item in "$@"; do
        lbl="${item%%|*}"
        (( ${#lbl} > max_label_len )) && max_label_len=${#lbl}
    done

    # --- 4. Render แต่ละ Row ---
    for item in "$@"; do
        lbl="${item%%|*}"
        val="${item#*|}"

        padded_lbl="$(printf "%-*s" "$max_label_len" "$lbl")"

        c "$label_c" "$label_s" "$padded_lbl"
        printf "%s" "$sep"
        cn "$val_c" "$val_s" "$val"
    done

    printf "%s\n" "$border"
    bn_2_=yes
}
