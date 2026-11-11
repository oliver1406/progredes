# Operação do laboratório Docker

## Responsabilidades

| Frente | Responsabilidade |
|---|---|
| Plataforma/acesso | Docker/Desktop, recursos, persistência, início/reinício, acesso local e eventual acesso remoto |
| Código/entrega | GitHub oficial, PR, réplica Gitea, runner, SHA/imagem e aceite das versões |
| Confiabilidade | Zabbix/Grafana, canal de alerta, backup local/externo e restauração |

Definir titulares e substitutos no GitHub. Contas individuais, incidentes e evidências sem segredos. Use o [README](../README.md) para instalação e portas. Os exemplos abaixo usam PowerShell no Windows; em Linux/macOS, troque `./microlab.ps1` por `bash microlab.sh`.

## Configuração e persistência

Todos os comandos administrativos rodam no container temporário. Configurações privadas e estado ficam no volume `microlab-workspace`; cópias locais, no volume `microlab-backups`. As dependências do host são Docker e seu terminal. Não execute `scripts/*.sh` diretamente no computador.

Antes do primeiro `up`, escolha as senhas de Grafana e Duplicati com `secret GRAFANA_ADMIN_PASSWORD` e `secret DUPLICATI_UI_PASSWORD`. Os demais segredos são gerados. O comando `secret` não mostra a senha na tela nem a coloca no comando do terminal do host. Administradores do Docker ainda têm acesso ao ambiente e aos dados privados. Segredos gerados não vão para o clone/Git. Nunca publique `compose config` interpolado ou inspeções completas de containers.

Para configuração não sensível: `./microlab.ps1 config CHAVE VALOR`. O perfil aceita só `BIND_IP=127.0.0.1`. Alterar senhas de bancos ou Grafana no arquivo depois de inicializados **não** atualiza automaticamente as contas persistidas; faça rotação coordenada no serviço e no arquivo.

`up` inicia os serviços básicos e espera verificações de banco, HTTP e backup. Aplicações ainda dependem de release, e interfaces com configuração inicial podem exigir concluir o assistente. Falha deixa diagnóstico e pode deixar parte dos containers iniciada para investigação; use `status` e `logs SERVIÇO`. O retorno de `check` não prova notificações, recuperação ou funcionamento de uma aplicação real.

`stop` preserva containers/volumes; `down` remove os containers do Compose, preservando volumes; `up` os recria. Não apagar volumes nem executar reset/prune de dados. O administrador não é parte do Compose e encerra ao terminar. A rede externa microlab-proxy é mantida pelo lançador.

## GitHub, Gitea e runner

1. Criar o único repositório oficial no GitHub e publicar **a pasta do projeto**, inclusive `.github`, `.gitea` e arquivos ocultos. Habilitar revisão/proteção da main. Não enviar dados runtime.
2. Finalizar instalação/administrador no Gitea em http://127.0.0.1:3000; banco SQLite interno e registro público desabilitado. Criar repositório privado comum e vazio do mesmo projeto, com Actions. Não usar pull mirror como garantia de evento CI.
3. Gerar token de registro no escopo desse repositório e executar:

```powershell
./microlab.ps1 runner
```

O token é pedido sem eco e usado em container transitório. Revogar depois o token de registro no Gitea; proteger a identidade `.runner` no volume. Revogar token de registro não revoga identidade já criada. Registro existente é recusado: para apenas aplicar configuração, reinicie com `./microlab.ps1 compose --profile ci up -d --force-recreate gitea-runner`. Confirme runner online/Idle, label `microlab` e um job real.

Somente colaboradores/código confiáveis nesse runner. Socket Docker concede autoridade sobre o daemon. Não executar workflows de forks ou de terceiros não revisados. Para produção de fato, separar executor e infraestrutura conforme necessidade.

4. Depois de PR aprovado na main oficial, sincronizar:

```powershell
./microlab.ps1 sync https://github.com/CONTA/REPOSITORIO.git SHA_COMPLETO DONO/REPOSITORIO_GITEA
```

Substitua os argumentos em maiúsculas. O clone de sincronização fica no volume privado, verifica se o SHA pertence à main oficial e faz push normal para `http://gitea:3000/DONO/REPOSITORIO_GITEA.git`, sem force. Autentique quando solicitado. Não coloque token na URL; credenciais Git não são armazenadas pelo script. GitHub privado precisa de acesso Git adequado. Se a réplica divergir, investigar antes de sincronizar. O comando não prova sucesso do job: conferir CI do mesmo SHA no Gitea.

## Entrega e rollback

CI constrói uma vez, confere saúde/versão e grava evidência em volume somente após sucesso. A imagem fica no mesmo daemon, sem registry externo neste laboratório.

```powershell
./microlab.ps1 stage SHA_COMPLETO
# Testar http://127.0.0.1:8081 e registrar resultado humano.
./microlab.ps1 promote SHA_COMPLETO
# Após investigar eventual incidente:
./microlab.ps1 rollback
```

A promoção pede o responsável pelo aceite, confere imagem por ID, versão HTTP e `SELECT 1` no banco correto. Repetir a mesma versão mantém a anterior útil. Falha em primeira implantação para o serviço por não haver versão anterior; nas posteriores tenta restaurar e validar a anterior. Rollback de imagem não desfaz migração de banco.

O teste de release usa a rede interna do Docker. **A porta publicada, o navegador, NPM, DNS e certificados precisam de teste próprio** no aceite. A aplicação incluída é estática; teste SQL separado não comprova transação de negócio.

Não executar `docker image prune -a` nem apagar evidências/estado/imagens atuais e anteriores. O administrador serializa operações, mas jobs e outros administradores podem agir por fora. Alteração por Portainer deve retornar ao código/revisão.

## Monitoramento

1. Concluir instalação Zabbix e trocar a senha administrativa inicial conforme a imagem fixada. Executar `./microlab.ps1 monitor`; informar senha atual ou fornecer `ZBX_API_TOKEN` no ambiente do terminal antes do comando. O lançador encaminha esse token apenas à execução temporária, sem gravá-lo no `.env`.
2. Confirmar dados recentes do host **microlab-docker** e item `microlab.backup.age`. Seu nome coincide com o agente em container. O bootstrap preserva templates e não modifica um host antigo não gerenciado.
3. No host `microlab-services`, conferir HTTP de produção/homologação. Haverá problema antes dos primeiros releases; isso não significa que as aplicações já existam.
4. Criar usuário Zabbix de leitura `grafana-reader`, com acesso API e leitura do grupo Microlab. Executar:

```powershell
./microlab.ps1 config ZABBIX_GRAFANA_USER grafana-reader
./microlab.ps1 secret ZABBIX_GRAFANA_PASSWORD
./microlab.ps1 grafana
```

5. Conferir datasource saudável e consultas reais no Grafana. O painel provisionado é explicativo; criar painéis após validar nomes e alcance das métricas, exportá-los ao clone e revisar no GitHub. Plugin fixado em 6.10.1, compatibilidade a testar.
6. Definir/testar canal e destinatário autorizados no Zabbix, PROBLEM e RECOVERY. Configurar verificador em outra máquina com acesso real ao ambiente para detectar perda do Docker/computador. Este perfil local não configura esse caminho remoto.

O agente em container não monitora integralmente o Windows/hardware e não descobre automaticamente cada container. A visão CPU/memória/kernel pode pertencer à base Linux do Docker, e filesystem ao container/volumes. Identifique isso nos títulos dos painéis. Monitoramento da máquina real exige coleta própria, a definir quando houver servidor de destino.

## Backup e restauração de banco

O backup faz três dumps custom (produção, homologação, Zabbix), verifica arquivos e `pg_restore --list`, calcula checksum e só então publica um conjunto e avança o timestamp em volume compartilhado. Retenção de sete dias só após novo conjunto validado. Estrutura/checksum não substituem restauração.

```powershell
./microlab.ps1 compose exec -T postgres-staging psql -v ON_ERROR_STOP=1 -U microlab -d microlab -c "CREATE TABLE IF NOT EXISTS microlab_restore_probe(id int primary key, value text); INSERT INTO microlab_restore_probe VALUES(1,'microlab-restore-sentinel-v1') ON CONFLICT(id) DO UPDATE SET value=EXCLUDED.value;"
./microlab.ps1 backup
./microlab.ps1 compose exec -T backup ls /backups/db
./microlab.ps1 restore-drill /workspace/backups/db/CONJUNTO/staging.dump
```

Escolha `CONJUNTO` real. O drill usa outro Postgres descartável, sem portas nem volume de produção, restaura com erro fatal e confere sentinela. Para outros dumps, passe consulta e resultado esperado como argumentos; não usar só SELECT 1 como prova de dados recuperados. Não restaurar sobre banco em uso.

## Ferramentas, cópia externa e exportação

Pausar pushes e confirmar runner Idle. Reservar janela: o snapshot para Gitea, Grafana, proxy, Duplicati, runner e Portainer que estavam ativos; captura arquivos consistentes/certificados/config/estado/evidências/imagens e tenta reiniciar essas ferramentas. Confirmar que todas voltaram.

```powershell
./microlab.ps1 snapshot --confirmed-idle
./microlab.ps1 export ./exports/recuperacao-01.tgz --confirmed-idle
```

`export` faz novo snapshot consistente, pausa o escritor de dumps durante a montagem e copia o arquivo de recuperação para o computador. Recusa sobrescrever um arquivo existente. **Esse arquivo contém credenciais e dados, sem cifragem de conteúdo aplicada pelo lançador:** guardar em pasta privada e cifrar antes de copiar para fora. No Windows, herda as permissões da pasta escolhida; conferir acesso. `exports/` fica fora do Git e do contexto da imagem. Exportação é cópia local, não comprova backup externo nem restauração.

Duplicati recebe o staging em `/source`, sem volumes SQLite vivos. Configurar job para `/source/db` e `/source/tools`, excluindo temporários `.run.*` e `.capture.*`; escolher destino externo, credencial dedicada, passphrase de conteúdo, agenda após snapshots, retenção e notificações. `SETTINGS_ENCRYPTION_KEY` protege configuração local e não substitui a passphrase do backup. Guardar chaves recuperáveis fora deste Docker/computador.

Em desastre, usar outro Docker vazio e a mesma revisão do projeto; recuperar e verificar arquivos externos antes de subir serviços; restaurar `.env` e estado no volume workspace e os demais volumes com as ferramentas paradas; importar dumps em bancos vazios, carregar `app-images.tar` com `docker image load`, regenerar configurações públicas pelo lançador e iniciar dependências. A identidade do runner exige revisão antes de reativar CI. O arquivo config.tgz contém infra/estado, incluindo configuração de runner quando criada. Siga procedimentos oficiais Gitea/Grafana das versões fixadas. **Restauração integral das ferramentas é procedimento manual que precisa ser ensaiado em outro daemon**, não foi automatizada/certificada pelo drill de banco.

Meta inicial de RPO: até 24h para bancos, dependente da máquina ligada e job funcionando; RTO a medir. Não declarar 3-2-1, RPO/RTO atendidos ou nuvem pronta sem prova.

## Atualizações

Alterar fontes/lock somente em revisão planejada, registrar versões, notas de migração, escanear e testar em outro Docker de ensaio antes de atualizar o ambiente principal. `scripts/lock-images.sh` é ferramenta interna e seu resultado precisa voltar ao clone/PR; o volume runtime é atualizado pelos arquivos versionados a cada comando. Não editar apenas a cópia runtime esperando que vire fonte oficial.

O lançador recompõe sua imagem usando cache, sem baixar nova base mutável: a base está fixada no lock. Os pacotes apk de ferramentas ainda dependem do repositório no momento do build. Registrar versões efetivas. O ambiente deve cumprir [A1–A15](ACEITE.md) antes de ser aceito para a finalidade definida.
