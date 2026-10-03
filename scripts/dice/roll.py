#!/usr/bin/env python3
"""
DICE SIMULATOR - MULTI MODE ENGINE (Python Port)
============================================================
Supports:
  - Mode 1: Profit Mode (Martingale recovery with low win chance)
  - Mode 2: Wager Mode (High win chance, flat bet to build wager volume)
  - Mode 3: Hybrid Mode (Wager mode that switches to Profit recovery when dropped)
  - Profit Vault: Secures surplus profits upon recovery completion
  - Central Config: Reads defaults from ~/ssot/dice.env
============================================================
"""

import argparse
import math
import os
from pathlib import Path
import random
import time

# ─────────────────────────────────────────
# [0] HELPER COLOR
# ─────────────────────────────────────────
def cn(code: int, text: str, bold: bool = False) -> str:
    """Helper formatting text with ANSI 256 color code."""
    style = "1;" if bold else ""
    return f"\033[{style}38;5;{code}m{text}\033[0m"

def _wc(text: str) -> str:
    return cn(255, str(text), True)

def _gr(text: str) -> str:
    return cn(235, str(text), False)

def pos_c(text: str) -> str:
    return cn(82, str(text), True)

def neg_c(text: str) -> str:
    return cn(124, str(text), True)

# ─────────────────────────────────────────
# [0.1] LOAD SSOT CENTRAL CONFIG (dice.env)
# ─────────────────────────────────────────
def load_env_config() -> dict[str, str]:
    """Load configuration from ~/ssot/dice.env if available."""
    config: dict[str, str] = {}
    ssot_dir = os.environ.get("SSOT", os.path.expanduser("~/ssot"))
    env_path = Path(ssot_dir) / "dice.env"

    if env_path.is_file():
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, val = line.split("=", 1)
                    val = val.split("#", 1)[0].strip().strip("\"'")
                    config[key.strip()] = val
    # Allow OS environment variables to override
    for k, v in os.environ.items():
        if k in config or k.startswith("CUSTOM_"):
            config[k] = v
    return config

# ─────────────────────────────────────────
# [1] ARGUMENT PARSER
# ─────────────────────────────────────────
def parse_arguments(env_cfg: dict[str, str]):
    def cfg_get(key: str, default, cast_type=str):
        if key in env_cfg:
            try:
                return cast_type(env_cfg[key])
            except (ValueError, TypeError):
                pass
        return default

    parser = argparse.ArgumentParser(
        description="Multi-Mode Dice Simulator (Martingale / Wager / Hybrid)",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "-m", "--mode", type=int, choices=[1, 2, 3, 4],
        default=cfg_get("GAME_MODE", 3, int),
        help="Game mode: 1(profit), 2(wager), 3(hybrid), 4(custom)"
    )
    parser.add_argument(
        "-b", "--basebet", type=float,
        default=cfg_get("BASE_BET", 2.0, float),
        help="Base bet amount"
    )
    parser.add_argument(
        "-c", "--chance", type=float,
        default=cfg_get("WIN_CHANCE", 3.96, float),
        help="Win chance %% (Profit Mode)"
    )
    parser.add_argument(
        "-wc", "--wager-chance", type=float,
        default=cfg_get("WAGER_WIN_CHANCE", 98.0, float),
        help="Win chance %% (Wager Mode)"
    )
    parser.add_argument(
        "-sb", "--startbalance", type=float,
        default=cfg_get("START_BALANCE", 10000.0, float),
        help="Starting balance"
    )
    parser.add_argument(
        "-r", "--rounds", type=int,
        default=cfg_get("MAX_ROUNDS", 20000, int),
        help="Max rounds"
    )
    parser.add_argument(
        "-ml", "--maxloss", type=int,
        default=cfg_get("MAX_LOSS_STREAK", 10000, int),
        help="Max loss streak limit"
    )
    parser.add_argument(
        "-sw", "--stop-win", type=float, default=None,
        help="Stop profit target (amount)"
    )
    parser.add_argument(
        "-sl", "--stop-wagered", type=float,
        default=cfg_get("WAGER_TARGET", 200000.0, float),
        help="Wager target limit"
    )
    parser.add_argument(
        "-ow", "--on-win", type=int,
        default=cfg_get("STOP_ON_WIN", 5000, int),
        help="Stop after N wins"
    )
    parser.add_argument(
        "-s", "--strategy", type=str, choices=["low", "high"],
        default=cfg_get("BET_STRATEGY", "high", str),
        help="Bet strategy low|high"
    )
    parser.add_argument(
        "-d", "--delay", type=float, default=0.0,
        help="Delay (seconds) between rounds (e.g. 0.05)"
    )
    return parser.parse_args()

# ─────────────────────────────────────────
# [2] MAIN SIMULATION LOGIC
# ─────────────────────────────────────────
def run_simulation():
    env_cfg = load_env_config()
    args = parse_arguments(env_cfg)
    round_delay = args.delay
    game_mode = args.mode

    house_edge = float(env_cfg.get("HE", 1.0))
    start_balance = args.startbalance
    base_bet = args.basebet
    profit_win_chance = args.chance
    wager_win_chance = args.wager_chance
    max_rounds = args.rounds
    max_loss_streak_limit = args.maxloss
    wager_target = args.stop_wagered
    stop_on_win = args.on_win
    bet_target = args.strategy

    # Thresholds & triggers
    loss_trigger_pct = float(env_cfg.get("LOSS_TRIGGER", 2.0))
    profit_trigger_pct = float(env_cfg.get("PROFIT_TRIGGER", 1.0))
    wager_bet_pct = float(env_cfg.get("WAGER_BET", 2.5))
    stop_profit_target_pct = float(env_cfg.get("STOP_PROFIT_TARGET", 20.0))

    trigger_balance = (1.0 - (loss_trigger_pct / 100.0)) * start_balance
    trigger_balance_profit = start_balance + ((profit_trigger_pct / 100.0) * start_balance)

    wager_base_bet = (wager_bet_pct / 100.0) * start_balance
    stop_profit = args.stop_win if args.stop_win is not None else (stop_profit_target_pct / 100.0) * start_balance

    # Profit Mode Math
    profit_payout = (1.0 - (house_edge / 100.0)) / (profit_win_chance / 100.0)
    profit_win_mul = profit_payout - 1.0
    lose_mul = (1.0 + (1.0 / (profit_payout - 1.0)) + (0.05 / profit_payout)) if (profit_payout > 1.0) else 2.0
    profit_t_low = int(profit_win_chance * 100)
    profit_t_high = int((100 - profit_win_chance) * 100)

    # Wager Mode Math
    wager_payout = (1.0 - (house_edge / 100.0)) / (wager_win_chance / 100.0)
    wager_win_mul = wager_payout - 1.0
    wager_t_low = int(wager_win_chance * 100)
    wager_t_high = int((100 - wager_win_chance) * 100)

    # Mode 4 (Custom Strategy) Configurations
    c_base_bet = float(env_cfg.get("CUSTOM_BASE_BET", 0.000081))
    c_win_chance = float(env_cfg.get("CUSTOM_WIN_CHANCE", 49.50))
    c_bet_target = str(env_cfg.get("CUSTOM_BET_TARGET", "high")).strip().lower()

    c_loss_mul = float(env_cfg.get("CUSTOM_LOSS_MUL", 2.0))
    c_loss_mul_every = int(env_cfg.get("CUSTOM_LOSS_MUL_EVERY", 1))
    c_loss_reset_first = int(env_cfg.get("CUSTOM_LOSS_RESET_FIRST", 0))
    c_loss_chg_bet_streak = int(env_cfg.get("CUSTOM_LOSS_CHANGE_BET_STREAK", 0))
    c_loss_chg_bet_val = float(env_cfg.get("CUSTOM_LOSS_CHANGE_BET_VALUE", 0.0))
    c_loss_chg_chance_streak = int(env_cfg.get("CUSTOM_LOSS_CHANGE_CHANCE_STREAK", 0))
    c_loss_chg_chance_val = float(env_cfg.get("CUSTOM_LOSS_CHANGE_CHANCE_VALUE", 0.0))

    c_win_mul = float(env_cfg.get("CUSTOM_WIN_MUL", 1.0))
    c_win_reset_base = int(env_cfg.get("CUSTOM_WIN_RESET_BASE", 1))

    c_rst_after_bets = int(env_cfg.get("CUSTOM_RESET_AFTER_BETS", 0))
    c_rst_loss_streak = int(env_cfg.get("CUSTOM_RESET_ON_LOSS_STREAK", 0))
    c_rst_loss_tot_every = int(env_cfg.get("CUSTOM_RESET_ON_LOSS_TOTAL_EVERY", 0))
    c_rst_loss_val_row = float(env_cfg.get("CUSTOM_RESET_ON_LOSS_VALUE_ROW", 0.0))
    c_rst_loss_val_tot_every = float(env_cfg.get("CUSTOM_RESET_ON_LOSS_VALUE_TOTAL_EVERY", 0.0))
    c_rst_loss_since_max_p = float(env_cfg.get("CUSTOM_RESET_ON_LOSS_SINCE_MAX_PROFIT", 0.0))

    c_rst_win_streak = int(env_cfg.get("CUSTOM_RESET_ON_WIN_STREAK", 0))
    c_rst_win_tot_every = int(env_cfg.get("CUSTOM_RESET_ON_WIN_TOTAL_EVERY", 0))
    c_rst_win_val_row = float(env_cfg.get("CUSTOM_RESET_ON_WIN_VALUE_ROW", 0.0))
    c_rst_win_val_tot_every = float(env_cfg.get("CUSTOM_RESET_ON_WIN_VALUE_TOTAL_EVERY", 0.0))
    c_rst_win_since_min_p = float(env_cfg.get("CUSTOM_RESET_ON_WIN_SINCE_MIN_PROFIT", 0.0))

    c_stp_after_bets = int(env_cfg.get("CUSTOM_STOP_AFTER_BETS", 0))
    c_stp_loss_streak = int(env_cfg.get("CUSTOM_STOP_ON_LOSS_STREAK", 0))
    c_stp_loss_tot = int(env_cfg.get("CUSTOM_STOP_ON_LOSS_TOTAL", 0))
    c_stp_loss_val_row = float(env_cfg.get("CUSTOM_STOP_ON_LOSS_VALUE_ROW", 0.0))
    c_stp_loss_val_tot = float(env_cfg.get("CUSTOM_STOP_ON_LOSS_VALUE_TOTAL", 0.0))
    c_stp_loss_since_max_p = float(env_cfg.get("CUSTOM_STOP_ON_LOSS_SINCE_MAX_PROFIT", 0.0))

    c_stp_win_streak = int(env_cfg.get("CUSTOM_STOP_ON_WIN_STREAK", 0))
    c_stp_win_tot = int(env_cfg.get("CUSTOM_STOP_ON_WIN_TOTAL", 0))
    c_stp_win_val_row = float(env_cfg.get("CUSTOM_STOP_ON_WIN_VALUE_ROW", 0.0))
    c_stp_win_val_tot = float(env_cfg.get("CUSTOM_STOP_ON_WIN_VALUE_TOTAL", 0.0))
    c_stp_win_since_min_p = float(env_cfg.get("CUSTOM_STOP_ON_WIN_SINCE_MIN_PROFIT", 0.0))

    c_upper_limit_bal = float(env_cfg.get("CUSTOM_UPPER_LIMIT_BALANCE", 0.0))
    c_lower_limit_bal = float(env_cfg.get("CUSTOM_LOWER_LIMIT_BALANCE", 0.0))
    c_min_bet = float(env_cfg.get("CUSTOM_MIN_BET", 0.0))
    c_max_bet = float(env_cfg.get("CUSTOM_MAX_BET", 0.0))
    c_zigzag_every = int(env_cfg.get("CUSTOM_ZIGZAG_EVERY", 0))
    c_bets_per_sec = float(env_cfg.get("CUSTOM_BETS_PER_SEC", 0.0))
    if round_delay == 0.0 and c_bets_per_sec > 0:
        round_delay = 1.0 / c_bets_per_sec

    # State variables
    balance = start_balance
    profit_vault = 0.0          # Vault for securing recovered profit
    wagered = 0.0
    total_profit = 0.0
    round_num = 0
    win_count = 0
    win_streak = 0
    lose_count = 0
    loss_streak = 0
    max_loss_streak = 0
    wrong_side = 0
    win_history: list[tuple[float, int, str]] = []

    # Custom Mode Runtime State
    custom_current_chance = c_win_chance
    active_bet_target = c_bet_target if game_mode == 4 else bet_target
    max_profit = 0.0
    min_profit = 0.0
    loss_value_streak = 0.0
    total_loss_value = 0.0
    win_value_streak = 0.0
    total_win_value = 0.0
    zigzag_count = 0
    loss_since_last_mul = 0

    if game_mode == 2:
        current_mode = "WAGER"
        nextbet = wager_base_bet
    elif game_mode == 3:
        current_mode = "WAGER"
        nextbet = wager_base_bet
    elif game_mode == 4:
        current_mode = "CUSTOM"
        nextbet = c_base_bet
    else:
        current_mode = "PROFIT"
        nextbet = base_bet

    rare_counts = {
        "9900x": 0, "4950x": 0, "3300x": 0, "2475x": 0, "1980x": 0,
        "1650x": 0, "1414x": 0, "1237x": 0, "1100x": 0, "990x": 0
    }

    def check_rare_number(roll: int):
        if roll in (9999, 0): rare_counts["9900x"] += 1
        elif roll in (9998, 1): rare_counts["4950x"] += 1
        elif roll in (9997, 2): rare_counts["3300x"] += 1
        elif roll in (9996, 3): rare_counts["2475x"] += 1
        elif roll in (9995, 4): rare_counts["1980x"] += 1
        elif roll in (9994, 5): rare_counts["1650x"] += 1
        elif roll in (9993, 6): rare_counts["1414x"] += 1
        elif roll in (9992, 7): rare_counts["1237x"] += 1
        elif roll in (9991, 8): rare_counts["1100x"] += 1
        elif roll in (9990, 9): rare_counts["990x"] += 1

    def roll_dice(mode: str):
        nonlocal wrong_side
        roll = random.randint(0, 9999)

        if mode == "CUSTOM":
            t_low = int(custom_current_chance * 100)
            t_high = int((100.0 - custom_current_chance) * 100)
            cur_target = active_bet_target
        elif mode == "WAGER":
            t_low, t_high = wager_t_low, wager_t_high
            cur_target = bet_target
        else:
            t_low, t_high = profit_t_low, profit_t_high
            cur_target = bet_target

        if cur_target == "low":
            if roll < t_low:
                result = "win"
            else:
                result = "lose"
                if roll >= t_high:
                    wrong_side += 1
        else:  # cur_target == "high"
            if roll >= t_high:
                result = "win"
            else:
                result = "lose"
                if roll < t_low:
                    wrong_side += 1

        return roll, result

    def check_stop_condition(current_nextbet: float) -> str:
        if balance <= 0:
            return "BUST: balance depleted"
        if loss_streak >= max_loss_streak_limit:
            return f"MAX_STREAK: {loss_streak} consecutive losses"
        if current_nextbet > balance:
            return f"BET_GT_BAL: bet={current_nextbet:.8f} balance={balance:.8f}"

        if game_mode == 4:
            if c_upper_limit_bal > 0 and balance >= c_upper_limit_bal:
                return f"UPPER LIMIT: balance={balance:.8f} >= {c_upper_limit_bal:.8f}"
            if c_lower_limit_bal > 0 and balance <= c_lower_limit_bal:
                return f"LOWER LIMIT: balance={balance:.8f} <= {c_lower_limit_bal:.8f}"
            if c_stp_after_bets > 0 and round_num >= c_stp_after_bets:
                return f"STOP AFTER BETS: reached {c_stp_after_bets} bets"
            if c_stp_loss_streak > 0 and loss_streak >= c_stp_loss_streak:
                return f"STOP ON LOSS STREAK: {loss_streak} losses in a row"
            if c_stp_loss_tot > 0 and lose_count >= c_stp_loss_tot:
                return f"STOP ON TOTAL LOSSES: {lose_count} losses"
            if c_stp_loss_val_row > 0 and loss_value_streak >= c_stp_loss_val_row:
                return f"STOP ON VALUE LOST IN A ROW: {loss_value_streak:.8f}"
            if c_stp_loss_val_tot > 0 and total_loss_value >= c_stp_loss_val_tot:
                return f"STOP ON TOTAL VALUE LOST: {total_loss_value:.8f}"
            if c_stp_loss_since_max_p > 0 and (max_profit - total_profit) >= c_stp_loss_since_max_p:
                return f"STOP ON LOSS SINCE MAX PROFIT: {(max_profit - total_profit):.8f}"
            if c_stp_win_streak > 0 and win_streak >= c_stp_win_streak:
                return f"STOP ON WIN STREAK: {win_streak} wins in a row"
            if c_stp_win_tot > 0 and win_count >= c_stp_win_tot:
                return f"STOP ON TOTAL WINS: {win_count} wins"
            if c_stp_win_val_row > 0 and win_value_streak >= c_stp_win_val_row:
                return f"STOP ON VALUE WON IN A ROW: {win_value_streak:.8f}"
            if c_stp_win_val_tot > 0 and total_win_value >= c_stp_win_val_tot:
                return f"STOP ON TOTAL VALUE WON: {total_win_value:.8f}"
            if c_stp_win_since_min_p > 0 and (total_profit - min_profit) >= c_stp_win_since_min_p:
                return f"STOP ON WIN SINCE MIN PROFIT: {(total_profit - min_profit):.8f}"
        else:
            if total_profit >= stop_profit:
                return f"PROFIT REACHED: {stop_profit:.8f}"
            if wagered >= wager_target:
                return f"WAGER REACHED: {wager_target:.2f}"
        return ""

    def print_round(r_num: int, roll: int, result: str, bet: float, mode_played: str, win_amt: float):
        r_fmt = f"{r_num:3d}"
        roll_fmt = f"{roll:4d}"
        bal_fmt = f"{balance:13.8f}"
        stk_fmt = f"{loss_streak:2d}"

        bal_c = neg_c(bal_fmt) if start_balance > balance else cn(28, bal_fmt, True)

        if mode_played == "CUSTOM":
            active_high = int((100.0 - custom_current_chance) * 100)
            active_low = int(custom_current_chance * 100)
            cur_target = active_bet_target
        elif mode_played == "WAGER":
            active_high = wager_t_high
            active_low = wager_t_low
            cur_target = bet_target
        else:
            active_high = profit_t_high
            active_low = profit_t_low
            cur_target = bet_target

        if (cur_target == "low" and roll >= active_high) or (cur_target == "high" and roll < active_low):
            roll_c = cn(45, roll_fmt, True)
        else:
            roll_c = cn(245, roll_fmt, False)

        if mode_played == "CUSTOM":
            mode_badge = cn(39, "CUSTOM", True)
        elif mode_played == "PROFIT":
            mode_badge = cn(208, "PROFIT", True)
        else:
            mode_badge = cn(75, "WAGER ", True)

        icon = pos_c("WIN ") if result == "win" else neg_c("LOSS")

        if mode_played == "WAGER":
            pct = (wagered / wager_target) * 100.0 if wager_target > 0 else 0.0
            w_fmt = f"{wagered:8.2f}/{wager_target:<8.2f} ({pct:5.1f}%)"
            w_c = cn(141, w_fmt, True)

            if result == "win":
                win_str = pos_c(f"+{win_amt:10.8f}")
                print(f"[{r_fmt}] | {mode_badge} | R:{roll_c} | {icon} | Wager:{w_c} | Won:{win_str} | Bal:{bal_c}")
            else:
                print(f"[{r_fmt}] | {mode_badge} | R:{roll_c} | {icon} | Wager:{w_c} | Bal:{bal_c} | Stk:{stk_fmt}")
        else:
            if result == "win":
                amt_c = pos_c(f"+{win_amt:12.8f}")
                pnl_c = pos_c(f"+{total_profit:12.8f}")
                print(f"[{r_fmt}] | {mode_badge} | R:{roll_c} | {icon} | Won:{amt_c} | PnL:{pnl_c} | Bal:{bal_c}")
            else:
                amt_c = f"{bet:12.8f}"
                pnl_c = neg_c(f"{total_profit:12.8f}") if total_profit < 0 else _gr(f"{total_profit:12.8f}")
                print(f"[{r_fmt}] | {mode_badge} | R:{roll_c} | {icon} | Bet:{amt_c} | PnL:{pnl_c} | Bal:{bal_c} | Stk:{stk_fmt}")

    # Header
    print(cn(136, "=" * 74))
    print(cn(255, "  DICE SIMULATOR - MULTI MODE ENGINE (Python)"))
    print(cn(136, "=" * 74))
    if current_mode == "CUSTOM":
        print(f" Mode: CUSTOM | Bal: {start_balance:.8f} | Base: {c_base_bet:.8f} | Chance: {c_win_chance:.2f}% | Target: {active_bet_target.upper()}")
        print(f" LossMul: {c_loss_mul:.2f}x (every {c_loss_mul_every}) | WinMul: {c_win_mul:.2f}x (resetBase={bool(c_win_reset_base)})")
        print(f" ZigZag: every {c_zigzag_every} bets | Limits: MinBet={c_min_bet:.8f} MaxBet={c_max_bet:.8f}")
    else:
        print(f" Mode: {current_mode} | Bal: {start_balance:.8f} | Base: {base_bet:.8f} | WagerBet: {wager_base_bet:.8f}")
        print(f" ProfitWC: {profit_win_chance:.2f}% ({profit_payout:.4f}x) | WagerWC: {wager_win_chance:.2f}% ({wager_payout:.4f}x)")
        print(f" StopProfit: +{stop_profit:.8f} | WagerTarget: {wager_target:.2f} | LossTrigger: -{loss_trigger_pct:.1f}% (<={trigger_balance:.2f})")
    print(cn(136, "=" * 74))

    stop_reason = ""

    # Main Loop
    while round_num < max_rounds:
        if win_count >= stop_on_win:
            stop_reason = f"WIN LIMIT: reached {stop_on_win} wins"
            break

        stop_reason = check_stop_condition(nextbet)
        if stop_reason:
            break

        round_num += 1
        current_bet = nextbet
        round_mode = current_mode

        wagered += current_bet

        last_roll, result = roll_dice(round_mode)

        # Settle Math
        win_amount = 0.0
        if round_mode == "CUSTOM":
            c_payout = (1.0 - (house_edge / 100.0)) / (custom_current_chance / 100.0)
            c_win_multiplier = c_payout - 1.0
            if result == "win":
                win_amount = current_bet * c_win_multiplier
                balance += win_amount
                total_profit = balance - start_balance
                max_profit = max(max_profit, total_profit)
                min_profit = min(min_profit, total_profit)

                win_count += 1
                win_streak += 1
                loss_streak = 0
                loss_value_streak = 0.0
                win_value_streak += win_amount
                total_win_value += win_amount
                loss_since_last_mul = 0
                custom_current_chance = c_win_chance  # Reset dynamic chance

                if c_win_reset_base == 1:
                    nextbet = c_base_bet
                else:
                    nextbet = current_bet * c_win_mul

                # On Win Reset Triggers
                if c_rst_win_streak > 0 and win_streak % c_rst_win_streak == 0:
                    nextbet = c_base_bet
                if c_rst_win_tot_every > 0 and win_count % c_rst_win_tot_every == 0:
                    nextbet = c_base_bet
                if c_rst_win_val_row > 0 and win_value_streak >= c_rst_win_val_row:
                    nextbet = c_base_bet
                    win_value_streak = 0.0
                if c_rst_win_val_tot_every > 0 and total_win_value >= c_rst_win_val_tot_every:
                    nextbet = c_base_bet
                if c_rst_win_since_min_p > 0 and (total_profit - min_profit) >= c_rst_win_since_min_p:
                    nextbet = c_base_bet
            else:
                balance -= current_bet
                total_profit = balance - start_balance
                max_profit = max(max_profit, total_profit)
                min_profit = min(min_profit, total_profit)

                win_streak = 0
                win_value_streak = 0.0
                loss_streak += 1
                lose_count += 1
                loss_value_streak += current_bet
                total_loss_value += current_bet
                loss_since_last_mul += 1
                if loss_streak > max_loss_streak:
                    max_loss_streak = loss_streak

                # Multiplier calculation
                if c_loss_reset_first == 1 and loss_streak == 1:
                    nextbet = c_base_bet
                elif loss_since_last_mul >= c_loss_mul_every:
                    nextbet = current_bet * c_loss_mul
                    loss_since_last_mul = 0
                else:
                    nextbet = current_bet

                # Dynamic changes after streak
                if c_loss_chg_bet_streak > 0 and loss_streak >= c_loss_chg_bet_streak:
                    nextbet = c_loss_chg_bet_val
                if c_loss_chg_chance_streak > 0 and loss_streak >= c_loss_chg_chance_streak:
                    custom_current_chance = c_loss_chg_chance_val

                # On Loss Reset Triggers
                if c_rst_loss_streak > 0 and loss_streak % c_rst_loss_streak == 0:
                    nextbet = c_base_bet
                if c_rst_loss_tot_every > 0 and lose_count % c_rst_loss_tot_every == 0:
                    nextbet = c_base_bet
                if c_rst_loss_val_row > 0 and loss_value_streak >= c_rst_loss_val_row:
                    nextbet = c_base_bet
                    loss_value_streak = 0.0
                if c_rst_loss_val_tot_every > 0 and total_loss_value >= c_rst_loss_val_tot_every:
                    nextbet = c_base_bet
                if c_rst_loss_since_max_p > 0 and (max_profit - total_profit) >= c_rst_loss_since_max_p:
                    nextbet = c_base_bet

            # General Reset Triggers
            if c_rst_after_bets > 0 and round_num % c_rst_after_bets == 0:
                nextbet = c_base_bet

            # Min / Max Bet Cap
            if c_min_bet > 0 and nextbet < c_min_bet:
                nextbet = c_min_bet
            if c_max_bet > 0 and nextbet > c_max_bet:
                nextbet = c_max_bet

            # Zig-Zag Toggle
            if c_zigzag_every > 0:
                zigzag_count += 1
                if zigzag_count >= c_zigzag_every:
                    active_bet_target = "low" if active_bet_target == "high" else "high"
                    zigzag_count = 0
        elif round_mode == "WAGER":
            if result == "win":
                win_amount = current_bet * wager_win_mul
                balance += win_amount
                total_profit = (balance - start_balance) + profit_vault
                nextbet = wager_base_bet
                loss_streak = 0
                win_count += 1
                win_streak += 1
            else:
                balance -= current_bet
                nextbet = wager_base_bet
                total_profit = (balance - start_balance) + profit_vault
                win_streak = 0
                loss_streak += 1
                lose_count += 1
                if loss_streak > max_loss_streak:
                    max_loss_streak = loss_streak
        else:  # PROFIT Mode (Martingale)
            if result == "win":
                win_amount = current_bet * profit_win_mul
                balance += win_amount
                total_profit = (balance - start_balance) + profit_vault
                nextbet = base_bet
                loss_streak = 0
                win_count += 1
                win_streak += 1
            else:
                balance -= current_bet
                nextbet = current_bet * lose_mul
                total_profit = (balance - start_balance) + profit_vault
                win_streak = 0
                loss_streak += 1
                lose_count += 1
                if loss_streak > max_loss_streak:
                    max_loss_streak = loss_streak

        if result == "win":
            win_history.append((win_amount, round_num, round_mode))

        # Mode Transition Check with Profit Vault Skimming (Hybrid Mode 3)
        if game_mode == 3:
            if current_mode == "WAGER":
                if balance <= trigger_balance:
                    print()
                    print(cn(196, f"  >>> [MODE SWITCH] ⚠️  Balance dropped below trigger ({trigger_balance:.2f}) -> RECOVERY (PROFIT MODE) <<<", True))
                    current_mode = "PROFIT"
                    nextbet = base_bet
                    loss_streak = 0
            elif current_mode == "PROFIT":
                recovered = False
                if result == "win" and balance >= start_balance:
                    recovered = True
                elif balance >= trigger_balance_profit:
                    recovered = True

                if recovered:
                    surplus = balance - start_balance
                    profit_vault += surplus
                    balance = start_balance
                    total_profit = profit_vault

                    print()
                    print(cn(46, f"  >>> [MODE SWITCH] 🎯 Capital recovered! Secured +{surplus:.8f} to Vault (Total Vault: {profit_vault:.8f}) <<<", True))
                    print(cn(46, f"  >>> Main Balance reset to {start_balance:.8f} -> RESUME WAGER MODE <<<", True))
                    current_mode = "WAGER"
                    nextbet = wager_base_bet
                    loss_streak = 0

        check_rare_number(last_roll)
        print_round(round_num, last_roll, result, current_bet, round_mode, win_amount)

        if round_delay > 0:
            time.sleep(round_delay)

    # Summary
    if total_profit > 0:
        profit_c = pos_c(f"+{total_profit:.8f}")
        bal_c = pos_c(f"{balance:.8f}")
    elif total_profit < 0:
        profit_c = neg_c(f"{total_profit:.8f}")
        bal_c = neg_c(f"{balance:.8f}")
    else:
        profit_c = _gr(f"{total_profit:.8f}")
        bal_c = _gr(f"{balance:.8f}")

    wagered_c = cn(245, f"{wagered:.8f}", True)
    vault_c = pos_c(f"+{profit_vault:.8f}")

    print()
    print(cn(136, "=" * 74))
    print(cn(255, "  SESSION SUMMARY"))
    print(cn(136, "=" * 74))
    print(
        f"  {_wc('Rounds')}: {round_num}  {pos_c('W')}: {win_count}  "
        f"{neg_c('L')}: {lose_count}  {_wc('MaxStreak')}: {max_loss_streak}"
    )
    print(f"  {_wc('Active Balance')}: {bal_c}")
    print(f"  {_wc('Profit Vault')}:   {vault_c}")
    print(f"  {_wc('Net Total PnL')}:  {profit_c}")
    print(f"  {_wc('Wagered')}:        {wagered_c} / {wager_target:.2f}")

    if total_profit > 0:
        print(pos_c("  Result: PROFIT"))
    elif total_profit < 0:
        print(neg_c("  Result: LOSS"))
    else:
        print(_gr("  Result: BREAK EVEN"))

    if stop_reason:
        print(cn(45, f"  Stop Reason: {stop_reason}"))

    print(cn(136, "=" * 74))
    print(f"  {pos_c('TOP 5 BIGGEST WINS')}")
    print(cn(136, "=" * 74))
    if win_history:
        top5 = sorted(win_history, key=lambda x: x[0], reverse=True)[:5]
        for rank, (amt, r_num, r_mode) in enumerate(top5, 1):
            if r_mode == "CUSTOM":
                w_mode_c = cn(39, r_mode, True)
            elif r_mode == "PROFIT":
                w_mode_c = cn(208, r_mode, True)
            else:
                w_mode_c = cn(75, r_mode, True)
            print(f"  #{rank}. {pos_c(f'+{amt:12.8f}')} | {_wc(f'Round {r_num}')} | {w_mode_c}")
    else:
        print(f"  {_gr('No wins recorded.')}")

    print(cn(136, "=" * 74))
    print(f"  {pos_c('Rare Number')}")
    print(cn(136, "=" * 74))
    for key, val in rare_counts.items():
        print(f"  {_wc(key)}: {val}")
    print(f"  {pos_c('wrong_side')}: {wrong_side}")
    print(" ")
    print(cn(136, "=" * 74))


# ─────────────────────────────────────────
# [CALC] BASEBET CALCULATOR
# ─────────────────────────────────────────
def calc_basebet():
    """
    Optimal BaseBet Calculator.
    Formula: BaseBet = Balance * (mul - 1) / (mul^N - 1)
    Default N is derived from: P(N consecutive losses) < risk_threshold
    => N = ceil(log(risk) / log(1 - win_chance))
    """
    parser = argparse.ArgumentParser(
        description="BaseBet Calculator — find the safe bet size to survive N losses",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Example: roll.py calc --balance 10000 --mul 2.0 --chance 4.95\n"
               "         roll.py calc --balance 10000 --mul 20 --chance 4.95 --max-loss-n 10"
    )
    parser.add_argument("--balance",     "-b",  type=float, required=True,
                        help="Starting balance")
    parser.add_argument("--mul",         "-m",  type=float, required=True,
                        help="Loss multiplier (e.g. 2.0 for Martingale, 20 for your custom)")
    parser.add_argument("--chance",      "-c",  type=float, required=True,
                        help="Win chance %% (e.g. 4.95 for 4.95%%)")
    parser.add_argument("--max-loss-n",  "-n",  type=int,   default=None,
                        help="Max consecutive losses to cover (default: auto-calculated from --risk)")
    parser.add_argument("--risk",        "-r",  type=float, default=0.001,
                        help="Acceptable probability of hitting the streak (default: 0.001 = 0.1%%)")
    parser.add_argument("--coverage",    "-cov", type=float, default=1.0,
                        help="Fraction of balance to use as coverage (default: 1.0 = 100%%)")
    args = parser.parse_args()

    balance      = args.balance
    mul          = args.mul
    win_chance_p = args.chance / 100.0
    loss_p       = 1.0 - win_chance_p
    risk         = args.risk
    coverage     = args.coverage

    # Derived N from math if not provided
    if args.max_loss_n is not None:
        n_user = args.max_loss_n
        n_auto = None
    else:
        if loss_p >= 1.0:
            n_auto = 999
        else:
            n_auto = math.ceil(math.log(risk) / math.log(loss_p))
        n_user = None

    n_cover = n_user if n_user is not None else n_auto

    def basebet_for(n: int, bal: float, m: float) -> float:
        if m == 1.0:
            return (bal * coverage) / n
        try:
            # Use log to avoid float overflow: m^n = exp(n * log(m))
            log_mn = n * math.log(m)
            if log_mn > 700:  # exp(710) ~ float max, guard overflow
                # BaseBet ≈ balance * (m-1) / m^n ≈ ~0, but display as log-space estimate
                log_basebet = math.log(bal * coverage * (m - 1.0)) - log_mn
                return math.exp(log_basebet)
            denom = math.exp(log_mn) - 1.0
            if denom <= 0:
                return 0.0
            return (bal * coverage * (m - 1.0)) / denom
        except (OverflowError, ValueError):
            return 0.0

    def total_exposure(n: int, base: float, m: float) -> float:
        if m == 1.0:
            return base * n
        try:
            mn = math.exp(n * math.log(m)) if n * math.log(m) < 700 else float("inf")
            return base * (mn - 1.0) / (m - 1.0)
        except (OverflowError, ValueError):
            return float("inf")

    sep = cn(136, "=" * 74)

    print()
    print(sep)
    print(cn(255, "  BASEBET CALCULATOR", True))
    print(sep)
    print(f"  {_wc('Balance')}:       {pos_c(f'{balance:.8f}')}"
          f"  {_wc('Coverage')}:    {cn(220, f'{coverage*100:.1f}%', True)}")
    print(f"  {_wc('Multiplier')}:    {cn(220, f'{mul:.5f}x', True)}"
          f"  {_wc('Win Chance')}: {cn(220, f'{args.chance:.4f}%', True)}")
    print(f"  {_wc('Loss Prob')}:     {cn(220, f'{loss_p*100:.4f}%', True)}")
    print(sep)

    # Auto N info
    if n_auto is not None:
        streak_prob = loss_p ** n_auto
        print(f"  {_wc('Risk Threshold')}:    {cn(208, f'{risk*100:.3f}%', True)}"
              f"  (1 in {cn(220, f'{1/risk:,.0f}', True)} sessions)")
        print(f"  {_wc('Auto N (math)')}:     {cn(46, str(n_auto), True)}"
              f"  {_gr(f'(actual streak prob = {streak_prob:.6%})')}")
    else:
        streak_prob = loss_p ** n_user
        print(f"  {_wc('Manual N')}:         {cn(46, str(n_user), True)}"
              f"  {_gr(f'(streak prob = {streak_prob:.6%})')}")

    print(sep)

    def fmt_val(v: float, width: int = 18) -> str:
        """Smart format: fixed 8dp for normal values, scientific for tiny ones."""
        if v == 0.0:
            return f"{'0.00000000':>{width}}"
        if v != float("inf") and (abs(v) < 1e-7 or abs(v) > 1e15):
            return f"{v:>{width}.6e}"
        return f"{v:>{width}.8f}"

    # ─── Min Practical Bet Threshold ───────────────────────────────────────
    # Most platforms minimum is 0.00000001 (1 satoshi equivalent)
    MIN_PRACTICAL_BET = 1e-8

    # Find max N that balance can actually cover (BaseBet >= MIN_PRACTICAL_BET)
    # BaseBet = balance * (m-1) / (m^N - 1)  >= min_bet
    # => m^N - 1 <= balance * (m-1) / min_bet
    # => N <= log(balance*(m-1)/min_bet + 1) / log(m)
    if mul == 1.0:
        max_coverable_n = int(balance * coverage / MIN_PRACTICAL_BET)
    else:
        try:
            max_n_float = math.log(balance * coverage * (mul - 1.0) / MIN_PRACTICAL_BET + 1.0) / math.log(mul)
            max_coverable_n = int(max_n_float)
        except (ValueError, ZeroDivisionError):
            max_coverable_n = 0

    # Main result
    base = basebet_for(n_cover, balance, mul)
    exposure = total_exposure(n_cover, base, mul)
    exp_pct = f"{(exposure/balance)*100:.2f}%" if exposure != float("inf") else "∞"
    is_feasible = base >= MIN_PRACTICAL_BET

    if not is_feasible:
        # ── INSUFFICIENT BALANCE WARNING ─────────────────────────────────
        print(cn(196, "  ╔══════════════════════════════════════════════════════════════════╗", True))
        print(cn(196, f"  ║  ⛔  BALANCE INSUFFICIENT TO COVER THIS STRATEGY               ║", True))
        print(cn(196, "  ╚══════════════════════════════════════════════════════════════════╝", True))
        print()
        print(f"  {_wc('Requested N')}:         {cn(196, str(n_cover), True)}"
              f"  {_gr(f'(requires BaseBet = {fmt_val(base).strip()})')}")
        print(f"  {_wc('Min Practical Bet')}:  {cn(220, f'{MIN_PRACTICAL_BET:.8f}', True)}")
        print()
        print(cn(208, f"  ⚠  Your balance of {balance:.8f} can only support up to:", True))
        print()
        rec_base = basebet_for(max_coverable_n, balance, mul)
        print(f"  {pos_c('>>> Max Coverable N')}:  {cn(46, str(max_coverable_n), True)}"
              f"  {_gr(f'(streak prob = {loss_p**max_coverable_n:.6%})')}")
        print(f"  {pos_c('>>> Recommended BaseBet')}: {cn(226, fmt_val(rec_base).strip(), True)}")
        print()
        print(cn(245, "  Tip: Lower the multiplier, reduce N, or increase your balance.", False))
        print()
        # Update to max coverable for the rest of the output
        n_cover = max_coverable_n
        base = rec_base
        exposure = total_exposure(n_cover, base, mul)
        exp_pct = f"{(exposure/balance)*100:.2f}%" if exposure != float("inf") else "∞"
    else:
        print(f"  {_wc('Cover N Losses')}:   {cn(46, str(n_cover), True)}")
        print(f"  {pos_c('>>> Recommended BaseBet')}: {cn(226, fmt_val(base).strip(), True)}")
        print(f"  {_wc('Max Exposure')}:     {cn(208, fmt_val(exposure).strip(), True)}"
              f"  {_gr(f'({exp_pct} of balance)')}")

    # Bet progression table for N_cover
    print(sep)
    print(f"  {_wc('Bet Progression (consecutive losses)')}"
          f"  {_gr(f'[BaseBet={fmt_val(base).strip()} | Mul={mul}x]')}")
    print(sep)
    acc = 0.0
    b = base
    limit = min(n_cover, 30)
    for i in range(1, limit + 1):
        acc += b
        b_c = neg_c(fmt_val(b)) if b > balance * 0.1 else cn(245, fmt_val(b), False)
        acc_c = neg_c(fmt_val(acc)) if acc >= balance else cn(220, fmt_val(acc), False)
        print(f"  Loss #{i:>3d}: Bet = {b_c} | Cumulative = {acc_c}")
        b *= mul
    if n_cover > 30:
        print(f"  {_gr(f'  ... ({n_cover - 30} more levels, showing first 30 only)')}")

    # Scenario table: compare N presets
    print(sep)
    print(f"  {_wc('Scenario Comparison')} {_gr(f'(Balance={balance} | Mul={mul}x | Chance={args.chance}%)')}")
    print(sep)
    n_list = sorted(set([5, 10, 15, 20, n_cover] + ([n_user] if n_user else [])))
    print(f"  {'N (Losses)':>12} | {'BaseBet':>18} | {'Exposure':>18} | Streak Prob")
    print(f"  {'-'*12}-+-{'-'*18}-+-{'-'*18}-+-{'-'*16}")
    for n in n_list:
        bb = basebet_for(n, balance, mul)
        exp = total_exposure(n, bb, mul)
        try:
            prob = loss_p ** n
        except OverflowError:
            prob = 0.0
        mark = cn(226, " <<<", True) if n == n_cover else ""
        print(f"  {n:>12} | {cn(220, fmt_val(bb), True)} | {cn(208, fmt_val(exp), True)} | {cn(245, f'{prob:.8%}', False)}{mark}")

    print(sep)
    print()


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "calc":
        sys.argv.pop(1)  # remove 'calc' subcommand
        calc_basebet()
    else:
        run_simulation()