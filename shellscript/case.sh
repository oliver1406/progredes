#!/bin/bash

echo "escolha uma cor (vermelho, azul ou verde):"
read cor
case $cor in
	vermelho)
		echo "você escolheu vermelho"
		;;
	azul)
		echo "você escolheu azul"
		;;
	verde)
		echo "você escolheu verde"
		;;
	*)
		echo "cor desconhecida"
		;;
esac
