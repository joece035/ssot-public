# ============================================================
# SupperBoom env function (moved from 00-env.sh)
# ============================================================

# ============================================================
# Boom env function (moved from 00-env.sh)
# ============================================================

_() {
    # ให้ render.sh รันก่อน
    if ! command -v bn_2 &> /dev/null && ! command -v bn_3 &> /dev/null; then
        _check -f "$SSOT/lessons/auto_table/render.sh" "source" || return 1
    fi
    local base_c="${WIN_PATH}c/Users/User/Documents/mumusharedfolder"
    local base_z="${WIN_PATH}z/MuMuSharedFolder"
    local base_backup="${WIN_PATH}h/boom"
    local base_hb="${WIN_PATH}h/MuMuSharedFolder"
    local list_=(
        "css|${base_c}/Screenshots"
        "cvdo|${base_c}/VideoRecords"
        "hss|${base_hb}/Screenshots"
        "hvdo|${base_hb}/VideoRecords"
        "bss|${base_backup}/Screenshots"
        "bvdo|${base_backup}/VideoRecords"
        "zss|${base_z}/Screenshots"
        "zvdo|${base_z}/VideoRecords"
        "h|--help"
    ) 
    case $1 in
        css)         printf "%s\n" "${base_c}/Screenshots" ;;
        cvdo)        printf "%s\n" "${base_c}/VideoRecords" ;;
        hss)         printf "%s\n" "${base_hb}/Screenshots" ;;
        hvdo)        printf "%s\n" "${base_hb}/VideoRecords" ;;
        bss)         printf "%s\n" "${base_backup}/Screenshots" ;;
        bvdo)        printf "%s\n" "${base_backup}/VideoRecords" ;;
        zss)         printf "%s\n" "${base_z}/Screenshots" ;;
        zvdo)        printf "%s\n" "${base_z}/VideoRecords" ;;
        -h|--help)   ( bn_2 "${list_[@]}" ) ;;
        *)           ( bn_3 "${list_[@]}" ) ;;
    esac
}

rn_lgr(){
    local space="  "
    local name="${1:-$space}"   
    local a b c d e

       case "$name" in  
            a) name='.7oEz' ;; 
            b) name='-MVP-#35' ;; 
            c) name='J1' ;; 
            d) name='J2' ;; 
            e) name='J3' ;;
            *) name="$name" ;; 
        esac
    echo "$name" | clip.exe
    cn lg b "ชื่อใหม่ = $(cn 45 b "$name") ถูก cp ไว้ใน clipboard แล้ว"

}
lgrn(){
    rn_lgr "$@"
}

