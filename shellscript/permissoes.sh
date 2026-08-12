#!/bin/bash
#Desafio Prático Integrado
#Cenário: A empresa precisa de uma pasta compartilhada chamada /projetos/backend para a equipe de desenvolvimento.

#Instruções:

#Crie o grupo devs.
#Crie os usuários lucas e juliana, ambos pertencentes ao grupo devs.
#Crie o diretório /projetos/backend.
#Configure a pasta /projetos/backend para que:
#O dono seja o root e o grupo seja devs.
#Membros do grupo devs tenham acesso total (leitura, escrita e execução/navegação).
#Usuários fora do grupo devs não tenham nenhum acesso (nem leitura, nem navegação).
#Qualquer arquivo criado dentro da pasta por lucas ou juliana pertença automaticamente ao grupo devs (dica: SGID).


echo "Criando o grupo devs"
groupadd devs
echo "Criando o User Lucas"
useradd -M lucas -g devs -p "lucas" -e "2026-08-31" -c "lucas"
echo "Criando o user Juliana"

