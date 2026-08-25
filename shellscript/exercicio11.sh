#!/bin/bash

arquivo="$1"

online="online.log"
offline="offline.log"

> "$online"
> "$offline"

while IFS= read -r ip
do
    if [ -z "$ip" ]; then
        continue
    fi

    if ping -c 1 -W 1 "$ip" > /dev/null 2>&1; then
        echo "$ip está online."
        echo "$ip" >> "$online"
    else
        echo "$ip está offline."
        echo "$ip" >> "$offline"
    fi

done < "$arquivo"

echo
echo "IPs online foram salvos em: $online"
echo "IPs offline foram salvos em: $offline"
