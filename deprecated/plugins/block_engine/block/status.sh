#!/bin/bash


# ============================================================
# block/status.sh — Data providers (Status Renderers)
# ============================================================
# Functions:
#   status_new   — system status dashboard (SSH, Tailscale, Syncthing, Acode-X)
#   op_profile   — operator profile dashboard
# ============================================================
# Each function collects data then calls dashboard_array.
# No global side-effects beyond what dashboard needs.
# ============================================================

# ============================================================
# status_new — JOE system status block
# ============================================================
status_new() {
  
 
    # -- 1. SSH Status
    local ssh_val ssh_emo
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        ssh_val="ACTIVE"
        ssh_emo="🟢"
    else
        ssh_val="LOCAL"
        ssh_emo="💻"
    fi

    # -- 2. Tailscale Status
    #    Primary : `timeout 5` (WSL / Termux / macOS / Linux) — clean, no job noise.
    #    Fallback: git-bash has no `timeout` → bg+wait, but wrapped in
    #              `set +m` subshell to suppress bash job-control notifications
    #              ([1] PID / [2]+ Terminated) that would otherwise leak into
    #              the dashboard output.  The subshell ALSO prevents the bg
    #              job from inheriting the interactive shell's monitor mode.
    local ts_val
    if command -v tailscale &>/dev/null; then
        if command -v timeout &>/dev/null; then
            # -- Primary path: `timeout` is a single foreground command.
            #    Exit codes: 0 = ok, 124 = timeout, 125 = timeout itself failed, 127 = cmd not found.
            timeout 5 tailscale status &>/dev/null
            local rc=$?
            if   (( rc == 0 ));   then ts_val="ONLINE"
            elif (( rc == 124 )); then ts_val="OFFLINE/SLOW"
            else                     ts_val="OFFLINE"
            fi
        else
            # -- Fallback path: git-bash (no timeout). Run bg work in a
            #    subshell with monitor mode disabled so `[1] PID` / `Terminated`
            #    notifications never print. Capture rc via the subshell's stdout.
            local rc
            rc=$(
                set +m   # disable job-control notifications in this subshell
                tailscale status &>/dev/null &
                local ts_pid=$!
                ( sleep 5; kill "$ts_pid" 2>/dev/null ) &
                local killer=$!
                wait "$ts_pid" 2>/dev/null
                local _rc=$?
                kill "$killer" 2>/dev/null
                wait "$killer" 2>/dev/null   # reap so no "Terminated" leaks
                printf '%s\n' "$_rc"
            2>&1)
            if   [[ "$rc" == "0" ]];   then ts_val="ONLINE"
            elif [[ "$rc" == "143" ]]; then ts_val="OFFLINE/SLOW"
            else                            ts_val="OFFLINE"
            fi
        fi
    else
        ts_val="NO TAILSCALE"
    fi

    # -- 3. Syncthing Status
    local st_raw st_val st_emo
    st_raw=$(_get_syncthing_raw 2>/dev/null || echo "UNKNOWN|❓")
    st_val="${st_raw%|*}"
    st_emo="${st_raw#*|}"

    # -- 4. Acode-X terminal status
    local axs_ axs_emo
    if pgrep -f axs > /dev/null 2>&1; then
        axs_="ONLINE"
        axs_emo="🟢"
    else
        axs_="OFFLINE"
        axs_emo="🔴"
    fi
    # -- 5.Oenclaw & Hermes detection
    local openclaw_ver hermes_ver tool tools
    tools=( "openclaw" "hermes" )

    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
             case "$tool" in
                "openclaw")
                    openclaw_ver=$("$tool" --version 2>/dev/null | cut -d" " -f1,2)
                    ;;
                "hermes")
                    hermes_ver=$("$tool" --version 2>/dev/null | awk 'NR==1 {print $3, $4}')
                    ;;
             esac
        else
             case "$tool" in
                "openclaw") openclaw_ver="NOT INSTALLED" ;;
                "hermes")   hermes_ver="NOT INSTALLED" ;;
             esac
        fi
        done

        local ROWS=(
        "🌍|JOE_ENV|${JOE_ENV:-UNKNOWN}|📱"
        "🔐|SSH|${ssh_val}|${ssh_emo}"
        "🌐|TAILSCALE|${ts_val}|🌐"
        "📂|CURRENT DIR|$(basename "$PWD")|📂"
        "🔄|SYNCTHING|${st_val}|${st_emo}"
        "🆚|Acode-X|${axs_}|${axs_emo}"
        "📅|date|$(date | cut -d" " -f1,3,2,6)|📅"
        "🌘|time|$(date | cut -d" " -f4,5)|🕒"
	    "🦞|Openclaw ver.|${openclaw_ver}|🦀"
        "🤖|Hermes ver.|${hermes_ver}|🤖"
    )
        dashboard_array "${ROWS[@]}"
    
       
     
}

# ============================================================
# op_profile — Operator profile block
# ============================================================
op_() {
local shells=$(basename  $SHELL)
    
    local example_ROWS=(
        "👤|USER|${USER:-$(whoami)}|🔑"
        "🏠|HOME|${HOME:-~}|📁"
        "🇹🇭|AI MODEL|${MODEL:-$OPENCODE_MODEL}|🌏"
        "🕜|UPTIME|$(uptime -p 2>/dev/null | sed 's/up //' || echo 'N/A')|⏰"
        "🐚|SHELL|${shells:-bash}|🔧"
        "📅|DATE|$(date '+%Y-%m-%d')|📅"
    )
    dashboard_array "${example_ROWS[@]}"
}


joe_test() {
    # offset -1→+1: -1=left, 0=center, +1=right
    # border_random: yes=rainbow, no=fixed, random=single random color
    local rcb=("yes" "no" "random")
    local offsets=(-1 -0.75 -0.5 -0.25 0 0.25 0.5 0.75 1)
    local labels=("ซ้ายสุด" "3/4ซ้าย" "กลางซ้าย" "1/4ซ้าย" "กลาง" "1/4ขวา" "กลางขวา" "3/4ขวา" "ขวาสุด")
    local i=0
    for off in "${offsets[@]}"; do
        for rc in "${rcb[@]}"; do
            cn lg b "─── OFFSET=$off (${labels[$i]}) BORDER=$rc ───"
            _THEME[border_random]="$rc"
            _THEME[offset]="$off"
            local ROWS=(
                "👤|USER|${USER:-$(whoami)}|🔑"
                "🏠|HOME|${HOME:-~}|📁"
                "🖥️|HOST|${HOSTNAME:-$(hostname)}|🌐"
                "⏱️|UPTIME|$(uptime -p 2>/dev/null | sed 's/up //' || echo 'N/A')|⏱️"
                "🐚|SHELL|${SHELL:-bash}|🔧"
                "📅|DATE|$(date '+%Y-%m-%d')|📅"
            )
            dashboard_array "${ROWS[@]}"
            echo ""
        done
        (( i++ ))
    done
}


openv() {
   
    cn lg b "openclaw.json CONFIGURED!" 
    
     local ROWS=(  
        "|OPENCLAW_STATE_DIR|$OPENCLAW_STATE_DIR|"
        "|LOCAL_URL|$OPENCLAW_LOCAL_URL|"
        "|MODEL|$OPENCLAW_MODEL|"
        "|TIME_OUT|$OPENCLAW_TIMEOUT|"
        "|OPENCLAW_GATEWAY_PORT|$OPENCLAW_GATEWAY_PORT|"
        "|OPENCLAW_TOKEN|$(_mask_token "$OPENCLAW_TOKEN")|"
        "|BRAVE_API_KEY|$(_mask_token "$BRAVE_API_KEY")|"
        "|TELEGRAM_BOT_TOKEN|$(_mask_token "$TELEGRAM_BOT_TOKEN")|"
        "|DISCORD_BOT_TOKEN|$(_mask_token "$DISCORD_BOT_TOKEN")|"
        "|WORKSPACE|$WORKSPACE|"
        "|OPENCLAW_BIN|$OPENCLAW_BIN|"
        "|OPENCLAW_INDEX_JS|$OPENCLAW_INDEX_JS|"
    )
    dashboard_array "${ROWS[@]}"
}

jrun(){
   
   local off=(-1 -0.9 -0.8 -0.7 -0.6 -0.5 -0.4 -0.3 -0.2 -0.1 -0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1)
   local i=0
    
    for off_ in "${off[@]}"; do
    
      _THEME[offset]="$off_"
      local ROWS=(
                "👤|USER|${USER:-$(whoami)}|🔑"
                "🏠|HOME|${HOME:-~}|📁"
                "🖥️|HOST|${HOSTNAME:-$(hostname)}|🌐"
                "⏱️|UPTIME|$(uptime -p 2>/dev/null | sed 's/up //' || echo 'N/A')|⏱️"
                "🐚|SHELL|${SHELL:-bash}|🔧"
                "📅|DATE|$(date '+%Y-%m-%d')|📅"
            )
            dashboard_array "${ROWS[@]}"
            echo ""
        done
      
    
      
      
}