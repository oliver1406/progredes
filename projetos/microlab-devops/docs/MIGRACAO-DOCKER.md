# Mudança de VM Debian para Docker local

Data da revisão: 04/11/2026, America/Cuiaba.

Decisão: substituir a exigência de uma VM Debian criada pela equipe por um laboratório de serviços Docker, com ferramentas de operação também em container. No Windows, Docker Desktop continua dependendo da virtualização/WSL 2 que ele próprio utiliza; não é uma VM Debian administrada pelo projeto.

| Antes | Agora |
|---|---|
| Setup de pacotes no Debian com sudo | Docker disponível no computador e lançador PowerShell/Bash |
| Tailscale autenticado e IP específico | Perfil local em 127.0.0.1; acesso remoto opcional futuro |
| Agente Zabbix instalado no host | Agente em container, nome microlab-docker |
| Unidade systemd para iniciar a stack | Restart policies e Docker ativo; testar reinício da máquina/Desktop |
| Scripts operacionais dependem de Node/jq/curl no host | Administrador temporário contém as ferramentas |
| Bind mounts de scripts, config e backups | Volumes Docker compartilhados, inicializados pelo administrador |
| Teste direto da porta do host no release | Teste HTTP entre serviços; acesso pelo navegador/porta publicada é aceite separado |

Os lançadores constroem a imagem de operação a partir da base pública fixada por digest. Pacotes adicionais apk são instalados no build; ainda é necessário registrar versões e escanear a imagem construída no ensaio. Fixar a base não fixa por si só todas as versões desses pacotes.

Segredos são gerados no volume privado e preservados nas reexecuções. O runtime recebe uma cópia dos arquivos versionados a cada comando; editar esses arquivos diretamente no volume não é atualização oficial e será sobrescrito. Faça alterações no clone, revise/publice no GitHub e depois execute novamente o lançador. O arquivo `.env` e o estado não existem na imagem e não são sobrescritos pelo código versionado.

O administrador temporário com acesso ao Docker foi autorizado pelo usuário nesta revisão. Esse acesso permite controlar todos os containers/volumes do daemon; use uma instalação Docker destinada ao laboratório e código confiável. Ele é removido ao terminar cada comando. Nenhuma senha é exibida no comando de inicialização. A exportação é uma ação explícita e produz arquivo privado com credenciais, que deve ser cifrado antes do armazenamento externo.

Não há conversão automática de uma instalação Debian com dados. Não execute importações ou remova volumes de um ambiente anterior sem cópia recuperável e plano específico. Os cinco anexos originais e o ZIP da revisão anterior foram preservados.

## Referências oficiais conferidas

- [Containers e diferença para VM](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)
- [Docker Desktop no Windows com WSL 2](https://docs.docker.com/desktop/features/wsl/)
- [Volumes persistentes](https://docs.docker.com/engine/storage/volumes/)
- [Publicação de portas](https://docs.docker.com/engine/network/port-publishing/)
- [Autoridade do daemon Docker](https://docs.docker.com/engine/security/)
- [Zabbix 7.0 em containers](https://www.zabbix.com/documentation/7.0/en/manual/installation/containers)
- [Tailscale em container, alternativa futura](https://tailscale.com/docs/features/containers/docker/how-to/connect-docker-container)
