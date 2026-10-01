#!/usr/bin/env bash

# ============================================================
# MARTINGALE DICE SIMULATOR - Guideline / Template
# ============================================================
# Strategy:
#   - lose -> bet x dynamic recovering multiplier (LOSEMUL)
#   - win  -> reset to BASE_BET
# ============================================================
source $HOME/.bashrc
set -u

# ─────────────────────────────────────────
# [0] HELPER COLOR
# ─────────────────────────────────────────
_wc() { cn 255 b "$@"; } #white color
_gr(){ cn 235 d "$@"; } #gray color
+c(){ cn 82 b "$@"; }  #win color
-c(){ cn 124 b "$@"; }  #lose color

# ─────────────────────────────────────────
# [1] CONFIGURATION  (flag-based args)
# ─────────────────────────────────────────
HE=1                    # house edge %
GAME_MODE=1             # 1=profit, 2=wager, 3=hybrid (wager + recovering profit)
START_BALANCE=10000
STOP_PROFIT_TARGET=2    # 2% from start balance
STOP_LOSS_TARGET=10     # 10% from start balance

# --- profit mode defaults ---
BASE_BET=1
WIN_CHANCE=0.99
MAX_ROUNDS=2000
MAX_LOSS_STREAK=1000
STOP_ON_WIN=50
STOP_BALANCE=
BET_STRATEGY="high"     # "low" or "high"

# --- wager mode defaults ---
LOSS_TRIGGER=5          # % balance drop to switch to recovery
PROFIT_TRIGGER=1        # % profit above start balance to switch back to wager
WAGER_BET="2.5"         # 2.5% of start balance
WAGER_WIN_CHANCE=98
WAGER_TARGET=100
WAGER_STOP_ON_WIN=50
WAGER_BET_STRATEGY="high"

# --- flag parser ---
_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "  -m  | --mode           Game mode: 1(profit), 2(wager), 3(hybrid) (default: 1)"
    echo "  -b  | --basebet        Base bet amount          (default: 1)"
    echo "  -c  | --chance         Win chance %             (default: 0.99)"
    echo "  -sb | --startbalance   Starting balance         (default: 10000)"
    echo "  -r  | --rounds         Max rounds               (default: 2000)"
    echo "  -ml | --maxloss        Max loss streak          (default: 1000)"
    echo "  -sw | --stop-win       Stop profit target       (default: auto calculated)"
    echo "  -sl | --stop-wagered   Wager limit target       (default: 100)"
    echo "  -ow | --on-win         Stop after N wins        (default: 50)"
    echo "  -s  | --strategy       Bet strategy low|high    (default: high)"
    echo "  -h  | --help           Show this help"
    exit 0
}

CLI_STOP_PROFIT=""
CLI_WAGER_TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)           GAME_MODE="$2";          shift 2 ;;
        -b|--basebet)        BASE_BET="$2";           shift 2 ;;
        -c|--chance)         WIN_CHANCE="$2";         shift 2 ;;
        -sb|--startbalance)  START_BALANCE="$2";      shift 2 ;;
        -r|--rounds)         MAX_ROUNDS="$2";         shift 2 ;;
        -ml|--maxloss)       MAX_LOSS_STREAK="$2";    shift 2 ;;
        -sw|--stop-win)      CLI_STOP_PROFIT="$2";    shift 2 ;;
        -sl|--stop-wagered)  CLI_WAGER_TARGET="$2";   shift 2 ;;
        -ow|--on-win)        STOP_ON_WIN="$2";        shift 2 ;;
        -s|--strategy)       BET_STRATEGY="$2";       shift 2 ;;
        -h|--help)           _usage ;;
        *) echo "Unknown flag: $1" >&2; _usage ;;
    esac
done

bet_target="$BET_STRATEGY"

# Dynamic targets calculation based on real START_BALANCE
if [[ -n "$CLI_STOP_PROFIT" ]]; then
    STOP_PROFIT="$CLI_STOP_PROFIT"
else
    STOP_PROFIT=$(mth "($STOP_PROFIT_TARGET/100)*$START_BALANCE" 8 d)
fi

if [[ -n "$CLI_WAGER_TARGET" ]]; then
    WAGER_TARGET="$CLI_WAGER_TARGET"
fi

STOP_LOSS=$(mth "($STOP_LOSS_TARGET/100)*$START_BALANCE" 8 d)
WAGER_BASE_BET=$(mth "($WAGER_BET/100)*$START_BALANCE" 8 d)

TRIGGER_BALANCE=$(mth "(1-($LOSS_TRIGGER/100))*$START_BALANCE" 8 d)
TRIGGER_BALANCE_PROFIT=$(mth "$START_BALANCE+($PROFIT_TRIGGER/100)*$START_BALANCE" 8 d)

# Payout multiplier: (1 - HE/100) / (WIN_CHANCE/100)
payout=$(mth "(1-($HE/100))/($WIN_CHANCE/100)" 4 d)

# Multiplier for Martingale recovery:
LOSEMUL=$(mth "1 + (1 / ($payout - 1)) + (0.05 / $payout)" 4 d)

# ─────────────────────────────────────────
# [2] GLOBAL STATE
# ─────────────────────────────────────────
threshold_low=$(mth "$WIN_CHANCE*100" 0 d)
threshold_high=$(mth "(100-$WIN_CHANCE)*100" 0 d)
balance=$START_BALANCE
wagered=0
total_profit=0
round=0
win_count=0
win_streak=0
lose_count=0
loss_streak=0
max_loss_streak=0
last_roll=0

# Initial Mode & Initial Bet
if [[ "$GAME_MODE" == "2" ]]; then
    MODE="WAGER"
    nextbet=$WAGER_BASE_BET
elif [[ "$GAME_MODE" == "3" ]]; then
    MODE="WAGER"
    nextbet=$WAGER_BASE_BET
else
    MODE="PROFIT"
    nextbet=$BASE_BET
fi

rare_number9900x=0
rare_number4950x=0
rare_number3300x=0
rare_number2475x=0
rare_number1980x=0
rare_number1650x=0
rare_number1414x=0
rare_number1237x=0
rare_number1100x=0
rare_number990x=0
wrong_side=0

# ─────────────────────────────────────────
# [3] MATH HELPERS
# ─────────────────────────────────────────
fadd() {
    mth "$1+$2" 8 d
}

fsub() {
    mth "$1-$2" 8 d
}

fmul() {
    mth "$1*$2" 8 d
}

float_div() {
    mth "$1/$2" 8 d
}

fgt() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'
}

fgte() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
}

# ─────────────────────────────────────────
# [4] ROLL DICE
# ─────────────────────────────────────────
roll_dice() {
    local roll
    roll=$(( RANDOM % 10000 ))
    last_roll="$roll"

    if [[ "$bet_target" == "low" ]]; then
        if (( roll < threshold_low )); then
            result="win"
        else
            result="lose"
            (( roll >= threshold_high )) && (( wrong_side++ ))
        fi
    else # bet_target == "high"
        if (( roll >= threshold_high )); then
            result="win"
        else
            result="lose"
            (( roll < threshold_low )) && (( wrong_side++ ))
        fi
    fi
}

# ─────────────────────────────────────────
# [5] MODES LOGIC
# ─────────────────────────────────────────
profit_mode() {
    local result="$1"   # win | lose
    local bet="$2"      # bet amount this round

    if [[ "$result" == "win" ]]; then
        win_amount=$(fmul "$bet" "$payout")
        balance=$(fadd "$balance" "$win_amount")
        net_profit=$(fsub "$win_amount" "$bet")
        total_profit=$(fsub "$balance" "$START_BALANCE")
        nextbet=$BASE_BET
        loss_streak=0
        ((win_count++))
        ((win_streak++))
    else
        balance=$(fsub "$balance" "$bet")
        nextbet=$(fmul "$bet" "$LOSEMUL")
        total_profit=$(fsub "$balance" "$START_BALANCE")
        win_streak=0
        ((loss_streak++))
        ((lose_count++))

        if (( loss_streak > max_loss_streak )); then
            max_loss_streak=$loss_streak
        fi
    fi
}

wagering_mode() {
    local result="$1"   # win | lose
    local bet="$2"      # bet amount this round

    if [[ "$result" == "win" ]]; then
        win_amount=$(fmul "$bet" "$payout")
        balance=$(fadd "$balance" "$win_amount")
        net_profit=$(fsub "$win_amount" "$bet")
        total_profit=$(fsub "$balance" "$START_BALANCE")
        nextbet=$WAGER_BASE_BET
        loss_streak=0
        ((win_count++))
        ((win_streak++))
    else
        balance=$(fsub "$balance" "$bet")
        nextbet=$WAGER_BASE_BET
        total_profit=$(fsub "$balance" "$START_BALANCE")
        win_streak=0
        ((loss_streak++))
        ((lose_count++))

        if (( loss_streak > max_loss_streak )); then
            max_loss_streak=$loss_streak
        fi
    fi
}

dobet() {
    local res="$1"
    local bet="$2"

    if [[ "$GAME_MODE" == "1" ]]; then
        MODE="PROFIT"
        profit_mode "$res" "$bet"

    elif [[ "$GAME_MODE" == "2" ]]; then
        MODE="WAGER"
        wagering_mode "$res" "$bet"

    elif [[ "$GAME_MODE" == "3" ]]; then
        # Check condition to switch state
        if fgte "$TRIGGER_BALANCE" "$balance"; then
            # Balance drop to/below trigger -> RECOVERY (PROFIT MODE)
            if [[ "$MODE" != "PROFIT" ]]; then
                MODE="PROFIT"
                nextbet=$BASE_BET
            fi
            profit_mode "$res" "$bet"

        elif fgte "$balance" "$TRIGGER_BALANCE_PROFIT"; then
            # Recovered with target profit -> BACK TO WAGER
            if [[ "$MODE" != "WAGER" ]]; then
                MODE="WAGER"
                nextbet=$WAGER_BASE_BET
            fi
            wagering_mode "$res" "$bet"

        else
            # In-between zone -> keep current mode running
            if [[ "$MODE" == "PROFIT" ]]; then
                profit_mode "$res" "$bet"
            else
                MODE="WAGER"
                wagering_mode "$res" "$bet"
            fi
        fi
    fi
}

# ─────────────────────────────────────────
# [6] STOP CONDITIONS
# ─────────────────────────────────────────
stop_condition() {
    # (a) balance depleted
    if ! fgt "$balance" 0; then
        echo "BUST: balance depleted"
        return 0
    fi
    # (b) loss streak exceeded limit
    if (( loss_streak >= MAX_LOSS_STREAK )); then
        echo "MAX_STREAK: $loss_streak consecutive losses"
        return 0
    fi
    # (c) next bet > balance
    if fgt "$nextbet" "$balance"; then
        echo "BET_GT_BAL: bet=$nextbet balance=$balance"
        return 0
    fi

    # (d) profit target reached
    if fgte "$total_profit" "$STOP_PROFIT"; then
        echo "PROFIT REACHED: $STOP_PROFIT"
        return 0
    fi

    # (e) wager target reached
    if fgte "$wagered" "$WAGER_TARGET"; then
        echo "WAGER REACHED: $WAGER_TARGET"
        return 0
    fi

    return 1
}

# ─────────────────────────────────────────
# [7] PRINT ROUND
# ─────────────────────────────────────────
print_round() {
    local roll="$1"
    local result="$2"
    local bet="$3"
    local total_profit="$4"
    local current_mode="$5"
    local icon r_fmt roll_fmt bal_fmt stk_fmt roll_c mode_badge

    printf -v r_fmt    "%3d"    "$round"
    printf -v roll_fmt "%4d"    "$roll"
    printf -v bal_fmt  "%13.8f" "$balance"
    printf -v stk_fmt  "%2d"    "$loss_streak"

    # Color balance based on start balance
    if fgt "$START_BALANCE" "$balance"; then
        local bal_c=$(cn 124 b "$bal_fmt")
    else
        local bal_c=$(cn 28 b "$bal_fmt")
    fi

    # Highlight wrong side rolls
    if [[ "$bet_target" == "low" ]] && (( roll >= threshold_high )); then
        roll_c="$(cn 45 b "$roll_fmt")"
    elif [[ "$bet_target" == "high" ]] && (( roll < threshold_low )); then
        roll_c="$(cn 45 b "$roll_fmt")"
    else
        roll_c="$(cn 245 d "$roll_fmt")"
    fi

    # Mode Badge
    if [[ "$current_mode" == "PROFIT" ]]; then
        mode_badge="$(cn 208 b "PROFIT")"
    else
        mode_badge="$(cn 75 b "WAGER ")"
    fi

    if [[ "$result" == "win" ]]; then
        icon="$(+c "WIN ")"
    else
        icon="$(-c "LOSS")"
    fi

    # Print based on Mode Purpose
    if [[ "$current_mode" == "WAGER" ]]; then
        # WAGER MODE: Focus on Wager progress % and balance impact
        local pct=$(mth "($wagered/$WAGER_TARGET)*100" 1 d)
        printf -v w_fmt "%8.2f/%-8.2f (%5.1f%%)" "$wagered" "$WAGER_TARGET" "$pct"
        local w_c=$(cn 141 b "$w_fmt")

        if [[ "$result" == "win" ]]; then
            printf "[%s] | %s | R:%s | %s | Wager: %s | Bal: %s\n" \
                "$r_fmt" "$mode_badge" "$roll_c" "$icon" "$w_c" "$bal_c"
        else
            printf "[%s] | %s | R:%s | %s | Wager: %s | Bal: %s | Stk:%s\n" \
                "$r_fmt" "$mode_badge" "$roll_c" "$icon" "$w_c" "$bal_c" "$stk_fmt"
        fi
    else
        # PROFIT MODE: Focus on PnL, Bet size, Martingale streak
        if [[ "$result" == "win" ]]; then
            printf -v amt_fmt "%12.8f" "$win_amount"
            local amt_c="$(+c "+$amt_fmt")"
            local profit_c="$(+c "+$total_profit")"
            printf "[%s] | %s | R:%s | %s | Won:%s | PnL:%s | Bal:%s\n" \
                "$r_fmt" "$mode_badge" "$roll_c" "$icon" "$amt_c" "$profit_c" "$bal_c"
        else
            printf -v amt_fmt "%12.8f" "$bet"
            local amt_c="$amt_fmt"
            local profit_c
            if fgt "0" "$total_profit"; then
                profit_c="$(-c "$total_profit")"
            else
                profit_c="$(_gr "$total_profit")"
            fi
            printf "[%s] | %s | R:%s | %s | Bet:%s | PnL:%s | Bal:%s | Stk:%s\n" \
                "$r_fmt" "$mode_badge" "$roll_c" "$icon" "$amt_c" "$profit_c" "$bal_c" "$stk_fmt"
        fi
    fi
}

# ─────────────────────────────────────────
# [7.1] RARE NUMBER HUNT
# ─────────────────────────────────────────
hunting() {
    local last_roll="$1"
    if (( last_roll == 9999 || last_roll == 0 )); then
        (( rare_number9900x++ ))
    elif (( last_roll == 9998 || last_roll == 1 )); then
        (( rare_number4950x++ ))
    elif (( last_roll == 9997 || last_roll == 2 )); then
        (( rare_number3300x++ ))
    elif (( last_roll == 9996 || last_roll == 3 )); then
        (( rare_number2475x++ ))
    elif (( last_roll == 9995 || last_roll == 4 )); then
        (( rare_number1980x++ ))
    elif (( last_roll == 9994 || last_roll == 5 )); then
        (( rare_number1650x++ ))
    elif (( last_roll == 9993 || last_roll == 6 )); then
        (( rare_number1414x++ ))
    elif (( last_roll == 9992 || last_roll == 7 )); then
        (( rare_number1237x++ ))
    elif (( last_roll == 9991 || last_roll == 8 )); then
        (( rare_number1100x++ ))
    elif (( last_roll == 9990 || last_roll == 9 )); then
        (( rare_number990x++ ))
    fi
}

# ─────────────────────────────────────────
# [8] MAIN LOOP
# ─────────────────────────────────────────
cn 136 b "=========================================================================="
cn 255 b "  DICE SIMULATOR - MULTI MODE ENGINE"
cn 136 b "=========================================================================="
printf " Mode: %s | Bal: %.8f | Base: %.8f | WagerBet: %.8f | WC: %.2f%%\n" \
    "$MODE" "$START_BALANCE" "$BASE_BET" "$WAGER_BASE_BET" "$WIN_CHANCE"
printf " StopProfit: +%.8f | WagerTarget: %.2f | LossTrigger: -%s%%\n" \
    "$STOP_PROFIT" "$WAGER_TARGET" "$LOSS_TRIGGER"
cn 136 b "=========================================================================="

stop_reason=""

while (( round < MAX_ROUNDS )); do
    if (( win_count >= STOP_ON_WIN )); then
        stop_reason="WIN LIMIT: reached $STOP_ON_WIN wins"
        break
    fi

    # Check stop conditions
    if stop_reason=$(stop_condition); then
        break
    fi

    ((round++))

    # Freeze current round bet and mode
    current_bet="$nextbet"
    round_mode="$MODE"

    wagered=$(fadd "$wagered" "$current_bet")

    # --- roll dice ---
    roll_dice

    # --- dobet logic ---
    dobet "$result" "$current_bet"

    # --- hunting ---
    hunting "$last_roll"

    # --- print round ---
    print_round "$last_roll" "$result" "$current_bet" "$total_profit" "$round_mode"
done

# ─────────────────────────────────────────
# [9] SESSION SUMMARY
# ─────────────────────────────────────────
if fgt "$total_profit" "0"; then
    profit_c="$(+c "+$total_profit")"
    bal_c="$(+c "$balance")"
elif fgt "0" "$total_profit"; then
    profit_c="$(-c "$total_profit")"
    bal_c="$(-c "$balance")"
else
    profit_c="$(_gr "$total_profit")"
    bal_c="$(_gr "$balance")"
fi
wagered_c="$(cn 245 b "$wagered")"

echo ""
cn 136 b "=========================================================================="
cn 255 b "  SESSION SUMMARY"
cn 136 b "=========================================================================="
printf "  $(_wc 'Rounds'): %d  $(+c 'W'): %d  $(-c 'L'): %d  $(_wc 'MaxStreak'): %d\n" \
    "$round" "$win_count" "$lose_count" "$max_loss_streak"

printf "  $(_wc 'Final Balance'): %s\n" "$bal_c"
printf "  $(_wc 'Net PnL'): %s\n" "$profit_c"
printf "  $(_wc 'Wagered'): %s / %.2f\n" "$wagered_c" "$WAGER_TARGET"

if fgt "$balance" "$START_BALANCE"; then
    +c "  Result: PROFIT"
elif fgt "$START_BALANCE" "$balance"; then
    -c "  Result: LOSS"
else
    _gr "  Result: BREAK EVEN"
fi

[[ -n "$stop_reason" ]] && cn 45 b "  Stop Reason: $stop_reason"
cn 136 b "=========================================================================="
printf "  $(+c "Rare Number")\n" 
cn 136 b "=========================================================================="
printf "  $(_wc "9900x"): %d\n" "$rare_number9900x"
printf "  $(_wc "4950x"): %d\n" "$rare_number4950x"
printf "  $(_wc "3300x"): %d\n" "$rare_number3300x"
printf "  $(_wc "2475x"): %d\n" "$rare_number2475x"
printf "  $(_wc "1980x"): %d\n" "$rare_number1980x"
printf "  $(_wc "1650x"): %d\n" "$rare_number1650x"
printf "  $(_wc "1414x"): %d\n" "$rare_number1414x"
printf "  $(_wc "1237x"): %d\n" "$rare_number1237x"
printf "  $(_wc "1100x"): %d\n" "$rare_number1100x"
printf "  $(_wc "990x"): %d\n" "$rare_number990x"
printf "  $(+c "wrong_side"): %d\n" "$wrong_side"
echo " "
cn 136 b "=========================================================================="