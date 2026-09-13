#!/usr/bin/env bash
# ------------------------------------------------------------
# File: test.sh
# ------------------------------------------------------------

 source "01-colors.sh"
 echo "TEST something"
 for f in $(ls -ltr $bin); do
    echo $f
done

