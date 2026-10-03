# bash: #!/usr/bin/env bash
#!/usr/bin/env pwsh

# ============================================================
# MARTINGALE DICE SIMULATOR - Guideline / Template
# ============================================================
# Strategy:
#   - lose -> bet x dynamic recovering multiplier (LOSEMUL)
#   - win  -> reset to BASE_BET
# ============================================================
# bash: source $HOME/.bashrc
. "$HOME/.bashrc"  # source -> . (dot-sourcing เหมือนกัน)
# bash: set -u
Set-StrictMode -Version Latest  # set -u -> Set-StrictMode (ใช้ตัวแปรก่อนกำหนดแล้ว error)

# ─────────────────────────────────────────
# [0] HELPER COLOR
# ─────────────────────────────────────────
# bash: _wc() { cn 255 b "$@"; } #white color
function _wc {  # ฟังก์ชัน bash -> function name {
    cn 255 b "$@"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}
# bash: _gr(){ cn 235 d "$@"; } #gray color
function _gr {  # ฟังก์ชัน bash -> function name {
    cn 235 d "$@"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}
# bash: +c(){ cn 82 b "$@"; }  #win color
+c(){ cn 82 b "$@"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}
# bash: -c(){ cn 124 b "$@"; }  #lose color
-c(){ cn 124 b "$@"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# ─────────────────────────────────────────
# [1] CONFIGURATION  (SSOT dice.env + Flag args)
# ─────────────────────────────────────────
# bash: CONFIG_FILE="${SSOT:-$HOME/ssot}/dice.env"
$CONFIG_FILE = "$(($SSOT ?? "$HOME/ssot"))/dice.env"  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
# bash: if [[ -f "$CONFIG_FILE" ]]; then
if (Test-Path $CONFIG_FILE -PathType Leaf) {  # if ...; then -> if (...) {
    # bash: source "$CONFIG_FILE"
    . $CONFIG_FILE  # source -> . (dot-sourcing เหมือนกัน)
# bash: else
} else {  # else -> } else {
    # Fallback defaults if dice.env missing
    # bash: HE=1.0
    $HE = 1.0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: GAME_MODE=3
    $GAME_MODE = 3  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: START_BALANCE=10000
    $START_BALANCE = 10000  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: STOP_PROFIT_TARGET=20.0
    $STOP_PROFIT_TARGET = 20.0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: STOP_LOSS_TARGET=10.0
    $STOP_LOSS_TARGET = 10.0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: BASE_BET=2.0
    $BASE_BET = 2.0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: WIN_CHANCE=3.96
    $WIN_CHANCE = 3.96  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: MAX_ROUNDS=20000
    $MAX_ROUNDS = 20000  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: MAX_LOSS_STREAK=10000
    $MAX_LOSS_STREAK = 10000  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: STOP_ON_WIN=5000
    $STOP_ON_WIN = 5000  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: BET_STRATEGY="high"
    $BET_STRATEGY = 'high'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: LOSS_TRIGGER=2.0
    $LOSS_TRIGGER = 2.0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: PROFIT_TRIGGER=1.0
    $PROFIT_TRIGGER = 1.0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: WAGER_BET="2.5"
    $WAGER_BET = 2.5  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: WAGER_WIN_CHANCE=98.0
    $WAGER_WIN_CHANCE = 98.0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: WAGER_TARGET=200000.0
    $WAGER_TARGET = 200000.0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: WAGER_STOP_ON_WIN=5000
    $WAGER_STOP_ON_WIN = 5000  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# --- flag parser ---
# bash: _usage() {
function _usage {  # ฟังก์ชัน bash -> function name {
    # bash: echo "Usage: $0 [OPTIONS]"
    Write-Output "Usage: $PSCommandPath [OPTIONS]"  # echo -> Write-Output
    # bash: echo "  -m  | --mode           Game mode: 1(profit), 2(wager), 3(hybrid) (default: $GAME_MODE)"
    Write-Output "  -m  | --mode           Game mode: 1(profit), 2(wager), 3(hybrid) (default: $GAME_MODE)"  # echo -> Write-Output
    # bash: echo "  -b  | --basebet        Base bet amount          (default: $BASE_BET)"
    Write-Output "  -b  | --basebet        Base bet amount          (default: $BASE_BET)"  # echo -> Write-Output
    # bash: echo "  -c  | --chance         Win chance % (Profit)    (default: $WIN_CHANCE)"
    Write-Output "  -c  | --chance         Win chance % (Profit)    (default: $WIN_CHANCE)"  # echo -> Write-Output
    # bash: echo "  -wc | --wager-chance   Win chance % (Wager)     (default: $WAGER_WIN_CHANCE)"
    Write-Output "  -wc | --wager-chance   Win chance % (Wager)     (default: $WAGER_WIN_CHANCE)"  # echo -> Write-Output
    # bash: echo "  -sb | --startbalance   Starting balance         (default: $START_BALANCE)"
    Write-Output "  -sb | --startbalance   Starting balance         (default: $START_BALANCE)"  # echo -> Write-Output
    # bash: echo "  -r  | --rounds         Max rounds               (default: $MAX_ROUNDS)"
    Write-Output "  -r  | --rounds         Max rounds               (default: $MAX_ROUNDS)"  # echo -> Write-Output
    # bash: echo "  -ml | --maxloss        Max loss streak          (default: $MAX_LOSS_STREAK)"
    Write-Output "  -ml | --maxloss        Max loss streak          (default: $MAX_LOSS_STREAK)"  # echo -> Write-Output
    # bash: echo "  -sw | --stop-win       Stop profit target       (default: auto calculated)"
    Write-Output '  -sw | --stop-win       Stop profit target       (default: auto calculated)'  # echo -> Write-Output
    # bash: echo "  -sl | --stop-wagered   Wager limit target       (default: $WAGER_TARGET)"
    Write-Output "  -sl | --stop-wagered   Wager limit target       (default: $WAGER_TARGET)"  # echo -> Write-Output
    # bash: echo "  -ow | --on-win         Stop after N wins        (default: $STOP_ON_WIN)"
    Write-Output "  -ow | --on-win         Stop after N wins        (default: $STOP_ON_WIN)"  # echo -> Write-Output
    # bash: echo "  -s  | --strategy       Bet strategy low|high    (default: $BET_STRATEGY)"
    Write-Output "  -s  | --strategy       Bet strategy low|high    (default: $BET_STRATEGY)"  # echo -> Write-Output
    # bash: echo "  -h  | --help           Show this help"
    Write-Output '  -h  | --help           Show this help'  # echo -> Write-Output
    # bash: exit 0
    exit 0  # exit เหมือนกัน
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# bash: CLI_STOP_PROFIT=""
$CLI_STOP_PROFIT = ''  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: CLI_WAGER_TARGET=""
$CLI_WAGER_TARGET = ''  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# bash: while [[ $# -gt 0 ]]; do
while ($args.Count -gt 0) {  # while ...; do -> while (...) {
    # bash: case "$1" in
    switch -Wildcard ($args[0]) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
        # bash: -m|--mode)           GAME_MODE="$2";          shift 2 ;;
        { $_ -eq '-m' -or $_ -eq '--mode' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $GAME_MODE = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -b|--basebet)        BASE_BET="$2";           shift 2 ;;
        { $_ -eq '-b' -or $_ -eq '--basebet' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $BASE_BET = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -c|--chance)         WIN_CHANCE="$2";         shift 2 ;;
        { $_ -eq '-c' -or $_ -eq '--chance' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $WIN_CHANCE = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -wc|--wager-chance)  WAGER_WIN_CHANCE="$2";   shift 2 ;;
        { $_ -eq '-wc' -or $_ -eq '--wager-chance' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $WAGER_WIN_CHANCE = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -sb|--startbalance)  START_BALANCE="$2";      shift 2 ;;
        { $_ -eq '-sb' -or $_ -eq '--startbalance' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $START_BALANCE = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -r|--rounds)         MAX_ROUNDS="$2";         shift 2 ;;
        { $_ -eq '-r' -or $_ -eq '--rounds' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $MAX_ROUNDS = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -ml|--maxloss)       MAX_LOSS_STREAK="$2";    shift 2 ;;
        { $_ -eq '-ml' -or $_ -eq '--maxloss' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $MAX_LOSS_STREAK = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -sw|--stop-win)      CLI_STOP_PROFIT="$2";    shift 2 ;;
        { $_ -eq '-sw' -or $_ -eq '--stop-win' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $CLI_STOP_PROFIT = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -sl|--stop-wagered)  CLI_WAGER_TARGET="$2";   shift 2 ;;
        { $_ -eq '-sl' -or $_ -eq '--stop-wagered' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $CLI_WAGER_TARGET = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -ow|--on-win)        STOP_ON_WIN="$2";        shift 2 ;;
        { $_ -eq '-ow' -or $_ -eq '--on-win' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $STOP_ON_WIN = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -s|--strategy)       BET_STRATEGY="$2";       shift 2 ;;
        { $_ -eq '-s' -or $_ -eq '--strategy' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            $BET_STRATEGY = $args[1]  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # TODO: 'shift' ไม่มีใน pwsh ตรงตัว: shift 2
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -h|--help)           _usage ;;
        { $_ -eq '-h' -or $_ -eq '--help' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            _usage  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: *) echo "Unknown flag: $1" >&2; _usage ;;
        default {  # *) -> default
            echo "Unknown flag: $1" >&2  # >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; $1/$@/$# -> $args[0]/$args/$args.Count; คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
            _usage  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
    # bash: esac
    # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
    }
# bash: done
# -> จบ loop — pwsh ปิดด้วย } แทน done
}

# bash: bet_target="$BET_STRATEGY"
$bet_target = $BET_STRATEGY  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# Dynamic targets calculation based on real START_BALANCE
# bash: if [[ -n "$CLI_STOP_PROFIT" ]]; then
if (-not [string]::IsNullOrEmpty($CLI_STOP_PROFIT)) {  # if ...; then -> if (...) {
    # bash: STOP_PROFIT="$CLI_STOP_PROFIT"
    $STOP_PROFIT = $CLI_STOP_PROFIT  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: else
} else {  # else -> } else {
    # bash: STOP_PROFIT=$(mth "($STOP_PROFIT_TARGET/100)*$START_BALANCE" 8 d)
    $STOP_PROFIT = $(mth "($STOP_PROFIT_TARGET/100)*$START_BALANCE" 8 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# bash: if [[ -n "$CLI_WAGER_TARGET" ]]; then
if (-not [string]::IsNullOrEmpty($CLI_WAGER_TARGET)) {  # if ...; then -> if (...) {
    # bash: WAGER_TARGET="$CLI_WAGER_TARGET"
    $WAGER_TARGET = $CLI_WAGER_TARGET  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# bash: STOP_LOSS=$(mth "($STOP_LOSS_TARGET/100)*$START_BALANCE" 8 d)
$STOP_LOSS = $(mth "($STOP_LOSS_TARGET/100)*$START_BALANCE" 8 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: WAGER_BASE_BET=$(mth "($WAGER_BET/100)*$START_BALANCE" 8 d)
$WAGER_BASE_BET = $(mth "($WAGER_BET/100)*$START_BALANCE" 8 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# bash: TRIGGER_BALANCE=$(mth "(1-($LOSS_TRIGGER/100))*$START_BALANCE" 8 d)
$TRIGGER_BALANCE = $(mth "(1-($LOSS_TRIGGER/100))*$START_BALANCE" 8 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: TRIGGER_BALANCE_PROFIT=$(mth "$START_BALANCE+($PROFIT_TRIGGER/100)*$START_BALANCE" 8 d)
$TRIGGER_BALANCE_PROFIT = $(mth "$START_BALANCE+($PROFIT_TRIGGER/100)*$START_BALANCE" 8 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# Payout & Thresholds for PROFIT MODE
# bash: payout=$(mth "(1-($HE/100))/($WIN_CHANCE/100)" 4 d)
$payout = $(mth "(1-($HE/100))/($WIN_CHANCE/100)" 4 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: profit_win_mul=$(mth "$payout - 1" 4 d)
$profit_win_mul = $(mth "$payout - 1" 4 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: LOSEMUL=$(mth "1 + (1 / ($payout - 1)) + (0.05 / $payout)" 4 d)
$LOSEMUL = $(mth "1 + (1 / ($payout - 1)) + (0.05 / $payout)" 4 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: profit_threshold_low=$(mth "$WIN_CHANCE*100" 0 d)
$profit_threshold_low = $(mth "$WIN_CHANCE*100" 0 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: profit_threshold_high=$(mth "(100-$WIN_CHANCE)*100" 0 d)
$profit_threshold_high = $(mth "(100-$WIN_CHANCE)*100" 0 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# Payout & Thresholds for WAGER MODE
# bash: wager_payout=$(mth "(1-($HE/100))/($WAGER_WIN_CHANCE/100)" 4 d)
$wager_payout = $(mth "(1-($HE/100))/($WAGER_WIN_CHANCE/100)" 4 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: wager_win_mul=$(mth "$wager_payout - 1" 4 d)
$wager_win_mul = $(mth "$wager_payout - 1" 4 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: wager_threshold_low=$(mth "$WAGER_WIN_CHANCE*100" 0 d)
$wager_threshold_low = $(mth "$WAGER_WIN_CHANCE*100" 0 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: wager_threshold_high=$(mth "(100-$WAGER_WIN_CHANCE)*100" 0 d)
$wager_threshold_high = $(mth "(100-$WAGER_WIN_CHANCE)*100" 0 d)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# ─────────────────────────────────────────
# [2] GLOBAL STATE
# ─────────────────────────────────────────
# bash: balance=$START_BALANCE
$balance = $START_BALANCE  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: wagered=0
$wagered = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: total_profit=0
$total_profit = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: round=0
$round = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: win_count=0
$win_count = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: win_streak=0
$win_streak = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: lose_count=0
$lose_count = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: loss_streak=0
$loss_streak = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: max_loss_streak=0
$max_loss_streak = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: last_roll=0
$last_roll = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# Initial Mode & Initial Bet
# bash: if [[ "$GAME_MODE" == "2" ]]; then
if ($GAME_MODE -eq 2) {  # if ...; then -> if (...) {
    # bash: MODE="WAGER"
    $MODE = 'WAGER'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: nextbet=$WAGER_BASE_BET
    $nextbet = $WAGER_BASE_BET  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: elif [[ "$GAME_MODE" == "3" ]]; then
} elseif ($GAME_MODE -eq 3) {  # elif ...; then -> } elseif (...) {
    # bash: MODE="WAGER"
    $MODE = 'WAGER'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: nextbet=$WAGER_BASE_BET
    $nextbet = $WAGER_BASE_BET  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: else
} else {  # else -> } else {
    # bash: MODE="PROFIT"
    $MODE = 'PROFIT'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: nextbet=$BASE_BET
    $nextbet = $BASE_BET  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# bash: rare_number9900x=0
$rare_number9900x = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: rare_number4950x=0
$rare_number4950x = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: rare_number3300x=0
$rare_number3300x = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: rare_number2475x=0
$rare_number2475x = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: rare_number1980x=0
$rare_number1980x = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: rare_number1650x=0
$rare_number1650x = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: rare_number1414x=0
$rare_number1414x = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: rare_number1237x=0
$rare_number1237x = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: rare_number1100x=0
$rare_number1100x = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: rare_number990x=0
$rare_number990x = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: wrong_side=0
$wrong_side = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# ─────────────────────────────────────────
# [3] MATH HELPERS
# ─────────────────────────────────────────
# bash: fadd() {
function fadd {  # ฟังก์ชัน bash -> function name {
    # bash: mth "$1+$2" 8 d
    mth "$1+$2" 8 d  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# bash: fsub() {
function fsub {  # ฟังก์ชัน bash -> function name {
    # bash: mth "$1-$2" 8 d
    mth "$1-$2" 8 d  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# bash: fmul() {
function fmul {  # ฟังก์ชัน bash -> function name {
    # bash: mth "$1*$2" 8 d
    mth "$1*$2" 8 d  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# bash: float_div() {
function float_div {  # ฟังก์ชัน bash -> function name {
    # bash: mth "$1/$2" 8 d
    mth "$1/$2" 8 d  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# bash: fgt() {
function fgt {  # ฟังก์ชัน bash -> function name {
    # bash: awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# bash: fgte() {
function fgte {  # ฟังก์ชัน bash -> function name {
    # bash: awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้); $1/$@/$# -> $args[0]/$args/$args.Count
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# ─────────────────────────────────────────
# [4] ROLL DICE (Mode Aware)
# ─────────────────────────────────────────
# bash: roll_dice() {
function roll_dice {  # ฟังก์ชัน bash -> function name {
    # bash: local mode="$1"
    $mode = $args[0]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local roll
    roll  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
    # bash: roll=$(( RANDOM % 10000 ))
    $roll = ( $RANDOM % 10000 )  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: last_roll="$roll"
    $last_roll = $roll  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

    # bash: local t_low t_high
    t_low t_high  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
    # bash: if [[ "$mode" == "WAGER" ]]; then
    if ($mode -eq 'WAGER') {  # if ...; then -> if (...) {
        # bash: t_low="$wager_threshold_low"
        $t_low = $wager_threshold_low  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: t_high="$wager_threshold_high"
        $t_high = $wager_threshold_high  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: else
    } else {  # else -> } else {
        # bash: t_low="$profit_threshold_low"
        $t_low = $profit_threshold_low  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: t_high="$profit_threshold_high"
        $t_high = $profit_threshold_high  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # bash: if [[ "$bet_target" == "low" ]]; then
    if ($bet_target -eq 'low') {  # if ...; then -> if (...) {
        # bash: if (( roll < t_low )); then
        if (( $roll < $t_low )) {  # if ...; then -> if (...) {
            # bash: result="win"
            $result = 'win'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: else
        } else {  # else -> } else {
            # bash: result="lose"
            $result = 'lose'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: (( roll >= t_high )) && (( wrong_side++ ))
            (( roll >= t_high )) && (( wrong_side++ ))  # TODO: นิพจน์ ((...)) แบบนี้ต้องตรวจเอง
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
    # bash: else # bet_target == "high"
    } else {  # else -> } else {
        # bash: if (( roll >= t_high )); then
        if (( $roll >= $t_high )) {  # if ...; then -> if (...) {
            # bash: result="win"
            $result = 'win'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: else
        } else {  # else -> } else {
            # bash: result="lose"
            $result = 'lose'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: (( roll < t_low )) && (( wrong_side++ ))
            (( roll < t_low )) && (( wrong_side++ ))  # TODO: นิพจน์ ((...)) แบบนี้ต้องตรวจเอง
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# ─────────────────────────────────────────
# [5] MODES LOGIC
# ─────────────────────────────────────────
# bash: profit_mode() {
function profit_mode {  # ฟังก์ชัน bash -> function name {
    # bash: local result="$1"
    $result = $args[0]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local bet="$2"
    $bet = $args[1]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)

    # bash: if [[ "$result" == "win" ]]; then
    if ($result -eq 'win') {  # if ...; then -> if (...) {
        # bash: win_amount=$(fmul "$bet" "$profit_win_mul")
        $win_amount = $(fmul "$bet" "$profit_win_mul")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: balance=$(fadd "$balance" "$win_amount")
        $balance = $(fadd "$balance" "$win_amount")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: total_profit=$(fsub "$balance" "$START_BALANCE")
        $total_profit = $(fsub "$balance" "$START_BALANCE")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: nextbet=$BASE_BET
        $nextbet = $BASE_BET  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: loss_streak=0
        $loss_streak = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: ((win_count++))
        $win_count++  # ((i++)) -> $i++ (เหมือนกัน)
        # bash: ((win_streak++))
        $win_streak++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: else
    } else {  # else -> } else {
        # bash: balance=$(fsub "$balance" "$bet")
        $balance = $(fsub "$balance" "$bet")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: nextbet=$(fmul "$bet" "$LOSEMUL")
        $nextbet = $(fmul "$bet" "$LOSEMUL")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: total_profit=$(fsub "$balance" "$START_BALANCE")
        $total_profit = $(fsub "$balance" "$START_BALANCE")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: win_streak=0
        $win_streak = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: ((loss_streak++))
        $loss_streak++  # ((i++)) -> $i++ (เหมือนกัน)
        # bash: ((lose_count++))
        $lose_count++  # ((i++)) -> $i++ (เหมือนกัน)

        # bash: if (( loss_streak > max_loss_streak )); then
        if (( $loss_streak > $max_loss_streak )) {  # if ...; then -> if (...) {
            # bash: max_loss_streak=$loss_streak
            $max_loss_streak = $loss_streak  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# bash: wagering_mode() {
function wagering_mode {  # ฟังก์ชัน bash -> function name {
    # bash: local result="$1"
    $result = $args[0]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local bet="$2"
    $bet = $args[1]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)

    # bash: if [[ "$result" == "win" ]]; then
    if ($result -eq 'win') {  # if ...; then -> if (...) {
        # bash: win_amount=$(fmul "$bet" "$wager_win_mul")
        $win_amount = $(fmul "$bet" "$wager_win_mul")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: balance=$(fadd "$balance" "$win_amount")
        $balance = $(fadd "$balance" "$win_amount")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: total_profit=$(fsub "$balance" "$START_BALANCE")
        $total_profit = $(fsub "$balance" "$START_BALANCE")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: nextbet=$WAGER_BASE_BET
        $nextbet = $WAGER_BASE_BET  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: loss_streak=0
        $loss_streak = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: ((win_count++))
        $win_count++  # ((i++)) -> $i++ (เหมือนกัน)
        # bash: ((win_streak++))
        $win_streak++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: else
    } else {  # else -> } else {
        # bash: balance=$(fsub "$balance" "$bet")
        $balance = $(fsub "$balance" "$bet")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: nextbet=$WAGER_BASE_BET
        $nextbet = $WAGER_BASE_BET  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: total_profit=$(fsub "$balance" "$START_BALANCE")
        $total_profit = $(fsub "$balance" "$START_BALANCE")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: win_streak=0
        $win_streak = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: ((loss_streak++))
        $loss_streak++  # ((i++)) -> $i++ (เหมือนกัน)
        # bash: ((lose_count++))
        $lose_count++  # ((i++)) -> $i++ (เหมือนกัน)

        # bash: if (( loss_streak > max_loss_streak )); then
        if (( $loss_streak > $max_loss_streak )) {  # if ...; then -> if (...) {
            # bash: max_loss_streak=$loss_streak
            $max_loss_streak = $loss_streak  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# Settle current bet and evaluate mode switch for next round
# bash: dobet() {
function dobet {  # ฟังก์ชัน bash -> function name {
    # bash: local res="$1"
    $res = $args[0]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local bet="$2"
    $bet = $args[1]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local current_m="$3"
    $current_m = $args[2]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)

    # Step 1: Settle current round based on the mode it was played in
    # bash: if [[ "$current_m" == "WAGER" ]]; then
    if ($current_m -eq 'WAGER') {  # if ...; then -> if (...) {
        # bash: wagering_mode "$res" "$bet"
        wagering_mode "$res" "$bet"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
    # bash: else
    } else {  # else -> } else {
        # bash: profit_mode "$res" "$bet"
        profit_mode "$res" "$bet"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # Step 2: Check for mode transition in Hybrid mode (Mode 3)
    # bash: if [[ "$GAME_MODE" == "3" ]]; then
    if ($GAME_MODE -eq 3) {  # if ...; then -> if (...) {
        # bash: if [[ "$MODE" == "WAGER" ]]; then
        if ($MODE -eq 'WAGER') {  # if ...; then -> if (...) {
            # Currently in WAGER: Switch to RECOVERY if balance drops to/below trigger
            # bash: if fgte "$TRIGGER_BALANCE" "$balance"; then
            if (fgte "$TRIGGER_BALANCE" "$balance") {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
                # bash: echo ""
                Write-Output ''  # echo -> Write-Output
                # bash: cn 196 b "  >>> [MODE SWITCH] ⚠️  Balance dropped below trigger ($TRIGGER_BALANCE) -> RECOVERY (PROFIT MODE) <<<"
                cn 196 b "  >>> [MODE SWITCH] ⚠️  Balance dropped below trigger ($TRIGGER_BALANCE) -> RECOVERY (PROFIT MODE) <<<"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                # bash: MODE="PROFIT"
                $MODE = 'PROFIT'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                # bash: nextbet=$BASE_BET
                $nextbet = $BASE_BET  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                # bash: loss_streak=0
                $loss_streak = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: fi
            # -> จบ if — pwsh ปิดด้วย } แทน fi
            }
        # bash: elif [[ "$MODE" == "PROFIT" ]]; then
        } elseif ($MODE -eq 'PROFIT') {  # elif ...; then -> } elseif (...) {
            # Currently in RECOVERY (PROFIT): Exit recovery if:
            # 1. Just WON and capital is fully restored (balance >= START_BALANCE)
            # OR
            # 2. Balance reached TRIGGER_BALANCE_PROFIT target
            # bash: local recovered=false
            $recovered = 'false'  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
            # bash: if [[ "$res" == "win" ]] && fgte "$balance" "$START_BALANCE"; then
            if (($res -eq 'win' -and fgte "$balance" "$START_BALANCE")) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
                # bash: recovered=true
                $recovered = 'true'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: elif fgte "$balance" "$TRIGGER_BALANCE_PROFIT"; then
            } elseif (fgte "$balance" "$TRIGGER_BALANCE_PROFIT") {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
                # bash: recovered=true
                $recovered = 'true'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: fi
            # -> จบ if — pwsh ปิดด้วย } แทน fi
            }

            # bash: if [[ "$recovered" == true ]]; then
            if ($recovered -eq 'true') {  # if ...; then -> if (...) {
                # bash: echo ""
                Write-Output ''  # echo -> Write-Output
                # bash: cn 46 b "  >>> [MODE SWITCH] 🎯 Capital recovered! (Bal: $balance >= Start: $START_BALANCE) -> RESUME WAGER MODE <<<"
                cn 46 b "  >>> [MODE SWITCH] 🎯 Capital recovered! (Bal: $balance >= Start: $START_BALANCE) -> RESUME WAGER MODE <<<"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
                # bash: MODE="WAGER"
                $MODE = 'WAGER'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                # bash: nextbet=$WAGER_BASE_BET
                $nextbet = $WAGER_BASE_BET  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
                # bash: loss_streak=0
                $loss_streak = 0  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: fi
            # -> จบ if — pwsh ปิดด้วย } แทน fi
            }
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# ─────────────────────────────────────────
# [6] STOP CONDITIONS
# ─────────────────────────────────────────
# bash: stop_condition() {
function stop_condition {  # ฟังก์ชัน bash -> function name {
    # (a) balance depleted
    # bash: if ! fgt "$balance" 0; then
    if (-not (fgt "$balance" 0)) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
        # bash: echo "BUST: balance depleted"
        Write-Output 'BUST: balance depleted'  # echo -> Write-Output
        # bash: return 0
        return 0  # return เหมือนกัน
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
    # (b) loss streak exceeded limit
    # bash: if (( loss_streak >= MAX_LOSS_STREAK )); then
    if (( $loss_streak >= $MAX_LOSS_STREAK )) {  # if ...; then -> if (...) {
        # bash: echo "MAX_STREAK: $loss_streak consecutive losses"
        Write-Output "MAX_STREAK: $loss_streak consecutive losses"  # echo -> Write-Output
        # bash: return 0
        return 0  # return เหมือนกัน
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
    # (c) next bet > balance
    # bash: if fgt "$nextbet" "$balance"; then
    if (fgt "$nextbet" "$balance") {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
        # bash: echo "BET_GT_BAL: bet=$nextbet balance=$balance"
        Write-Output "BET_GT_BAL: bet=$nextbet balance=$balance"  # echo -> Write-Output
        # bash: return 0
        return 0  # return เหมือนกัน
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # (d) profit target reached
    # bash: if fgte "$total_profit" "$STOP_PROFIT"; then
    if (fgte "$total_profit" "$STOP_PROFIT") {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
        # bash: echo "PROFIT REACHED: $STOP_PROFIT"
        Write-Output "PROFIT REACHED: $STOP_PROFIT"  # echo -> Write-Output
        # bash: return 0
        return 0  # return เหมือนกัน
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # (e) wager target reached
    # bash: if fgte "$wagered" "$WAGER_TARGET"; then
    if (fgte "$wagered" "$WAGER_TARGET") {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
        # bash: echo "WAGER REACHED: $WAGER_TARGET"
        Write-Output "WAGER REACHED: $WAGER_TARGET"  # echo -> Write-Output
        # bash: return 0
        return 0  # return เหมือนกัน
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # bash: return 1
    return 1  # return เหมือนกัน
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# ─────────────────────────────────────────
# [7] PRINT ROUND
# ─────────────────────────────────────────
# bash: print_round() {
function print_round {  # ฟังก์ชัน bash -> function name {
    # bash: local roll="$1"
    $roll = $args[0]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local result="$2"
    $result = $args[1]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local bet="$3"
    $bet = $args[2]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local total_profit="$4"
    $total_profit = $args[3]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local current_mode="$5"
    $current_mode = $args[4]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: local icon r_fmt roll_fmt bal_fmt stk_fmt roll_c mode_badge
    icon r_fmt roll_fmt bal_fmt stk_fmt roll_c mode_badge  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)

    # bash: printf -v r_fmt    "%3d"    "$round"
    Write-Host -NoNewline ("-v" -f 'r_fmt', '%3d', $round)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
    # bash: printf -v roll_fmt "%4d"    "$roll"
    Write-Host -NoNewline ("-v" -f 'roll_fmt', '%4d', $roll)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
    # bash: printf -v bal_fmt  "%13.8f" "$balance"
    Write-Host -NoNewline ("-v" -f 'bal_fmt', '%13.8f', $balance)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
    # bash: printf -v stk_fmt  "%2d"    "$loss_streak"
    Write-Host -NoNewline ("-v" -f 'stk_fmt', '%2d', $loss_streak)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง

    # Color balance based on start balance
    # bash: if fgt "$START_BALANCE" "$balance"; then
    if (fgt "$START_BALANCE" "$balance") {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
        # bash: local bal_c=$(cn 124 b "$bal_fmt")
        $bal_c = $(cn 124 b "$bal_fmt")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: else
    } else {  # else -> } else {
        # bash: local bal_c=$(cn 28 b "$bal_fmt")
        $bal_c = $(cn 28 b "$bal_fmt")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # Threshold for highlighting wrong side
    # bash: local active_high active_low
    active_high active_low  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
    # bash: if [[ "$current_mode" == "WAGER" ]]; then
    if ($current_mode -eq 'WAGER') {  # if ...; then -> if (...) {
        # bash: active_high="$wager_threshold_high"
        $active_high = $wager_threshold_high  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: active_low="$wager_threshold_low"
        $active_low = $wager_threshold_low  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: else
    } else {  # else -> } else {
        # bash: active_high="$profit_threshold_high"
        $active_high = $profit_threshold_high  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: active_low="$profit_threshold_low"
        $active_low = $profit_threshold_low  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # bash: if [[ "$bet_target" == "low" ]] && (( roll >= active_high )); then
    if (($bet_target -eq 'low' -and ( $roll >= $active_high ))) {  # if ...; then -> if (...) {
        # bash: roll_c="$(cn 45 b "$roll_fmt")"
        $roll_c = $(cn 45 b "$roll_fmt")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: elif [[ "$bet_target" == "high" ]] && (( roll < active_low )); then
    } elseif (($bet_target -eq 'high' -and ( $roll < $active_low ))) {  # elif ...; then -> } elseif (...) {
        # bash: roll_c="$(cn 45 b "$roll_fmt")"
        $roll_c = $(cn 45 b "$roll_fmt")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: else
    } else {  # else -> } else {
        # bash: roll_c="$(cn 245 d "$roll_fmt")"
        $roll_c = $(cn 245 d "$roll_fmt")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # Mode Badge
    # bash: if [[ "$current_mode" == "PROFIT" ]]; then
    if ($current_mode -eq 'PROFIT') {  # if ...; then -> if (...) {
        # bash: mode_badge="$(cn 208 b "PROFIT")"
        $mode_badge = $(cn 208 b "PROFIT")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: else
    } else {  # else -> } else {
        # bash: mode_badge="$(cn 75 b "WAGER ")"
        $mode_badge = $(cn 75 b "WAGER ")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # bash: if [[ "$result" == "win" ]]; then
    if ($result -eq 'win') {  # if ...; then -> if (...) {
        # bash: icon="$(+c "WIN ")"
        $icon = $(+c "WIN ")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: else
    } else {  # else -> } else {
        # bash: icon="$(-c "LOSS")"
        $icon = $(-c "LOSS")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # Print based on Mode Purpose
    # bash: if [[ "$current_mode" == "WAGER" ]]; then
    if ($current_mode -eq 'WAGER') {  # if ...; then -> if (...) {
        # bash: local pct=$(mth "($wagered/$WAGER_TARGET)*100" 1 d)
        $pct = $(mth "($wagered/$WAGER_TARGET)*100" 1 d)  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
        # bash: printf -v w_fmt "%8.2f/%-8.2f (%5.1f%%)" "$wagered" "$WAGER_TARGET" "$pct"
        Write-Host -NoNewline ("-v" -f 'w_fmt', '%8.2f/%-8.2f (%5.1f%%)', $wagered, $WAGER_TARGET, $pct)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
        # bash: local w_c=$(cn 141 b "$w_fmt")
        $w_c = $(cn 141 b "$w_fmt")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)

        # bash: if [[ "$result" == "win" ]]; then
        if ($result -eq 'win') {  # if ...; then -> if (...) {
            # bash: printf -v win_str "+%10.8f" "$win_amount"
            Write-Host -NoNewline ("-v" -f 'win_str', '+%10.8f', $win_amount)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
            # bash: printf "[%s] | %s | R:%s | %s | Wager:%s | Won:%s | Bal:%s\n"                  "$r_fmt" "$mode_badge" "$roll_c" "$icon" "$w_c" "$(+c "$win_str")" "$bal_c"
            Write-Host -NoNewline ("[{0}] | {1} | R:{2} | {3} | Wager:{4} | Won:{5} | Bal:{6}`n" -f $r_fmt, $mode_badge, $roll_c, $icon, $w_c, $(+c "$win_str"), $bal_c)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n
        # bash: else
        } else {  # else -> } else {
            # bash: printf "[%s] | %s | R:%s | %s | Wager:%s | Bal:%s | Stk:%s\n"                  "$r_fmt" "$mode_badge" "$roll_c" "$icon" "$w_c" "$bal_c" "$stk_fmt"
            Write-Host -NoNewline ("[{0}] | {1} | R:{2} | {3} | Wager:{4} | Bal:{5} | Stk:{6}`n" -f $r_fmt, $mode_badge, $roll_c, $icon, $w_c, $bal_c, $stk_fmt)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
    # bash: else
    } else {  # else -> } else {
        # bash: if [[ "$result" == "win" ]]; then
        if ($result -eq 'win') {  # if ...; then -> if (...) {
            # bash: printf -v amt_fmt "%12.8f" "$win_amount"
            Write-Host -NoNewline ("-v" -f 'amt_fmt', '%12.8f', $win_amount)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
            # bash: local amt_c="$(+c "+$amt_fmt")"
            $amt_c = $(+c "+$amt_fmt")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
            # bash: local profit_c="$(+c "+$total_profit")"
            $profit_c = $(+c "+$total_profit")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
            # bash: printf "[%s] | %s | R:%s | %s | Won:%s | PnL:%s | Bal:%s\n"                  "$r_fmt" "$mode_badge" "$roll_c" "$icon" "$amt_c" "$profit_c" "$bal_c"
            Write-Host -NoNewline ("[{0}] | {1} | R:{2} | {3} | Won:{4} | PnL:{5} | Bal:{6}`n" -f $r_fmt, $mode_badge, $roll_c, $icon, $amt_c, $profit_c, $bal_c)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n
        # bash: else
        } else {  # else -> } else {
            # bash: printf -v amt_fmt "%12.8f" "$bet"
            Write-Host -NoNewline ("-v" -f 'amt_fmt', '%12.8f', $bet)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
            # bash: local amt_c="$amt_fmt"
            $amt_c = $amt_fmt  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
            # bash: local profit_c
            profit_c  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: if fgt "0" "$total_profit"; then
            if (fgt "0" "$total_profit") {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
                # bash: profit_c="$(-c "$total_profit")"
                $profit_c = $(-c "$total_profit")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: else
            } else {  # else -> } else {
                # bash: profit_c="$(_gr "$total_profit")"
                $profit_c = $(_gr "$total_profit")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
            # bash: fi
            # -> จบ if — pwsh ปิดด้วย } แทน fi
            }
            # bash: printf "[%s] | %s | R:%s | %s | Bet:%s | PnL:%s | Bal:%s | Stk:%s\n"                  "$r_fmt" "$mode_badge" "$roll_c" "$icon" "$amt_c" "$profit_c" "$bal_c" "$stk_fmt"
            Write-Host -NoNewline ("[{0}] | {1} | R:{2} | {3} | Bet:{4} | PnL:{5} | Bal:{6} | Stk:{7}`n" -f $r_fmt, $mode_badge, $roll_c, $icon, $amt_c, $profit_c, $bal_c, $stk_fmt)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n
        # bash: fi
        # -> จบ if — pwsh ปิดด้วย } แทน fi
        }
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# ─────────────────────────────────────────
# [7.1] RARE NUMBER HUNT
# ─────────────────────────────────────────
# bash: hunting() {
function hunting {  # ฟังก์ชัน bash -> function name {
    # bash: local last_roll="$1"
    $last_roll = $args[0]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
    # bash: if (( last_roll == 9999 || last_roll == 0 )); then
    if ((( last_roll == 9999 -or last_roll == 0 ))) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
        # bash: (( rare_number9900x++ ))
        $rare_number9900x++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: elif (( last_roll == 9998 || last_roll == 1 )); then
    } elseif ((( last_roll == 9998 -or last_roll == 1 ))) {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
        # bash: (( rare_number4950x++ ))
        $rare_number4950x++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: elif (( last_roll == 9997 || last_roll == 2 )); then
    } elseif ((( last_roll == 9997 -or last_roll == 2 ))) {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
        # bash: (( rare_number3300x++ ))
        $rare_number3300x++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: elif (( last_roll == 9996 || last_roll == 3 )); then
    } elseif ((( last_roll == 9996 -or last_roll == 3 ))) {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
        # bash: (( rare_number2475x++ ))
        $rare_number2475x++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: elif (( last_roll == 9995 || last_roll == 4 )); then
    } elseif ((( last_roll == 9995 -or last_roll == 4 ))) {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
        # bash: (( rare_number1980x++ ))
        $rare_number1980x++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: elif (( last_roll == 9994 || last_roll == 5 )); then
    } elseif ((( last_roll == 9994 -or last_roll == 5 ))) {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
        # bash: (( rare_number1650x++ ))
        $rare_number1650x++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: elif (( last_roll == 9993 || last_roll == 6 )); then
    } elseif ((( last_roll == 9993 -or last_roll == 6 ))) {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
        # bash: (( rare_number1414x++ ))
        $rare_number1414x++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: elif (( last_roll == 9992 || last_roll == 7 )); then
    } elseif ((( last_roll == 9992 -or last_roll == 7 ))) {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
        # bash: (( rare_number1237x++ ))
        $rare_number1237x++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: elif (( last_roll == 9991 || last_roll == 8 )); then
    } elseif ((( last_roll == 9991 -or last_roll == 8 ))) {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
        # bash: (( rare_number1100x++ ))
        $rare_number1100x++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: elif (( last_roll == 9990 || last_roll == 9 )); then
    } elseif ((( last_roll == 9990 -or last_roll == 9 ))) {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
        # bash: (( rare_number990x++ ))
        $rare_number990x++  # ((i++)) -> $i++ (เหมือนกัน)
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

# ─────────────────────────────────────────
# [8] MAIN LOOP
# ─────────────────────────────────────────
# bash: cn 136 b "=========================================================================="
cn 136 b "=========================================================================="  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: cn 255 b "  DICE SIMULATOR - MULTI MODE ENGINE"
cn 255 b "  DICE SIMULATOR - MULTI MODE ENGINE"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: cn 136 b "=========================================================================="
cn 136 b "=========================================================================="  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf " Mode: %s | Bal: %.8f | Base: %.8f | WagerBet: %.8f\n"      "$MODE" "$START_BALANCE" "$BASE_BET" "$WAGER_BASE_BET"
Write-Host -NoNewline (" Mode: {0} | Bal: {1} | Base: {2} | WagerBet: {3}`n" -f $MODE, $START_BALANCE, $BASE_BET, $WAGER_BASE_BET)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n
# bash: printf " ProfitWC: %.2f%% (%.4fx) | WagerWC: %.2f%% (%.4fx)\n"      "$WIN_CHANCE" "$payout" "$WAGER_WIN_CHANCE" "$wager_payout"
Write-Host -NoNewline (" ProfitWC: {0}% ({1}x) | WagerWC: {2}% ({3}x)`n" -f $WIN_CHANCE, $payout, $WAGER_WIN_CHANCE, $wager_payout)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; เหลือ % แบบที่แปลงไม่ได้ (%q/%x/...) — ตรวจเอง; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
# bash: printf " StopProfit: +%.8f | WagerTarget: %.2f | LossTrigger: -%s%% (<=%.2f)\n"      "$STOP_PROFIT" "$WAGER_TARGET" "$LOSS_TRIGGER" "$TRIGGER_BALANCE"
Write-Host -NoNewline (" StopProfit: +{0} | WagerTarget: {1} | LossTrigger: -{2}% (<={3})`n" -f $STOP_PROFIT, $WAGER_TARGET, $LOSS_TRIGGER, $TRIGGER_BALANCE)  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; เหลือ % แบบที่แปลงไม่ได้ (%q/%x/...) — ตรวจเอง; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
# bash: cn 136 b "=========================================================================="
cn 136 b "=========================================================================="  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)

# bash: stop_reason=""
$stop_reason = ''  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# bash: while (( round < MAX_ROUNDS )); do
while (( $round < $MAX_ROUNDS )) {  # while ...; do -> while (...) {
    # bash: if (( win_count >= STOP_ON_WIN )); then
    if (( $win_count >= $STOP_ON_WIN )) {  # if ...; then -> if (...) {
        # bash: stop_reason="WIN LIMIT: reached $STOP_ON_WIN wins"
        $stop_reason = "WIN LIMIT: reached $STOP_ON_WIN wins"  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
        # bash: break
        break  # ชื่อเหมือนกันใน pwsh
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # Check stop conditions
    # bash: if stop_reason=$(stop_condition); then
    if (-not [string]::IsNullOrEmpty("stop_reason=$(stop_condition)")) {  # if ...; then -> if (...) {
        # bash: break
        break  # ชื่อเหมือนกันใน pwsh
    # bash: fi
    # -> จบ if — pwsh ปิดด้วย } แทน fi
    }

    # bash: ((round++))
    $round++  # ((i++)) -> $i++ (เหมือนกัน)

    # Freeze current round bet and mode
    # bash: current_bet="$nextbet"
    $current_bet = $nextbet  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: round_mode="$MODE"
    $round_mode = $MODE  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

    # bash: wagered=$(fadd "$wagered" "$current_bet")
    $wagered = $(fadd "$wagered" "$current_bet")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

    # --- roll dice (mode aware) ---
    # bash: roll_dice "$round_mode"
    roll_dice "$round_mode"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)

    # --- settle math & check mode transitions ---
    # bash: dobet "$result" "$current_bet" "$round_mode"
    dobet "$result" "$current_bet" "$round_mode"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)

    # --- hunting ---
    # bash: hunting "$last_roll"
    hunting "$last_roll"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)

    # Print log of round played
    # bash: print_round "$last_roll" "$result" "$current_bet" "$total_profit" "$round_mode"
    print_round "$last_roll" "$result" "$current_bet" "$total_profit" "$round_mode"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: done
# -> จบ loop — pwsh ปิดด้วย } แทน done
}

# ─────────────────────────────────────────
# [9] SESSION SUMMARY
# ─────────────────────────────────────────
# bash: if fgt "$total_profit" "0"; then
if (fgt "$total_profit" "0") {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
    # bash: profit_c="$(+c "+$total_profit")"
    $profit_c = $(+c "+$total_profit")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: bal_c="$(+c "$balance")"
    $bal_c = $(+c "$balance")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: elif fgt "0" "$total_profit"; then
} elseif (fgt "0" "$total_profit") {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
    # bash: profit_c="$(-c "$total_profit")"
    $profit_c = $(-c "$total_profit")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: bal_c="$(-c "$balance")"
    $bal_c = $(-c "$balance")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: else
} else {  # else -> } else {
    # bash: profit_c="$(_gr "$total_profit")"
    $profit_c = $(_gr "$total_profit")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
    # bash: bal_c="$(_gr "$balance")"
    $bal_c = $(_gr "$balance")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}
# bash: wagered_c="$(cn 245 b "$wagered")"
$wagered_c = $(cn 245 b "$wagered")  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

# bash: echo ""
Write-Output ''  # echo -> Write-Output
# bash: cn 136 b "=========================================================================="
cn 136 b "=========================================================================="  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: cn 255 b "  SESSION SUMMARY"
cn 255 b "  SESSION SUMMARY"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: cn 136 b "=========================================================================="
cn 136 b "=========================================================================="  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc 'Rounds'): %d  $(+c 'W'): %d  $(-c 'L'): %d  $(_wc 'MaxStreak'): %d\n"      "$round" "$win_count" "$lose_count" "$max_loss_streak"
printf "  $(_wc 'Rounds'): %d  $(+c 'W'): %d  $(-c 'L'): %d  $(_wc 'MaxStreak'): %d\n"      "$round" "$win_count" "$lose_count" "$max_loss_streak"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)

# bash: printf "  $(_wc 'Final Balance'): %s\n" "$bal_c"
printf "  $(_wc 'Final Balance'): %s\n" "$bal_c"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc 'Net PnL'): %s\n" "$profit_c"
printf "  $(_wc 'Net PnL'): %s\n" "$profit_c"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc 'Wagered'): %s / %.2f\n" "$wagered_c" "$WAGER_TARGET"
printf "  $(_wc 'Wagered'): %s / %.2f\n" "$wagered_c" "$WAGER_TARGET"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)

# bash: if fgt "$balance" "$START_BALANCE"; then
if (fgt "$balance" "$START_BALANCE") {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
    # bash: +c "  Result: PROFIT"
    +c "  Result: PROFIT"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: elif fgt "$START_BALANCE" "$balance"; then
} elseif (fgt "$START_BALANCE" "$balance") {  # elif ...; then -> } elseif (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
    # bash: -c "  Result: LOSS"
    -c "  Result: LOSS"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: else
} else {  # else -> } else {
    # bash: _gr "  Result: BREAK EVEN"
    _gr "  Result: BREAK EVEN"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: fi
# -> จบ if — pwsh ปิดด้วย } แทน fi
}

# bash: [[ -n "$stop_reason" ]] && cn 45 b "  Stop Reason: $stop_reason"
[[ -n "$stop_reason" ]] && cn 45 b "  Stop Reason: $stop_reason"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
# bash: cn 136 b "=========================================================================="
cn 136 b "=========================================================================="  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(+c "Rare Number")\n"
Write-Host -NoNewline ("  `$(+c Rare" -f 'Number)\n')  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n; bash printf วน fmt ซ้ำได้ แต่ pwsh -f ต้องให้ครบ — ตรวจเอง
# bash: cn 136 b "=========================================================================="
cn 136 b "=========================================================================="  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc "9900x"): %d\n" "$rare_number9900x"
printf "  $(_wc "9900x"): %d\n" "$rare_number9900x"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc "4950x"): %d\n" "$rare_number4950x"
printf "  $(_wc "4950x"): %d\n" "$rare_number4950x"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc "3300x"): %d\n" "$rare_number3300x"
printf "  $(_wc "3300x"): %d\n" "$rare_number3300x"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc "2475x"): %d\n" "$rare_number2475x"
printf "  $(_wc "2475x"): %d\n" "$rare_number2475x"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc "1980x"): %d\n" "$rare_number1980x"
printf "  $(_wc "1980x"): %d\n" "$rare_number1980x"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc "1650x"): %d\n" "$rare_number1650x"
printf "  $(_wc "1650x"): %d\n" "$rare_number1650x"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc "1414x"): %d\n" "$rare_number1414x"
printf "  $(_wc "1414x"): %d\n" "$rare_number1414x"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc "1237x"): %d\n" "$rare_number1237x"
printf "  $(_wc "1237x"): %d\n" "$rare_number1237x"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc "1100x"): %d\n" "$rare_number1100x"
printf "  $(_wc "1100x"): %d\n" "$rare_number1100x"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(_wc "990x"): %d\n" "$rare_number990x"
printf "  $(_wc "990x"): %d\n" "$rare_number990x"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: printf "  $(+c "wrong_side"): %d\n" "$wrong_side"
printf "  $(+c "wrong_side"): %d\n" "$wrong_side"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
# bash: echo " "
Write-Output ' '  # echo -> Write-Output
# bash: cn 136 b "=========================================================================="
cn 136 b "=========================================================================="  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
