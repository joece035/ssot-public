#!/usr/bin/env bash

# ============================================================
# MARTINGALE DICE SIMULATOR — Guideline / Template
# ============================================================
# Strategy:
#   - lose -> bet x2
#   - win  -> reset to BASE_BET
# ============================================================

set -u

# ─────────────────────────────────────────
# [1] CONFIGURATION
# ─────────────────────────────────────────

START_BALANCE=1000      # starting balance
BASE_BET=1              # base bet amount
WIN_CHANCE=49.5         # win probability %
MAX_ROUNDS=200          # simulation rounds
MAX_LOSS_STREAK=10      # safety stop: max consecutive losses

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

# ─────────────────────────────────────────
# [3] FLOAT MATH (via awk)
# ─────────────────────────────────────────

fadd() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a + b }'; }
fsub() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a - b }'; }
fmul() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a * b }'; }
fgt()  { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'; }

# ─────────────────────────────────────────
# [4] ROLL DICE
# Simulate win/lose based on WIN_CHANCE
# ─────────────────────────────────────────

roll_dice() {
    # สุ่ม 0-9999 เทียบกับ threshold
    # WIN_CHANCE=49.5  ->  threshold=4950
    # ถ้า roll < threshold = win
    local threshold
    threshold=$(awk -v c="$WIN_CHANCE" 'BEGIN { printf "%d", c * 100 }')

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
        # WIN: เพิ่ม balance, reset bet กลับ base
        balance=$(fadd "$balance" "$bet")
        current_bet=$BASE_BET
        loss_streak=0
        ((win_count++))

    else
        # LOSE: ลด balance, double bet
        balance=$(fsub "$balance" "$bet")
        current_bet=$(fmul "$current_bet" 2)
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
    # (c) next bet > balance (ไม่มีเงินพอเล่น)
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
    local result="$1"
    local bet="$2"
    local icon="WIN"
    [[ "$result" == "lose" ]] && icon="LOS"

    printf "Round %3d | %s | Bet: %10.2f | Balance: %12.2f | Streak: %d\n" \
        "$round" "$icon" "$bet" "$balance" "$loss_streak"
}

# ─────────────────────────────────────────
# [8] MAIN LOOP
# ─────────────────────────────────────────

echo "======================================"
echo "  MARTINGALE DICE SIMULATOR"
echo "======================================"
printf "  Start: %.2f | BaseBet: %.2f | Win: %.2f percent\n" \
    "$START_BALANCE" "$BASE_BET" "$WIN_CHANCE"
echo "======================================"

stop_reason=""

while (( round < MAX_ROUNDS )); do
    ((round++))

    # ตรวจ stop ก่อน bet
    if stop_reason=$(should_stop); then
        break
    fi

    # --- roll ---
    result=$(roll_dice)
    bet_this_round=$current_bet

    # --- apply martingale ---
    apply_martingale "$result" "$bet_this_round"

    # --- print ---
    print_round "$result" "$bet_this_round"
done

# ─────────────────────────────────────────
# [9] SESSION SUMMARY
# ─────────────────────────────────────────

echo
echo "======================================"
echo "  SESSION SUMMARY"
echo "======================================"
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
echo "======================================"
