#!/bin/bash
# ครอบคลุม: while, if/elif/else, case, substitution, redirect, glob
set -u
dir=/tmp/codetrans-test2
mkdir -p "$dir"
total=0
while [ $total -lt 3 ]; do
  total=$((total + 1))
  echo "step $total"
done

if [ -d "$dir" ]; then
  echo "dir exists"
elif [ -n "$dir" ]; then
  echo "dir name set"
else
  echo "no dir"
fi

case "$total" in
  3) echo "three" ;;
  4) echo "four" ;;
  *) echo "other" ;;
esac

files=$(ls /tmp | head -2)
echo "files: $files"

grep -c . /etc/hostname > "$dir/count.txt"
cat "$dir/count.txt"

for f in "$dir"/*.txt; do
  echo "file: $f"
done

rm -rf "$dir"
