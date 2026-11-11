#!/usr/bin/env sh
set -eu
file=/status/db-last-success
if [ ! -r "$file" ]; then printf '999999999\n'; exit 0; fi
last=$(cat "$file")
case "$last" in ''|*[!0-9]*) exit 1;; esac
now=$(date +%s)
[ "$last" -le "$now" ] || exit 1
printf '%s\n' "$((now-last))"
