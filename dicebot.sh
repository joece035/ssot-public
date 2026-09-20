#!/usr/bin/env bash
# ------------------------------------------------------------
# File: dicebot.sh
# ------------------------------------------------------------

set -euo pipefail

readonly PROG="$(basename "$0")"

# --- Logging ---
LOGFILE="$HOME/.local/share/dicebot.log"
mkdir -p "$(dirname "$LOGFILE")"

log() {
    printf "%s | %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"
}

# --- Telegram variables ---
readonly BOT_TOKEN="your_bot_token_here"
readonly CHAT_ID="your_chat_id_here"

# ------------------------------------------------------------
# Send Telegram message via curl (supports UTF-8)
# ------------------------------------------------------------

# Escapes MarkdownV2 special characters in $text
escape_mdv2() {
    local text="$1"
    # Escape special chars: \ \_ \* \[ \] \( \) \~ \` \> \# \+ \- \= \| \{ \} \. !
    text=${text//\\/\\\\}
    text=${text//_/\\_}
    text=${text//\*/\\*}
    text=${text//[/\\[}
    text=${text//]/\\]}
    text=${text//(/\\(}
    text=${text//)/\\)}
    text=${text//~/\\~}
    text=${text//`/\\`}
    text=${text//>/\\>}
    text=${text//#/\\#}
    text=${text//+/\\+}
    text=${text//-/\\-}
    text=${text//=/\\=}
    text=${text//|/\\|}
    text=${text//\{/\\\{}
    text=${text//\}/\\\}}
    text=${text//./\\.}
    text=${text//!/\\!}
    printf "%s" "$text"
}

send_tg_message() {
    local msg="$1"

    if [[ -z "$BOT_TOKEN" ]] || [[ "$BOT_TOKEN" == "your_bot_token_here" ]]; then
        log "ERROR: BOT_TOKEN not set"
        printf "ERROR: BOT_TOKEN not set\n"
        return 1
    fi

    if [[ -z "$CHAT_ID" ]] || [[ "$CHAT_ID" == "your_chat_id_here" ]]; then
        log "ERROR: CHAT_ID not set"
        printf "ERROR: CHAT_ID not set\n"
        return 1
    fi

    # Send as MarkdownV2
    local json="{\"chat_id\":\"$CHAT_ID\",\"text\":\"$(escape_mdv2 "$msg")\",\"parse_mode\":\"MarkdownV2\"}"

    curl --silent --show-error -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
      -H "Content-Type: application/json" \
      -d "$json"

    local http_code="${PIPESTATUS[0]}"
    if [[ "$http_code" -ne 0 ]]; then
        log "ERROR: Telegram API error (code $http_code)"
        printf "ERROR: Telegram API error (code %s)\n" "$http_code"
        return 1
    fi

    log "✅ Telegram message sent successfully"
    return 0
}

# ------------------------------------------------------------
# Dice rolling core
# ------------------------------------------------------------

parse_dice() {
    local dice="$1"
    local num=1
    local sides=6

    if [[ $dice =~ ^([0-9]+)d([0-9]+)$ ]]; then
        num=${BASH_REMATCH[1]}
        sides=${BASH_REMATCH[2]}
    elif [[ $dice =~ ^d([0-9]+)$ ]]; then
        num=1
        sides=${BASH_REMATCH[1]}
    else
        echo "Invalid dice format: $dice"
        return 1
    fi

    if (( sides < 1 )); then
        echo "Dice sides must be >= 1"
        return 1
    fi

    printf "%d\n%d\n" "$num" "$sides"
    return 0
}

roll_dice() {
    local num=$1
    local sides=$2

    local total=0
    local rolls=()

    for i in $(seq 1 "$num"); do
        local roll=$(( RANDOM % sides + 1 ))
        rolls+=("$roll")
        total=$((total + roll))
    done

    echo "$total"
    printf "%s\n" "${rolls[@]}"
}

# ------------------------------------------------------------
# Generate Markdown summary
# ------------------------------------------------------------

format_markdown() {
    local user="$1"
    local dice="$2"
    shift 2
    local rolls=("@")
    local total=$1

    local rolls_list=""
    for roll in "${rolls[@]}"; do
        rolls_list+="\`$roll\` "
    done
    rolls_list="${rolls_list% }"

    printf "🎲 **%s rolled \`%s\`**\n\nRolls: %s\n\n📊 **Total: %d**\n"
        "$user" "$dice" "$rolls_list" "$total"
}

# ------------------------------------------------------------
# Main execution
# ------------------------------------------------------------

show_help() {
    printf "Usage: %s [dice]\n\nExamples:\n" "$PROG"
    printf "  %s 1d20   # roll one 20-sided die\n" "$PROG"
    printf "  %s 2d6    # roll two 6-sided dice\n" "$PROG"
    printf "  %s d100   # same as 1d100\n" "$PROG"
    printf "\nSends result to Telegram (MarkdownV2 format).\n"
    printf "Output is also logged to '%s'\n" "$LOGFILE"
}

# Handle Ctrl+C and kill signals
trap 'log "INTERRUPTED"; exit 1' INT TERM EXIT

# Parse arguments
if [[ $# -eq 0 ]]; then
    show_help
    log "INFO: show_help called"
    exit 0
fi

readonly DICE_INPUT="$1"

# Validate dice format
if ! parse_dice "$DICE_INPUT" >&2; then
    log "ERROR: Invalid dice format: $DICE_INPUT"
    exit 1
fi

# Unpack parsed values
read -r NUM_DICE SIDES_PER_DIE < <(parse_dice "$DICE_INPUT")

# Get username (safe for non-ASCII)
readonly USERNAME=$(id -un)

# Perform roll
read -r TOTAL ROLLS_OUTPUT < <(roll_dice "$NUM_DICE" "$SIDES_PER_DIE")

# Read rolls into array
IFS='\n' read -r -d '' -a ROLLS <<< "$ROLLS_OUTPUT"

# Generate Markdown
MARKDOWN=$(format_markdown "$USERNAME" "$DICE_INPUT" "${ROLLS[@]}" "$TOTAL")

# Send to Telegram
send_tg_message "$MARKDOWN"

# Also log to file (plain text)
printf "%s\n\n" "$MARKDOWN" >> "$LOGFILE"

log "INFO: roll=$DICE_INPUT, total=$TOTAL, user=$USERNAME"
exit 0
