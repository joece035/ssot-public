#!/usr/bin/env bash
# ============================================================
# tools/env-manager.sh — SSOT Environment Variable Manager (TUI)
# ============================================================
# Interactive & CLI tool to manage environment variables in SSOT
# Target default: $SSOT/bootstrap/00-env.sh (Customizable)
#
# Features:
#   - Add / Edit / Delete variables safely (with auto-backup)
#   - Search across variable names, values, and comments
#   - Check exact duplicates, duplicate values, and similar names/descriptions
#   - Switch target file on the fly
#   - Full TUI + CLI non-interactive mode
#
# V4 SSOT style — uses c()/cn() helpers from 01-colors.sh.
# ============================================================

set -uo pipefail 2>/dev/null || true

# --- Load Color Engine SSOT ---
_SSOT_ROOT="${SSOT:-$HOME/ssot}"
if [[ -f "$_SSOT_ROOT/core/01-colors.sh" ]]; then
    source "$_SSOT_ROOT/core/01-colors.sh"
elif [[ -f "$_SSOT_ROOT/01-colors.sh" ]]; then
    source "$_SSOT_ROOT/01-colors.sh"
fi

# Fallback color helpers if 01-colors.sh not sourced
if ! declare -f cn >/dev/null 2>&1; then
    cn() {
        local col="${1:-}" style="${2:-}"
        shift 2 2>/dev/null || shift $#
        echo "$*"
    }
    c() {
        local col="${1:-}" style="${2:-}"
        shift 2 2>/dev/null || shift $#
        printf "%s" "$*"
    }
fi

# --- Target File Resolution ---
DEFAULT_TARGET="$_SSOT_ROOT/bootstrap/00-env.sh"
TARGET_FILE="${ENV_TARGET_FILE:-$DEFAULT_TARGET}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"

# Parse optional CLI flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file|--target)
            TARGET_FILE="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

CLI_CMD="${1:-}"
[[ $# -gt 0 ]] && shift || true

# --- Safety & Backup ---
_ensure_target() {
    if [[ ! -f "$TARGET_FILE" ]]; then
        cn 196 b "❌ Error: Target file not found: $TARGET_FILE"
        return 1
    fi
    return 0
}

_create_backup() {
    local target="$1"
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local fname
    fname="$(basename "$target")"
    local bkp_path="$BACKUP_DIR/${fname}.${ts}.bak"
    if cp "$target" "$bkp_path" 2>/dev/null; then
        echo "$bkp_path"
        return 0
    else
        # Fallback local backup
        local local_bkp="${target}.bak.${ts}"
        cp "$target" "$local_bkp" 2>/dev/null || true
        echo "$local_bkp"
        return 0
    fi
}

# --- Core Parser Engine ---
# Output format per line: LINE_NO|TYPE|NAME|VALUE|COMMENT|SECTION
_parse_env_file() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1

    python3 -c "
import sys, re

filepath = sys.argv[1]
current_section = 'General'
prev_comment = ''

with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
    for idx, line in enumerate(f, 1):
        raw = line.strip()
        
        # Detect section header
        if re.match(r'^#\s*={5,}', raw):
            prev_comment = ''
            continue
        sec_match = re.match(r'^#\s*([0-9]+\.?\s*[^=]+)', raw)
        if sec_match and not raw.startswith('# export'):
            current_section = sec_match.group(1).strip()
            prev_comment = ''
            continue

        # Standalone comment
        if raw.startswith('#'):
            c_text = raw.lstrip('#').strip()
            if c_text and not c_text.startswith('='):
                prev_comment = c_text if not prev_comment else prev_comment + ' | ' + c_text
            continue

        if not raw:
            prev_comment = ''
            continue

        # Export or standard assignment: export VAR=val or VAR=val
        m = re.match(r'^(export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$', raw)
        if m:
            is_export = 'EXPORT' if m.group(1) else 'VAR'
            var_name = m.group(2)
            rest = m.group(3).strip()
            
            # Split inline comment
            inline_comment = ''
            val = rest
            
            # Handle quoted values or unquoted values with #
            if (val.startswith('\"') and '\"' in val[1:]) or (val.startswith(\"'\") and \"'\" in val[1:]):
                q = val[0]
                end_q = val.find(q, 1)
                if end_q != -1:
                    val_part = val[:end_q+1]
                    after = val[end_q+1:].strip()
                    if after.startswith('#'):
                        inline_comment = after.lstrip('#').strip()
                    val = val_part
            else:
                if '#' in val:
                    parts = val.split('#', 1)
                    val = parts[0].strip()
                    inline_comment = parts[1].strip()
            
            # Clean outer quotes for display/analysis
            clean_val = val
            if (clean_val.startswith('\"') and clean_val.endswith('\"')) or (clean_val.startswith(\"'\") and clean_val.endswith(\"'\")):
                clean_val = clean_val[1:-1]
                
            final_comment = inline_comment or prev_comment
            
            print(f'{idx}|{is_export}|{var_name}|{clean_val}|{final_comment}|{current_section}')
            prev_comment = ''
" "$file" 2>/dev/null || awk -F'=' '
    /^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/ {
        line = $0
        sub(/^[[:space:]]*/, "", line)
        is_exp = (line ~ /^export/) ? "EXPORT" : "VAR"
        sub(/^export[[:space:]]+/, "", line)
        vname = substr(line, 1, index(line, "=")-1)
        vval = substr(line, index(line, "=")+1)
        print NR "|" is_exp "|" vname "|" vval "||General"
    }
' "$file"
}

# --- Statistics & Health Summary ---
_get_stats() {
    local file="$1"
    local parsed
    parsed="$(_parse_env_file "$file")"
    local total_vars
    total_vars=$(echo "$parsed" | grep -c . || echo 0)
    [[ "$total_vars" -eq 0 ]] && { echo "0|0|0"; return; }

    local dup_names
    dup_names=$(echo "$parsed" | cut -d'|' -f3 | sort | uniq -d | wc -l)
    
    local dup_vals
    dup_vals=$(echo "$parsed" | awk -F'|' 'length($4)>3 {print $4}' | sort | uniq -d | wc -l)

    echo "$total_vars|$dup_names|$dup_vals"
}

# --- UI Header ---
_draw_header() {
    local file="$1"
    local stats
    stats="$(_get_stats "$file")"
    local total="${stats%%|*}"
    local rem="${stats#*|}"
    local dup_n="${rem%%|*}"
    local dup_v="${rem#*|}"

    echo
    c 208 b " ⚙️  Env Manager "
    cn 244 b " (SSOT Environment Controller)"
    cn 240 "─────────────────────────────────────────────────────────────────"
    c 246 "  Target File      : "
    cn 45 b "$file"
    c 246 "  Total Variables  : "
    c 46 b "$total"
    c 246 " vars"
    c 240 " | "
    c 246 "Duplicate Names : "
    if [[ "$dup_n" -gt 0 ]]; then
        cn 196 b "$dup_n ⚠️"
    else
        cn 46 "0 (Clean)"
    fi
    c 246 "  Duplicate Values : "
    if [[ "$dup_v" -gt 0 ]]; then
        c 226 b "$dup_v repeated"
    else
        c 46 "0"
    fi
    c 240 " | "
    c 246 "Backup Dir : "
    cn 244 "$BACKUP_DIR"
    cn 240 "─────────────────────────────────────────────────────────────────"
}

# --- Function 1: List Variables ---
cmd_list() {
    local filter="${1:-}"
    _ensure_target || return 1
    
    local parsed
    parsed="$(_parse_env_file "$TARGET_FILE")"
    [[ -z "$parsed" ]] && { cn 226 "No variables found in $TARGET_FILE"; return 0; }

    echo
    c 51 b " 📋 Environment Variables in "
    cn 250 b "$(basename "$TARGET_FILE")"
    cn 240 "─────────────────────────────────────────────────────────────────"
    printf "%-5s %-28s %-25s %s\n" "LINE" "VARIABLE" "VALUE" "SECTION / COMMENT"
    cn 240 "───── ──────────────────────────── ───────────────────────── ────────────────────"

    while IFS='|' read -r lno vtype vname vval vcomm vsec; do
        [[ -z "$vname" ]] && continue
        if [[ -n "$filter" ]]; then
            if ! echo "$vname $vval $vcomm $vsec" | grep -qi "$filter"; then
                continue
            fi
        fi

        # Truncate value if too long
        local disp_val="$vval"
        if (( ${#disp_val} > 23 )); then
            disp_val="${disp_val:0:20}..."
        fi

        # Comment or Section
        local desc="${vcomm:-$vsec}"
        if (( ${#desc} > 30 )); then
            desc="${desc:0:27}..."
        fi

        printf "%-5s " "$lno"
        c 46 b "$(printf "%-28s" "$vname") "
        c 252 "$(printf "%-25s" "$disp_val") "
        cn 244 "$desc"
    done <<< "$parsed"
    cn 240 "─────────────────────────────────────────────────────────────────"
}

# --- Function 2: Search ---
cmd_search() {
    local query="${1:-}"
    _ensure_target || return 1

    if [[ -z "$query" ]]; then
        c 226 "Enter search keyword: "
        read -r query
    fi
    [[ -z "$query" ]] && { cn 226 "Search cancelled."; return 0; }

    echo
    c 51 b " 🔍 Search Results for: "
    cn 226 b "\"$query\""
    cn 240 "─────────────────────────────────────────────────────────────────"

    local parsed
    parsed="$(_parse_env_file "$TARGET_FILE")"
    local matches=0

    while IFS='|' read -r lno vtype vname vval vcomm vsec; do
        [[ -z "$vname" ]] && continue
        if echo "$vname $vval $vcomm $vsec" | grep -qi "$query"; then
            ((matches++))
            c 244 "Line $lno: "
            c 46 b "$vname"
            c 240 "="
            c 254 "\"$vval\""
            if [[ -n "$vcomm" ]]; then
                c 240 "  # "
                cn 226 "$vcomm"
            else
                cn 240 "  ($vsec)"
            fi
        fi
    done <<< "$parsed"

    if [[ "$matches" -eq 0 ]]; then
        cn 196 "  No matching variables or comments found."
    else
        echo
        cn 46 "  Found $matches match(es)."
    fi
    cn 240 "─────────────────────────────────────────────────────────────────"
}

# --- Function 3: Add Variable ---
cmd_add() {
    _ensure_target || return 1
    local var_name="${1:-}"
    local var_val="${2:-}"
    local var_desc="${3:-}"

    if [[ -z "$var_name" ]]; then
        echo
        cn 51 b " ➕ Add New Environment Variable"
        cn 240 "─────────────────────────────────────────────────────────────────"
        c 226 "  Variable Name (e.g. MY_API_KEY) : "
        read -r var_name
    fi

    # Trim and validate
    var_name="$(echo "$var_name" | tr -d '[:space:]')"
    if [[ ! "$var_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        cn 196 "❌ Invalid variable name '$var_name'. Must contain only alphanumeric and underscore, starting with letter/underscore."
        return 1
    fi

    # Check if exists
    local parsed
    parsed="$(_parse_env_file "$TARGET_FILE")"
    local existing
    existing=$(echo "$parsed" | awk -F'|' -v n="$var_name" '$3 == n {print $1 "|" $4}')
    if [[ -n "$existing" ]]; then
        local exist_line="${existing%%|*}"
        local exist_val="${existing#*|}"
        cn 196 "⚠️  Variable '$var_name' ALREADY EXISTS at line $exist_line with value: \"$exist_val\""
        c 226 "  Do you want to edit it instead? [y/N]: "
        read -r do_edit
        if [[ "$do_edit" =~ ^[Yy]$ ]]; then
            cmd_edit "$var_name"
            return $?
        fi
        return 1
    fi

    # Check similar names to warn
    local similar
    similar=$(echo "$parsed" | awk -F'|' -v n="$var_name" '
        tolower($3) ~ tolower(n) || tolower(n) ~ tolower($3) {
            if ($3 != n) print $1 "|" $3 "|" $4
        }
    ')
    if [[ -n "$similar" ]]; then
        cn 226 "ℹ️  Found similarly named variable(s):"
        while IFS='|' read -r slno sname sval; do
            [[ -n "$sname" ]] && cn 244 "   - Line $slno: $sname = \"$sval\""
        done <<< "$similar"
    fi

    if [[ -z "$var_val" ]]; then
        c 226 "  Value                           : "
        read -r var_val
    fi

    if [[ -z "$var_desc" ]]; then
        c 244 "  Description / Comment (optional): "
        read -r var_desc
    fi

    # Create backup before modification
    local bkp
    bkp="$(_create_backup "$TARGET_FILE")"
    cn 240 "  ✓ Backup created at: $bkp"

    # Append to target file
    {
        echo ""
        if [[ -n "$var_desc" ]]; then
            echo "# $var_desc"
        fi
        echo "export ${var_name}=\"${var_val}\""
    } >> "$TARGET_FILE"

    cn 46 b "✅ Successfully added '${var_name}' to $(basename "$TARGET_FILE")!"
    c 246 "   export "
    c 46 b "$var_name"
    c 240 "="
    cn 254 "\"$var_val\""
}

# --- Function 4: Edit Variable ---
cmd_edit() {
    _ensure_target || return 1
    local var_name="${1:-}"
    local new_val="${2:-}"
    local new_desc="${3:-}"

    if [[ -z "$var_name" ]]; then
        echo
        cn 51 b " ✏️  Edit Environment Variable"
        cn 240 "─────────────────────────────────────────────────────────────────"
        c 226 "  Enter Variable Name to edit : "
        read -r var_name
    fi

    var_name="$(echo "$var_name" | tr -d '[:space:]')"
    local parsed
    parsed="$(_parse_env_file "$TARGET_FILE")"
    local found
    found=$(echo "$parsed" | awk -F'|' -v n="$var_name" '$3 == n {print $1 "|" $4 "|" $5 "|" $6}')

    if [[ -z "$found" ]]; then
        # Try case-insensitive search
        local suggestions
        suggestions=$(echo "$parsed" | awk -F'|' -v n="$var_name" 'tolower($3) ~ tolower(n) {print $3}')
        cn 196 "❌ Variable '$var_name' not found in $(basename "$TARGET_FILE")."
        if [[ -n "$suggestions" ]]; then
            cn 226 "  Did you mean one of these?"
            echo "$suggestions" | while read -r s; do
                [[ -n "$s" ]] && cn 244 "    - $s"
            done
        fi
        return 1
    fi

    local line_no cur_val cur_desc cur_sec
    line_no="$(echo "$found" | cut -d'|' -f1)"
    cur_val="$(echo "$found" | cut -d'|' -f2)"
    cur_desc="$(echo "$found" | cut -d'|' -f3)"
    cur_sec="$(echo "$found" | cut -d'|' -f4)"

    echo
    c 244 "Editing: "
    c 46 b "$var_name"
    c 240 " (Line $line_no in $cur_sec)"
    echo
    c 246 "  Current Value   : "
    cn 254 "\"$cur_val\""
    c 246 "  Current Comment : "
    cn 244 "${cur_desc:-<None>}"
    cn 240 "─────────────────────────────────────────────────────────────────"

    # Scan for usages in SSOT codebase to notify impact
    local usages
    usages=$(grep -rnE "\b$var_name\b" "$_SSOT_ROOT" --include="*.sh" 2>/dev/null | grep -v "$TARGET_FILE:$line_no:" | head -5 || true)
    if [[ -n "$usages" ]]; then
        cn 226 "  ℹ️  Variable is referenced in other scripts:"
        echo "$usages" | while read -r u; do
            cn 244 "     $u"
        done
    fi

    if [[ -z "$new_val" ]]; then
        c 226 "  New Value [Press Enter to keep current]: "
        read -r input_val
        if [[ -n "$input_val" ]]; then
            new_val="$input_val"
        else
            new_val="$cur_val"
        fi
    fi

    if [[ -z "$new_desc" ]]; then
        c 244 "  New Comment [Press Enter to keep current]: "
        read -r input_desc
        if [[ -n "$input_desc" ]]; then
            new_desc="$input_desc"
        else
            new_desc="$cur_desc"
        fi
    fi

    # Backup
    local bkp
    bkp="$(_create_backup "$TARGET_FILE")"
    cn 240 "  ✓ Backup created at: $bkp"

    # Update line in place
    local new_line="export ${var_name}=\"${new_val}\""
    if [[ -n "$new_desc" ]]; then
        new_line="${new_line}  # ${new_desc}"
    fi

    # Python replacement or sed
    python3 -c "
import sys
filepath, target_line, new_content = sys.argv[1], int(sys.argv[2]), sys.argv[3]
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()
lines[target_line - 1] = new_content + '\n'
with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(lines)
" "$TARGET_FILE" "$line_no" "$new_line" 2>/dev/null || {
        sed -i "${line_no}s/.*/$(echo "$new_line" | sed 's/[\/&]/\\&/g')/" "$TARGET_FILE"
    }

    cn 46 b "✅ Successfully updated '${var_name}' at line $line_no!"
}

# --- Function 5: Delete Variable ---
cmd_delete() {
    _ensure_target || return 1
    local var_name="${1:-}"

    if [[ -z "$var_name" ]]; then
        echo
        cn 196 b " 🗑️  Delete Environment Variable"
        cn 240 "─────────────────────────────────────────────────────────────────"
        c 226 "  Enter Variable Name to delete : "
        read -r var_name
    fi

    var_name="$(echo "$var_name" | tr -d '[:space:]')"
    local parsed
    parsed="$(_parse_env_file "$TARGET_FILE")"
    local found
    found=$(echo "$parsed" | awk -F'|' -v n="$var_name" '$3 == n {print $1 "|" $4 "|" $5}')

    if [[ -z "$found" ]]; then
        cn 196 "❌ Variable '$var_name' not found in $(basename "$TARGET_FILE")."
        return 1
    fi

    local line_no cur_val cur_desc
    line_no="$(echo "$found" | cut -d'|' -f1)"
    cur_val="$(echo "$found" | cut -d'|' -f2)"
    cur_desc="$(echo "$found" | cut -d'|' -f3)"

    echo
    c 196 b "  Target: "
    c 46 b "$var_name"
    c 240 " = "
    cn 254 "\"$cur_val\""
    c 244 "  Line  : $line_no"
    [[ -n "$cur_desc" ]] && cn 244 "  Desc  : $cur_desc"
    echo

    # Check for references
    local usages
    usages=$(grep -rnE "\b$var_name\b" "$_SSOT_ROOT" --include="*.sh" 2>/dev/null | grep -v "$TARGET_FILE:$line_no:" || true)
    if [[ -n "$usages" ]]; then
        cn 196 b "  ⚠️  WARNING: This variable is used in other SSOT files:"
        echo "$usages" | head -8 | while read -r u; do
            cn 226 "     $u"
        done
        local ucount
        ucount=$(echo "$usages" | wc -l)
        if [[ "$ucount" -gt 8 ]]; then
            cn 244 "     ... and $((ucount - 8)) more occurrences."
        fi
        echo
    fi

    c 196 b "  Are you sure you want to delete '$var_name'? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        cn 226 "  Deletion cancelled."
        return 0
    fi

    local bkp
    bkp="$(_create_backup "$TARGET_FILE")"
    cn 240 "  ✓ Backup created at: $bkp"

    # Delete line
    python3 -c "
import sys
filepath, target_line = sys.argv[1], int(sys.argv[2])
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()
del lines[target_line - 1]
with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(lines)
" "$TARGET_FILE" "$line_no" 2>/dev/null || {
        sed -i "${line_no}d" "$TARGET_FILE"
    }

    cn 46 b "✅ Deleted '$var_name' (Line $line_no) from $(basename "$TARGET_FILE")."
}

# --- Function 6: Check Duplicates & Similarities ---
cmd_check() {
    _ensure_target || return 1
    echo
    c 51 b " 🔎 Audit: Duplicate & Similarity Report"
    cn 244 " for $(basename "$TARGET_FILE")"
    cn 240 "─────────────────────────────────────────────────────────────────"

    python3 -c "
import sys, re
from collections import defaultdict
from difflib import SequenceMatcher

filepath = sys.argv[1]

# 1. Parse all vars
vars_list = []
with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
    for idx, line in enumerate(f, 1):
        raw = line.strip()
        m = re.match(r'^(export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$', raw)
        if m:
            vname = m.group(2)
            rest = m.group(3).strip()
            # Clean val
            val = rest
            if '#' in val:
                val = val.split('#', 1)[0].strip()
            if (val.startswith('\"') and val.endswith('\"')) or (val.startswith(\"'\") and val.endswith(\"'\")):
                val = val[1:-1]
            vars_list.append((idx, vname, val))

# A. Exact Duplicate Names
name_counts = defaultdict(list)
for idx, name, val in vars_list:
    name_counts[name].append((idx, val))

exact_dups = {k: v for k, v in name_counts.items() if len(v) > 1}

print('=== EXACT DUPLICATE NAMES ===')
if exact_dups:
    for name, occurrences in exact_dups.items():
        print(f'DUP_NAME|{name}|' + ';'.join([f'L{idx}:\"{val}\"' for idx, val in occurrences]))
else:
    print('NONE')

# B. Duplicate Values (Paths, Keys, URLs)
val_counts = defaultdict(list)
for idx, name, val in vars_list:
    if len(val) >= 4 and not val.isdigit() and val not in ('true', 'false', '0', '1', '', 'none', 'null'):
        val_counts[val].append((idx, name))

dup_vals = {k: v for k, v in val_counts.items() if len(v) > 1}

print('=== DUPLICATE VALUES ===')
if dup_vals:
    for val, occurrences in dup_vals.items():
        print(f'DUP_VAL|{val}|' + ';'.join([f'L{idx}:{name}' for idx, name in occurrences]))
else:
    print('NONE')

# C. Similar Variable Names (Levenshtein / SequenceMatcher >= 0.72)
print('=== SIMILAR NAMES ===')
similar_pairs = []
names = list(set([x[1] for x in vars_list]))
for i in range(len(names)):
    for j in range(i + 1, len(names)):
        n1, n2 = names[i], names[j]
        ratio = SequenceMatcher(None, n1.lower(), n2.lower()).ratio()
        if 0.72 <= ratio < 1.0:
            similar_pairs.append((ratio, n1, n2))

similar_pairs.sort(reverse=True)
if similar_pairs:
    for ratio, n1, n2 in similar_pairs[:15]:
        pct = int(ratio * 100)
        print(f'SIM_NAME|{pct}%|{n1}|{n2}')
else:
    print('NONE')
" "$TARGET_FILE" 2>/dev/null | {
        local section=""
        while IFS='|' read -r type f1 f2 f3; do
            case "$type" in
                "=== EXACT DUPLICATE NAMES ===")
                    cn 196 b "📌 1. Exact Duplicate Variable Names:"
                    section="DUP_NAME"
                    ;;
                "=== DUPLICATE VALUES ===")
                    echo
                    cn 226 b "📌 2. Duplicate Values (Identical Path / Key / Config):"
                    section="DUP_VAL"
                    ;;
                "=== SIMILAR NAMES ===")
                    echo
                    cn 51 b "📌 3. Similar Variable Names (Potential Redundancy / Typos):"
                    section="SIM_NAME"
                    ;;
                "NONE")
                    cn 46 "   ✓ None found (Clean)."
                    ;;
                "DUP_NAME")
                    c 196 "   ❌ Duplicate: "
                    c 46 b "$f1 "
                    cn 244 "-> Defined multiple times: $f2"
                    ;;
                "DUP_VAL")
                    c 226 "   ⚠️  Value: "
                    c 254 "\"$f1\" "
                    cn 244 "-> Shared across: $f2"
                    ;;
                "SIM_NAME")
                    c 246 "   - [$f1 match] "
                    c 46 b "$f2"
                    c 240 " <──> "
                    cn 51 b "$f3"
                    ;;
            esac
        done
    }
    cn 240 "─────────────────────────────────────────────────────────────────"
}

# --- Function 7: Change Target File ---
cmd_change_target() {
    echo
    cn 51 b " 📂 Select Target Environment File"
    cn 240 "─────────────────────────────────────────────────────────────────"
    c 246 "  Current Target: "
    cn 45 b "$TARGET_FILE"
    echo
    cn 252 "  Available SSOT files:"
    
    local files=()
    local idx=1
    
    local candidates=(
        "$_SSOT_ROOT/bootstrap/00-env.sh"
        "$_SSOT_ROOT/core/01-colors.sh"
        "$_SSOT_ROOT/core/aliases.sh"
        "$_SSOT_ROOT/core/profiles.sh"
        "$_SSOT_ROOT/profiles/termux/.env"
        "$_SSOT_ROOT/profiles/wsl/.env"
        "$_SSOT_ROOT/profiles/mumu/.env"
    )
    
    for cand in "${candidates[@]}"; do
        if [[ -f "$cand" ]]; then
            files+=("$cand")
            c 226 "   [$idx] "
            cn 254 "$cand"
            ((idx++))
        fi
    done
    
    c 226 "   [c] "
    cn 244 "Enter Custom File Path"
    echo
    c 226 "  Select [1-$((idx-1))] or path: "
    read -r choice
    
    if [[ -z "$choice" ]]; then
        cn 244 "  Target unchanged."
        return 0
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice < idx )); then
        TARGET_FILE="${files[$((choice-1))]}"
        cn 46 b "  ✓ Switched target file to: $TARGET_FILE"
    elif [[ "$choice" == "c" || "$choice" == "C" ]]; then
        c 226 "  Enter full path to file: "
        read -r custom_path
        if [[ -f "$custom_path" ]]; then
            TARGET_FILE="$custom_path"
            cn 46 b "  ✓ Switched target file to: $TARGET_FILE"
        else
            cn 196 "  ❌ File does not exist: $custom_path"
        fi
    elif [[ -f "$choice" ]]; then
        TARGET_FILE="$choice"
        cn 46 b "  ✓ Switched target file to: $TARGET_FILE"
    else
        cn 196 "  ❌ Invalid selection or file not found."
    fi
}

# --- Function 8: Backup & Restore Management ---
cmd_backup_menu() {
    echo
    cn 51 b " 💾 Backup & Restore"
    cn 240 "─────────────────────────────────────────────────────────────────"
    c 246 "  Target File : "
    cn 45 b "$TARGET_FILE"
    c 246 "  Backup Dir  : "
    cn 244 "$BACKUP_DIR"
    echo
    cn 252 "  Options:"
    cn 226 "   [1] Create manual backup snapshot now"
    cn 226 "   [2] List existing backups"
    cn 226 "   [3] Restore from a backup"
    cn 244 "   [0] Back to main menu"
    echo
    c 226 "  Choice [0-3]: "
    read -r bchoice

    case "$bchoice" in
        1)
            local bkp
            bkp="$(_create_backup "$TARGET_FILE")"
            cn 46 b "  ✅ Backup created successfully: $bkp"
            ;;
        2)
            echo
            cn 51 "  Existing backups for $(basename "$TARGET_FILE"):"
            ls -1t "$BACKUP_DIR"/$(basename "$TARGET_FILE")*.bak 2>/dev/null | head -10 | while read -r bf; do
                c 244 "   - "
                c 46 "$(basename "$bf") "
                cn 240 "($(date -r "$bf" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$bf" 2>/dev/null || echo ''))"
            done || cn 244 "   No backups found in $BACKUP_DIR"
            ;;
        3)
            echo
            local bkp_list=()
            local bidx=1
            while IFS= read -r bf; do
                [[ -z "$bf" ]] && continue
                bkp_list+=("$bf")
                c 226 "   [$bidx] "
                c 46 "$(basename "$bf") "
                cn 240 "($(date -r "$bf" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$bf" 2>/dev/null || echo ''))"
                ((bidx++))
            done < <(ls -1t "$BACKUP_DIR"/$(basename "$TARGET_FILE")*.bak 2>/dev/null | head -10)

            if [[ ${#bkp_list[@]} -eq 0 ]]; then
                cn 196 "  No backups available to restore."
                return 0
            fi

            c 226 "  Select backup to restore [1-$((bidx-1))] (or 0 to cancel): "
            read -r rsel
            if [[ "$rsel" =~ ^[1-9][0-9]*$ ]] && (( rsel <= ${#bkp_list[@]} )); then
                local chosen_bkp="${bkp_list[$((rsel-1))]}"
                c 196 b "  ⚠️  This will overwrite $TARGET_FILE with $(basename "$chosen_bkp"). Continue? [y/N]: "
                read -r rconf
                if [[ "$rconf" =~ ^[Yy]$ ]]; then
                    _create_backup "$TARGET_FILE" >/dev/null 2>&1
                    cp "$chosen_bkp" "$TARGET_FILE"
                    cn 46 b "  ✅ Restored successfully from $chosen_bkp!"
                else
                    cn 226 "  Restore cancelled."
                fi
            fi
            ;;
        *)
            return 0
            ;;
    esac
}

# --- Interactive TUI Main Loop ---
tui_main() {
    while true; do
        clear 2>/dev/null || true
        _draw_header "$TARGET_FILE"
        echo
        cn 254 b "  ACTION MENU:"
        cn 226 "   [1] 📋 List All Variables"
        cn 226 "   [2] 🔍 Search (Name / Value / Description)"
        cn 226 "   [3] ➕ Add New Variable"
        cn 226 "   [4] ✏️  Edit Variable"
        cn 226 "   [5] 🗑️  Delete Variable"
        cn 226 "   [6] 🔎 Check Duplicates & Similarities"
        cn 226 "   [7] 📂 Switch Target File"
        cn 226 "   [8] 💾 Backup & Restore"
        cn 244 "   [0] 🚪 Exit"
        echo
        c 226 b "  Select option [0-8]: "
        read -r opt

        case "$opt" in
            1)
                cmd_list
                echo
                c 244 "Press Enter to continue..."
                read -r _
                ;;
            2)
                cmd_search
                echo
                c 244 "Press Enter to continue..."
                read -r _
                ;;
            3)
                cmd_add
                echo
                c 244 "Press Enter to continue..."
                read -r _
                ;;
            4)
                cmd_edit
                echo
                c 244 "Press Enter to continue..."
                read -r _
                ;;
            5)
                cmd_delete
                echo
                c 244 "Press Enter to continue..."
                read -r _
                ;;
            6)
                cmd_check
                echo
                c 244 "Press Enter to continue..."
                read -r _
                ;;
            7)
                cmd_change_target
                echo
                c 244 "Press Enter to continue..."
                read -r _
                ;;
            8)
                cmd_backup_menu
                echo
                c 244 "Press Enter to continue..."
                read -r _
                ;;
            0|q|Q|exit)
                echo
                cn 46 "Goodbye! 👋"
                break
                ;;
            *)
                cn 196 "Invalid option. Please enter 0-8."
                sleep 1
                ;;
        esac
    done
}

# --- CLI Dispatcher ---
case "$CLI_CMD" in
    ls|list)
        cmd_list "$@"
        ;;
    s|search|find)
        cmd_search "$@"
        ;;
    a|add|new)
        cmd_add "$@"
        ;;
    e|edit|set)
        cmd_edit "$@"
        ;;
    d|del|delete|rm)
        cmd_delete "$@"
        ;;
    c|check|audit|dup)
        cmd_check "$@"
        ;;
    target|file)
        cmd_change_target
        ;;
    bkp|backup)
        cmd_backup_menu
        ;;
    help|-h|--help)
        echo "Usage: env-manager.sh [options] [command] [args...]"
        echo ""
        echo "Options:"
        echo "  -f, --target <file>   Specify target env file (Default: $DEFAULT_TARGET)"
        echo ""
        echo "Commands:"
        echo "  list [filter]         List variables in target file"
        echo "  search <keyword>      Search variables by name, value, or comment"
        echo "  add <name> <val> [desc] Add new variable"
        echo "  edit <name> [val] [desc] Edit existing variable"
        echo "  del <name>            Delete variable"
        echo "  check                 Audit duplicate names, values, and similar names"
        echo "  backup                Manage backups and restores"
        echo "  (no command)          Launch interactive TUI mode"
        ;;
    "")
        tui_main
        ;;
    *)
        cn 196 "Unknown command '$CLI_CMD'. Run with --help or no arguments for interactive TUI."
        exit 1
        ;;
esac
