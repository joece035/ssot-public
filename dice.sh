#!/usr/bin/env bash

set -u

# ============================================================
# FUSION BOT v4.0 - Bash Simulation
# ============================================================

# ============================================================
# CONFIGURATION
# ============================================================

main_mode=1

# -----------------------------
# WAGER MODE
# -----------------------------

wager_chance=99
wager_bet_percent=4.0
loss_cut_percent=4.0
recover_profit_percent=1
wager_target=50.00
enable_wager_target=true

# -----------------------------
# PROFIT MODE
# -----------------------------

auto_chance=false
chance_min=0.5
chance_max=0.75
chance_fixed=35

random_on_win=true
random_on_lose=false

# -----------------------------
# MULTIPLIER / BASE
# -----------------------------

risk_bonus_percent=10.0
house_edge=1.0
allowed_losses=12

bethigh=true
auto_switch=true
switch_on_win=false
switch_on_lose=false

# -----------------------------
# STOP RULES
# -----------------------------

stop_profit_target=0.2
stop_loss_limit=0
stop_max_loss_streak=0

min_bet_size=0.00000001


# ============================================================
# GLOBAL VARIABLES
# ============================================================

mode="wager"

start_balance=100.00
balance="$start_balance"

session_start=$(date +%s)

total_wagered=0
win_count=0
lose_count=0

loss_streak=0
max_loss_streak=0

wager_base_bet=0
consecutive_losses_in_cycle=0

working_balance="$balance"
profit_vault=0
cycle_start_balance="$balance"
original_cycle_balance="$balance"

wager_cycle_start="$balance"
profit_cycle_start="$balance"

wager_loss_amount=0

# จำลอง previousbalance
last_balance="$balance"


# ============================================================
# UTILITY FUNCTIONS
# ============================================================

float_add() {
    awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a + b }'
}

float_sub() {
    awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a - b }'
}

float_mul() {
    awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a * b }'
}

float_div() {
    awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a / b }'
}

float_gte() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
}

float_gt() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'
}


# ============================================================
# SWITCH MODE
# ============================================================

switch_mode() {

    local new_mode="$1"

    mode="$new_mode"

    loss_streak=0
    consecutive_losses_in_cycle=0

    if [[ "$mode" == "wager" ]]; then

        echo "🟢 เข้าสู่โหมด WAGERING"

        working_balance="$balance"

        wager_cycle_start="$balance"
        wager_loss_amount=0

        wager_base_bet=$(
            float_mul \
                "$wager_cycle_start" \
                "$(float_div "$wager_bet_percent" 100)"
        )

        chance="$wager_chance"
        nextbet="$wager_base_bet"

        printf '   📍 Wager Cycle Start: %.8f\n' \
            "$wager_cycle_start"

        printf '   💰 Wager Base Bet: %.8f (%.2f%%)\n' \
            "$wager_base_bet" \
            "$wager_bet_percent"

    else

        echo "🟡 เข้าสู่ PROFIT MODE"

        profit_cycle_start="$balance"
        cycle_start_balance="$balance"

        local loss_percent

        loss_percent=$(
            float_mul \
                "$(float_div "$wager_loss_amount" "$original_cycle_balance")" \
                100
        )

        printf '   📍 Profit Cycle Start: %.8f\n' \
            "$profit_cycle_start"

        printf '   💸 Wager Loss: %.8f (%.2f%%)\n' \
            "$wager_loss_amount" \
            "$loss_percent"

        nextbet=$(
            float_mul "$profit_cycle_start" 0.01
        )

        if ! float_gte "$nextbet" "$min_bet_size"; then
            nextbet="$min_bet_size"
        fi
    fi
}


# ============================================================
# PROFIT SEPARATION
# ============================================================

separate_profit_and_reset_cycle() {

    local cycle_profit

    cycle_profit=$(
        float_sub "$balance" "$original_cycle_balance"
    )

    if float_gt "$cycle_profit" 0; then

        profit_vault=$(
            float_add "$profit_vault" "$cycle_profit"
        )

        echo "💰 ═══════════════════════════════════════"

        printf '✅ Cycle Complete! Profit: %.8f\n' \
            "$cycle_profit"

        printf '🏦 Profit Vault: %.8f (Total)\n' \
            "$profit_vault"

        printf '🔄 Reset to Original: %.8f\n' \
            "$original_cycle_balance"

        echo "💰 ═══════════════════════════════════════"

        balance="$original_cycle_balance"
        working_balance="$original_cycle_balance"

        wager_cycle_start="$original_cycle_balance"
        profit_cycle_start="$original_cycle_balance"

        total_wagered=0
        wager_loss_amount=0

        loss_streak=0
        max_loss_streak=0

        # จำลอง resetseed
        echo "♻️ Variables reset — new cycle will start fresh."

    else

        printf \
            '⚠️ Cycle ended without profit (%.8f)\n' \
            "$cycle_profit"

        working_balance="$balance"
    fi
}


# ============================================================
# INITIALIZATION
# ============================================================

echo "🎬 FUSION BOT v4.0 - Bash Simulation"

printf '💵 Start Balance: %.8f\n' "$balance"

working_balance="$balance"
cycle_start_balance="$balance"
original_cycle_balance="$balance"

switch_mode "wager"


# ============================================================
# DO BET
# ============================================================

do_bet() {

    local previous_bet="$1"
    local result="$2"

    # ----------------------------------------
    # total_wagered += previousbet
    # ----------------------------------------

    total_wagered=$(
        float_add "$total_wagered" "$previous_bet"
    )

    working_balance="$balance"


    # ========================================================
    # WIN
    # ========================================================

    if [[ "$result" == "win" ]]; then

        ((win_count++))

        loss_streak=0
        consecutive_losses_in_cycle=0

        if [[ "$mode" == "wager" ]]; then
            nextbet="$wager_base_bet"
        fi


    # ========================================================
    # LOSS
    # ========================================================

    else

        ((lose_count++))

        ((loss_streak++))
        ((consecutive_losses_in_cycle++))


        if [[ "$mode" == "wager" ]]; then

            # ----------------------------------------
            # จำลอง previousbalance
            # ----------------------------------------

            local prev_balance="$last_balance"

            local real_loss_value

            real_loss_value=$(
                float_sub \
                    "$wager_cycle_start" \
                    "$prev_balance"
            )


            local real_loss_percent

            real_loss_percent=$(
                float_mul \
                    "$(float_div \
                        "$real_loss_value" \
                        "$wager_cycle_start")" \
                    100
            )


            printf \
                '📉 Wager Loss: %.2f%% / %.2f%%\n' \
                "$real_loss_percent" \
                "$loss_cut_percent"


            # ----------------------------------------
            # TRUE LOSS DETECTION
            # ----------------------------------------

            if [[ "$main_mode" -eq 1 ]] &&
               float_gte \
                   "$real_loss_percent" \
                   "$loss_cut_percent"
            then

                wager_loss_amount="$real_loss_value"

                printf \
                    '🚨 TRUE LOSS %.2f%% (%.8f) → Switching to Profit Mode\n' \
                    "$real_loss_percent" \
                    "$wager_loss_amount"

                # clear bet queue
                nextbet=0

                switch_mode "profit"

            else

                nextbet="$wager_base_bet"

            fi


        else

            # ----------------------------------------
            # PROFIT MODE
            # ----------------------------------------

            nextbet=$(
                float_mul "$profit_cycle_start" 0.01
            )

        fi

    fi


    # ========================================================
    # UPDATE LAST BALANCE
    # ========================================================

    last_balance="$balance"


    # ========================================================
    # WAGER TARGET
    # ========================================================

    if [[ "$enable_wager_target" == true ]] &&
       float_gte "$total_wagered" "$wager_target"
    then

        echo "🎯 Wager Target reached! Stopping..."

        separate_profit_and_reset_cycle

        echo "🛑 BOT STOPPED"

        return 0
    fi
}


# ============================================================
# EXAMPLE
# ============================================================

echo
echo "===== Simulation ====="

echo "Balance : $balance"
echo "Mode    : $mode"
echo "Next Bet: $nextbet"

# ตัวอย่าง:
#
do_bet 4.00 loss
#
balance="$new_balance"
#
do_bet "$nextbet" win