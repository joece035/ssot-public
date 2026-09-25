#!/usr/bin/env bash

# -- dice calculator for maths practical

# -- House Edge
HE=1.00   # % is 0.01
bet_amount="${2:-1}"  #  
balance="${3:-100}"   

# -- payout
payout="${1:-1.95}"  #  

# -- winchance
win_chance=$(mth "100*(1-($HE/100))/$payout")  # %

# -- expected value
ev=$(mth "($win_chance/100) * 3.5 - ((100-$win_chance)/100) * 3.5")

do_bet(){

    if (( balance < bet_amount )); then
        echo "Balance is too low!"
        exit 1
    fi
    
    if win
    
    
}
    
    

    

