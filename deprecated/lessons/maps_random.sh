#!/bin/bash
maps=("SKY" "FIRE" "WATER" "WIND")

rdm_1() {
    # รับค่าจาก Argument หรือใช้ค่า Default ถ้าไม่ได้ระบุ
    
    local -a maps=("${@}")
    if (( ${#maps[@]} == 0 )); then
        maps=("${maps[@]}")
    fi

    local n=${#maps[@]}
    local i j tmp

    # Fisher-Yates: สลับตำแหน่งแบบสุ่มจากหลังมาหน้า
    for (( i = n - 1; i > 0; i-- )); do
        j=$(( RANDOM % (i + 1) ))
        tmp="${maps[i]}"
        maps[i]="${maps[j]}"
        maps[j]="$tmp"
    done

    # แสดงผลตามลำดับที่สุ่มแล้วจนครบ
    for m in "${maps[@]}"; do
        cn 10 b "🎲 $m"
    done
}

rdm_2() {
    local -a maps=("${@}")
    if (( ${#maps[@]} == 0 )); then
       maps=("SKY" "FIRE" "WATER" "WIND")
    fi

    while IFS= read -r m; do
        cn 10 b "🎯 $m"
    done < <(shuf -e "${maps[@]}")
}

rdm_i() {
    local -a maps=("${@}")
    if (( ${#maps[@]} == 0 )); then
        maps=("SKY" "FIRE" "WIND" "WATER")
    fi

    # Shuffle ก่อน
    local n=${#maps[@]} i j tmp
    for (( i = n - 1; i > 0; i-- )); do
        j=$(( RANDOM % (i + 1) ))
        tmp="${maps[i]}"; maps[i]="${maps[j]}"; maps[j]="$tmp"
    done

    local count=1
    for m in "${maps[@]}"; do
        read -rp "Press [Enter] to pick map ($count/$n)..."
        cn 208 b "👉 [$count/$n] Map: $m"
        ((count++))
    done
    cn 82 b "✨ All maps have been picked!"
}
rdm(){
    
maps=("SKY" "FIRE" "WATER" "WIND")

    local mode=${1:-"rdm_i"}
    shift
    case $mode in 
    1) 
        rdm_1 "$@"
        ;;
    2) 
        rdm_2 "$@"
        ;;
    i) 
        rdm_i "$@"
        ;;
    *) 
        echo "Invalid mode"
        ;;
    esac
}