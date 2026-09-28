#!/usr/bin/env bash

source $HOME/.bashrc
test_p="$HOME/ssot/shared/personal"
test_p2="/home/joez/ssot/shared/functions"



printf '\"%s\"\n\"%s\"\n' "${test_p/#$HOME/\~}" "${test_p2/#$HOME/\~}"
    
    

    

float_add() {
		mth "$1+$2" 8 d
    awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a + b }'
}

float_sub() {
		mth "$1-$2" 8 d
   awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a - b }'
}

float_mul() {
		mth "$1*$2" 8 d
    awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a * b }'
}

float_div() {
		mth "$1/$2" 8 d
   awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a / b }'
}

float_gte() {
		#mth "ROUND($1+$2),8"
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
}

float_add 0.0067 0.004
echo 
float_sub 0.01 0.0076
echo
float_mul 0.00001 1.051
echo
float_div 0.0003 1.5
echo
float_gte 0.01 0.005
echo

