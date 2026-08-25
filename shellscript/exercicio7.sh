#!/bin/bash

for item in "$@"
do
    if [ ! -d "$item" ]; then
        echo "O $item não é um diretório!"
    else
        quantidade=$(find "$item" -maxdepth 1 -type f | wc -l)
        echo "O $item tem $quantidade arquivos."
    fi
done
