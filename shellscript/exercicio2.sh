#!/bin/bash
#exercicio 2

FILE="/etc/passwd"
if [ -e $FILE ]; then
	echo "o caminho $FILE está habilitado."
	if [ -r $FILE -a -w $FILE ]; then
		echo "você tem permissão para editar $FILE"
	else
		echo "Voce NÂO foi autorizado a editar $FILE"
	fi
fi

