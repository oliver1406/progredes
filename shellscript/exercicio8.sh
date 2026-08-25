#!/bin/bash

data=$(date +%Y-%m-%d)

for arquivo in *.png
do
    if [ -f "$arquivo" ]; then
        mv "$arquivo" "${data}-${arquivo}"
    fi
done
