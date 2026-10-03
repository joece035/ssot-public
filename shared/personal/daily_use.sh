#!/usr/bin/env bash

# --  ใไฟล์สำหรับสร้าง คอมมานไว้ใช้ส่วนตัวเพื่อนความรวดเร๋วแบบไม่เป็นทางการ
b20_bk(){
	local ads=${BEP20_BK:?'not found'}
		echo $ads
		cb_copy "$ads"
}

# -- ssot sync to git-bash || wsl || wsl2
ssot_update() {
	
	cd "$HOME/ssot" || return 1
	git add .
	git commit -m "Update from $JOE_ENV"
	git push &&
	
	local to_gb="cp -r "$hwsl2/ssot" "$hpc""
	local to_wsl="cp -r "$hwsl2/ssot" "$hwsl""
	local to_wsl2="cp -r "$hwsl2/ssot" "$hwsl2""

	case "${1:-}" in 
		"gb") eval "$to_gb" && echo "done sync to git-bash" ;;
		"wsl") eval "$to_wsl" && echo "done sync to wsl" ;;
		"wsl2") eval "$to_wsl2" && echo "done sync to wsl2" ;;
		*) echo "Usage: upssot [gb|wsl|wsl2]" ;;
	esac
	
	
}

alias dice="bash $SSOT/scripts/dice/roll.sh"
alias dicepy="$_py $SSOT/scripts/dice/roll.py"
alias dcf='micro $SSOT/dice.env'

banner_(){
	local _bn_='
auto N (คำนวณจาก math + risk threshold)
d -cc -b 10000 -m 2.0 -c 49.5

manual N ที่ต้องการ
d -cc -b 10000 -m 20 -c 4.95 --max-loss-n 10

# ปรับ risk threshold เป็น 0.01% (เข้มขึ้น)
d -cc -b 10000 -m 2.0 -c 49.5 --risk 0.0001

# ใช้เพียง 80% ของ balance เป็น coverage
d-cc -b 10000 -m 2.0 -c 49.5 --coverage 0.8
'
echo "$_bn_"
}

d(){
	local dice_dir="$SSOT/scripts/dice"
	local type=$1
	shift
	
	case "$type" in
		-sh|--bash)
				bash "$SSOT/scripts/dice/roll.sh" "$@"
				;;
		-py|--python)
				$_py "$SSOT/scripts/dice/roll.py"
		"$@"
				;;
		-cc|--cals)
				$_py "$SSOT/scripts/dice/roll.py" calc "$@"
				;;
		-h|--help)
				banner_ 
				;;
	esac	
	
	

	
	
}