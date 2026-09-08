 #!/bin/bash
# ============================================================
# fm-loader.sh — File Manager Integration
# ============================================================

# ============================================================

fm_(){

    if command -v fm >/dev/null 2>&1 ; then   
        cn 45 b "BASH_MANAGER is Loaded" &&
        fm learn on &&
        fm "$@"
    else
        _check -f  "$SSOT/core/bash-manager.sh" "source" &&
        fm learn on &&
        fm "$@"
    fi

}









