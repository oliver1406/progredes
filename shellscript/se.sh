#!/bin/bash
echo "digite um número"
read num

if [ $num -gt 10 ]; then
	echo "o numero é maior que 10."
else 
	echo "o numero é menor ou igual a 10."
fi
