#!/usr/bin/env python3


import subprocess


def _run(cmd):
    """รันคำสั่ง shell ตรงๆ แล้วคืน exit status (ใช้กับคำสั่งที่ไม่ได้แปลงเป็น python) """
    return subprocess.run(cmd, shell=True).returncode


def _sh(cmd):
    """รันคำสั่ง shell แล้วคืนผลลัพธ์ stdout (เทียบเท่า $(...) ใน bash) """
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.rstrip("\n")


def _ok(cmd):
    """คืน True เมื่อคำสั่ง exit status = 0 (เทียบเท่าการเช็ค condition ใน if) """
    return subprocess.run(cmd, shell=True).returncode == 0




# bash: set -u
# TODO: 'set' ไม่มีใน python ตรงตัว: set -u

# ============================================================
# FUSION BOT v4.0 - Bash Simulation
# ============================================================

# ============================================================
# CONFIGURATION
# ============================================================

# bash: main_mode=1
main_mode = 1  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# -----------------------------
# WAGER MODE
# -----------------------------

# bash: wager_chance=99
wager_chance = 99  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: wager_bet_percent=4.0
wager_bet_percent = 4.0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: loss_cut_percent=4.0
loss_cut_percent = 4.0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: recover_profit_percent=1
recover_profit_percent = 1  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: wager_target=50.00
wager_target = 50.00  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: enable_wager_target=true
enable_wager_target = "true"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# -----------------------------
# PROFIT MODE
# -----------------------------

# bash: auto_chance=false
auto_chance = "false"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: chance_min=0.5
chance_min = 0.5  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: chance_max=0.75
chance_max = 0.75  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: chance_fixed=35
chance_fixed = 35  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: random_on_win=true
random_on_win = "true"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: random_on_lose=false
random_on_lose = "false"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# -----------------------------
# MULTIPLIER / BASE
# -----------------------------

# bash: risk_bonus_percent=10.0
risk_bonus_percent = 10.0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: house_edge=1.0
house_edge = 1.0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: allowed_losses=12
allowed_losses = 12  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: bethigh=true
bethigh = "true"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: auto_switch=true
auto_switch = "true"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: switch_on_win=false
switch_on_win = "false"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: switch_on_lose=false
switch_on_lose = "false"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# -----------------------------
# STOP RULES
# -----------------------------

# bash: stop_profit_target=0.2
stop_profit_target = 0.2  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: stop_loss_limit=0
stop_loss_limit = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: stop_max_loss_streak=0
stop_max_loss_streak = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: min_bet_size=0.00000001
min_bet_size = 0.00000001  # กำหนดค่าตัวแปร (ไม่ต้องมี export)


# ============================================================
# GLOBAL VARIABLES
# ============================================================

# bash: mode="wager"
mode = "wager"  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: start_balance=100.00
start_balance = 100.00  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: balance="$start_balance"
balance = start_balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: session_start=$(date +%s)
session_start = _sh("date +%s")  # กำหนดค่าตัวแปร (ไม่ต้องมี export); $(cmd) -> _sh() (subprocess)

# bash: total_wagered=0
total_wagered = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: win_count=0
win_count = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: lose_count=0
lose_count = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: loss_streak=0
loss_streak = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: max_loss_streak=0
max_loss_streak = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: wager_base_bet=0
wager_base_bet = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: consecutive_losses_in_cycle=0
consecutive_losses_in_cycle = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: working_balance="$balance"
working_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: profit_vault=0
profit_vault = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: cycle_start_balance="$balance"
cycle_start_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: original_cycle_balance="$balance"
original_cycle_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: wager_cycle_start="$balance"
wager_cycle_start = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: profit_cycle_start="$balance"
profit_cycle_start = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: wager_loss_amount=0
wager_loss_amount = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# จำลอง previousbalance
# bash: last_balance="$balance"
last_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)


# ============================================================
# UTILITY FUNCTIONS
# ============================================================

# bash: float_add() {
def float_add():  # ฟังก์ชัน bash -> def name():
    # bash: awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a + b }'
    _run("awk -v a=\"" + str(1) + "\" -v b=\"" + str(2) + "\" 'BEGIN { printf \"%.8f\", a + b }")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }

# bash: float_sub() {
def float_sub():  # ฟังก์ชัน bash -> def name():
    # bash: awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a - b }'
    _run("awk -v a=\"" + str(1) + "\" -v b=\"" + str(2) + "\" 'BEGIN { printf \"%.8f\", a - b }")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }

# bash: float_mul() {
def float_mul():  # ฟังก์ชัน bash -> def name():
    # bash: awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a * b }'
    _run("awk -v a=\"" + str(1) + "\" -v b=\"" + str(2) + "\" 'BEGIN { printf \"%.8f\", a * b }")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }

# bash: float_div() {
def float_div():  # ฟังก์ชัน bash -> def name():
    # bash: awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a / b }'
    _run("awk -v a=\"" + str(1) + "\" -v b=\"" + str(2) + "\" 'BEGIN { printf \"%.8f\", a / b }")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }

# bash: float_gte() {
def float_gte():  # ฟังก์ชัน bash -> def name():
    # bash: awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
    _run("awk -v a=\"" + str(1) + "\" -v b=\"" + str(2) + "\" 'BEGIN { exit !(a >= b) }")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }

# bash: float_gt() {
def float_gt():  # ฟังก์ชัน bash -> def name():
    # bash: awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'
    _run("awk -v a=\"" + str(1) + "\" -v b=\"" + str(2) + "\" 'BEGIN { exit !(a > b) }")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }


# ============================================================
# SWITCH MODE
# ============================================================

# bash: switch_mode() {
def switch_mode():  # ฟังก์ชัน bash -> def name():

    # bash: local new_mode="$1"
    new_mode = 1  # python ไม่มี local

    # bash: mode="$new_mode"
    mode = new_mode  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

    # bash: loss_streak=0
    loss_streak = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
    # bash: consecutive_losses_in_cycle=0
    consecutive_losses_in_cycle = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

    # bash: if [[ "$mode" == "wager" ]]; then
    if str(mode) == "wager":  # ใส่ : แทน then

        # bash: echo "🟢 เข้าสู่โหมด WAGERING"
        print("\ud83d\udfe2 \u0e40\u0e02\u0e49\u0e32\u0e2a\u0e39\u0e48\u0e42\u0e2b\u0e21\u0e14 WAGERING")  # echo -> print()

        # bash: working_balance="$balance"
        working_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

        # bash: wager_cycle_start="$balance"
        wager_cycle_start = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: wager_loss_amount=0
        wager_loss_amount = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

        # bash: wager_base_bet=$(
        wager_base_bet = "$("  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: float_mul                  "$wager_cycle_start"                  "$(float_div "$wager_bet_percent" 100)"
        _run("float_mul                  \"" + str(wager_cycle_start) + "\"                  \"" + (_sh("float_div \"$wager_bet_percent\" 100")) + "\"")  # $(cmd) -> _sh() (subprocess); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
        # bash: )
        _run(")")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

        # bash: chance="$wager_chance"
        chance = wager_chance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: nextbet="$wager_base_bet"
        nextbet = wager_base_bet  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

        # bash: printf '   📍 Wager Cycle Start: %.8f\n'              "$wager_cycle_start"
        print("   \ud83d\udccd Wager Cycle Start: %.8f\n" % (wager_cycle_start,))  # printf -> print() + % format

        # bash: printf '   💰 Wager Base Bet: %.8f (%.2f%%)\n'              "$wager_base_bet"              "$wager_bet_percent"
        print("   \ud83d\udcb0 Wager Base Bet: %.8f (%.2f%%)\n" % (wager_base_bet, wager_bet_percent))  # printf -> print() + % format

    # bash: else
    else:  # else: (ไม่ต้องมี then)

        # bash: echo "🟡 เข้าสู่ PROFIT MODE"
        print("\ud83d\udfe1 \u0e40\u0e02\u0e49\u0e32\u0e2a\u0e39\u0e48 PROFIT MODE")  # echo -> print()

        # bash: profit_cycle_start="$balance"
        profit_cycle_start = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: cycle_start_balance="$balance"
        cycle_start_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

        # bash: local loss_percent
        _run("loss_percent")  # python ไม่มี local; คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

        # bash: loss_percent=$(
        loss_percent = "$("  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: float_mul                  "$(float_div "$wager_loss_amount" "$original_cycle_balance")"                  100
        _run("float_mul                  \"" + (_sh("float_div \"$wager_loss_amount\" \"$original_cycle_balance\"")) + "\"                  100")  # $(cmd) -> _sh() (subprocess); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
        # bash: )
        _run(")")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

        # bash: printf '   📍 Profit Cycle Start: %.8f\n'              "$profit_cycle_start"
        print("   \ud83d\udccd Profit Cycle Start: %.8f\n" % (profit_cycle_start,))  # printf -> print() + % format

        # bash: printf '   💸 Wager Loss: %.8f (%.2f%%)\n'              "$wager_loss_amount"              "$loss_percent"
        print("   \ud83d\udcb8 Wager Loss: %.8f (%.2f%%)\n" % (wager_loss_amount, loss_percent))  # printf -> print() + % format

        # bash: nextbet=$(
        nextbet = "$("  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: float_mul "$profit_cycle_start" 0.01
        _run("float_mul \"" + str(profit_cycle_start) + "\" 0.01")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
        # bash: )
        _run(")")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

        # bash: if ! float_gte "$nextbet" "$min_bet_size"; then
        if not (_ok("float_gte \"" + str(nextbet) + "\" \"" + str(min_bet_size) + "\"")):  # ใส่ : แทน then
            # bash: nextbet="$min_bet_size"
            nextbet = min_bet_size  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: fi
        # -> จบ if — python เยื้องกลับ (dedent) แทน fi
    # bash: fi
    # -> จบ if — python เยื้องกลับ (dedent) แทน fi
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }


# ============================================================
# PROFIT SEPARATION
# ============================================================

# bash: separate_profit_and_reset_cycle() {
def separate_profit_and_reset_cycle():  # ฟังก์ชัน bash -> def name():

    # bash: local cycle_profit
    _run("cycle_profit")  # python ไม่มี local; คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

    # bash: cycle_profit=$(
    cycle_profit = "$("  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
    # bash: float_sub "$balance" "$original_cycle_balance"
    _run("float_sub \"" + str(balance) + "\" \"" + str(original_cycle_balance) + "\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
    # bash: )
    _run(")")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

    # bash: if float_gt "$cycle_profit" 0; then
    if _ok("float_gt \"" + str(cycle_profit) + "\" 0"):  # ใส่ : แทน then

        # bash: profit_vault=$(
        profit_vault = "$("  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: float_add "$profit_vault" "$cycle_profit"
        _run("float_add \"" + str(profit_vault) + "\" \"" + str(cycle_profit) + "\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
        # bash: )
        _run(")")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

        # bash: echo "💰 ═══════════════════════════════════════"
        print("\ud83d\udcb0 \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550")  # echo -> print()

        # bash: printf '✅ Cycle Complete! Profit: %.8f\n'              "$cycle_profit"
        print("\u2705 Cycle Complete! Profit: %.8f\n" % (cycle_profit,))  # printf -> print() + % format

        # bash: printf '🏦 Profit Vault: %.8f (Total)\n'              "$profit_vault"
        print("\ud83c\udfe6 Profit Vault: %.8f (Total)\n" % (profit_vault,))  # printf -> print() + % format

        # bash: printf '🔄 Reset to Original: %.8f\n'              "$original_cycle_balance"
        print("\ud83d\udd04 Reset to Original: %.8f\n" % (original_cycle_balance,))  # printf -> print() + % format

        # bash: echo "💰 ═══════════════════════════════════════"
        print("\ud83d\udcb0 \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550")  # echo -> print()

        # bash: balance="$original_cycle_balance"
        balance = original_cycle_balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: working_balance="$original_cycle_balance"
        working_balance = original_cycle_balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

        # bash: wager_cycle_start="$original_cycle_balance"
        wager_cycle_start = original_cycle_balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: profit_cycle_start="$original_cycle_balance"
        profit_cycle_start = original_cycle_balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

        # bash: total_wagered=0
        total_wagered = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: wager_loss_amount=0
        wager_loss_amount = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

        # bash: loss_streak=0
        loss_streak = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: max_loss_streak=0
        max_loss_streak = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

        # จำลอง resetseed
        # bash: echo "♻️ Variables reset — new cycle will start fresh."
        print("\u267b\ufe0f Variables reset \u2014 new cycle will start fresh.")  # echo -> print()

    # bash: else
    else:  # else: (ไม่ต้องมี then)

        # bash: printf              '⚠️ Cycle ended without profit (%.8f)\n'              "$cycle_profit"
        print("\u26a0\ufe0f Cycle ended without profit (%.8f)\n" % (cycle_profit,))  # printf -> print() + % format

        # bash: working_balance="$balance"
        working_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
    # bash: fi
    # -> จบ if — python เยื้องกลับ (dedent) แทน fi
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }


# ============================================================
# INITIALIZATION
# ============================================================

# bash: echo "🎬 FUSION BOT v4.0 - Bash Simulation"
print("\ud83c\udfac FUSION BOT v4.0 - Bash Simulation")  # echo -> print()

# bash: printf '💵 Start Balance: %.8f\n' "$balance"
print("\ud83d\udcb5 Start Balance: %.8f\n" % (balance,))  # printf -> print() + % format

# bash: working_balance="$balance"
working_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: cycle_start_balance="$balance"
cycle_start_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
# bash: original_cycle_balance="$balance"
original_cycle_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

# bash: switch_mode "wager"
_run("switch_mode \"wager\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell


# ============================================================
# DO BET
# ============================================================

# bash: do_bet() {
def do_bet():  # ฟังก์ชัน bash -> def name():

    # bash: local previous_bet="$1"
    previous_bet = 1  # python ไม่มี local
    # bash: local result="$2"
    result = 2  # python ไม่มี local

    # ----------------------------------------
    # total_wagered += previousbet
    # ----------------------------------------

    # bash: total_wagered=$(
    total_wagered = "$("  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
    # bash: float_add "$total_wagered" "$previous_bet"
    _run("float_add \"" + str(total_wagered) + "\" \"" + str(previous_bet) + "\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
    # bash: )
    _run(")")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

    # bash: working_balance="$balance"
    working_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)


    # ========================================================
    # WIN
    # ========================================================

    # bash: if [[ "$result" == "win" ]]; then
    if str(result) == "win":  # ใส่ : แทน then

        # bash: ((win_count++))
        win_count += 1

        # bash: loss_streak=0
        loss_streak = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: consecutive_losses_in_cycle=0
        consecutive_losses_in_cycle = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

        # bash: if [[ "$mode" == "wager" ]]; then
        if str(mode) == "wager":  # ใส่ : แทน then
            # bash: nextbet="$wager_base_bet"
            nextbet = wager_base_bet  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
        # bash: fi
        # -> จบ if — python เยื้องกลับ (dedent) แทน fi


        # ========================================================
        # LOSS
        # ========================================================

    # bash: else
    else:  # else: (ไม่ต้องมี then)

        # bash: ((lose_count++))
        lose_count += 1

        # bash: ((loss_streak++))
        loss_streak += 1
        # bash: ((consecutive_losses_in_cycle++))
        consecutive_losses_in_cycle += 1


        # bash: if [[ "$mode" == "wager" ]]; then
        if str(mode) == "wager":  # ใส่ : แทน then

            # ----------------------------------------
            # จำลอง previousbalance
            # ----------------------------------------

            # bash: local prev_balance="$last_balance"
            prev_balance = last_balance  # python ไม่มี local

            # bash: local real_loss_value
            _run("real_loss_value")  # python ไม่มี local; คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

            # bash: real_loss_value=$(
            real_loss_value = "$("  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
            # bash: float_sub                      "$wager_cycle_start"                      "$prev_balance"
            _run("float_sub                      \"" + str(wager_cycle_start) + "\"                      \"" + str(prev_balance) + "\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
            # bash: )
            _run(")")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell


            # bash: local real_loss_percent
            _run("real_loss_percent")  # python ไม่มี local; คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

            # bash: real_loss_percent=$(
            real_loss_percent = "$("  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
            # bash: float_mul                      "$(float_div                          "$real_loss_value"                          "$wager_cycle_start")"                      100
            _run("float_mul                      \"" + (_sh("float_div                          \"$real_loss_value\"                          \"$wager_cycle_start\"")) + "\"                      100")  # $(cmd) -> _sh() (subprocess); คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
            # bash: )
            _run(")")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell


            # bash: printf                  '📉 Wager Loss: %.2f%% / %.2f%%\n'                  "$real_loss_percent"                  "$loss_cut_percent"
            print("\ud83d\udcc9 Wager Loss: %.2f%% / %.2f%%\n" % (real_loss_percent, loss_cut_percent))  # printf -> print() + % format


            # ----------------------------------------
            # TRUE LOSS DETECTION
            # ----------------------------------------

            # bash: then
            if (int(main_mode) == 1 and _ok("float_gte                     \"" + str(real_loss_percent) + "\"                     \"" + str(loss_cut_percent) + "\"")):  # ใส่ : แทน then

                # bash: wager_loss_amount="$real_loss_value"
                wager_loss_amount = real_loss_value  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

                # bash: printf                      '🚨 TRUE LOSS %.2f%% (%.8f) → Switching to Profit Mode\n'                      "$real_loss_percent"                      "$wager_loss_amount"
                print("\ud83d\udea8 TRUE LOSS %.2f%% (%.8f) \u2192 Switching to Profit Mode\n" % (real_loss_percent, wager_loss_amount))  # printf -> print() + % format

                # clear bet queue
                # bash: nextbet=0
                nextbet = 0  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

                # bash: switch_mode "profit"
                _run("switch_mode \"profit\"")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

            # bash: else
            else:  # else: (ไม่ต้องมี then)

                # bash: nextbet="$wager_base_bet"
                nextbet = wager_base_bet  # กำหนดค่าตัวแปร (ไม่ต้องมี export)

            # bash: fi
            # -> จบ if — python เยื้องกลับ (dedent) แทน fi


        # bash: else
        else:  # else: (ไม่ต้องมี then)

            # ----------------------------------------
            # PROFIT MODE
            # ----------------------------------------

            # bash: nextbet=$(
            nextbet = "$("  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
            # bash: float_mul "$profit_cycle_start" 0.01
            _run("float_mul \"" + str(profit_cycle_start) + "\" 0.01")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
            # bash: )
            _run(")")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

        # bash: fi
        # -> จบ if — python เยื้องกลับ (dedent) แทน fi

    # bash: fi
    # -> จบ if — python เยื้องกลับ (dedent) แทน fi


    # ========================================================
    # UPDATE LAST BALANCE
    # ========================================================

    # bash: last_balance="$balance"
    last_balance = balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)


    # ========================================================
    # WAGER TARGET
    # ========================================================

    # bash: then
    if (str(enable_wager_target) == "true" and _ok("float_gte \"" + str(total_wagered) + "\" \"" + str(wager_target) + "\"")):  # ใส่ : แทน then

        # bash: echo "🎯 Wager Target reached! Stopping..."
        print("\ud83c\udfaf Wager Target reached! Stopping...")  # echo -> print()

        # bash: separate_profit_and_reset_cycle
        _run("separate_profit_and_reset_cycle")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell

        # bash: echo "🛑 BOT STOPPED"
        print("\ud83d\uded1 BOT STOPPED")  # echo -> print()

        # bash: return 0
        return 0  # return เหมือนกันใน python
    # bash: fi
    # -> จบ if — python เยื้องกลับ (dedent) แทน fi
# bash: }
# -> จบฟังก์ชัน — python เยื้องกลับแทน }


# ============================================================
# EXAMPLE
# ============================================================

# bash: echo
print()  # echo -> print()
# bash: echo "===== Simulation ====="
print("===== Simulation =====")  # echo -> print()

# bash: echo "Balance : $balance"
print(f"Balance : {balance}")  # echo -> print(); $VAR -> f-string {VAR}
# bash: echo "Mode    : $mode"
print(f"Mode    : {mode}")  # echo -> print(); $VAR -> f-string {VAR}
# bash: echo "Next Bet: $nextbet"
print(f"Next Bet: {nextbet}")  # echo -> print(); $VAR -> f-string {VAR}

# ตัวอย่าง:
#
# bash: do_bet 4.00 loss
_run("do_bet 4.00 loss")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
#
# bash: balance="$new_balance"
balance = new_balance  # กำหนดค่าตัวแปร (ไม่ต้องมี export)
#
# bash: do_bet "$nextbet" win
_run("do_bet \"" + str(nextbet) + "\" win")  # คำสั่งที่ไม่ได้แปลง -> _run() รันผ่าน shell
