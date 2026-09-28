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
# [1] CONFIGURATION
# ─────────────────────────────────────────
HE=1                    # house edge %
START_BALANCE=1000      # starting balance
BASE_BET=1              # base bet amount
WIN_CHANCE="49.5"       # win probability %
MAX_ROUNDS=200          # simulation rounds
MAX_LOSS_STREAK=10      # safety stop: max consecutive losses

# Payout multiplier: (1 - HE/100) / (WIN_CHANCE/100)
payout=$(mth "(1-($HE/100))/($WIN_CHANCE/100)" 4 d)

# Multiplier ทบเมื่อแพ้:
# - Classic Martingale (กำไรคงที่เท่ากับไม้แรกเสมอ): 1 + (1 / (payout - 1))
# - Exponential Profit (กำไรโตตามสตรีค เช่น 5%): 1 + (1.05 / (payout - 1))
LOSEMUL=$(mth "1 + (1 / ($payout - 1))" 4 d)

# ─────────────────────────────────────────
# [2] GLOBAL STATE
# ─────────────────────────────────────────
balance=$START_BALANCE
current_bet=$BASE_BET
round=0
win_count=0
lose_count=0
loss_streak=0
max_loss_streak=0
last_roll=0

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
    local threshold
    threshold=$(mth "$WIN_CHANCE*100" 0 d)

    local roll
    roll=$(( RANDOM % 10000 ))

    if (( roll < threshold )); then
        echo "$roll win"
    else
        echo "$roll lose"
    fi
}

# ─────────────────────────────────────────
# [5] MARTINGALE LOGIC
# ─────────────────────────────────────────
apply_martingale() {
    local result="$1"   # win | lose
    local bet="$2"      # bet amount this round

    if [[ "$result" == "win" ]]; then
        # WIN: กำไรสุทธิ = bet * (payout - 1)
        local net_profit
        net_profit=$(fmul "$bet" "$(fsub "$payout" 1)")
        balance=$(fadd "$balance" "$net_profit")
        current_bet=$BASE_BET
        loss_streak=0
        ((win_count++))
    else
        # LOSE: เสียเงินเดิมพัน, ทบเงินด้วย LOSEMUL
        balance=$(fsub "$balance" "$bet")
        current_bet=$(fmul "$current_bet" "$LOSEMUL")
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
should_stop() {
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
    if fgt "$current_bet" "$balance"; then
        echo "BET_GT_BAL: bet=$current_bet balance=$balance"
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
    local icon="WIN"
    [[ "$result" == "lose" ]] && icon="LOS"

    printf "Round %3d | Roll: %4d | %s | Bet: %10.2f | Balance: %12.2f | Streak: %d\n" \
        "$round" "$roll" "$icon" "$bet" "$balance" "$loss_streak"
}

# ─────────────────────────────────────────
# [8] MAIN LOOP
# ─────────────────────────────────────────
echo "=========================================================================="
echo "  MARTINGALE DICE SIMULATOR"
echo "=========================================================================="
printf "  Start: %.2f | BaseBet: %.2f | WinChance: %.2f%% | Payout: %.4fx | LoseMul: %.4fx\n" \
    "$START_BALANCE" "$BASE_BET" "$WIN_CHANCE" "$payout" "$LOSEMUL"
echo "=========================================================================="

stop_reason=""

while (( round < MAX_ROUNDS )); do
    ((round++))

    # ตรวจสอบเงื่อนไขหยุดก่อนเดิมพัน
    if stop_reason=$(should_stop); then
        break
    fi

    bet_this_round=$current_bet

    # --- roll dice ---
    read -r last_roll result <<< "$(roll_dice)"

    # --- apply martingale ---
    apply_martingale "$result" "$bet_this_round"

    # --- print round ---
    print_round "$last_roll" "$result" "$bet_this_round"
done

# ─────────────────────────────────────────
# [9] SESSION SUMMARY
# ─────────────────────────────────────────
echo
echo "=========================================================================="
echo "  SESSION SUMMARY"
echo "=========================================================================="
printf "  Rounds: %d  W: %d  L: %d  MaxStreak: %d\n" \
    "$round" "$win_count" "$lose_count" "$max_loss_streak"

profit=$(fsub "$balance" "$START_BALANCE")
printf "  Final Balance : %.8f\n" "$balance"
printf "  Net PnL       : %.8f\n" "$profit"

if fgt "$balance" "$START_BALANCE"; then
    echo "  Result: PROFIT"
elif fgt "$START_BALANCE" "$balance"; then
    echo "  Result: LOSS"
else
    echo "  Result: BREAK EVEN"
fi

[[ -n "$stop_reason" ]] && echo "  Stop Reason: $stop_reason"
echo "=========================================================================="
