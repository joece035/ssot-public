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

