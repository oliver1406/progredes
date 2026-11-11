# Evidência de validação local — Docker

Data: 04/11/2026, America/Cuiaba. Escopo: adaptação para Docker local, sem VM Debian separada nem Tailscale obrigatório. A referência anterior de 28/10/2026 foi substituída por este relatório; os anexos originais e o ZIP anterior foram preservados.

| Verificação | Resultado |
|---|---|
| Integridade dos cinco anexos | SHA-256 das cópias e originais coincidem |
| Sintaxe shell | 17 arquivos conferidos com shfmt v3.14.1; nenhuma execução Bash/Linux |
| JavaScript | 7 módulos, incluindo teste, aprovados em Node --check; Node local v24.22.1 |
| YAML/JSON | 5 YAML sem chaves duplicadas e 2 JSON válidos |
| Compose | 15 definições resolvidas, todos os perfis; Compose v5.6.1 standalone, sem daemon |
| Controle negativo Compose | Senha obrigatória vazia rejeitada; fixture completa aceita |
| Armazenamento/rede | Volumes nomeados; nenhum bind de arquivo/diretório do host; socket é a exceção administrativa explícita; portas publicadas resolvem 127.0.0.1 |
| Controle negativo estrutural | Inclusão de bind de backups dependente do host é rejeitada pelo mesmo verificador que aceita a configuração vigente |
| Lançador Windows | Parser PowerShell nativo aprovado; 6 cenários com função Docker simulada, sem execução de containers |
| Configuração e API | 7 testes automatizados aprovados, zero falhas |
| Lock de imagens | 12 referências por digest; 11 herdadas da revisão anterior e agente Zabbix acrescentado com manifesto/SHA-256 conferidos no registry oficial |

Os testes de configuração verificam parser sem expansão de código, chaves duplicadas, geração de segredos/reexecução, rejeição de bind público e tailnet no perfil local, URL/senha inválida sem escrita e estado isolado de release. A API Zabbix é simulada: erros HTTP/JSON/envelope rejeitados, bootstrap novo/reexecutado e preservação de campos/IDs.

Os seis cenários do lançador PowerShell verificam encaminhamento de argumentos/volumes, falha quando Docker informa Windows containers, falha de build sem iniciar administrador, exportação com caminho contendo espaços/limpeza do helper, recusa de sobrescrita e criação da rede quando ausente. Isso **não** equivale à execução real do daemon ou à leitura de um backup válido. O parser e o comportamento PowerShell foram executados no PowerShell 7 deste computador; compatibilidade operacional com Windows PowerShell 5.1 precisa de ensaio se ele for utilizado.

A referência de imagem do agente foi consultada na revisão atual. As demais referências permanecem as aprovadas anteriormente; não houve atualização automática de todas as ferramentas. Manifesto/digest não certifica execução, segurança ou compatibilidade. A base do administrador é fixada, mas pacotes apk adicionais são resolvidos no build; registrar e escanear a imagem efetivamente construída no aceite.

## O que continua pendente

Não há comando Docker instalado/disponível neste computador. Nenhum container foi iniciado; não foram executados Dockerfile.ops, Compose up, runner, build de app, promoção/rollback, dump, snapshot, exportação real ou restauração. Também faltam GitHub remoto, contas definitivas, alertas, acesso compartilhado e storage externo.

As dependências Debian/systemd/Tailscale foram retiradas dos scripts operacionais vigentes. Os relatórios de revisão independentes em REVISAO-INSTALACAO.md e REVISAO-OPERACAO.md são históricos da base anterior e não certificam esta nova arquitetura. A revisão atual do perfil Docker foi feita de forma sequencial, com verificações estáticas e simulações descritas acima.

Três critérios locais atendidos: arquitetura/lançadores verificáveis, regressões/configuração/API e documentação operacional. Um critério permanece como handoff obrigatório: executar inicialização e ciclo de versão/recuperação em Docker real. Não é necessário criar a VM Debian para isso. Siga [o README](../README.md) e [o aceite A1–A15](ACEITE.md).
