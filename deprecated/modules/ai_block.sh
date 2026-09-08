#!/bin/bash
# ============================================================
# ai_block.sh — AI Status Block for JOE_BLOCK Engine
# ============================================================
# Provides AI status display integration with JOE_BLOCK
# ============================================================

# ============================================================
# AI BLOCK STYLE - Integrates with JOE_BLOCK engine
# ============================================================
_style_ai() {
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #
    set_ _data_ROWS        "ai_status"    # -- AI data source
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #
    set_ BORDER_RANDOM_C   "no"   # -- no random color border
    set_ FRAME_RANDOM_C    "no"   # -- no random color frame  
    # ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰  #

    # -- AI-specific layout constants
    set_ OFFSET            "$(bc_ $(tp)/4)"  # ---- ตำแหน่งบล็อค
    
    # -- AI Color Theme (Cyan/Purple gradient)
    set_ BORDER_RANDOM      "▨"
    set_ FRAME_RANDOM       "‖"
    set_ TOP_BORDER         "▰"
    set_ BOT_BORDER         "▰"
    
    # -- AI Color Config (Cyan-Purple theme) — ใช้ short name ของ color(): cr=cyan, m=magenta
    set_ MID_LINE_C        'cr ""'
    set_ ROW_FRAME_C       'cr ""'
    set_ MID_FRAME_C       'cr ""'
    set_ TOP_BORDER_C      'cr b'
    set_ BOT_BORDER_C      'm b'
    
    # -- Label & Value colors (AI theme)
    set_ LABEL_C           'cr ""'   # -- label color
    set_ VALUE_C           'w bi'      # -- value color (bright white)
    set_ MID_SEP_C         'm b' # -- mid separator color
    
    set_ MID_SEP_          " → "       # -- label-value separator (arrow style)
}

# ============================================================
# AI STATUS DATA SOURCE
# ============================================================
ai_status_data() {
    local rows=()
    
    # Row 1: AI Status
    local ai_state=$(ai_status 2>/dev/null || echo "offline||unknown")
    local status=$(echo "$ai_state" | cut -d'|' -f1)
    local sessions=$(echo "$ai_state" | cut -d'|' -f2)
    local last_active=$(echo "$ai_state" | cut -d'|' -f3)
    
    local status_icon
    case "$status" in
        online)  status_icon="🟢" ;;
        offline) status_icon="🔴" ;;
        *)       status_icon="⚪" ;;
    esac
    
    rows+=("🤖|AI Status|${status}|${status_icon}")
    rows+=("🧠|Sessions|${sessions}|📊")
    rows+=("⏰|Last Active|${last_active}|📅")
    
    # Row 4: Current Context
    local context=$(ai_context_analyze 2>/dev/null || echo "dir:$(pwd)")
    local current_dir=$(echo "$context" | grep -o "dir:[^|]*" | cut -d: -f2 | xargs basename)
    rows+=("📂|Current Dir|${current_dir}|📁")
    
    # Row 5: Git Status (if available)
    if git rev-parse --git-dir &>/dev/null 2>&1; then
        local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        local modified=$(git status --porcelain 2>/dev/null | wc -l)
        rows+=("🔀|Git Branch|${branch}|📝 ${modified} modified")
    fi
    
    # Output for JOE_BLOCK
    printf '%s\n' "${rows[@]}"
}

# ============================================================
# AI BLOCK RENDERER (uses JOE_BLOCK engine)
# ============================================================
ai_block_render() {
    local style="${1:-ai}"
    
    # Load AI style
    _style_ai
    
    # Get AI status data
    local ai_data=$(ai_status_data)
    
    # Use JOE_BLOCK engine to render
    if [[ -f "$JOE_PLUGINS/block_engine/entry.sh" ]]; then
        source "$JOE_PLUGINS/block_engine/entry.sh"
        echo "$ai_data" | dashboard
    else
        # Fallback: simple display
        cn cyan b "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$ai_data" | while IFS='|' read -r emoji_l label value emoji_r; do
            cn cyan b "  ${emoji_l} ${label}: ${value} ${emoji_r}"
        done
        cn cyan b "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
}

# ============================================================
# INTEGRATION WITH JOE_BLOCK
# ============================================================
# Add this to JOE_BLOCK to show AI status:
# 
# If you want to add AI block to existing JOE_BLOCK:
#   source "$SSOT/tools/ai_block.sh"
#   ai_block_render
#
# Or use the dedicated command:
#   joe ai-status
# ============================================================

# Aliases
alias ai-block='ai_block_render'
alias ai-display='ai_block_render'
