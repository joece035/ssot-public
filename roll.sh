#!/usr/bin/env bash

# ============================================================
# MARTINGALE DICE SIMULATOR — Guideline / Template
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
# [1] CONFIGURATION
# ─────────────────────────────────────────
HE=1                    # house edge %
BASE_BET=${1:-1}              # base bet amount
WIN_CHANCE=${2:-0.99}        # win probability %
START_BALANCE=${3:-1000}      # starting balance
MAX_ROUNDS=${7:-2000}          # simulation rounds
MAX_LOSS_STREAK=${5:-1000}   # safety stop: max consecutive losses
BET_STRATEGY="high"      # "low" หรือ "high"
bet_target="$BET_STRATEGY"
WARGER_TARGET=${6:-1000}

# -- stop condition config
STOP_ON_WIN=5             # stop on any win
STOP_PROFIT=${4:-500}
STOP_BALANCE=


# Payout multiplier: (1 - HE/100) / (WIN_CHANCE/100)
payout=$(mth "(1-($HE/100))/($WIN_CHANCE/100)" 4 d)

# Multiplier ทบเมื่อแพ้:
# - Classic Martingale (กำไรคงที่เท่ากับไม้แรกเสมอ): 1 + (1 / (payout - 1))
# - Exponential Profit (กำไรโตตามสตรีค เช่น 5%): 1 + (1.05 / (payout - 1))
LOSEMUL=$(mth "1 + (1 / ($payout - 1))+(0.05/$payout)" 4 d)

# ─────────────────────────────────────────
# [2] GLOBAL STATE
# ─────────────────────────────────────────
threshold_low=$(mth "$WIN_CHANCE*100" 0 d)
threshold_high=$(mth "(100-$WIN_CHANCE)*100" 0 d)
balance=$START_BALANCE
nextbet=$BASE_BET
wagered=0
total_profit=0
round=0
win_count=0
win_streak=0
lose_count=0
loss_streak=0
max_loss_streak=0
last_roll=0

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
# Simulate win/lose based on WIN_CHANCE
# Returns: "<roll_value> <win|lose>"
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
            # ตรวจจับว่าถ้าแทง Low แต่ดันไปออกแต้มฝั่ง High (Wrong side)
            (( roll >= threshold_high )) && (( wrong_side++ ))
        fi
    else # bet_target == "high"
        if (( roll >= threshold_high )); then
            result="win"
        else
            result="lose"
            # ตรวจจับว่าถ้าแทง High แต่ดันไปออกแต้มฝั่ง Low (Wrong side)
            (( roll < threshold_low )) && (( wrong_side++ ))
        fi
    fi
}

# ─────────────────────────────────────────
# [5] MARTINGALE LOGIC
# ─────────────────────────────────────────
dobet() {

    local result="$1"   # win | lose
    local bet="$2"      # bet amount this round

    if [[ "$result" == "win" ]]; then
        # WIN: กำไรสุทธิ = bet * (payout - 1)
        win_amount=$(fmul "$bet" "$payout")
        balance=$(fadd "$balance" "$win_amount")
        net_profit=$(fsub "$win_amount" "$bet")
		total_profit=$(fsub "$balance" "$START_BALANCE")
        nextbet=$BASE_BET
        loss_streak=0
        ((win_count++))
		((win_streak++))
    else
        # LOSE: เสียเงินเดิมพัน, ทบเงินด้วย LOSEMUL
        
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

# ─────────────────────────────────────────
# [6] STOP CONDITIONS
# ─────────────────────────────────────────
stop_condition() {

    
    local nextbet=$nextbet
    # (a) balance หมด
    if ! fgt "$balance" 0; then
        echo "BUST: balance depleted"
        return 0
    fi
    # (b) loss streak เกิน limit
    if (( loss_streak >= MAX_LOSS_STREAK )); then
        echo "MAX_STREAK: $loss_streak consecutive losses"
        return 0
    fi
    # (c) next bet > balance (ไม่มีเงินพอเดิมพันตาต่อไป)
    if fgt "$nextbet" "$balance"; then
        echo "BET_GT_BAL: bet=$nextbet balance=$balance"
        return 0
    fi

    if fgte "$total_profit" "$STOP_PROFIT"; then
        echo "PROFIT REACHED: $STOP_PROFIT"
        return 0
    fi

    if fgte "$wagered" "$WARGER_TARGET"; then
        echo "WARGER REACHED: $WARGER_TARGET"
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
    local icon r_fmt roll_fmt amt_fmt bal_fmt stk_fmt roll_c

    # 1. Format ความกว้างตัวเลขก่อนระบายสี
    printf -v r_fmt    "%3d"   "$round"
    printf -v roll_fmt "%4d"   "$roll"
    printf -v bal_fmt  "%13.8f" "$balance"
    printf -v stk_fmt  "%2d"   "$loss_streak"
    
    if fgt "$START_BALANCE" "$balance" ; then
        local bal_c=$(cn 124 b "$bal_fmt")
    else
        local bal_c=$(cn 28 b "$bal_fmt")    
    fi

    if [[ "$result" == "win" ]]; then
        printf -v amt_fmt "%13.8f" "$win_amount"
        icon="$(+c "WIN ")"
        roll_c="$(+c "$roll_fmt")"
        local amt_c="$(+c "+$amt_fmt")"
        local profit_c="$(+c "+$total_profit")"

        # Print ออกมาด้วย %s สบายๆ ไม่เบี้ยวแน่นอน
        printf -v _data "[%s] | R: %s | %s | won:%s | $(+c "Profit:") %s\n" \
            "$r_fmt" "$roll_c" "$icon" "$amt_c" "$profit_c"
            
        printf "%s" "$_data"
    else
        printf -v amt_fmt "%10.8f" "$bet"
        icon="$(-c "LOSS")"
        local amt_c="$amt_fmt"

        # ตรวจจับ wrong side เพื่อ highlight roll number (Cyan 45)
        if [[ "$bet_target" == "low" ]] && (( roll >= threshold_high )); then
            roll_c="$(cn 45 b "$roll_fmt")"
        elif [[ "$bet_target" == "high" ]] && (( roll < threshold_low )); then
            roll_c="$(cn 45 b "$roll_fmt")"
        else
            roll_c="$(cn 245 d "$roll_fmt")"
        fi
        
        printf "[%s] | R: %s | %s | Bet: %s | Bal: %s | Stk: %s\n" \
            "$r_fmt" "$roll_c" "$icon" "$amt_c" "$bal_c" "$stk_fmt"
    fi
}

# ─────────────────────────────────────────
# [7.1] RARE NUMBER HUNT
# ─────────────────────────────────────────
hunting(){
    # 1. นับ rare number
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
cn 255 b "  MARTINGALE DICE SIMULATOR"
cn 136 b "=========================================================================="
printf " Bal: %.8f | base: %.8f | WC: %.2f%% | Payout: %.4fx | Mul: %.4fx\n " \
    "$START_BALANCE" "$BASE_BET" "$WIN_CHANCE" "$payout" "$LOSEMUL"
cn 136 b "=========================================================================="

stop_reason=""

while (( round < MAX_ROUNDS )); do
    if (( win_count >= STOP_ON_WIN )); then
        stop_reason="WIN LIMIT: reached $STOP_ON_WIN wins"
        break
    fi

    # ตรวจสอบเงื่อนไขหยุดก่อนเดิมพัน
    if stop_reason=$(stop_condition); then
        break
    fi

    ((round++))
    wagered=$(fadd "$wagered" "$nextbet")

    # --- roll dice ---
    roll_dice   # -- result stored in $result and $last_roll ---
    # --- apply martingale ---
    dobet "$result" "$nextbet"
    # --- hunting ---
    hunting "$last_roll"
    # --- print round ---
    print_round "$last_roll" "$result" "$nextbet" "$total_profit"
done

# ─────────────────────────────────────────
# [9] SESSION SUMMARY
# ─────────────────────────────────────────

# -- dynamic color --
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
printf "  $(_wc 'Wagered'): %s\n" "$wagered_c"

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
