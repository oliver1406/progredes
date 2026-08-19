#!/bin/bash
# exercicio 4

if [ -f $1 ]; then
	echo "$1 é um arquivo comum"
elif [ -d $1 ]; then
	echo "$1 é um diretório"
else
	echo "$1 é uma outra coisa"
fi
ls -lh $1
