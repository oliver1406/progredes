#!/bin/bash
# exercicio 3 
echo "Digite o caminho do arquivo ou diretório: "
read FILE
if [ -f "$FILE" ]; then
	echo "$FIlE é um arquivo comum"
elif [ -d "$FILE" ]; then
	echo "$FILE é um diretório"
else
	echo "$FILE é alguma outra coisa"
fi

echo "Listagem detalhada"
ls -lh "$FILE"
