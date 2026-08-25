#!/bin/bash

diretorio="$1"

if [ ! -d "$diretorio" ]; then
    echo "O $diretorio não é um diretório!"
    exit 1
fi

quantidade=$(find "$diretorio" -maxdepth 1 -type f | wc -l)

echo "O $diretorio tem $quantidade arquivos."
