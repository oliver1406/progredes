> Histórico da revisão anterior, baseada em Debian. A operação vigente foi substituída pelo perfil [Docker local](MIGRACAO-DOCKER.md); use o [README atual](../README.md).

# Revisão dos anexos e decisões

Data da revisão: 28/10/2026. Fontes: `docker-compose-final.yaml`, `setup-server.sh`, `set-runner-token.sh`, `zabbix-bootstrap.sh` e `diagrama-arquitetura.jpeg`, confirmados pelo usuário. Os originais foram preservados fora deste repositório de entrega, no diretório de trabalho da revisão. Dois agentes fizeram leituras independentes de instalação e operação; o responsável integrou as correções e verificações.

## Parecer

Os anexos descreviam a intenção do laboratório, mas não uma entrega completa. Faltavam `.env.example`, configuração do runner, aplicação, pipeline e procedimentos de recuperação. Iniciar containers seria insuficiente para comprovar entrega de serviços.

| Evidência no material original | Impacto | Tratamento nesta base |
|---|---|---|
| Setup linhas 34–35 e Compose 71–74 exigem arquivos ausentes | Instalação/runner não reproduzíveis | Estrutura canônica, ambiente gerado e configuração runtime do runner |
| Compose 78–87: aplicação comentada | Nada para implantar/validar | Demo HTTP explícita; integração da aplicação real continua necessária |
| Nenhum workflow nos anexos | Registro do runner não entrega CI/CD | Workflow Gitea, smoke test e scripts separados de staging/promoção/rollback |
| `pg_dump \| gzip` em laço, Compose 188–191 | Gzip vazio pode parecer backup bom | Formato custom, retorno obrigatório, `pg_restore --list`, checksum, conjunto temporário e marcador após sucesso |
| Somente banco da aplicação com dump | Zabbix sem recuperação lógica | Dumps separados de produção, homologação e Zabbix |
| Gitea/Grafana/NPM copiados ao vivo; certificados ausentes | SQLite inconsistente e perda de configuração | Snapshot de ferramentas paradas, certificados, configuração e imagens de release |
| Duplicati sem destino/job | Nenhuma cópia externa demonstrada | Roteiro obrigatório de destino, passphrase, retenção e restauração remota; ainda depende da equipe |
| Tags `latest`/amplas, plugin sem versão | Atualizações implícitas | Compose usa digests; plugin fixado; atualização explícita por lock e revisão |
| Runner com socket Docker, Compose 75 | Job pode controlar host | Risco mantido e explicitado para laboratório confiável; sem execução de código externo |
| Rede do runner confundida com rede de jobs | Checkout/serviços podem ser inacessíveis | Rede explícita `microlab-ci`, capacidade 1 e imagem de ferramentas própria |
| Token em `.env` e container permanente | Credencial reutilizável inspecionável | Registro em container transitório; token não fica no daemon permanente; revogação exigida |
| Setup 129–136 só ordena tailscaled | IP pode faltar no reboot | Unidade da stack espera pelo endereço específico com timeout e repetição |
| Reexecução sem Tailscale mantém bind antigo | Agente e servidor podem divergir | Falha explícita; nenhuma troca silenciosa para loopback |
| Falha de instalação do agente vira aviso | Resumo pode anunciar sucesso incompleto | Instalação obrigatória, série verificada e serviço ativo; amostra real exigida no bootstrap |
| API sem timeout; fallback altera host padrão | Espera ilimitada e migração indevida | Chamadas limitadas, envelope validado, host próprio marcado como gerenciado, sem `templates_clear` |
| Grafana só instala plugin | Dashboard não comprova coleta/alerta | Datasource dedicado com teste; consultas e painéis precisam validação de métricas reais |
| Monitor no mesmo host | Queda total impede novo alerta local | Verificador externo obrigatório no aceite; não incluído como serviço local fictício |
| Diagrama mostra Kuma, dois runners e registry | Desenho promete componentes ausentes | Arquitetura textual corrigida; um runner, imagens locais e Zabbix/Grafana |

## Decisões de escopo

O usuário confirmou manter Gitea no laboratório. Há **um projeto oficial no GitHub**, replicado em um repositório comum no Gitea. Não existe desenvolvimento independente ou sincronização bidirecional. O push controlado de um SHA aprovado dispara o pipeline; não se presume que um pull mirror gere o evento desejado.

Não foi acrescentado registry local: a aplicação é construída no daemon do laboratório e identificada pelo ID de conteúdo. As imagens ativas e anterior entram no snapshot para recuperação. Em implantação com vários hosts, substituir esse armazenamento por registry autenticado e promover pelo digest, mantendo os mesmos critérios de teste.

A demonstração é estática: o teste SQL separado verifica disponibilidade do banco, sem provar uma transação de negócio. Quando a aplicação real chegar, ela precisa de teste funcional com banco, migrações compatíveis e regras próprias de recuperação. Reverter imagem não desfaz migração de dados.

As portas diretas são acessos administrativos/diagnósticos privados, publicados somente no IP definido. NPM exige cadastro real de proxy hosts e DNS. HTTP dentro da tailnet tem proteção de transporte VPN, mas não fornece certificado HTTPS ao navegador. Acesso de pessoas depende das ACLs/grants da tailnet.

## Referências oficiais usadas

- [Docker: ordem de inicialização e saúde](https://docs.docker.com/compose/how-tos/startup-order/) e [acesso ao daemon](https://docs.docker.com/engine/security/protect-access/).
- [Gitea Runner 5: instalação Docker](https://docs.gitea.com/runner/installation/docker/) e [configuração correspondente](https://docs.gitea.com/runner/reference/config-example/). O antigo `gitea/act_runner` foi sucedido por `gitea/runner`; esta base fixa o novo binário por digest.
- [Gitea: backup e restauração](https://docs.gitea.com/administration/backup-and-restore/) e [Grafana: backup](https://grafana.com/docs/grafana/latest/administration/back-up-grafana/).
- [Zabbix 7.0: host.update](https://www.zabbix.com/documentation/7.0/en/manual/api/reference/host/update) e [API](https://www.zabbix.com/documentation/7.0/en/manual/api).
- [Grafana: instalação de plugins](https://grafana.com/docs/grafana/latest/administration/plugin-management/plugin-install/) e [provisionamento](https://grafana.com/docs/grafana/latest/administration/provisioning/).
- [Duplicati: imagem Docker e chaves](https://docs.duplicati.com/platform-specific-guides/using-duplicati-from-docker). A chave das configurações locais é diferente da passphrase que cifra o conteúdo do backup.

O registro de resultados efetivos está em `VALIDACAO-LOCAL.md`. O aceite no servidor é uma etapa aberta e não deve ser confundido com os testes estáticos desta revisão.
