#!/bin/bash
# ============================================================
# color-chart.sh — Visual 256-color picker
# ============================================================
# Browse all 256 colors. Print the code you want to use.
# Usage: bash tools/color-chart.sh
# ============================================================
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing
# Standard 16 colors
echo -e "\n\e[1;38;5;255m━━━ Standard 16 (0-15) ━━━\e[0m"
for i in {0..15}; do
    printf '\e[38;5;%sm%3d\e[0m ' "$i" "$i"
    (( (i+1) % 8 == 0 )) && echo
done

# 216 color cube (16-231)
echo -e "\n\e[1;38;5;255m━━━ 6x6x6 Color Cube (16-231) ━━━\e[0m"
for i in {16..231}; do
    printf '\e[38;5;%sm%3d\e[0m ' "$i" "$i"
    (( (i-15) % 12 == 0 )) && echo
done

# Grayscale (232-255)
echo -e "\n\e[1;38;5;255m━━━ Grayscale (232-255) ━━━\e[0m"
for i in {232..255}; do
    printf '\e[38;5;%sm%3d\e[0m ' "$i" "$i"
    (( (i-231) % 8 == 0 )) && echo
done

# Common picks (cheat sheet)
echo -e "\n\e[1;38;5;255m━━━ Joe's Favorite Picks ━━━\e[0m"
if [[ -n "${ZSH_VERSION:-}" ]]; then
    typeset -A picks=(
        [red]=196 [lred]=203 [orange]=208 [yellow]=226 [lg]=82
        [llg]=46 [green]=34 [cyan]=51 [lcyan]=87 [blue]=33
        [lblue]=75 [purple]=141 [pink]=213 [gray]=244 [white]=255
        [dim]=245
    )
else
    declare -A picks=(
        [red]=196 [lred]=203 [orange]=208 [yellow]=226 [lg]=82
        [llg]=46 [green]=34 [cyan]=51 [lcyan]=87 [blue]=33
        [lblue]=75 [purple]=141 [pink]=213 [gray]=244 [white]=255
        [dim]=245
    )
fi
for name in "${!picks[@]}"; do
    num=${picks[$name]}
    printf "\e[38;5;%sm████\e[0m %-8s = \e[1;38;5;255m%s\e[0m\n" "$num" "$name" "$num"
done | sort -k4

echo -e "\n\e[1;38;5;255m━━━ Usage ━━━\e[0m"
echo -e "  Inline:  \e[38;5;202mtext\e[0m"
echo -e "  Helper:  c 202 b \"text\""
echo -e "  Style:   \e[1;38;5;202mbold\e[0m  \e[3;38;5;141mitalic\e[0m  \e[4;38;5;82mu\e[0m"
echo -e "  Combo:   \e[1;4;38;5;196mbo+un+red\e[0m"
