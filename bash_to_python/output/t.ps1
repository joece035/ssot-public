# bash: #!/usr/bin/env bash
#!/usr/bin/env pwsh



# bash: link_(){
function link_ {  # ฟังก์ชัน bash -> function name {
    # bash: case "$1" in
    switch -Wildcard ($args[0]) {  # case -> switch -Wildcard (glob * ใช้ได้เลย)
        # bash: -r|relink)
        { $_ -eq '-r' -or $_ -eq 'relink' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            # ตรวจสอบความพร้อมของ Base Environment
            # bash: local ssot_dir="${SSOT:-$HOME/ssot}"
            $ssot_dir = ($SSOT ?? "$HOME/ssot")  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)
            # bash: local node_host="${NODE_HOST:-$(echo "${JOE_ENV:-wsl2}" | tr '[:upper:]' '[:lower:]')}"
            $node_host = "$(($NODE_HOST ?? '$(echo ${JOE_ENV:-wsl2')) | tr [:upper:] [:lower:])}"  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-def} -> ?? (null-coalescing ของ PS 7+)

            # bash: if [[ ! -d "$ssot_dir" ]]; then
            if (-not (Test-Path $ssot_dir -PathType Container)) {  # if ...; then -> if (...) {
                # bash: echo "SSOT directory not found: $ssot_dir"
                Write-Output "SSOT directory not found: $ssot_dir"  # echo -> Write-Output
                # bash: return 1
                return 1  # return เหมือนกัน
            # bash: fi
            # -> จบ if — pwsh ปิดด้วย } แทน fi
            }

            # แมปปิ้ง Target (Symlink) -> Source (ไฟล์ต้นทาง) ตามมาตรฐาน SSOT Infrastructure
            # bash: local -A links=(
            -A links=(  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: ["$HOME/.bashrc"]="$ssot_dir/profiles/$node_host/.bashrc"
            ["$HOME/.bashrc"]="$ssot_dir/profiles/$node_host/.bashrc"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: ["$HOME/.zshrc"]="$ssot_dir/profiles/$node_host/.zshrc"
            ["$HOME/.zshrc"]="$ssot_dir/profiles/$node_host/.zshrc"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: ["$HOME/.local/bin/joe"]="$ssot_dir/joe.sh"
            ["$HOME/.local/bin/joe"]="$ssot_dir/joe.sh"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: ["$HOME/.local/bin/node-status"]="$ssot_dir/bootstrap/nodes/node-status.sh"
            ["$HOME/.local/bin/node-status"]="$ssot_dir/bootstrap/nodes/node-status.sh"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: ["$HOME/.local/bin/shared"]="$ssot_dir/tools/sync_shared.sh"
            ["$HOME/.local/bin/shared"]="$ssot_dir/tools/sync_shared.sh"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: ["$HOME/.local/bin/env"]="$ssot_dir/bootstrap/templates/env"
            ["$HOME/.local/bin/env"]="$ssot_dir/bootstrap/templates/env"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: ["$ssot_dir/.env"]="$HOME/.env"
            ["$ssot_dir/.env"]="$HOME/.env"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: ["$ssot_dir/.env.secret"]="$HOME/.env.secret"
            ["$ssot_dir/.env.secret"]="$HOME/.env.secret"  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)
            # bash: )
            )  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)

            # 1. Clean State: บังคับลบเฉพาะ Target ที่เป็น Symlink เก่าทิ้งเพื่อเตรียมสร้างใหม่
            # bash: for target in "${!links[@]}"; do
            foreach ($target in ${!links[@]}) {  # for..in -> foreach
                # bash: local target_path="${target/#$HOME/\~}"
                $target_path = ($target -replace ('^' + [regex]::Escape($HOME)), '~')  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
                # bash: if [[ -L "$target" ]]; then
                if ((Get-Item $target).LinkType) {  # if ...; then -> if (...) {
                    # bash: rm -f "$target"
                    Remove-Item -Force $target  # rm -> Remove-Item (-r=-Recurse, -f=-Force)
                    # bash: echo "cleaned symlink: $target_path"
                    Write-Output "cleaned symlink: $target_path"  # echo -> Write-Output
                # bash: elif [[ -e "$target" ]]; then
                } elseif (Test-Path $target) {  # elif ...; then -> } elseif (...) {
                    # bash: echo "skip non-symlink (preserving file): $target_path"
                    Write-Output "skip non-symlink (preserving file): $target_path"  # echo -> Write-Output
                # bash: fi
                # -> จบ if — pwsh ปิดด้วย } แทน fi
                }
            # bash: done
            # -> จบ loop — pwsh ปิดด้วย } แทน done
            }

            # 2. ป้องกันกรณีไดเรกทอรีปลายทางยังไม่ถูกสร้าง
            # bash: mkdir -p "$HOME/.local/bin"
            New-Item -ItemType Directory -Force "$HOME/.local/bin"  # mkdir -p -> New-Item -ItemType Directory -Force

            # 3. Re-link ใหม่ทั้งหมดจาก Clean State
            # bash: for target in "${!links[@]}"; do
            foreach ($target in ${!links[@]}) {  # for..in -> foreach
                # bash: local source="${links[$target]}"
                $source = ${links[$target]}  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว); ${..:-..} / $! แบบซับซ้อนต้องแปลงเอง
                # bash: local source_path="${source/#$HOME/\~}"
                $source_path = ($source -replace ('^' + [regex]::Escape($HOME)), '~')  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
                # bash: if [[ -e "$source" ]]; then
                if (Test-Path $source) {  # if ...; then -> if (...) {
                    # bash: ln -sf "$source" "$target" && echo "done symlink $source_path -> ${target/#$HOME/\~}"
                    ln -sf "$source" "$target" && echo "done symlink $source_path -> ${target/#$HOME/\~}"  # &&/|| ใช้ได้บน PowerShell 7+ (5.1 ใช้; if ($?) แทน); คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)
                # bash: else
                } else {  # else -> } else {
                    # bash: echo "source not found: $source_path"
                    Write-Output "source not found: $source_path"  # echo -> Write-Output
                # bash: fi
                # -> จบ if — pwsh ปิดด้วย } แทน fi
                }
            # bash: done
            # -> จบ loop — pwsh ปิดด้วย } แทน done
            }

            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -c|check)
        { $_ -eq '-c' -or $_ -eq 'check' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            # bash: local directory="$2"
            $directory = $args[1]  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
            # bash: local file_to=""
            $file_to = ''  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
            # bash: if [[ -z "$directory" || ! -d "$directory" ]]; then
            if ([[ -z "$directory" -or -not (-d "$directory" ]])) {  # if ...; then -> if (...) {; เงื่อนไขเป็นคำสั่ง — bash เช็ค exit code แต่ pwsh เช็คค่าบูลีน/ต้องดู $? เอง
                # bash: echo "Error: Please specify a valid directory. (e.g. link_ check /path/to/dir)"
                Write-Output 'Error: Please specify a valid directory. (e.g. link_ check /path/to/dir)'  # echo -> Write-Output
                # bash: return 1
                return 1  # return เหมือนกัน
            # bash: fi
            # -> จบ if — pwsh ปิดด้วย } แทน fi
            }

            # bash: local count=0
            $count = 0  # local -> $var (ในฟังก์ชัน pwsh แยก scope ให้อยู่แล้ว)
            # bash: while IFS= read -r -d '' f; do
            while (IFS= read -r -d '' f) {  # while ...; do -> while (...) {; เงื่อนไขเป็นคำสั่ง — ดู $? เอง
                # bash: file_to=$(readlink "$f" 2>/dev/null)
                $file_to = $(readlink "$f" 2>/dev/null)  # กำหนดค่าตัวแปร (bash x=.. -> pwsh $x=..)

                # ตรวจสอบว่า Target ปลายทางมีอยู่จริงหรือไม่
                # bash: if [[ -e "$f" ]]; then
                if (Test-Path $f) {  # if ...; then -> if (...) {
                    # bash: echo "${f/#$HOME/\~} -> ${file_to/#$HOME/\~}"
                    Write-Output "$(($f -replace ('^' + [regex]::Escape($HOME)), '~')) -> $(($file_to -replace ('^' + [regex]::Escape($HOME)), '~'))"  # echo -> Write-Output
                # bash: else
                } else {  # else -> } else {
                    # bash: echo "${f/#$HOME/\~} -> ${file_to/#$HOME/\~} [BROKEN]"
                    Write-Output "$(($f -replace ('^' + [regex]::Escape($HOME)), '~')) -> $(($file_to -replace ('^' + [regex]::Escape($HOME)), '~')) [BROKEN]"  # echo -> Write-Output
                # bash: fi
                # -> จบ if — pwsh ปิดด้วย } แทน fi
                }
                # bash: (( count++ ))
                $count++  # ((i++)) -> $i++ (เหมือนกัน)
                # bash: done < <(find "$directory" -maxdepth 1 -type l -print0 2>/dev/null)
                done < <(find "$directory" -maxdepth 1 -type l -print0 2>/dev/null)  # pwsh ไม่มี < (input redirect) — ใช้ Get-Content file | cmd แทน; >/>> รูปเดียวกัน แต่ pwsh เขียนเป็น UTF-8 — ตรวจ encoding เอง; คำสั่ง native ส่งผ่านตรง (pwsh รัน ls/grep/git/... ได้)

                # bash: if [[ $count -eq 0 ]]; then
                if ($count -eq 0) {  # if ...; then -> if (...) {
                    # bash: echo "No links found in $directory"
                    Write-Output "No links found in $directory"  # echo -> Write-Output
                # bash: else
                } else {  # else -> } else {
                    # bash: echo "Total links: $count"
                    Write-Output "Total links: $count"  # echo -> Write-Output
                # bash: fi
                # -> จบ if — pwsh ปิดด้วย } แทน fi
                }

                break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: -s|--show|-ssot|--ssot)
        { $_ -eq '-s' -or $_ -eq '--show' -or $_ -eq '-ssot' -or $_ -eq '--ssot' } {  # a|b) -> { $_ -eq ... } (pwsh ไม่มี | ใน case)
            # bash: link_check
            link_check  # ส่งผ่านตรง (pwsh รันคำสั่ง native ได้)

            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
        # bash: *)
        default {  # *) -> default
            # bash: echo "Usage: ${FUNCNAME[0]:-link_} {-r|relink | -c|check <directory> | -s|--show|-ssot|--ssot}"
            Write-Output "`${FUNCNAME[0]:-link_}Usage:  {-r|relink | -c|check <directory> | -s|--show|-ssot|--ssot}"  # echo -> Write-Output; bash $FUNCNAME ไม่มีใน pwsh ตรงๆ — ใช้ $MyInvocation.MyCommand.Name
            break  # ;; ของ bash -> break (switch ของ pwsh ไม่หยุดเอง)
        }
    # bash: esac
    # -> จบ case — pwsh ปิด switch ด้วย } แทน esac
    }
# bash: }
# -> จบฟังก์ชัน — pwsh ปิดด้วย } แทน } (รูปเดียวกัน)
}

