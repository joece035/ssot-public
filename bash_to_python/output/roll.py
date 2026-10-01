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
# bash: -c(){ cn 124 b "$@"; }  #lose color
_run("-c(){ cn 124 b \"" + (" ".join(sys.argv[1:])) + "\"")

# ─────────────────────────────────────────
# [1] CONFIGURATION  (flag-based args)
# ─────────────────────────────────────────
# bash: HE=1                    # house edge %
HE = 1

# --- defaults ---
# bash: BASE_BET=1
BASE_BET = 1
# bash: WIN_CHANCE=0.99
WIN_CHANCE = 0.99
# bash: START_BALANCE=1000
START_BALANCE = 1000
# bash: MAX_ROUNDS=2000
MAX_ROUNDS = 2000
# bash: MAX_LOSS_STREAK=1000
MAX_LOSS_STREAK = 1000
# bash: WARGER_TARGET=1000
WARGER_TARGET = 1000
# bash: STOP_ON_WIN=5
STOP_ON_WIN = 5
# bash: STOP_PROFIT=500
STOP_PROFIT = 500
# bash: STOP_BALANCE=
STOP_BALANCE = ""
# bash: BET_STRATEGY="high"     # "low" or "high"
BET_STRATEGY = "high"

# --- flag parser ---
# bash: _usage() {
def _usage():
    # bash: echo "Usage: $0 [OPTIONS]"
    print(glob.glob("Usage: " + (sys.argv[0]) + " [OPTIONS]"))
    # bash: echo "  -b  | --basebet        Base bet amount          (default: 1)"
    print("  -b  | --basebet        Base bet amount          (default: 1)")
    # bash: echo "  -c  | --chance         Win chance %             (default: 0.99)"
    print("  -c  | --chance         Win chance %             (default: 0.99)")
    # bash: echo "  -sb | --startbalance   Starting balance         (default: 1000)"
    print("  -sb | --startbalance   Starting balance         (default: 1000)")
    # bash: echo "  -r  | --rounds         Max rounds               (default: 2000)"
    print("  -r  | --rounds         Max rounds               (default: 2000)")
    # bash: echo "  -ml | --maxloss        Max loss streak          (default: 1000)"
    print("  -ml | --maxloss        Max loss streak          (default: 1000)")
    # bash: echo "  -sw | --stop-win       Stop profit target       (default: 500)"
    print("  -sw | --stop-win       Stop profit target       (default: 500)")
    # bash: echo "  -sl | --stop-lose      Stop loss (wager limit)  (default: 1000)"
    print("  -sl | --stop-lose      Stop loss (wager limit)  (default: 1000)")
    # bash: echo "  -ow | --on-win         Stop after N wins        (default: 5)"
    print("  -ow | --on-win         Stop after N wins        (default: 5)")
    # bash: echo "  -s  | --strategy       Bet strategy low|high    (default: high)"
    print("  -s  | --strategy       Bet strategy low|high    (default: high)")
    # bash: echo "  -h  | --help           Show this help"
    print("  -h  | --help           Show this help")
    # bash: exit 0
    sys.exit(0)

# bash: while [[ $# -gt 0 ]]; do
while int(len(sys.argv) - 1) > 0:
    # bash: case "$1" in
    match sys.argv[1]:
        # bash: -b|--basebet)        BASE_BET="$2";        shift 2 ;;
        case _ if any(str(sys.argv[1]) == "-b", str(sys.argv[1]) == "--basebet"):
            BASE_BET = sys.argv[2]
            # TODO: 'shift' ไม่มีใน python ตรงตัว: shift 2
        # bash: -c|--chance)         WIN_CHANCE="$2";      shift 2 ;;
        case _ if any(str(sys.argv[1]) == "-c", str(sys.argv[1]) == "--chance"):
            WIN_CHANCE = sys.argv[2]
            # TODO: 'shift' ไม่มีใน python ตรงตัว: shift 2
        # bash: -sb|--startbalance)  START_BALANCE="$2";   shift 2 ;;
        case _ if any(str(sys.argv[1]) == "-sb", str(sys.argv[1]) == "--startbalance"):
            START_BALANCE = sys.argv[2]
            # TODO: 'shift' ไม่มีใน python ตรงตัว: shift 2
        # bash: -r|--rounds)         MAX_ROUNDS="$2";      shift 2 ;;
        case _ if any(str(sys.argv[1]) == "-r", str(sys.argv[1]) == "--rounds"):
            MAX_ROUNDS = sys.argv[2]
            # TODO: 'shift' ไม่มีใน python ตรงตัว: shift 2
        # bash: -ml|--maxloss)       MAX_LOSS_STREAK="$2"; shift 2 ;;
        case _ if any(str(sys.argv[1]) == "-ml", str(sys.argv[1]) == "--maxloss"):
            MAX_LOSS_STREAK = sys.argv[2]
            # TODO: 'shift' ไม่มีใน python ตรงตัว: shift 2
        # bash: -sw|--stop-win)      STOP_PROFIT="$2";     shift 2 ;;
        case _ if any(str(sys.argv[1]) == "-sw", str(sys.argv[1]) == "--stop-win"):
            STOP_PROFIT = sys.argv[2]
            # TODO: 'shift' ไม่มีใน python ตรงตัว: shift 2
        # bash: -sl|--stop-lose)     WARGER_TARGET="$2";   shift 2 ;;
        case _ if any(str(sys.argv[1]) == "-sl", str(sys.argv[1]) == "--stop-lose"):
            WARGER_TARGET = sys.argv[2]
            # TODO: 'shift' ไม่มีใน python ตรงตัว: shift 2
        # bash: -ow|--on-win)        STOP_ON_WIN="$2";     shift 2 ;;
        case _ if any(str(sys.argv[1]) == "-ow", str(sys.argv[1]) == "--on-win"):
            STOP_ON_WIN = sys.argv[2]
            # TODO: 'shift' ไม่มีใน python ตรงตัว: shift 2
        # bash: -s|--strategy)       BET_STRATEGY="$2";    shift 2 ;;
        case _ if any(str(sys.argv[1]) == "-s", str(sys.argv[1]) == "--strategy"):
            BET_STRATEGY = sys.argv[2]
            # TODO: 'shift' ไม่มีใน python ตรงตัว: shift 2
        # bash: -h|--help)           _usage ;;
        case _ if any(str(sys.argv[1]) == "-h", str(sys.argv[1]) == "--help"):
            _run("_usage")
        # bash: *) echo "Unknown flag: $1" >&2; _usage ;;
        case _:
            _run("echo \"Unknown flag: " + (sys.argv[1]) + "\" >&2")
            _run("_usage")

# bash: bet_target="$BET_STRATEGY"
bet_target = BET_STRATEGY
# bash: STOP_BALANCE=
STOP_BALANCE = ""


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
# bash: threshold_low=$(mth "$WIN_CHANCE*100" 0 d)
threshold_low = _sh("mth \"$WIN_CHANCE*100\" 0 d")
# bash: threshold_high=$(mth "(100-$WIN_CHANCE)*100" 0 d)
threshold_high = _sh("mth \"(100-$WIN_CHANCE)*100\" 0 d")
# bash: balance=$START_BALANCE
balance = START_BALANCE
# bash: nextbet=$BASE_BET
nextbet = BASE_BET
# bash: wagered=0
wagered = 0
# bash: total_profit=0
total_profit = 0
# bash: round=0
round = 0
# bash: win_count=0
win_count = 0
# bash: win_streak=0
win_streak = 0
# bash: lose_count=0
lose_count = 0
# bash: loss_streak=0
loss_streak = 0
# bash: max_loss_streak=0
max_loss_streak = 0
# bash: last_roll=0
last_roll = 0

# bash: rare_number9900x=0
rare_number9900x = 0
# bash: rare_number4950x=0
rare_number4950x = 0
# bash: rare_number3300x=0
rare_number3300x = 0
# bash: rare_number2475x=0
rare_number2475x = 0
# bash: rare_number1980x=0
rare_number1980x = 0
# bash: rare_number1650x=0
rare_number1650x = 0
# bash: rare_number1414x=0
rare_number1414x = 0
# bash: rare_number1237x=0
rare_number1237x = 0
# bash: rare_number1100x=0
rare_number1100x = 0
# bash: rare_number990x=0
rare_number990x = 0
# bash: wrong_side=0
wrong_side = 0

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
    # bash: last_roll="$roll"
    last_roll = roll

    # bash: if [[ "$bet_target" == "low" ]]; then
    if str(bet_target) == "low":
        # bash: if (( roll < threshold_low )); then
        if _ok("(( roll < threshold_low ))"):
            # bash: result="win"
            result = "win"
        # bash: else
        else:
            # bash: result="lose"
            result = "lose"
            # ตรวจจับว่าถ้าแทง Low แต่ดันไปออกแต้มฝั่ง High (Wrong side)
            # bash: (( roll >= threshold_high )) && (( wrong_side++ ))
            _run("(( roll >= threshold_high )) && (( wrong_side++ ))")
    # bash: else # bet_target == "high"
    else:
        # bash: if (( roll >= threshold_high )); then
        if _ok("(( roll >= threshold_high ))"):
            # bash: result="win"
            result = "win"
        # bash: else
        else:
            # bash: result="lose"
            result = "lose"
            # ตรวจจับว่าถ้าแทง High แต่ดันไปออกแต้มฝั่ง Low (Wrong side)
            # bash: (( roll < threshold_low )) && (( wrong_side++ ))
            _run("(( roll < threshold_low )) && (( wrong_side++ ))")

# ─────────────────────────────────────────
# [5] MARTINGALE LOGIC
# ─────────────────────────────────────────
# bash: dobet() {
def dobet():

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
        # bash: total_profit=$(fsub "$balance" "$START_BALANCE")
        total_profit = _sh("fsub \"$balance\" \"$START_BALANCE\"")
        # bash: nextbet=$BASE_BET
        nextbet = BASE_BET
        # bash: loss_streak=0
        loss_streak = 0
        # bash: ((win_count++))
        win_count += 1
        # bash: ((win_streak++))
        win_streak += 1
    # bash: else
    else:
        # LOSE: เสียเงินเดิมพัน, ทบเงินด้วย LOSEMUL

        # bash: balance=$(fsub "$balance" "$bet")
        balance = _sh("fsub \"$balance\" \"$bet\"")
        # bash: nextbet=$(fmul "$bet" "$LOSEMUL")
        nextbet = _sh("fmul \"$bet\" \"$LOSEMUL\"")
        # bash: total_profit=$(fsub "$balance" "$START_BALANCE")
        total_profit = _sh("fsub \"$balance\" \"$START_BALANCE\"")
        # bash: win_streak=0
        win_streak = 0
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
# bash: stop_condition() {
def stop_condition():


    # bash: local nextbet=$nextbet
    nextbet = nextbet
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
    # bash: if fgt "$nextbet" "$balance"; then
    if _ok("fgt \"" + str(nextbet) + "\" \"" + str(balance) + "\""):
        # bash: echo "BET_GT_BAL: bet=$nextbet balance=$balance"
        print(f"BET_GT_BAL: bet={nextbet} balance={balance}")
        # bash: return 0
        return 0

    # bash: if fgte "$total_profit" "$STOP_PROFIT"; then
    if _ok("fgte \"" + str(total_profit) + "\" \"" + str(STOP_PROFIT) + "\""):
        # bash: echo "PROFIT REACHED: $STOP_PROFIT"
        print(f"PROFIT REACHED: {STOP_PROFIT}")
        # bash: return 0
        return 0

    # bash: if fgte "$wagered" "$WARGER_TARGET"; then
    if _ok("fgte \"" + str(wagered) + "\" \"" + str(WARGER_TARGET) + "\""):
        # bash: echo "WARGER REACHED: $WARGER_TARGET"
        print(f"WARGER REACHED: {WARGER_TARGET}")
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
    # bash: local total_profit="$4"
    total_profit = sys.argv[4]
    # bash: local icon r_fmt roll_fmt amt_fmt bal_fmt stk_fmt roll_c
    _run("icon r_fmt roll_fmt amt_fmt bal_fmt stk_fmt roll_c")

    # 1. Format ความกว้างตัวเลขก่อนระบายสี
    # bash: printf -v r_fmt    "%3d"   "$round"
    print("-v" % ("r_fmt", "%3d", round))
    # bash: printf -v roll_fmt "%4d"   "$roll"
    print("-v" % ("roll_fmt", "%4d", roll))
    # bash: printf -v bal_fmt  "%13.8f" "$balance"
    print("-v" % ("bal_fmt", "%13.8f", balance))
    # bash: printf -v stk_fmt  "%2d"   "$loss_streak"
    print("-v" % ("stk_fmt", "%2d", loss_streak))

    # bash: if fgt "$START_BALANCE" "$balance" ; then
    if _ok("fgt \"" + str(START_BALANCE) + "\" \"" + str(balance) + "\""):
        # bash: local bal_c=$(cn 124 b "$bal_fmt")
        bal_c = _sh("cn 124 b \"$bal_fmt\"")
    # bash: else
    else:
        # bash: local bal_c=$(cn 28 b "$bal_fmt")
        bal_c = _sh("cn 28 b \"$bal_fmt\"")

    # bash: if [[ "$result" == "win" ]]; then
    if str(result) == "win":
        # bash: printf -v amt_fmt "%13.8f" "$win_amount"
        print("-v" % ("amt_fmt", "%13.8f", win_amount))
        # bash: icon="$(+c "WIN ")"
        icon = _sh("+c \"WIN \"")
        # bash: roll_c="$(+c "$roll_fmt")"
        roll_c = _sh("+c \"$roll_fmt\"")
        # bash: local amt_c="$(+c "+$amt_fmt")"
        amt_c = _sh("+c \"+$amt_fmt\"")
        # bash: local profit_c="$(+c "+$total_profit")"
        profit_c = _sh("+c \"+$total_profit\"")

        # Print ออกมาด้วย %s สบายๆ ไม่เบี้ยวแน่นอน
        # bash: printf -v _data "[%s] | R: %s | %s | won:%s | $(+c "Profit:") %s\n"              "$r_fmt" "$roll_c" "$icon" "$amt_c" "$profit_c"
        print("-v" % ("_data", glob.glob("[%s] | R: %s | %s | won:%s | " + (_sh("+c \"Profit:\"")) + " %s\\n"), r_fmt, roll_c, icon, amt_c, profit_c))

        # bash: printf "%s" "$_data"
        print("%s" % (_data,))
    # bash: else
    else:
        # bash: printf -v amt_fmt "%10.8f" "$bet"
        print("-v" % ("amt_fmt", "%10.8f", bet))
        # bash: icon="$(-c "LOSS")"
        icon = _sh("-c \"LOSS\"")
        # bash: local amt_c="$amt_fmt"
        amt_c = amt_fmt

        # ตรวจจับ wrong side เพื่อ highlight roll number (Cyan 45)
        # bash: if [[ "$bet_target" == "low" ]] && (( roll >= threshold_high )); then
        if (str(bet_target) == "low" and _ok("(( roll >= threshold_high ))")):
            # bash: roll_c="$(cn 45 b "$roll_fmt")"
            roll_c = _sh("cn 45 b \"$roll_fmt\"")
    # bash: elif [[ "$bet_target" == "high" ]] && (( roll < threshold_low )); then
    elif (str(bet_target) == "high" and _ok("(( roll < threshold_low ))")):
        # bash: roll_c="$(cn 45 b "$roll_fmt")"
        roll_c = _sh("cn 45 b \"$roll_fmt\"")
    # bash: else
    else:
        # bash: roll_c="$(cn 245 d "$roll_fmt")"
        roll_c = _sh("cn 245 d \"$roll_fmt\"")

    # bash: printf "[%s] | R: %s | %s | Bet: %s | Bal: %s | Stk: %s\n"              "$r_fmt" "$roll_c" "$icon" "$amt_c" "$bal_c" "$stk_fmt"
    print("[%s] | R: %s | %s | Bet: %s | Bal: %s | Stk: %s\n" % (r_fmt, roll_c, icon, amt_c, bal_c, stk_fmt))

# ─────────────────────────────────────────
# [7.1] RARE NUMBER HUNT
# ─────────────────────────────────────────
# bash: hunting(){
def hunting():
    # 1. นับ rare number
    # bash: local last_roll="$1"
    last_roll = sys.argv[1]

    # bash: if (( last_roll == 9999 || last_roll == 0 )); then
    if _ok("(( last_roll == 9999") or _ok("last_roll == 0 ))"):
        # bash: (( rare_number9900x++ ))
        rare_number9900x += 1
# bash: elif (( last_roll == 9998 || last_roll == 1 )); then
elif _ok("(( last_roll == 9998") or _ok("last_roll == 1 ))"):
    # bash: (( rare_number4950x++ ))
    rare_number4950x += 1
# bash: elif (( last_roll == 9997 || last_roll == 2 )); then
elif _ok("(( last_roll == 9997") or _ok("last_roll == 2 ))"):
    # bash: (( rare_number3300x++ ))
    rare_number3300x += 1
# bash: elif (( last_roll == 9996 || last_roll == 3 )); then
elif _ok("(( last_roll == 9996") or _ok("last_roll == 3 ))"):
    # bash: (( rare_number2475x++ ))
    rare_number2475x += 1
# bash: elif (( last_roll == 9995 || last_roll == 4 )); then
elif _ok("(( last_roll == 9995") or _ok("last_roll == 4 ))"):
    # bash: (( rare_number1980x++ ))
    rare_number1980x += 1
# bash: elif (( last_roll == 9994 || last_roll == 5 )); then
elif _ok("(( last_roll == 9994") or _ok("last_roll == 5 ))"):
    # bash: (( rare_number1650x++ ))
    rare_number1650x += 1
# bash: elif (( last_roll == 9993 || last_roll == 6 )); then
elif _ok("(( last_roll == 9993") or _ok("last_roll == 6 ))"):
    # bash: (( rare_number1414x++ ))
    rare_number1414x += 1
# bash: elif (( last_roll == 9992 || last_roll == 7 )); then
elif _ok("(( last_roll == 9992") or _ok("last_roll == 7 ))"):
    # bash: (( rare_number1237x++ ))
    rare_number1237x += 1
# bash: elif (( last_roll == 9991 || last_roll == 8 )); then
elif _ok("(( last_roll == 9991") or _ok("last_roll == 8 ))"):
    # bash: (( rare_number1100x++ ))
    rare_number1100x += 1
# bash: elif (( last_roll == 9990 || last_roll == 9 )); then
elif _ok("(( last_roll == 9990") or _ok("last_roll == 9 ))"):
    # bash: (( rare_number990x++ ))
    rare_number990x += 1
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
    # bash: if (( win_count >= STOP_ON_WIN )); then
    if _ok("(( win_count >= STOP_ON_WIN ))"):
        # bash: stop_reason="WIN LIMIT: reached $STOP_ON_WIN wins"
        stop_reason = f"WIN LIMIT: reached {STOP_ON_WIN} wins"
        # bash: break
        break

    # ตรวจสอบเงื่อนไขหยุดก่อนเดิมพัน
    # bash: if stop_reason=$(stop_condition); then
    if _ok("stop_reason=" + (_sh("stop_condition"))):
        # bash: break
        break

    # bash: ((round++))
    round += 1
    # bash: wagered=$(fadd "$wagered" "$nextbet")
    wagered = _sh("fadd \"$wagered\" \"$nextbet\"")

    # --- roll dice ---
    # bash: roll_dice   # -- result stored in $result and $last_roll ---
    _run("roll_dice")
    # --- apply martingale ---
    # bash: dobet "$result" "$nextbet"
    _run("dobet \"" + str(result) + "\" \"" + str(nextbet) + "\"")
    # --- hunting ---
    # bash: hunting "$last_roll"
    _run("hunting \"" + str(last_roll) + "\"")
    # --- print round ---
    # bash: print_round "$last_roll" "$result" "$nextbet" "$total_profit"
    _run("print_round \"" + str(last_roll) + "\" \"" + str(result) + "\" \"" + str(nextbet) + "\" \"" + str(total_profit) + "\"")

# ─────────────────────────────────────────
# [9] SESSION SUMMARY
# ─────────────────────────────────────────

# -- dynamic color --
# bash: if fgt "$total_profit" "0"; then
if _ok("fgt \"" + str(total_profit) + "\" \"0\""):
    # bash: profit_c="$(+c "+$total_profit")"
    profit_c = _sh("+c \"+$total_profit\"")
    # bash: bal_c="$(+c "$balance")"
    bal_c = _sh("+c \"$balance\"")
# bash: elif fgt "0" "$total_profit"; then
elif _ok("fgt \"0\" \"" + str(total_profit) + "\""):
    # bash: profit_c="$(-c "$total_profit")"
    profit_c = _sh("-c \"$total_profit\"")
    # bash: bal_c="$(-c "$balance")"
    bal_c = _sh("-c \"$balance\"")
# bash: else
else:
    # bash: profit_c="$(_gr "$total_profit")"
    profit_c = _sh("_gr \"$total_profit\"")
    # bash: bal_c="$(_gr "$balance")"
    bal_c = _sh("_gr \"$balance\"")
# bash: wagered_c="$(cn 245 b "$wagered")"
wagered_c = _sh("cn 245 b \"$wagered\"")

# bash: echo ""
print("")
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")
# bash: cn 255 b "  SESSION SUMMARY"
_run("cn 255 b \"  SESSION SUMMARY\"")
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")
# bash: printf "  $(_wc 'Rounds'): %d  $(+c 'W'): %d  $(-c 'L'): %d  $(_wc 'MaxStreak'): %d\n"      "$round" "$win_count" "$lose_count" "$max_loss_streak"
print("  " + (_sh("_wc 'Rounds'")) + ": %d  " + (_sh("+c 'W'")) + ": %d  " + (_sh("-c 'L'")) + ": %d  " + (_sh("_wc 'MaxStreak'")) + ": %d\\n", round, win_count, lose_count, max_loss_streak)

# bash: printf "  $(_wc 'Final Balance'): %s\n" "$bal_c"
print("  " + (_sh("_wc 'Final Balance'")) + ": %s\\n", bal_c)
# bash: printf "  $(_wc 'Net PnL'): %s\n" "$profit_c"
print("  " + (_sh("_wc 'Net PnL'")) + ": %s\\n", profit_c)
# bash: printf "  $(_wc 'Wagered'): %s\n" "$wagered_c"
print("  " + (_sh("_wc 'Wagered'")) + ": %s\\n", wagered_c)

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
    # bash: _gr "  Result: BREAK EVEN"
    _run("_gr \"  Result: BREAK EVEN\"")


# bash: [[ -n "$stop_reason" ]] && cn 45 b "  Stop Reason: $stop_reason"
_run("[[ -n \"" + str(stop_reason) + "\" ]] && cn 45 b \"  Stop Reason: " + str(stop_reason) + "\"")
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")
# bash: printf "  $(+c "Rare Number")\n"
print("  $(+c Rare" % ("Number)\\n",))
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")
# bash: printf "  $(_wc "9900x"): %d\n" "$rare_number9900x"
print("  " + (_sh("_wc \"9900x\"")) + ": %d\\n", rare_number9900x)
# bash: printf "  $(_wc "4950x"): %d\n" "$rare_number4950x"
print("  " + (_sh("_wc \"4950x\"")) + ": %d\\n", rare_number4950x)
# bash: printf "  $(_wc "3300x"): %d\n" "$rare_number3300x"
print("  " + (_sh("_wc \"3300x\"")) + ": %d\\n", rare_number3300x)
# bash: printf "  $(_wc "2475x"): %d\n" "$rare_number2475x"
print("  " + (_sh("_wc \"2475x\"")) + ": %d\\n", rare_number2475x)
# bash: printf "  $(_wc "1980x"): %d\n" "$rare_number1980x"
print("  " + (_sh("_wc \"1980x\"")) + ": %d\\n", rare_number1980x)
# bash: printf "  $(_wc "1650x"): %d\n" "$rare_number1650x"
print("  " + (_sh("_wc \"1650x\"")) + ": %d\\n", rare_number1650x)
# bash: printf "  $(_wc "1414x"): %d\n" "$rare_number1414x"
print("  " + (_sh("_wc \"1414x\"")) + ": %d\\n", rare_number1414x)
# bash: printf "  $(_wc "1237x"): %d\n" "$rare_number1237x"
print("  " + (_sh("_wc \"1237x\"")) + ": %d\\n", rare_number1237x)
# bash: printf "  $(_wc "1100x"): %d\n" "$rare_number1100x"
print("  " + (_sh("_wc \"1100x\"")) + ": %d\\n", rare_number1100x)
# bash: printf "  $(_wc "990x"): %d\n" "$rare_number990x"
print("  " + (_sh("_wc \"990x\"")) + ": %d\\n", rare_number990x)
# bash: printf "  $(+c "wrong_side"): %d\n" "$wrong_side"
print("  " + (_sh("+c \"wrong_side\"")) + ": %d\\n", wrong_side)
# bash: echo " "
print(" ")
# bash: cn 136 b "=========================================================================="
_run("cn 136 b \"==========================================================================\"")
