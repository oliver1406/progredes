#!/bin/bash
a=5
b=3
soma=$((a + b))
echo "soma: $soma"
if [ $a -gt $b ]; then
	echo "$a é maior que $b"
fi

