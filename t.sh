#!/usr/bin/env bash

test_p="$HOME/ssot/shared/personal"
test_p2="/home/joez/ssot/shared/functions"



printf '\"%s\"\n\"%s\"\n' "${test_p/#$HOME/\~}" "${test_p2/#$HOME/\~}"
    
    

    

