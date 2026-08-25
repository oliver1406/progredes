#!/bin/bash

diretorio="$1"
extensao="$2"
data=$(date +%Y-%m-%d)

for arquivo in "$diretorio"/*."$extensao"
do
    if [ -f "$arquivo" ]; then
        nome=$(basename "$arquivo")
        novo_nome="${data}-${nome}"

        echo "Antes: $nome"
        echo "Depois: $novo_nome"
        echo

        mv "$arquivo" "$diretorio/$novo_nome"
    fi
done
