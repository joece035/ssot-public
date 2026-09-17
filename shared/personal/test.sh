#!/usr/bin/env bash
# ------------------------------------------------------------
# File: test.sh

# กำหนดค่า Variable ด้วย Unicode Escape sequence
TOP_LINE=$'\u2594'      # ขอบบนสุด (Block element)
OVERLINE=$'\u203E'      # ขอบบน
MID_LINE=$'\u2500'      # กลางบรรทัด (Standard Box)
BOT_LINE=$'\u2581'      # ขอบล่างสุด (Block element)

zz(){
_bt_(){
	draw_ "$TOP_LINE" $1
}	
#draw_ "$MID_LINE" 15
_bb_(){
	draw_ "$BOT_LINE" $1
}	
 	_test="$(echo ${1:-$JOE_ENV})"
	_pad="$(( ${#_test} + 4 ))"
_nl
tf=""
tf+="$(_bb_ $_pad)\n"
tf+="$(printf '  %s  \n' "$_test")\n"
tf+="$(_bt_ $_pad)\n"

printf '%b\n' "$tf"
}
bp_(){

	# -- text
		local text="${1:-$JOE_ENV}" 
		local lens_="${#text}"
	# -- dynamic width & object
		local _w=$(( 2+lens_+2 ))
		local _l='│' 
		local _r='│'
		local _btop=$TOP_LINE
		local _bbot=$BOT_LINE

		# -- color configuration
		local random=
		local _bb_c=198
		local _bt_c=198
		local _l_c=235
		local _r_c=235
		local text_c=15
	# -- apply color and  -- sketup object
		
		local _bt="$(draw_ "$_btop" "$_w")"
		local _bb="$(draw_ "$_bbot" "$_w")"
		local t=$(cn " $text_c " "b" --bg 240 "$text")
	# -- random or no
		local bd l r blk
	 if [[ -n "$random" || "$random" == "1" ]]; then
	 	 bdt=$(rc "b" "$_bt")
		 bdb=$(rc "b" "$_bb")
	 	 #lr=$(rc "b" "$_l")
		  #r=$(cn "b" "$_r")
		 #blk=$(printf '%s %s %s\n' "$lr" "$t" "$lr")
	 else	 
		 bdt=$(cn "$_bt_c" "b" "$_bt")
		 bdb=$(cn "$_bb_c" "b" "$_bb")
		  #l=$(cn "$_l_c" "b" "$_l")
	#	  r=$(cn "$_r_c" "b" "$_r")
		 #blk=$(printf '%s %s %s\n' "$l" "$t" "$r")
	 fi	
		  l=$(cn "$_l_c" "b" "$_l")
		  r=$(cn "$_r_c" "b" "$_r")
		 blk=$(printf '%s %s %s\n' "$l" "$t" "$r" ) 
	# -- render
		local _bp_=""
		_bp_+="$bdb\n"
		_bp_+="$blk\n"
		_bp_+="$bdt"
		
		echo -e "$_bp_"
	  block_prompt="$_bp_"
}
bp_ ${1:-$JOE_ENV}