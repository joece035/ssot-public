 #!/bin/bash
# ============================================================
# 00-fm-loader.sh — File Manager Lazy Loader
# ============================================================
# แทนที่จะ source bash-manager.sh ทั้งไฟล์ (165KB) ทุก session
# ระบบนี้จะสร้าง stub wrapper สำหรับทุก fm_* / xfm_* function
# เมื่อเรียก function ครั้งแรก → auto-source bash-manager.sh
# ครั้งถัดไป → ฟังก์ชันจริงพร้อมใช้ทันที (ไม่ source ซ้ำ)
# ============================================================

# path ไปยังไฟล์ใหญ่
_FM_MANAGER_PATH="${SSOT:-$repository}/core/bash-manager.sh"

# ============================================================
# _register_lazy — สร้าง stub wrapper functions แบบ lazy-load
# Usage: _register_lazy <source_file> <func1> [func2 ...]
# ============================================================
_register_lazy() {
    local source_file="$1"
    shift
    local func_names=("$@")

    if [[ ! -f "$source_file" ]]; then
        echo "⚠️  _register_lazy: File not found: $source_file" >&2
        return 1
    fi

    for func in "${func_names[@]}"; do
        # ใช้ printf เพื่อสร้าง stub function body อย่างปลอดภัย
        # หลีกเลี่ยง quoting hell ใน eval string ที่ซับซ้อน
        local stub
        stub="$(printf '%s() {
    unset -f %s 2>/dev/null
    if source %s; then
        if declare -F %s >/dev/null 2>&1 || { [ -n "$ZSH_VERSION" ] && typeset -f %s >/dev/null 2>&1; }; then
            %s "$@"
        else
            echo "❌ Function %s not found after sourcing %s" >&2
            return 1
        fi
    else
        echo "❌ Failed to source: %s" >&2
        return 1
    fi
}' "$func" "$func" "$source_file" "$func" "$func" "$func" "$func" "$source_file" "$source_file")"
        eval "$stub"
    done
}

# ============================================================
# fm_ — Entry point ที่มีอยู่เดิม (ไม่เปลี่ยนแปลง)
# ============================================================
fm_() {
    if command -v fm >/dev/null 2>&1; then
        cn 45 b "BASH_MANAGER is Loaded" &&
        fm learn on &&
        fm "$@"
    else
        _check -f "$SSOT/core/bash-manager.sh" "source" &&
        fm learn on &&
        fm "$@"
    fi
}

# ============================================================
# Register fm_* functions — lazy-load จาก bash-manager.sh
# ============================================================
_register_lazy "$_FM_MANAGER_PATH" \
    fm_learn \
    fm_help \
    fm_ls \
    fm_lsa \
    fm_tree \
    fm_goto \
    fm_back \
    fm_home \
    fm_pwd \
    fm_cp \
    fm_mv \
    fm_rm \
    fm_rn \
    fm_mk \
    fm_mkdir \
    fm_touch \
    fm_link \
    fm_find \
    fm_grep \
    fm_findext \
    fm_findsize \
    fm_info \
    fm_size \
    fm_recent \
    fm_big \
    fm_dup \
    fm_zip \
    fm_unzip \
    fm_tar \
    fm_untar \
    fm_ziplist \
    fm_perm \
    fm_chmod \
    fm_chown \
    fm_mkexec \
    fm_rmexec \
    fm_df \
    fm_du \
    fm_clean \
    fm_trash \
    fm_emptytrash \
    fm_bren \
    fm_bcp \
    fm_bmv \
    fm_brm \
    fm_sortdir \
    fm_datedir \
    fm_world \
    fm_ssh \
    fm_push \
    fm_pull \
    fm_rls \
    fm_rrun \
    fm

# ============================================================
# Register xfm_* functions — lazy-load จาก bash-manager.sh
# ============================================================
_register_lazy "$_FM_MANAGER_PATH" \
    xfm_help \
    xfm_status \
    xfm_ls \
    xfm_cp \
    xfm_mv \
    xfm_rm \
    xfm_mkdir \
    xfm_info \
    xfm_df \
    xfm_du \
    xfm_find \
    xfm_sync \
    xfm_push \
    xfm_pull \
    xfm_merge \
    xfm
