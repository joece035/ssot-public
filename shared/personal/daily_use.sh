#!/usr/bin/env bash

# --  ใไฟล์สำหรับสร้าง คอมมานไว้ใช้ส่วนตัวเพื่อนความรวดเร๋วแบบไม่เป็นทางการ
b20_bk(){
	local ads=${BEP20_BK:?'not found'}
		echo $ads
		cb_copy "$ads"
}

