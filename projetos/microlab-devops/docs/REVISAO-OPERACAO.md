> Histórico da revisão anterior, baseada em Debian. A operação vigente foi substituída pelo perfil [Docker local](MIGRACAO-DOCKER.md); use o [README atual](../README.md).

# Revisão independente: arquitetura, operação e entrega

Data: 28/10/2026. Escopo: os cinco anexos confirmados, preservados em `work/originals`. Esta revisão não instalou serviços, não acessou servidor e não executou Docker. As linhas abaixo referem-se ao arquivo original `docker-compose-final.yaml`, salvo indicação contrária. GitHub é a fonte oficial única; Gitea e runner permanecem como laboratório, conforme esclarecimento do usuário.

## Parecer

A base descreve um laboratório de infraestrutura em um único host, mas não implementa ainda o serviço da equipe DEV de ponta a ponta. O Compose pode iniciar ferramentas depois de completar arquivos e configuração, porém não demonstra entrega de aplicação, alerta operacional, cópia remota ou recuperação. O diagrama apresenta capacidades planejadas como se já existissem. Não há evidência suficiente para certificar funcionamento integral ou disponibilidade.

## Achados concretos

### OP1 — Bloqueador: não existe aplicação implantável nem pipeline

Evidência: aplicação totalmente comentada nas linhas 78–87. Nenhum código, Dockerfile, workflow, teste de integração, registro de imagem ou rotina de deploy compõe os cinco anexos. Um runner registrado executa trabalhos que precisam ser definidos à parte.

Impacto: a infraestrutura pode ficar de pé sem entregar qualquer serviço de negócio; não há versão a homologar ou reverter.

Correção: fornecer uma aplicação de referência explicitamente demonstrativa, ou integrar a aplicação real da equipe; adicionar endpoint de saúde e teste funcional que exercite o banco, imagem identificada pelo commit, fluxo de CI e procedimento de promoção/rollback. Não chamar uma aplicação demonstrativa de aplicação de negócio concluída.

### OP2 — Bloqueador: arquivo de configuração obrigatório do runner não foi entregue

Evidência: `CONFIG_FILE=/config.yaml` e bind `./runner-config.yaml:/config.yaml:ro`, linhas 71–74. Esse arquivo não integra os anexos. A sintaxe curta de bind também pode criar diretório quando a origem não existe, tornando o erro de execução menos claro.

Impacto: o runner não tem configuração reproduzível e pode falhar ao ler o caminho como arquivo. Mesmo com o container ativo, os jobs precisam de ambiente, ferramentas, rede e acesso ao checkout próprios.

Correção: entregar configuração da versão escolhida, validar que a origem é arquivo antes de `up`, fixar a versão do runner e documentar/generar configuração correspondente. Os jobs criados pelo daemon Docker não herdam automaticamente as redes `ci_cd`/`backend` do container runner. Configurar e provar a conectividade do job com Gitea, registry e ambiente de teste. A [documentação versionada do Act Runner](https://docs.gitea.com/1.24/usage/actions/act-runner/) cobre configuração, registro e execução em containers. A documentação atual genérica já descreve outra série do runner; não misturar exemplos sem conferir compatibilidade.

### OP3 — Alto: acesso ao Docker rompe a fronteira esperada entre CI e produção

Evidência: socket do daemon no runner, linha 75, e Portainer, linha 220; runner associado também ao backend, linha 63. Há um único host e daemon para CI, aplicação e dados.

Impacto: jobs confiados ao runner podem controlar o daemon e, por ele, containers e arquivos do host. As quatro redes não isolam esse poder administrativo. Restringir apenas a rede do runner não resolve acesso pelo socket.

Correção: no laboratório, aceitar explicitamente apenas repositório e colaboradores confiáveis, proteger branches e aprovações e impedir execução de código externo não revisado. Preferir runner em VM/daemon separado para uso de produção. Portainer deve ser administrativo e opcional; mudanças feitas nele precisam voltar ao Compose para evitar divergência. A [documentação Docker sobre o socket](https://docs.docker.com/engine/security/protect-access/) mostra formas de proteger o acesso ao daemon, que deve permanecer restrito.

### OP4 — Alto: backup pode falhar sem produzir erro operacional claro

Evidência: linhas 185–191 usam `/bin/sh -c`, `pg_dump | gzip`, laço infinito sem verificação do retorno de `pg_dump`, arquivo final gravado diretamente e nome com apenas a data.

Impacto: se `pg_dump` falhar, `gzip` pode encerrar com sucesso e criar um arquivo gzip válido sem dump útil. A próxima retenção ainda pode apagar backups antigos. Reinícios no mesmo dia sobrescrevem o arquivo; a existência do container e do arquivo não comprova recuperabilidade.

Correção: executar dump em arquivo temporário com retorno verificado, preferencialmente formato customizado do PostgreSQL; validar o arquivo antes de renomear atomicamente e atualizar marcador de sucesso. Criar nomes com data/hora UTC, garantir espaço e permissões, executar retenção apenas após sucesso e alertar sobre idade do último backup, falha e falta de espaço. Testar falha de autenticação, banco indisponível e disco cheio; nenhum desses casos pode registrar sucesso ou apagar o último backup conhecido como bom.

### OP5 — Alto: conjunto de backup incompleto e cópia de bancos SQLite em uso

Evidência: somente banco da aplicação recebe dump, linhas 173–192. Duplicati lê volumes de Gitea/Grafana/NPM ao vivo, linhas 204–207. Não inclui banco Zabbix, certificados `npm_letsencrypt`, configuração/segredos necessários à reconstrução nem inventário de versões de imagens.

Impacto: perda de configurações, usuários, histórico, certificados e chaves; cópia de arquivos ativos pode ser inconsistente. Recuperar só o código do GitHub não recupera o estado dessas ferramentas.

Correção: mapear todos os estados, gerar dump do Zabbix e snapshots coerentes das ferramentas. Parar gravações ou usar mecanismo consistente de backup adequado a cada banco; copiar resultados fechados para staging e só então enviá-los ao destino remoto. Gitea deve ficar parado durante a captura consistente do conjunto banco/repositórios/arquivos, conforme [backup oficial Gitea](https://docs.gitea.com/administration/backup-and-restore/). Grafana também recomenda parar o serviço para copiar seu SQLite, conforme [backup oficial Grafana](https://grafana.com/docs/grafana/latest/administration/back-up-grafana/). Guardar segredos fora do Git, em armazenamento cifrado e recuperável. Fazer restauração em ambiente separado e comparar registros sentinela, não apenas listar arquivos.

### OP6 — Alto: Duplicati instalado não significa backup remoto configurado

Evidência: linhas 194–209 configuram UI, volume e chave de configurações; não há destino remoto, job, credenciais de storage, agendamento, retenção ou teste de restauração.

Impacto: o desenho afirma backup na nuvem e regra 3-2-1 sem implementação ou evidência. `SETTINGS_ENCRYPTION_KEY` protege configurações locais do Duplicati; não define por si só a passphrase de cifragem do conteúdo do backup.

Correção: documentar cadastro de destino externo, job que leia staging consistente, criptografia do backup com chave independente e recuperável, retenção, alertas e teste de restauração. Proibir perda da única cópia da chave na própria VM. A [documentação Docker Duplicati](https://docs.duplicati.com/platform-specific-guides/using-duplicati-from-docker) distingue configuração do servidor e seus segredos. Não declarar 3-2-1 até verificar número de cópias, meios e cópia externa reais.

### OP7 — Alto: ferramentas de monitoramento sem prova de detecção e alerta

Evidência: Grafana linhas 159–170 instala plugin sem provisioning de datasource/dashboard. Zabbix é inicializado com banco; bootstrap vincula só o template Linux ativo ao host. Não há canal de notificação, ação de alerta, verificação HTTP de aplicação, consulta de banco, idade de backup, monitor externo nem teste de entrega da notificação.

Impacto: CPU/memória do host podem aparecer sem que indisponibilidade de aplicação, dump inválido ou queda completa do host gere aviso à equipe. Monitor hospedado no próprio servidor não consegue enviar novo alerta quando o host inteiro perde energia/rede.

Correção: acrescentar verificações de serviço e transação útil, triggers de ausência de dados e atraso de backup, canal de alerta com destinatário autorizado e teste de problema/recuperação. Datasource Grafana deve apontar internamente para `http://zabbix-web:8080/api_jsonrpc.php`, usando usuário/token de leitura dedicado. Adotar verificador externo para alcance e queda do host. Sem canal definido, documentar essa etapa como pendente, sem enviar mensagens a terceiros nesta revisão.

### OP8 — Alto: atualização não é reproduzível

Evidência: `latest` em NPM/Gitea/runner/Grafana/Duplicati/Portainer, tags amplas de PostgreSQL e `alpine-7.0-latest` de Zabbix; plugin Grafana sem versão e imagem do job `act-latest`.

Impacto: máquinas ou datas distintas podem executar versões diferentes sem mudança no repositório; rollback do Compose não restaura necessariamente o binário anterior ou esquema de dados compatível.

Correção: selecionar conjunto de versões compatíveis, validar no laboratório e registrar digests; atualizar por PR com evidência. Não tratar pin como prova de ausência de vulnerabilidades. Build de aplicação uma vez por commit e promoção da mesma imagem/digest; guardar a anterior antes de trocar a versão. Migrações de banco precisam de plano próprio e compatibilidade retroativa ou restauração, pois reverter imagem não desfaz dados automaticamente.

### OP9 — Médio: `restart` e dependências não demonstram autorrecuperação

Evidência: `restart: unless-stopped` generalizado; healthchecks somente dos dois PostgreSQL; dependências curtas em Gitea e Zabbix-web, linhas 64–65 e 146–147. Não há teste pós-deploy.

Impacto: container rodando pode estar travado ou devolvendo erro. A espera por processo iniciado não comprova prontidão. Parada manual com `unless-stopped` permanece parada, e marcação unhealthy não é política de substituição automática.

Correção: healthchecks dos componentes críticos, espera limitada e pós-teste funcional; distinguir reinício de processo de recuperação real. [Docker Compose](https://docs.docker.com/compose/how-tos/startup-order/) explica a diferença entre iniciado e saudável. [Políticas de reinício](https://docs.docker.com/engine/containers/start-containers-automatically/) são acionadas por saída/reinício do daemon e têm comportamento específico para parada manual.

### OP10 — Médio: redes e acesso não correspondem integralmente ao desenho

Evidência: quatro bridges sem `internal: true` nas linhas 6–10; ferramentas possuem várias portas diretas publicadas em `BIND_IP`; NPM possui volume mas não definição de proxy hosts. Não há DNS fornecido, HTTPS provisionado ou ACL Tailscale documentada. Banco corretamente não publica 5432, mas isso não equivale a política completa de isolamento.

Impacto: nomes amigáveis e SSL automático não surgem do Compose. `BIND_IP` restringe a interface de publicação, mas não define quais usuários da tailnet podem entrar. Serviços conectados à mesma bridge podem comunicar entre si. HTTP privado na tailnet e HTTPS do navegador são camadas distintas.

Correção: manter padrão loopback; exigir IP da tailnet válido para acesso remoto, ACL/grants por função e protocolo. Definir nomes DNS/hosts e proxy hosts NPM com portas internas; proteger interfaces administrativas. Planejar método de certificado adequado a domínio real ou nome privado, sem prometer Let's Encrypt para nomes `.local`. Separar backend de jobs de build quando não precisam dele e documentar egress necessário. Testar de cliente autorizado, cliente não autorizado e fora da tailnet.

### OP11 — Médio: limites operacionais e concorrência não definidos

Evidência: todos os serviços num host, `container_name` fixo em todos, sem ambiente distinto de homologação, sem limites de recursos/concurrency no material, CI e banco disputando CPU/disco. O nome `microlab` é fixo na linha 4.

Impacto: duas implantações colidem em nomes/portas/volumes; testes podem atingir dados reais. Compilações ou retenção podem pressionar servidor. Não há alta disponibilidade: falha do host derruba CI, monitoramento, ferramentas e aplicação.

Correção: identificar homologação e produção por serviços/redes/bancos/volumes/portas separados ou usar VMs separadas; remover nomes globais desnecessários; definir capacidade do runner, disco livre e limites observados. Definir janela de manutenção, RPO/RTO como metas que só viram resultados após medição. Não prometer zero downtime ou SLA com um host.

### OP12 — Médio: diagrama está desatualizado

Evidência visual: bloco principal mostra Uptime Kuma ausente no Compose; duas caixas runner para um serviço; faixa de fluxo menciona Registry, homologação e produção sem implementação; inclui SSL e backups na nuvem como capacidades prontas. GitHub oficial e Tailscale não aparecem claramente.

Correção: refazer como diagrama de estado real: GitHub fonte → sincronização controlada → Gitea/runner → imagem identificada → homologação → aprovação → produção; NPM como entrada, Zabbix/Grafana e verificador externo, staging de backup → destino remoto. Marcar explicitamente o que exige configuração ou prova. Uma caixa de alta disponibilidade futura não altera a disponibilidade do host único atual.

## Fluxo de entrega recomendado

1. A equipe abre PR no único GitHub oficial. Revisão e CI validam sintaxe, testes da aplicação e configuração sem segredos.
2. Após aprovação, sincronizar um SHA específico do GitHub para a réplica do laboratório no Gitea, sem aceitar desenvolvimento independente ou sincronização bidirecional. Gitea oferece [pull mirror](https://docs.gitea.com/usage/repository/repo-mirror/), mas cópia de Git não prova disparo de Actions: testar o evento na versão escolhida. Alternativa previsível é push controlado do SHA aprovado para repositório comum de réplica e execução por push, registrando o SHA original.
3. Runner de repositório confiável testa e gera imagem identificada pelo SHA; publicar em registry escolhido ou manter imagem local identificada se o laboratório não precisa de registry. O desenho deve refletir a escolha real. Registar digest/ID e resultado dos testes.
4. Implantar em homologação isolada com dados próprios. Esperar saúde limitada por timeout; testar endpoint, leitura/escrita/consulta ao banco e versão retornada. Falha interrompe a promoção.
5. Responsável registra aceite; promoção usa a mesma imagem, sem rebuild, e guarda versão anterior. Serializar deploys para impedir corridas.
6. Produção recebe imagem aprovada e passa pelo mesmo pós-teste. Falha reverte à imagem anterior quando compatível com banco e registra incidente; mudança de esquema exige decisão explícita de recuperação de dados.
7. Evidência mínima por entrega: SHA, imagem/digest, ambiente, executor, horário, testes, aprovação e versão anterior. Dados sensíveis ficam fora dos logs e do Git.

## Critérios de aceite no servidor

- Clone limpo contém todos os arquivos referenciados; validação de configuração falha com variável obrigatória vazia e não imprime segredos.
- Subida inicial em Debian alvo funciona e reexecução preserva senhas, volumes e rotas; reboot recupera os serviços depois de o endereço Tailscale existir.
- Job real faz checkout, alcança Gitea e termina; job propositalmente falho bloqueia release.
- SHA aprovado gera imagem; mesma imagem passa homologação e produção; versão inválida reverte e mantém dado sentinela.
- Falha de serviço produz problema e alerta recebidos; recuperação produz evento; queda do host é percebida externamente.
- Backup inválido falha visivelmente, não atualiza sucesso e não elimina último válido; restauração em ambiente limpo recupera dado sentinela, configurações e acessos.
- Destino remoto recebe artefatos consistentes cifrados; restauração funciona com chaves recuperadas fora da VM.
- Cliente permitido acessa os serviços; cliente não autorizado e origem externa não acessam interfaces administrativas.

## Quatro passes e limitações

Passo 1 inventariou requisitos ausentes e defeitos do Compose. Passo 2 confrontou comportamento de Docker, Gitea, Grafana e Duplicati com fontes oficiais. Passo 3 buscou falhas silenciosas (dump comprimido vazio, job fora da rede, cópia SQLite ativa, monitor interno sem alerta de host) e incompatibilidade de versões. Passo 4 revisou a distinção entre capacidade planejada, implementação e prova de funcionamento.

Não foi executada instalação, build, pipeline, consulta API real, teste de falha ou restauração. Os critérios acima permanecem pendentes de evidência no servidor. Esta revisão conclui os achados estáticos e a proposta operacional, não certifica os serviços em execução.

## Segunda revisão: pacote consolidado

Escopo adicional: leitura de `outputs/microlab-devops`, com prioridade em `ci.sh`, `release.sh`, `release-state.mjs`, `backup-db.sh`, `snapshot-tools.sh`, `restore-drill.sh`, Compose e interfaces chamadas. A demo Nginx deliberadamente não usa PostgreSQL: a consulta SQL é um teste separado de infraestrutura, e isso deve continuar explícito. As observações abaixo registram o estado lido durante a revisão; o integrador pode corrigir a implementação depois deste registro.

Melhorias confirmadas: CI constrói e testa imagem por SHA, a evidência liga SHA a image ID no volume local; homologação e produção têm bancos/serviços separados; promoção é manual; o backup usa arquivos customizados temporários e publicação do conjunto somente após validação dos três dumps; snapshot para ferramentas SQLite antes de capturar volumes; drill restaura em container descartável sem portas. Nenhuma dessas leituras substitui execução no Debian.

### R2-1 — Alto: repetição de promoção apaga a versão de rollback

`release.sh`, linha 42 no snapshot revisado, copia a produção atual para `previous.json` incondicionalmente. Repetir `promote` do SHA já publicado sobrescreve a versão anterior útil com a própria atual. O comando seguinte de rollback retorna à mesma versão e perde a recuperação esperada. Detectar SHA/image ID já em produção antes dessa cópia; validar a implantação atual e tratar como no-op sem alterar `previous.json`. Teste recomendado: promover A, promover B, repetir B, reverter; resultado deve ser A.

### R2-2 — Alto: configuração inválida pode ser gravada antes do erro

`config.mjs`, linhas 41–47 no snapshot revisado: `set` chama `write(env)` antes das validações de senha, IP e URL. Um `set GITEA_ROOT_URL valor-invalido` retorna erro após já alterar o arquivo real. Uma senha curta também é gravada antes de ser rejeitada. Extrair validação completa e executá-la antes de qualquer gravação; teste negativo deve comparar os bytes do `.env` antes/depois e exigir igualdade quando o comando falhar.

### R2-3 — Alto: a restrição de publicação privada não vale para todos os caminhos

`config.mjs` restringe loopback/faixa da tailnet somente no `init` (linha 31); o `check` final aceita qualquer IPv4 (linha 46). `set BIND_IP 0.0.0.0` consegue passar e publicar serviços em todas as interfaces. Aplicar uma única validação de BIND_IP em `init`, `set` e `check`, antes de persistir. Testar 0.0.0.0, IP de LAN, IPv6 e IPv4 inválido como negativos; aceitar 127.0.0.1 e IP da tailnet válido, lembrando que faixa 100.64/10 sozinha não prova pertença à tailnet real.

### R2-4 — Alto: falha ao recuperar ferramentas é convertida em sucesso

`snapshot-tools.sh`, linhas 13–16 no snapshot revisado: trap chama `dc ... up -d ... || echo ERRO`. Se os arquivos foram criados mas o retorno das ferramentas falha, o erro vira `echo` e o processo pode terminar com sucesso, deixando serviços parados. Preservar código de saída original, retornar não zero em falha de recuperação, confirmar retomada/prontidão e emitir sucesso depois disso. Simular falha no `up` usado pela recuperação e exigir saída não zero, além de mensagem de incidente.

### R2-5 — Médio: imagem efetiva de produção não é comparada ao image ID aprovado

`check_app` em `release.sh` compara versão JSON, SQL e saúde, mas não `.Image` do container com o image ID esperado. `promote` verifica `.Image` da homologação, porém não de produção. Além disso, variáveis de imagem exportadas pelo shell têm precedência sobre arquivos de ambiente no Compose. Uma variável herdada pode selecionar outra imagem com o mesmo texto de revision. Comparar o image ID efetivo em `check_app` nos dois ambientes e impedir overrides inesperados nas variáveis de release. Essa verificação mede diretamente a promessa de promover o mesmo artefato.

### Limites que devem permanecer no relatório de entrega

- Evidência local de CI e socket Docker pertencem à mesma fronteira administrativa do servidor; não são atestação assinada independente. Jobs e operadores precisam ser confiáveis.
- A configuração do runner 5.2.4 precisa de job real que prove montagem do socket e persistência de `microlab-ci-evidence`. A documentação da série escolhida, e não a antiga de act_runner, governa esse comportamento.
- A aplicação demonstrativa não prova transação de negócio com o banco; `SELECT 1` prova apenas acesso SQL a uma instância separadamente. Aplicação real exigirá novos testes funcionais e de migração.
- O drill PostgreSQL cobre restauração do dump e sentinela. Restauração de Gitea, Grafana, NPM, Duplicati, imagens e configuração ainda exige ensaio completo documentado.
- Snapshot coerente local e UI Duplicati não demonstram envio remoto nem restauração externa. Canal de alertas e verificador fora do host continuam exigindo configuração e teste reais.
- Não houve execução de Docker ou instalação nesta segunda revisão. Os cinco defeitos foram enviados ao integrador assim que encontrados, antes da conclusão do relatório.

### Parecer final após correções do integrador

Releitura confirmou a correção dos cinco itens R2-1 a R2-5: promoção repetida preserva `previous.json`; validação completa ocorre antes da gravação; `validate` aplica a restrição de IP também em `set/check`; recuperação de snapshot preserva o status original e falha se o retorno das ferramentas falhar; todos os caminhos de `check_app` recebem e verificam o image ID esperado. O wrapper Compose também elimina overrides ambientais das variáveis de imagem/release, endereço e principais segredos.

Foi executado teste em memória da função `validate`: três endereços permitidos foram aceitos; seis endereços proibidos/inválidos, URL inválida e segredo curto foram rejeitados. A tentativa de executar um teste isolado do trap Bash foi impedida pelo Windows ao iniciar Git Bash (`NtCreateDirectoryObject`, acesso negado); portanto esse teste não conta como aprovado. Não houve instalação nem alteração de implementação por este revisor.

Não identifiquei resíduo bloqueador desses cinco achados na revisão estática atual. Permanecem os limites operacionais já listados: comprovação de pipeline e runner reais, ciclo de promoção/rollback, falhas controladas, alertas, cópia externa e restauração completa no Debian/Docker. O parecer valida as correções observadas, não certifica a operação integral.
