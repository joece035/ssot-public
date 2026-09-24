#!/usr/bin/env bash
# ======================================================
# core_theme.sh
# ======================================================

tp_(){

		local t=${1:-a}
		local a b c 
		local dir="$SSOT/deprecated/plugins/joe_theme"
		
		
		a="$dir/a.sh"
		b="$dir/b.sh"
		c="$dir/c.sh"
		
	
		
				case "$t" in
						"a")
								if [[ -f "$a" ]]; then
									unset PS1
									clear
									source "$a"
									fi
								;;
						"b")
								if [[ -f "$b" ]]; then
									unset PS1
									clear
									source "$b"
								fi
								;;
						"c")
								if [[ -f "$c" ]]; then
									unset PS1
									clear
									source "$c"
								fi
								;;
						*)
								;;
				esac				
}





