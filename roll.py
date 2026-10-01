#!/usr/bin/env python3
"""
DICE SIMULATOR - MULTI MODE ENGINE (Python Port)
============================================================
Supports:
  - Mode 1: Profit Mode (Martingale recovery with low win chance)
  - Mode 2: Wager Mode (High win chance, flat bet to build wager volume)
  - Mode 3: Hybrid Mode (Wager mode that switches to Profit recovery when dropped)
  - Central Config: Reads defaults from ~/ssot/dice.env
============================================================
"""

import argparse
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
        "-m", "--mode", type=int, choices=[1, 2, 3],
        default=cfg_get("GAME_MODE", 3, int),
        help="Game mode: 1(profit), 2(wager), 3(hybrid)"
    )
    parser.add_argument(
        "-b", "--basebet", type=float,
        default=cfg_get("BASE_BET", 2.0, float),
        help="Base bet amount"
    )
    parser.add_argument(
        "-c", "--chance", type=float,
        default=cfg_get("WIN_CHANCE", 3.96, float),
        help="Win chance % (Profit Mode)"
    )
    parser.add_argument(
        "-wc", "--wager-chance", type=float,
        default=cfg_get("WAGER_WIN_CHANCE", 98.0, float),
        help="Win chance % (Wager Mode)"
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

    # Thresholds & triggers from env or defaults
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
    lose_mul = 1.0 + (1.0 / (profit_payout - 1.0)) + (0.05 / profit_payout)
    profit_t_low = int(profit_win_chance * 100)
    profit_t_high = int((100 - profit_win_chance) * 100)

    # Wager Mode Math
    wager_payout = (1.0 - (house_edge / 100.0)) / (wager_win_chance / 100.0)
    wager_win_mul = wager_payout - 1.0
    wager_t_low = int(wager_win_chance * 100)
    wager_t_high = int((100 - wager_win_chance) * 100)

    # State variables
    balance = start_balance
    wagered = 0.0
    total_profit = 0.0
    round_num = 0
    win_count = 0
    win_streak = 0
    lose_count = 0
    loss_streak = 0
    max_loss_streak = 0
    wrong_side = 0

    if game_mode == 2:
        current_mode = "WAGER"
        nextbet = wager_base_bet
    elif game_mode == 3:
        current_mode = "WAGER"
        nextbet = wager_base_bet
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

        if mode == "WAGER":
            t_low, t_high = wager_t_low, wager_t_high
        else:
            t_low, t_high = profit_t_low, profit_t_high

        if bet_target == "low":
            if roll < t_low:
                result = "win"
            else:
                result = "lose"
                if roll >= t_high:
                    wrong_side += 1
        else:  # bet_target == "high"
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

        active_high = wager_t_high if mode_played == "WAGER" else profit_t_high
        active_low = wager_t_low if mode_played == "WAGER" else profit_t_low

        if (bet_target == "low" and roll >= active_high) or (bet_target == "high" and roll < active_low):
            roll_c = cn(45, roll_fmt, True)
        else:
            roll_c = cn(245, roll_fmt, False)

        mode_badge = cn(208, "PROFIT", True) if mode_played == "PROFIT" else cn(75, "WAGER ", True)
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
        if round_mode == "WAGER":
            if result == "win":
                win_amount = current_bet * wager_win_mul
                balance += win_amount
                total_profit = balance - start_balance
                nextbet = wager_base_bet
                loss_streak = 0
                win_count += 1
                win_streak += 1
            else:
                balance -= current_bet
                nextbet = wager_base_bet
                total_profit = balance - start_balance
                win_streak = 0
                loss_streak += 1
                lose_count += 1
                if loss_streak > max_loss_streak:
                    max_loss_streak = loss_streak
        else:  # PROFIT Mode (Martingale)
            if result == "win":
                win_amount = current_bet * profit_win_mul
                balance += win_amount
                total_profit = balance - start_balance
                nextbet = base_bet
                loss_streak = 0
                win_count += 1
                win_streak += 1
            else:
                balance -= current_bet
                nextbet = current_bet * lose_mul
                total_profit = balance - start_balance
                win_streak = 0
                loss_streak += 1
                lose_count += 1
                if loss_streak > max_loss_streak:
                    max_loss_streak = loss_streak

        # Mode Transition Check (Hybrid Mode 3)
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
                    print()
                    print(cn(46, f"  >>> [MODE SWITCH] 🎯 Capital recovered! (Bal: {balance:.2f} >= Start: {start_balance:.2f}) -> RESUME WAGER MODE <<<", True))
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

    print()
    print(cn(136, "=" * 74))
    print(cn(255, "  SESSION SUMMARY"))
    print(cn(136, "=" * 74))
    print(
        f"  {_wc('Rounds')}: {round_num}  {pos_c('W')}: {win_count}  "
        f"{neg_c('L')}: {lose_count}  {_wc('MaxStreak')}: {max_loss_streak}"
    )
    print(f"  {_wc('Final Balance')}: {bal_c}")
    print(f"  {_wc('Net PnL')}: {profit_c}")
    print(f"  {_wc('Wagered')}: {wagered_c} / {wager_target:.2f}")

    if balance > start_balance:
        print(pos_c("  Result: PROFIT"))
    elif start_balance > balance:
        print(neg_c("  Result: LOSS"))
    else:
        print(_gr("  Result: BREAK EVEN"))

    if stop_reason:
        print(cn(45, f"  Stop Reason: {stop_reason}"))

    print(cn(136, "=" * 74))
    print(f"  {pos_c('Rare Number')}")
    print(cn(136, "=" * 74))
    for key, val in rare_counts.items():
        print(f"  {_wc(key)}: {val}")
    print(f"  {pos_c('wrong_side')}: {wrong_side}")
    print(" ")
    print(cn(136, "=" * 74))


if __name__ == "__main__":
    run_simulation()