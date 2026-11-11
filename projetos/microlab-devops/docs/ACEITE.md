# Aceite do laboratório Docker — execução real pendente

Registrar data/hora, computador/daemon, versões Docker/Compose, SHA, image IDs, resultado, evidência sem segredo e revisor. Execute primeiro em um Docker destinado ao ensaio. No Desktop, registre recursos reservados e comportamento quando a sessão termina, a máquina suspende ou reinicia. Nenhum cenário abaixo foi executado com containers nesta revisão.

| ID | Cenário | Resultado obrigatório | Estado |
|---|---|---|---|
| A1 | Pasta limpa e Docker Linux | Lançador constrói administrador e inicia serviços sem instalar Debian/Tailscale/pacotes no host | Pendente |
| A2 | Reexecução e edição do clone | Senhas/volumes preservados; código revisado atualizado; configuração pública e privada separadas | Pendente |
| A3 | Stop/up, down/up e reboot | Contas/dados mantidos; Docker/Desktop volta conforme política adotada; confirmar saúde e backup após retorno | Pendente |
| A4 | Acesso local e proxy | Portas respondem no próprio computador; outro computador não acessa administração pelo perfil local; rotas NPM funcionam | Pendente |
| A5 | GitHub, réplica e runner | SHA pertence à main oficial; push controlado; token revogado; job real termina CI_PASSED | Pendente |
| A6 | CI negativo | Health/versão quebrados reprovam job e não produzem evidência aprovável | Pendente |
| A7 | Homologação e produção demonstrativa | Bancos/dados distintos; promoção mantém image ID, sem rebuild; aceite registrado | Pendente |
| A8 | Deploy com falha e rollback | Não promove candidato inválido; falha pós-deploy restaura imagem anterior validada; dado sentinela preservado | Pendente |
| A9 | Coleta e Grafana | Dados recentes no host microlab-docker, idade backup e checks HTTP; datasource/painéis validados; escopo das métricas identificado | Pendente |
| A10 | Alertas | Falha controlada de app/backup gera PROBLEM e RECOVERY, recebidos no canal autorizado | Pendente |
| A11 | Máquina/Docker indisponível | Verificador independente detecta falta de acesso; caminho remoto necessário definido antes desse ensaio | Pendente |
| A12 | Backup negativo | Credencial inválida/disco cheio/banco indisponível falham sem avançar marcador nem apagar último conjunto bom | Pendente |
| A13 | Restauração SQL | Dump em container descartável contém a estrutura e o dado sentinela esperados | Pendente |
| A14 | Restauração externa integral | Outro Docker vazio recupera ferramentas/config/certificados/imagens/bancos com backup externo e chaves independentes | Pendente |
| A15 | Update, capacidade e segurança | Versões reais/pacotes registrados e escaneados; consumo medido; concorrência, retenção e permissões adequadas | Pendente |

O administrador e o runner com socket são administrativos. Não ensaiar falhas destrutivas no Docker que contém outros projetos importantes. O ambiente é único por daemon; não subir duas pastas como se tivessem volumes diferentes.

A VM Debian deixou de ser pré-requisito destes testes. A disponibilidade do Docker em funcionamento passou a ser o requisito de execução. Monitoramento completo do sistema operacional físico, atualização de kernel, firewall e acesso de recuperação do servidor de destino são uma etapa própria, fora da simulação de serviços.

Somente depois de todos os cenários aplicáveis terem evidência é possível aceitar o ambiente para a finalidade definida. O perfil local ainda não entrega acesso compartilhado remoto, canais de alerta ou backup externo sem configuração complementar.
