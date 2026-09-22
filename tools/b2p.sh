#!/usr/bin/env bash
# ============================================================
# tools/b2p.sh — Bash → Python Side-by-Side Trainer
# ============================================================
# For Joe: you know Bash, now learn Python — side by side.
#
# Modes:
#   b2p                     all pairs as a cheat sheet
#   b2p -t <TOPIC>          only one topic (VAR, STR, ARR ...)
#   b2p --topics            list topics
#   b2p -q [N] [-t TOPIC]   quiz flip-card mode (N cards)
#   b2p -r [N]              N random cards (from all topics)
#   b2p -h                  this help
# ============================================================

set -uo pipefail 2>/dev/null || true

# --- SSOT Color Engine (with fallback) ---
_SSOT_ROOT="${SSOT:-$HOME/ssot}"
if [[ -f "$_SSOT_ROOT/core/01-colors.sh" ]]; then
    source "$_SSOT_ROOT/core/01-colors.sh"
fi
if ! declare -f cn >/dev/null 2>&1; then
    cn() { local col="${1:-}" style="${2:-}"; shift 2 2>/dev/null || shift $#; echo "$*"; }
    c()  { local col="${1:-}" style="${2:-}"; shift 2 2>/dev/null || shift $#; printf "%s" "$*"; }
fi

# --- Topic code → display name ---
declare -A TOPIC_BN=(
    [VAR]="Variables"
    [STR]="Strings"
    [ARR]="Lists / Arrays"
    [DICT]="Dictionaries"
    [COND]="Conditionals"
    [LOOP]="Loops"
    [FUNC]="Functions"
    [FILE]="Files & IO"
    [CMD]="Shell-out / Commands"
    [ERR]="Errors & exit"
    [PRINT]="Print & formatting"
)

# --- Data: topic<TAB>bash<TAB>python<TAB>expl (expl optional) ---
_load_data() {
    cat <<'B2P_EOF'
VAR	export VAR=value	os.environ['VAR'] = 'value'	reaches child processes
VAR	var=value	var = value	only this scope
VAR	unset VAR	del VAR	or just VAR = None
VAR	read VAR	VAR = input()	always returns a str
VAR	echo "$VAR"	print(VAR)	or better: print(f'{VAR}')
STR	s="${a}${b}"	s = a + b	or f-string: f'{a}{b}'
STR	len=${#s}	n = len(s)	
STR	${s^^}	s.upper()	
STR	${s,,}	s.lower()	
STR	${s:0:3}	s[0:3]	last index excluded
STR	${s//a/b}	s.replace('a', 'b')	all occurrences
STR	${s%.ext}	s.removesuffix('.ext')	Python 3.9+
STR	printf "%s-%s" a b	f'{a}-{b}'	
ARR	arr=(a b c)	arr = ['a', 'b', 'c']	
ARR	${arr[0]}	arr[0]	starts at index 0
ARR	${arr[@]}	arr	all elements
ARR	${#arr[@]}	len(arr)	
ARR	arr+=(d)	arr.append('d')	add at the end
ARR	${arr[@]:1:2}	arr[1:3]	slice — end excluded
ARR	for i in "${arr[@]}"; do :; done	for i in arr:	direct iteration
DICT	declare -A d	d = {}	or d = dict()
DICT	d[key]="val"	d['key'] = 'val'	
DICT	${d[key]}	d['key']	avoid KeyError: d.get('key')
DICT	${!d[@]}	d.keys()	all keys
DICT	${d[@]}	d.values()	all values
DICT	[[ -v d[key] ]]	'key' in d	existence check
COND	[[ -z "$s" ]]	if not s:	empty / unset
COND	[[ -n "$s" ]]	if s:	non-empty
COND	[[ $a -eq $b ]]	a == b	-eq → ==
COND	[[ $a -ne $b ]]	a != b	
COND	[[ $a -gt $b ]]	a > b	also: -lt → <, -ge → >=
COND	[[ -f "$f" ]]	os.path.isfile(f)	import os
COND	[[ -d "$d" ]]	os.path.isdir(d)	
COND	[[ $s =~ ^a+$ ]]	re.match(r'^a+$', s)	import re
COND	a && b	if a: b	run only when true
COND	a || b	a or b	
COND	case $x in a) :;; esac	match x: case 'a': ...	Python 3.10+
COND	! cond	not cond	boolean negation
LOOP	for i in {1..10}	for i in range(1, 11):	last number excluded
LOOP	for i in $(seq 1 10)	for i in range(1, 11):	
LOOP	for ((i=0; i<10; i++))	for i in range(10):	0 to 9
LOOP	while [[ $i -lt 10 ]]	while i < 10:	while the condition is true
LOOP	for f in *.txt	for f in glob.glob('*.txt'):	import glob
LOOP	break	break	same
LOOP	continue	continue	same
FUNC	myfunc() { :; }	def myfunc():	indentation = block
FUNC	myfunc a b	myfunc(a, b)	argument → parameter
FUNC	$1 / $2	def myfunc(a, b):	inside the function
FUNC	return 0	return	returns None
FUNC	echo "res" >&1 (in func)	return 'res'	return the result
FUNC	result=$(myfunc)	result = myfunc()	capture the result
FILE	cat file	print(open('file').read())	shortcut — with open() is better
FILE	echo hi > file	open('file', 'w').write('hi\n')	'w' = overwrite
FILE	echo hi >> file	open('file', 'a').write('hi\n')	'a' = append
FILE	while read -r l; do :; done < f	for line in open('f'):	line by line
FILE	wc -l file	sum(1 for _ in open('file'))	
FILE	head -n 5 file	list(open('file'))[:5]	
CMD	ls -la	subprocess.run(['ls', '-la'])	import subprocess
CMD	out=$(cmd)	out = subprocess.check_output(['cmd']).decode()	bytes → str
CMD	cmd 2>/dev/null	subprocess.run(..., stderr=subprocess.DEVNULL)	hide errors
CMD	cmd | grep x	[l for l in out.splitlines() if 'x' in l]	pipe → filter in python
CMD	$?	proc.returncode	from subprocess.run() result
ERR	exit 0	sys.exit(0)	import sys
ERR	exit 1	sys.exit(1)	non-zero = error
ERR	echo "err" >&2	print('err', file=sys.stderr)	stderr stream
ERR	set -e	try: ... except Exception: ...	handle failures yourself
PRINT	echo "hello"	print('hello')	
PRINT	echo -n "hi"	print('hi', end='')	no newline
PRINT	printf "%02d" 7	f'{7:02d}'	leading zero
PRINT	printf "%s %d" name 5	f'{name} {5}'	or '{} {}'.format(name, 5)
PRINT	printf "%-10s" x	f'{x:<10}'	left-align padding
B2P_EOF
}

mapfile -t _LINES < <(_load_data)

# _collect <topic|""> → matching line indices (one per line on stdout)
_collect() {
    local t="$1" i tp
    for ((i=0; i<${#_LINES[@]}; i++)); do
        tp="${_LINES[$i]%%$'\t'*}"
        if [[ -z "$t" || "$tp" == "$t" ]]; then
            printf '%s\n' "$i"
        fi
    done
}

# _header <topic|"">
_header() {
    local t="$1"
    if [[ -z "$t" ]]; then
        cn 45 bu "══ bash → python ── side by side ──  (${#_LINES[@]} pairs) ══"
    else
        cn 45 bu "══ ${TOPIC_BN[$t]:-$t} ══"
    fi
}

# ============ CHEAT SHEET ============
_cheat() {
    local t="$1" wb=0 wp=0 i tp b p e
    local -a idx=()
    mapfile -t idx < <(_collect "$t")
    [[ ${#idx[@]} -eq 0 ]] && { cn 196 b "Topic not found: ${t:-?}" >&2; return 1; }

    for i in "${idx[@]}"; do
        IFS=$'\t' read -r tp b p e <<< "${_LINES[$i]}"
        (( ${#b} > wb )) && wb=${#b}
        (( ${#p} > wp )) && wp=${#p}
    done
    wb=$((wb + 1))

    _header "$t"
    local prev_tp=""
    for i in "${idx[@]}"; do
        IFS=$'\t' read -r tp b p e <<< "${_LINES[$i]}"
        if [[ "$tp" != "$prev_tp" ]]; then
            printf '\n'
            cn 39 bu "  ▸ ${TOPIC_BN[$tp]:-$tp}"
            prev_tp="$tp"
        fi
        printf '  %s %s %s\n' "$(c 226 b "$(printf '%-*s' "$wb" "$b")")" "$(c 250 '→')" "$(c 82 b "$p")"
        [[ -n "$e" && "$e" != " " ]] && printf '      %s\n' "$(c 245 " # $e")"
    done
    printf '\n'
    cn 250 "Tip: b2p -q  → quiz mode,  b2p -r 5  → 5 random cards"
    printf '\n'
}

# ============ QUIZ (flip-card) ============
_quiz() {
    local t="$1" n="$2" i j tmp k
    local -a idx=()
    mapfile -t idx < <(_collect "$t")
    [[ ${#idx[@]} -eq 0 ]] && { cn 196 b "Topic not found: ${t:-?}" >&2; return 1; }
    (( n > ${#idx[@]} )) && n=${#idx[@]}

    # Fisher–Yates shuffle
    for ((i=${#idx[@]}-1; i>0; i--)); do
        j=$(( RANDOM % (i+1) ))
        tmp="${idx[$i]}"; idx[$i]="${idx[$j]}"; idx[$j]="$tmp"
    done

    local tp b p e guess
    for ((k=0; k<n; k++)); do
        IFS=$'\t' read -r tp b p e <<< "${_LINES[${idx[$k]}]}"
        printf '\n'
        cn 39 bu "── Card $((k+1))/$n │ ${TOPIC_BN[$tp]:-$tp} ──"
        printf '  %s  %s\n' "$(c 226 b 'BASH  :')" "$b"
        if [[ -t 0 ]]; then
            printf '  Type your Python guess + Enter (or plain Enter to reveal): '
            read -r guess
        fi
        printf '  %s  %s\n' "$(c 82 b 'PYTHON:')" "$p"
        [[ -n "$e" && "$e" != " " ]] && printf '  %s %s\n' "$(c 245 '#')" "$e"
    done
    printf '\n'
    cn 250 "Done! Again: b2p -q,  another topic: b2p -t COND -q"
    printf '\n'
}

# ============ TOPICS ============
_topics() {
    cn 45 bu "All topics:"
    local k
    for k in VAR STR ARR DICT COND LOOP FUNC FILE CMD ERR PRINT; do
        printf '  %-5s %s\n' "$(c 226 b "$k")" "${TOPIC_BN[$k]}"
    done
    printf '\n'
}

# ============ HELP ============
_help() {
    cat <<EOF

b2p — bash → python side-by-side trainer

USAGE:
  b2p                  all pairs as a cheat sheet
  b2p -t <TOPIC>       only one topic
  b2p --topics         list topics
  b2p -q [N] [-t TP]   quiz mode (N cards, default 10)
  b2p -r [N]           N random cards
  b2p -h               this help

TOPICS: VAR STR ARR DICT COND LOOP FUNC FILE CMD ERR PRINT
EOF
}

# ============ MAIN ============
MODE="cheat"; TOPIC=""; NUM=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    MODE="help"; shift ;;
        --topics)     MODE="topics"; shift ;;
        -q|--quiz)    MODE="quiz"; shift ;;
        -r|--random)  MODE="quiz"; shift ;;
        -t|--topic)   TOPIC="${2^^}"; shift 2 ;;
        [0-9]*)       NUM="$1"; shift ;;
        *)            cn 196 b "Unknown option: $1  (b2p -h for help)" >&2; exit 1 ;;
    esac
done

if [[ -n "$NUM" && "$MODE" == "cheat" ]]; then
    MODE="quiz"
fi
[[ -n "$NUM" ]] || NUM=10

case "$MODE" in
    help)   _help ;;
    topics) _topics ;;
    quiz)   _quiz "$TOPIC" "$NUM" || exit $? ;;
    *)      _cheat "$TOPIC" || exit $? ;;
esac
exit 0