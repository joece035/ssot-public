#!/usr/bin/env python3
"""
============================================================
MARTINGALE DICE SIMULATOR — Python Implementation
============================================================
Strategy:
  - lose -> bet x dynamic recovering multiplier (LOSEMUL)
  - win  -> reset to BASE_BET
============================================================
"""

import argparse
import random
import sys
import time


# ─────────────────────────────────────────
# [0] HELPER COLOR (ANSI Color Codes)
# ─────────────────────────────────────────
def cn(code: int, text: str, bold: bool = True) -> str:
    """Format string with ANSI 256-color codes."""
    style = "1;" if bold else "0;"
    return f"\033[{style}38;5;{code}m{text}\033[0m"


def _wc(text: str) -> str:  # white color
    return cn(255, text, True)


def _gr(text: str) -> str:  # gray color
    return cn(235, text, False)


def pos_c(text: str) -> str:  # win/positive color (+c)
    return cn(82, text, True)


def neg_c(text: str) -> str:  # lose/negative color (-c)
    return cn(124, text, True)


# ─────────────────────────────────────────
# [1] CONFIGURATION & ARGUMENT PARSER
# ─────────────────────────────────────────
def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Martingale Dice Simulator",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "-b",
        "--basebet",
        type=float,
        default=1.0,
        help="Base bet amount (default: 1)",
    )
    parser.add_argument(
        "-c",
        "--chance",
        type=float,
        default=0.99,
        help="Win chance % (default: 0.99)",
    )
    parser.add_argument(
        "-sb",
        "--startbalance",
        type=float,
        default=1000.0,
        help="Starting balance (default: 1000)",
    )
    parser.add_argument(
        "-r",
        "--rounds",
        type=int,
        default=2000,
        help="Max rounds (default: 2000)",
    )
    parser.add_argument(
        "-ml",
        "--maxloss",
        type=int,
        default=1000,
        help="Max loss streak (default: 1000)",
    )
    parser.add_argument(
        "-sw",
        "--stop-win",
        type=float,
        default=500.0,
        help="Stop profit target (default: 500)",
    )
    parser.add_argument(
        "-sl",
        "--stop-lose",
        type=float,
        default=1000.0,
        help="Stop loss / Wager limit (default: 1000)",
    )
    parser.add_argument(
        "-ow",
        "--on-win",
        type=int,
        default=5,
        help="Stop after N wins (default: 5)",
    )
    parser.add_argument(
        "-s",
        "--strategy",
        type=str,
        choices=["low", "high"],
        default="high",
        help="Bet strategy low|high (default: high)",
    )
    parser.add_argument(
        "-d",
        "--delay",
        type=float,
        default=0.0,
        help="Delay (seconds) between rounds, e.g. 0.05 (default: 0 = max speed)",
    )
    return parser.parse_args()


# ─────────────────────────────────────────
# [2] MAIN SIMULATION LOGIC
# ─────────────────────────────────────────
def run_simulation():
    args = parse_arguments()
    round_delay = args.delay

    # Constants
    house_edge = 1.0  # House edge %
    base_bet = args.basebet
    win_chance = args.chance
    start_balance = args.startbalance
    max_rounds = args.rounds
    max_loss_streak_limit = args.maxloss
    stop_profit = args.stop_win
    wager_target = args.stop_lose
    stop_on_win = args.on_win
    bet_target = args.strategy

    # Math calculations
    payout = (1 - (house_edge / 100)) / (win_chance / 100)
    lose_mul = 1 + (1 / (payout - 1)) + (0.05 / payout)

    threshold_low = int(win_chance * 100)
    threshold_high = int((100 - win_chance) * 100)

    # Global State Initialization
    balance = start_balance
    nextbet = base_bet
    wagered = 0.0
    total_profit = 0.0
    round_num = 0
    win_count = 0
    win_streak = 0
    lose_count = 0
    loss_streak = 0
    max_loss_streak = 0
    wrong_side = 0

    rare_counts = {
        "9900x": 0,  # 9999 or 0
        "4950x": 0,  # 9998 or 1
        "3300x": 0,  # 9997 or 2
        "2475x": 0,  # 9996 or 3
        "1980x": 0,  # 9995 or 4
        "1650x": 0,  # 9994 or 5
        "1414x": 0,  # 9993 or 6
        "1237x": 0,  # 9992 or 7
        "1100x": 0,  # 9991 or 8
        "990x": 0,  # 9990 or 9
    }

    def check_rare_number(roll: int):
        nonlocal wrong_side
        if roll in (9999, 0):
            rare_counts["9900x"] += 1
        elif roll in (9998, 1):
            rare_counts["4950x"] += 1
        elif roll in (9997, 2):
            rare_counts["3300x"] += 1
        elif roll in (9996, 3):
            rare_counts["2475x"] += 1
        elif roll in (9995, 4):
            rare_counts["1980x"] += 1
        elif roll in (9994, 5):
            rare_counts["1650x"] += 1
        elif roll in (9993, 6):
            rare_counts["1414x"] += 1
        elif roll in (9992, 7):
            rare_counts["1237x"] += 1
        elif roll in (9991, 8):
            rare_counts["1100x"] += 1
        elif roll in (9990, 9):
            rare_counts["990x"] += 1

    def roll_dice():
        nonlocal wrong_side
        roll = random.randint(0, 9999)

        if bet_target == "low":
            if roll < threshold_low:
                result = "win"
            else:
                result = "lose"
                if roll >= threshold_high:
                    wrong_side += 1
        else:  # bet_target == "high"
            if roll >= threshold_high:
                result = "win"
            else:
                result = "lose"
                if roll < threshold_low:
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
            return f"PROFIT REACHED: {stop_profit}"
        if wagered >= wager_target:
            return f"WARGER REACHED: {wager_target}"
        return ""

    def print_round(
        r_num: int, roll: int, result: str, bet: float, win_amt: float
    ):
        r_fmt = f"{r_num:3d}"
        roll_fmt = f"{roll:4d}"
        bal_fmt = f"{balance:13.8f}"
        stk_fmt = f"{loss_streak:2d}"

        bal_c = (
            cn(124, bal_fmt, True)
            if start_balance > balance
            else cn(28, bal_fmt, True)
        )

        if result == "win":
            amt_fmt = f"{win_amt:13.8f}"
            icon = pos_c("WIN ")
            roll_c = pos_c(roll_fmt)
            amt_c = pos_c(f"+{amt_fmt}")
            profit_c = pos_c(f"+{total_profit:.8f}")

            print(
                f"[{r_fmt}] | R: {roll_c} | {icon} | won:{amt_c} | {pos_c('Profit:')} {profit_c}"
            )
        else:
            amt_fmt = f"{bet:10.8f}"
            icon = neg_c("LOSS")

            if (bet_target == "low" and roll >= threshold_high) or (
                bet_target == "high" and roll < threshold_low
            ):
                roll_c = cn(45, roll_fmt, True)
            else:
                roll_c = cn(245, roll_fmt, False)

            print(
                f"[{r_fmt}] | R: {roll_c} | {icon} | Bet: {amt_fmt} | Bal: {bal_c} | Stk: {stk_fmt}"
            )

    # ─────────────────────────────────────────
    # HEADER PRINTING
    # ─────────────────────────────────────────
    print(cn(136, "=" * 74))
    print(cn(255, "  MARTINGALE DICE SIMULATOR"))
    print(cn(136, "=" * 74))
    print(
        f" Bal: {start_balance:.8f} | base: {base_bet:.8f} | WC: {win_chance:.2f}% | "
        f"Payout: {payout:.4f}x | Mul: {lose_mul:.4f}x"
    )
    print(cn(136, "=" * 74))

    stop_reason = ""

    # ─────────────────────────────────────────
    # MAIN LOOP
    # ─────────────────────────────────────────
    while round_num < max_rounds:
        if win_count >= stop_on_win:
            stop_reason = f"WIN LIMIT: reached {stop_on_win} wins"
            break

        stop_reason = check_stop_condition(nextbet)
        if stop_reason:
            break

        round_num += 1
        wagered += nextbet

        last_roll, result = roll_dice()

        # Martingale Logic
        win_amount = 0.0
        if result == "win":
            win_amount = nextbet * payout
            balance += win_amount
            total_profit = balance - start_balance
            nextbet = base_bet
            loss_streak = 0
            win_count += 1
            win_streak += 1
        else:
            balance -= nextbet
            nextbet = nextbet * lose_mul
            total_profit = balance - start_balance
            win_streak = 0
            loss_streak += 1
            lose_count += 1
            if loss_streak > max_loss_streak:
                max_loss_streak = loss_streak

        check_rare_number(last_roll)
        print_round(round_num, last_roll, result, nextbet, win_amount)
        if round_delay > 0:
            time.sleep(round_delay)
        
    # ─────────────────────────────────────────
    # SESSION SUMMARY
    # ─────────────────────────────────────────
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
    print(f"  {_wc('Wagered')}: {wagered_c}")

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