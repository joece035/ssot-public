#!/usr/bin/env python3


import glob
import os
import subprocess
import sys


HOME = os.environ.get("HOME", os.path.expanduser("~"))


def _run(cmd):
    """รันคำสั่ง shell ตรงๆ แล้วคืน exit status (ใช้กับคำสั่งที่ไม่ได้แปลงเป็น python) """
    return subprocess.run(cmd, shell=True).returncode


def _sh(cmd):
    """รันคำสั่ง shell แล้วคืนผลลัพธ์ stdout (เทียบเท่า $(...) ใน bash) """
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.rstrip("\n")


def _ok(cmd):
    """คืน True เมื่อคำสั่ง exit status = 0 (เทียบเท่าการเช็ค condition ใน if) """
    return subprocess.run(cmd, shell=True).returncode == 0




# ============================================================
# MARTINGALE DICE SIMULATOR — Guideline / Template
# ============================================================
# Strategy:
#   - lose -> bet x dynamic recovering multiplier (LOSEMUL)
#   - win  -> reset to BASE_BET
# ============================================================
# bash: source $HOME/.bashrc
exec(open(f"{HOME}/.bashrc").read())
# bash: set -u
# TODO: 'set' ไม่มีใน python ตรงตัว: set -u

# ─────────────────────────────────────────
# [0] HELPER COLOR
# ─────────────────────────────────────────
# bash: _wc() { cn 255 b "$@"; } #white color
def _wc():
    _run("cn 255 b \"" + (" ".join(sys.argv[1:])) + "\"")
# bash: _gr(){ cn 235 d "$@"; } #gray color
def _gr():
    _run("cn 235 d \"" + (" ".join(sys.argv[1:])) + "\"")
# bash: +c(){ cn 82 b "$@"; }  #win color
_run("+c(){ cn 82 b \"" + (" ".join(sys.argv[1:])) + "\"")
# bash: -c(){ cn lr b "$@"; }  #lose color
_run("-c(){ cn lr b \"" + (" ".join(sys.argv[1:])) + "\"")

# ─────────────────────────────────────────
# [1] CONFIGURATION
# ─────────────────────────────────────────
# bash: HE=1                    # house edge %
HE = 1
# bash: START_BALANCE=1000      # starting balance
START_BALANCE = 1000
# bash: BASE_BET=2              # base bet amount
BASE_BET = 2
# bash: WIN_CHANCE="9"       # win probability %
WIN_CHANCE = "9"
# bash: MAX_ROUNDS=2000          # simulation rounds
MAX_ROUNDS = 2000
# bash: MAX_LOSS_STREAK="1000"      # safety stop: max consecutive losses
MAX_LOSS_STREAK = "1000"
# bash: STOP_ON_WIN=5             # stop on first win
STOP_ON_WIN = 5

# Payout multiplier: (1 - HE/100) / (WIN_CHANCE/100)
# bash: payout=$(mth "(1-($HE/100))/($WIN_CHANCE/100)" 4 d)
payout = _sh("mth \"(1-($HE/100))/($WIN_CHANCE/100)\" 4 d")

# Multiplier ทบเมื่อแพ้:
# - Classic Martingale (กำไรคงที่เท่ากับไม้แรกเสมอ): 1 + (1 / (payout - 1))
# - Exponential Profit (กำไรโตตามสตรีค เช่น 5%): 1 + (1.05 / (payout - 1))
# bash: LOSEMUL=$(mth "1 + (1 / ($payout - 1))+(0.05/$payout)" 4 d)
LOSEMUL = _sh("mth \"1 + (1 / ($payout - 1))+(0.05/$payout)\" 4 d")

# ─────────────────────────────────────────
# [2] GLOBAL STATE
# ─────────────────────────────────────────
# bash: threshold=$(mth "$WIN_CHANCE*100" 0 d)
threshold = _sh("mth \"$WIN_CHANCE*100\" 0 d")
# bash: balance=$START_BALANCE
balance = START_BALANCE
# bash: current_bet=$BASE_BET
current_bet = BASE_BET
# bash: round=0
round = 0
# bash: win_count=0
win_count = 0
# bash: lose_count=0
lose_count = 0
# bash: loss_streak=0
loss_streak = 0
# bash: max_loss_streak=0
max_loss_streak = 0
# bash: last_roll=0
last_roll = 0

# ─────────────────────────────────────────
# [3] MATH HELPERS
# ─────────────────────────────────────────
# bash: fadd() {
def fadd():
    # bash: mth "$1+$2" 8 d
    _run("mth \"" + (sys.argv[1]) + "+" + (sys.argv[2]) + "\" 8 d")

# bash: fsub() {
def fsub():
    # bash: mth "$1-$2" 8 d
    _run("mth \"" + (sys.argv[1]) + "-" + (sys.argv[2]) + "\" 8 d")

# bash: fmul() {
def fmul():
    # bash: mth "$1*$2" 8 d
    _run("mth \"" + (sys.argv[1]) + "*" + (sys.argv[2]) + "\" 8 d")

# bash: float_div() {
def float_div():
    # bash: mth "$1/$2" 8 d
    _run("mth \"" + (sys.argv[1]) + "/" + (sys.argv[2]) + "\" 8 d")

# bash: fgt() {
def fgt():
    # bash: awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'
    _run("awk -v a=\"" + (sys.argv[1]) + "\" -v b=\"" + (sys.argv[2]) + "\" 'BEGIN { exit !(a > b) }")

# bash: fgte() {
def fgte():
    # bash: awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
    _run("awk -v a=\"" + (sys.argv[1]) + "\" -v b=\"" + (sys.argv[2]) + "\" 'BEGIN { exit !(a >= b) }")

# ─────────────────────────────────────────
# [4] ROLL DICE
# Simulate win/lose based on WIN_CHANCE
# Returns: "<roll_value> <win|lose>"
# ─────────────────────────────────────────
# bash: roll_dice() {
def roll_dice():
    # bash: local roll
    _run("roll")
    # bash: roll=$(( RANDOM % 10000 ))
    roll = ( RANDOM % 10000 )

    # bash: if (( roll < threshold )); then
    if _ok("(( roll < threshold ))"):
        # bash: last_roll="$roll"
        last_roll = roll
        # bash: result="win"
        result = "win"
        #echo "$roll win"
    # bash: else
    else:
        # bash: last_roll="$roll"
        last_roll = roll
        # bash: result="lose"
        result = "lose"
        #echo "$roll lose"

# ─────────────────────────────────────────
# [5] MARTINGALE LOGIC
# ─────────────────────────────────────────
# bash: apply_martingale() {
def apply_martingale():
    # bash: local result="$1"   # win | lose
    result = sys.argv[1]
    # bash: local bet="$2"      # bet amount this round
    bet = sys.argv[2]

    # bash: if [[ "$result" == "win" ]]; then
    if str(result) == "win":
        # WIN: กำไรสุทธิ = bet * (payout - 1)
        # bash: win_amount=$(fmul "$bet" "$payout")
        win_amount = _sh("fmul \"$bet\" \"$payout\"")
        # bash: balance=$(fadd "$balance" "$win_amount")
        balance = _sh("fadd \"$balance\" \"$win_amount\"")
        # bash: net_profit=$(fsub "$win_amount" "$bet")
        net_profit = _sh("fsub \"$win_amount\" \"$bet\"")
        # bash: current_bet=$BASE_BET
        current_bet = BASE_BET
        # bash: loss_streak=0
        loss_streak = 0
        # bash: ((win_count++))
        win_count += 1
    # bash: else
    else:
        # LOSE: เสียเงินเดิมพัน, ทบเงินด้วย LOSEMUL
        # bash: balance=$(fsub "$balance" "$bet")
        balance = _sh("fsub \"$balance\" \"$bet\"")
        # bash: current_bet=$(fmul "$bet" "$LOSEMUL")
        current_bet = _sh("fmul \"$bet\" \"$LOSEMUL\"")
        # bash: ((loss_streak++))
        loss_streak += 1
        # bash: ((lose_count++))
        lose_count += 1

        # bash: if (( loss_streak > max_loss_streak )); then
        if _ok("(( loss_streak > max_loss_streak ))"):
            # bash: max_loss_streak=$loss_streak
            max_loss_streak = loss_streak

# ─────────────────────────────────────────
# [6] STOP CONDITIONS
# ─────────────────────────────────────────
# bash: should_stop() {
def should_stop():
    # (a) balance หมด
    # bash: if ! fgt "$balance" 0; then
    if not (_ok("fgt \"" + str(balance) + "\" 0")):
        # bash: echo "BUST: balance depleted"
        print("BUST: balance depleted")
        # bash: return 0
        return 0
    # (b) loss streak เกิน limit
    # bash: if (( loss_streak >= MAX_LOSS_STREAK )); then
    if _ok("(( loss_streak >= MAX_LOSS_STREAK ))"):
        # bash: echo "MAX_STREAK: $loss_streak consecutive losses"
        print(f"MAX_STREAK: {loss_streak} consecutive losses")
        # bash: return 0
        return 0
    # (c) next bet > balance (ไม่มีเงินพอเดิมพันตาต่อไป)
    # bash: if fgt "$current_bet" "$balance"; then
    if _ok("fgt \"" + str(current_bet) + "\" \"" + str(balance) + "\""):
        # bash: echo "BET_GT_BAL: bet=$current_bet balance=$balance"
        print(f"BET_GT_BAL: bet={current_bet} balance={balance}")
        # bash: return 0
        return 0
    # bash: return 1
    return 1

# ─────────────────────────────────────────
# [7] PRINT ROUND
# ─────────────────────────────────────────
# bash: print_round() {
def print_round():
    # bash: local roll="$1"
    roll = sys.argv[1]
    # bash: local result="$2"
    result = sys.argv[2]
    # bash: local bet="$3"
    bet = sys.argv[3]
    # bash: local icon  r_fmt roll_fmt amt_fmt bal_fmt stk_fmt
    _run("icon  r_fmt roll_fmt amt_fmt bal_fmt stk_fmt")

    # 1. Format ความกว้างตัวเลขก่อนระบายสี
    # bash: printf -v r_fmt    "%3d"   "$round"
    print("-v" % ("r_fmt", "%3d", round))
    # bash: printf -v roll_fmt "%4d"   "$roll"
    print("-v" % ("roll_fmt", "%4d", roll))
    # bash: printf -v bal_fmt  "%13.8f" "$balance"
    print("-v" % ("bal_fmt", "%13.8f", balance))
    # bash: printf -v stk_fmt  "%2d"   "$loss_streak"
    print("-v" % ("stk_fmt", "%2d", loss_streak))

    # bash: if [[ "$result" == "win" ]]; then
    if str(result) == "win":

        # bash: printf -v amt_fmt "%13.8f" "$win_amount"
        print("-v" % ("amt_fmt", "%13.8f", win_amount))

        # 2. นำสตริงที่ได้ขนาดแน่นอนแล้วไปใส่สี
        # bash: icon="$(+c "WIN ")"
        icon = _sh("+c \"WIN \"")
        # bash: local roll_c="$(+c "$roll_fmt")"
        roll_c = _sh("+c \"$roll_fmt\"")
        # bash: local amt_c="$(+c "+$amt_fmt")"
        amt_c = _sh("+c \"+$amt_fmt\"")
        # bash: local net_profit_c="$(+c "+$net_profit")"
        net_profit_c = _sh("+c \"+$net_profit\"")

        # 3. Print ออกมาด้วย %s สบายๆ ไม่เบี้ยวแน่นอน
        # bash: printf -v _data "[%s] | R: %s | %s | won:%s | Bal: %s | $(+c "Profit:") %s\n"              "$r_fmt" "$roll_c" "$icon" "$amt_c" "$bal_fmt" "$net_profit_c"
        print("-v" % ("_data", glob.glob("[%s] | R: %s | %s | won:%s | Bal: %s | " + (_sh("+c \"Profit:\"")) + " %s\\n"), r_fmt, roll_c, icon, amt_c, bal_fmt, net_profit_c))

        # bash: printf "%s" "$_data"
        print("%s" % (_data,))
    # bash: else
    else:
        # bash: printf -v amt_fmt "%10.8f" "$bet"
        print("-v" % ("amt_fmt", "%10.8f", bet))
        # bash: icon="$(-c "LOSS")"
        icon = _sh("-c \"LOSS\"")
        # bash: local roll_c="$roll_fmt"
        roll_c = roll_fmt
        # bash: local amt_c="$amt_fmt"
        amt_c = amt_fmt

        # bash: printf "[%s] | R: %s | %s | Bet: %s | Bal: %s | Stk: %s\n"              "$r_fmt" "$roll_c" "$icon" "$amt_c" "$bal_fmt" "$stk_fmt"
        print("[%s] | R: %s | %s | Bet: %s | Bal: %s | Stk: %s\n" % (r_fmt, roll_c, icon, amt_c, bal_fmt, stk_fmt))

# ─────────────────────────────────────────
# [8] MAIN LOOP
# ─────────────────────────────────────────
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")
# bash: cn 255 b "  MARTINGALE DICE SIMULATOR"
_run("cn 255 b \"  MARTINGALE DICE SIMULATOR\"")
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")
# bash: printf " Bal: %.8f | base: %.8f | WC: %.2f%% | Payout: %.4fx | Mul: %.4fx\n "      "$START_BALANCE" "$BASE_BET" "$WIN_CHANCE" "$payout" "$LOSEMUL"
print(" Bal: %.8f | base: %.8f | WC: %.2f%% | Payout: %.4fx | Mul: %.4fx\n " % (START_BALANCE, BASE_BET, WIN_CHANCE, payout, LOSEMUL))
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")

# bash: stop_reason=""
stop_reason = ""

# bash: while (( round < MAX_ROUNDS )); do
while _ok("(( round < MAX_ROUNDS ))"):
    # bash: ((round++))
    round += 1

    # bash: if (( win_count >= STOP_ON_WIN )); then
    if _ok("(( win_count >= STOP_ON_WIN ))"):
        # bash: break
        break

    # ตรวจสอบเงื่อนไขหยุดก่อนเดิมพัน
    # bash: if stop_reason=$(should_stop); then
    if _ok("stop_reason=" + (_sh("should_stop"))):
        # bash: break
        break

    # bash: nextbet=$current_bet
    nextbet = current_bet

    # --- roll dice ---
    # bash: roll_dice   # -- result stored in $result and $last_roll ---
    _run("roll_dice")
    #printf "roll: %4d | result: %s\n" "$last_roll" "$result"
    # --- apply martingale ---
    # bash: apply_martingale "$result" "$nextbet"
    _run("apply_martingale \"" + str(result) + "\" \"" + str(nextbet) + "\"")

    # --- print round ---
    # bash: print_round "$last_roll" "$result" "$nextbet"
    _run("print_round \"" + str(last_roll) + "\" \"" + str(result) + "\" \"" + str(nextbet) + "\"")

# ─────────────────────────────────────────
# [9] SESSION SUMMARY
# ─────────────────────────────────────────
# bash: echo
print()
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")
# bash: cn 255 b "  SESSION SUMMARY"
_run("cn 255 b \"  SESSION SUMMARY\"")
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")
# bash: printf "  $(_wc 'Rounds'): %d  $(+c 'W'): %d  $(-c 'L'): %d  $(_wc 'MaxStreak'): %d\n"      "$round" "$win_count" "$lose_count" "$max_loss_streak"
print("  " + (_sh("_wc 'Rounds'")) + ": %d  " + (_sh("+c 'W'")) + ": %d  " + (_sh("-c 'L'")) + ": %d  " + (_sh("_wc 'MaxStreak'")) + ": %d\\n", round, win_count, lose_count, max_loss_streak)

# bash: profit=$(fsub "$balance" "$START_BALANCE")
profit = _sh("fsub \"$balance\" \"$START_BALANCE\"")
# bash: printf "  $(_wc 'Final Balance'): %.8f\n" "$balance"
print("  " + (_sh("_wc 'Final Balance'")) + ": %.8f\\n", balance)
# bash: printf "  $(_wc 'Net PnL'): %.8f\n" "$profit"
print("  " + (_sh("_wc 'Net PnL'")) + ": %.8f\\n", profit)

# bash: if fgt "$balance" "$START_BALANCE"; then
if _ok("fgt \"" + str(balance) + "\" \"" + str(START_BALANCE) + "\""):
    # bash: +c "  Result: PROFIT"
    _run("+c \"  Result: PROFIT\"")
# bash: elif fgt "$START_BALANCE" "$balance"; then
elif _ok("fgt \"" + str(START_BALANCE) + "\" \"" + str(balance) + "\""):
    # bash: -c "  Result: LOSS"
    _run("-c \"  Result: LOSS\"")
# bash: else
else:
    # bash: -c "  Result: BREAK EVEN"
    _run("-c \"  Result: BREAK EVEN\"")

# bash: [[ -n "$stop_reason" ]] && cn 216 b "  Stop Reason: $stop_reason"
_run("[[ -n \"" + str(stop_reason) + "\" ]] && cn 216 b \"  Stop Reason: " + str(stop_reason) + "\"")
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")
