# Microlab DevOps em Docker

Laboratório para equipe DEV operar serviços, testar entregas, monitorar e ensaiar recuperação. **GitHub é a fonte oficial única; Gitea é a réplica executora do laboratório.**

O projeto agora usa Docker para os serviços e para as ferramentas de administração. **Não exige instalar uma VM Debian separada, Tailscale, Node, PostgreSQL ou agente no computador.** No Windows, Docker Desktop usa sua base Linux/WSL 2. Esse conjunto é um ambiente de serviços em containers, não uma VM com sistema operacional próprio.

## Início no Windows

1. Instale/inicie Docker Desktop com Linux containers e WSL 2. Sugestão inicial para ensaio: reservar 4 CPUs, 12 GB RAM e 80 GB livres para Docker; medir o uso real, builds e retenção. Não foi feita instalação do Docker Desktop nesta revisão.
2. Extraia o pacote ou clone o repositório. Abra PowerShell **nessa pasta**. Antes da primeira criação dos serviços, defina senhas próprias de pelo menos 24 caracteres, sem espaços, aspas, `$`, crase ou barra invertida. Elas são digitadas sem eco:

```powershell
./microlab.ps1 secret GRAFANA_ADMIN_PASSWORD
./microlab.ps1 secret DUPLICATI_UI_PASSWORD
./microlab.ps1 up
./microlab.ps1 status
```

Se o Windows impedir execução de scripts, use pontualmente `powershell -NoProfile -ExecutionPolicy Bypass -File .\microlab.ps1 up` para o arquivo local revisado; não é necessário mudar a política permanente. Aplique o mesmo prefixo aos comandos de senhas quando necessário. Use sua sessão comum com acesso ao Docker.

Cada comando constrói/atualiza a imagem local de operação com cache e executa um **administrador temporário**, removido ao terminar. Esse administrador tem acesso ao Docker, autorizado para este laboratório; use somente código revisado. Nenhuma senha entra na imagem de operação nem no Git. Ele pode controlar o daemon inteiro, assim como o runner confiável; as redes não isolam esse poder. Uma operação por vez é permitida.

## Início no Linux ou macOS

Com Docker Engine ou Docker Desktop ativo e Bash disponível:

```bash
bash microlab.sh secret GRAFANA_ADMIN_PASSWORD
bash microlab.sh secret DUPLICATI_UI_PASSWORD
bash microlab.sh up
bash microlab.sh status
```

As ferramentas adicionais (Node, jq, curl, Git, Compose) rodam no administrador Docker. Não execute os scripts internos diretamente no host. `setup-server.sh` e `start-stack.sh` agora encaminham ao lançador; opções antigas de instalação Debian são recusadas.

## Acesso local

| Interface | Endereço |
|---|---|
| Gitea | http://127.0.0.1:3000 |
| Zabbix | http://127.0.0.1:8080 |
| Grafana | http://127.0.0.1:3001 |
| Nginx Proxy Manager | http://127.0.0.1:81 |
| Duplicati | http://127.0.0.1:8200 |
| Homologação após release | http://127.0.0.1:8081 |
| Produção demonstrativa após promoção | http://127.0.0.1:8082 |

Finalize contas no Gitea e altere credenciais iniciais do Zabbix/NPM conforme as versões utilizadas. Grafana usa `admin` e a senha definida antes do primeiro `up`. Variável alterada depois da criação de um banco não prova rotação da senha já persistida. Duplicati ainda requer configurar o job, destino externo, cifragem do conteúdo e retenção.

As portas ficam vinculadas a `127.0.0.1`. **O perfil é local:** outros computadores não entram automaticamente. Acesso compartilhado pela rede ou internet exige projeto próprio de autenticação, roteamento e proteção; Tailscale pode ser uma extensão futura opcional. Banco não publica 5432. Se uma porta já estiver ocupada, o Docker deve informar erro; o lançador não troca portas silenciosamente.

## Operação diária

```powershell
./microlab.ps1 check
./microlab.ps1 logs gitea
./microlab.ps1 stop
./microlab.ps1 up
./microlab.ps1 down
```

`stop` para serviços; `down` remove containers/redes do Compose e **preserva volumes**. O lançador não oferece exclusão de volumes. Não use limpeza de volumes, reset do Docker Desktop ou exclusão de sua base Linux sem backup externo recuperável.

Os dados ficam no Docker: `microlab-workspace` guarda configuração privada/estado; `microlab-backups` guarda cópias locais; os demais serviços têm seus próprios volumes. `microlab-runtime-config` contém configurações de serviço, e não o `.env` privado. Esses dados não aparecem na pasta clonada nem são enviados ao GitHub. Atualizar o código e executar novamente preserva segredos e dados; mudança de estrutura/versão deve ser homologada antes.

## Entrega, monitoramento e recuperação

O fluxo permanece GitHub → push controlado ao Gitea → CI → homologação → aceite humano → produção demonstrativa. A promoção usa a mesma imagem testada, sem reconstrução; há retorno à imagem anterior. É preciso criar os repositórios e registrar o runner antes do primeiro CI. A aplicação incluída é uma página HTTP de demonstração, sem transações com PostgreSQL; um serviço de negócio exige integração e testes próprios.

Siga [o manual operacional](docs/OPERACAO.md), [a arquitetura](docs/ARQUITETURA.md), [a mudança para Docker local](docs/MIGRACAO-DOCKER.md) e [o aceite](docs/ACEITE.md).

O agente em container cobre sua visão Linux e o marcador de backup. **Não certifica monitoramento de todo o Windows, do hardware físico ou de todos os containers.** Grafana começa com painel explicativo; métricas e alertas reais precisam ser comprovados. O computador suspenso/desligado interrompe serviços, CI e backup. Uma falha da máquina derruba todo o laboratório; não há alta disponibilidade.

## Validação desta entrega

Veja [a evidência local](docs/VALIDACAO-LOCAL.md). Foram conferidos modelo Compose, sintaxe, testes de configuração/API simulada e fronteiras do lançador PowerShell com Docker simulado. **Nenhum container foi iniciado neste computador porque não há Docker instalado/disponível.** Build, runner, promoção, restauração e reboot continuam pendentes de execução real; não há garantia operacional integral.

Os [relatórios dos anexos originais](docs/REVISAO.md) são históricos e registram a revisão anterior baseada em Debian. As instruções operacionais vigentes são este README e os documentos acima. O projeto remoto GitHub ainda não foi criado.
