#!/bin/bash

ip="$1"

if ping -c 1 -W 1 "$ip" > /dev/null 2>&1; then
    echo "O endereço $ip está online."
else
    echo "O endereço $ip está offline."
fi
