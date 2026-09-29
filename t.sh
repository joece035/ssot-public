#!/usr/bin/env bash

source $HOME/.bashrc
test_p="$HOME/ssot/shared/personal"
test_p2="/home/joez/ssot/shared/functions"



printf '\"%s\"\n\"%s\"\n' "${test_p/#$HOME/\~}" "${test_p2/#$HOME/\~}"
    
    

    

cmd=$(find $HOME -iname "*bak*" | sort )
f_c=$(find $HOME -iname "*bak*" | wc -l)
echo $cmd
echo $f_c
