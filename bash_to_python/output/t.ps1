# bash: #!/usr/bin/env bash
#!/usr/bin/env pwsh

# bash: test_p="$HOME/ssot/shared/personal"
$test_p = "$HOME/ssot/shared/personal"  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)
# bash: test_p2="/home/joez/ssot/shared/functions"
$test_p2 = '/home/joez/ssot/shared/functions'  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)



# bash: printf '\"%s\"\n\"%s\"\n' "${test_p/#$HOME/\~}" "${test_p2/#$HOME/\~}"
Write-Host -NoNewline ("`"{0}`"`n`"{1}`"`n" -f ($test_p -replace ('^' + [regex]::Escape($HOME)), '~'), ($test_p2 -replace ('^' + [regex]::Escape($HOME)), '~'))  # printf -> Write-Host -NoNewline + -f ({0} แทน %s); \n -> `n





