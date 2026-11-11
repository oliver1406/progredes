#!/usr/bin/env bash
# Administrador temporário autorizado pela equipe. O lançador usa --rm.
set -Eeuo pipefail
[[ "${MICROLAB_CONTAINER_MODE:-}" == 1 ]] || { echo 'Use microlab.ps1 ou microlab.sh' >&2; exit 1; }
umask 077
mkdir -p /workspace /runtime
exec 8>/workspace/.manager.lock
flock -n 8 || { echo 'Outra operação Microlab está em andamento' >&2; exit 1; }
cp -a /opt/microlab/. /workspace/
cd /workspace
mkdir -p state backups
chmod 700 state backups
node scripts/config.mjs init 127.0.0.1 >/dev/null
# Volume público, sem o .env privado.
mkdir -p /runtime/scripts /runtime/zabbix
cp -a infra/grafana /runtime/
cp infra/zabbix/agent2.conf /runtime/zabbix/
cp scripts/backup-db.sh scripts/backup-age.sh /runtime/scripts/
find /runtime -type d -exec chmod 755 {} +
find /runtime/grafana /runtime/zabbix /runtime/scripts -type f -exec chmod 644 {} +
if [[ -f infra/runner-config.runtime.yaml ]]; then
  cp infra/runner-config.runtime.yaml /runtime/
  chmod 600 /runtime/runner-config.runtime.yaml
fi
source scripts/common.sh
cmd="${1:-help}"; [[ $# == 0 ]] || shift
case "$cmd" in
  up)
    [[ $# == 0 ]] || die 'Uso: up'
    preflight
    dc up -d
    bash scripts/validate-server.sh
    printf 'Laboratório local iniciado: http://127.0.0.1:3000 (Gitea), :8080 (Zabbix), :3001 (Grafana).\n'
    printf 'Aplicações entram após o primeiro CI e release. Conclua contas, monitoramento e aceite do README.\n'
    ;;
  stop|down)
    [[ $# == 0 ]] || die 'Uso: stop | down (preserva volumes)'
    preflight; dc --profile '*' "$cmd"
    ;;
  status) preflight; dc --profile '*' ps -a;;
  logs) preflight; dc --profile '*' logs --tail 100 "$@";;
  check) bash scripts/validate-server.sh;;
  test)
    node --test tests/core.test.mjs
    for script in scripts/*.sh microlab.sh; do bash -n "$script"; done
    preflight
    echo 'LOCAL_CHECKS_PASSED: não substitui o ciclo operacional de aceite'
    ;;
  runner) bash scripts/set-runner-token.sh "$@";;
  stage|promote|rollback) bash scripts/release.sh "$cmd" "$@";;
  monitor) bash scripts/zabbix-bootstrap.sh "$@";;
  grafana) node scripts/provision-grafana.mjs;;
  backup) preflight; lock_ops; dc run --rm --no-deps backup --once;;
  snapshot) bash scripts/snapshot-tools.sh "$@";;
  restore-drill) bash scripts/restore-drill.sh "$@";;
  config)
    [[ $# == 2 && "$1" != *PASSWORD && "$1" != *KEY ]] || die 'Uso: config CHAVE VALOR; para senhas, use secret CHAVE'
    node scripts/config.mjs set "$1" "$2"
    ;;
  secret)
    [[ $# == 1 && ( "$1" == *PASSWORD || "$1" == *KEY ) ]] || die 'Uso: secret CHAVE_PASSWORD ou CHAVE_KEY'
    read -r -s -p "Novo valor de $1: " value; echo
    node scripts/config.mjs set "$1" "$value"
    unset value
    ;;
  sync)
    [[ $# == 3 && "$1" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(\.git)?$ && "$2" =~ ^[a-f0-9]{40}$ && "$3" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die 'Uso: sync https://github.com/CONTA/REPO.git SHA_COMPLETO DONO/REPO_GITEA'
    [[ -d source/.git ]] || git clone -- "$1" source
    [[ "$(git -C source remote get-url origin)" == "$1" ]] || die 'Clone existente pertence a outro GitHub; migração precisa de revisão'
    git -C source fetch origin main
    git -C source merge-base --is-ancestor "$2" origin/main || die 'Commit fora da main oficial'
    git -C source checkout --detach "$2"
    if git -C source remote get-url lab >/dev/null 2>&1; then git -C source remote set-url lab "http://gitea:3000/$3.git"; else git -C source remote add lab "http://gitea:3000/$3.git"; fi
    (cd source && bash scripts/sync-lab.sh "$2")
    ;;
  compose)
    for arg in "$@"; do [[ "$arg" != --volumes && "$arg" != -v ]] || die 'Remoção de volumes não faz parte deste lançador'; done
    preflight; dc "$@"
    ;;
  export)
    [[ "${1:-}" == --confirmed-idle && $# == 1 ]] || die 'Confirme runner Idle e pausa de pushes; uso: export --confirmed-idle'
    bash scripts/snapshot-tools.sh --confirmed-idle
    preflight; lock_ops
    mkdir -p export
    backup_id="$(dc ps -q backup)"; backup_running=false
    [[ -z "$backup_id" ]] || backup_running=true
    recover_backup() {
      local rc=$?; trap - EXIT
      if "$backup_running"; then dc up -d backup || rc=1; fi
      exit "$rc"
    }
    trap recover_backup EXIT
    if "$backup_running"; then dc stop backup; fi
    tar --exclude='.run.*' --exclude='.capture.*' -czf export/recovery.tgz.tmp infra state backups
    mv export/recovery.tgz.tmp export/recovery.tgz
    echo 'RECOVERY_EXPORT_CREATED: arquivo privado; cifre a cópia externa'
    ;;
  help)
    printf '%s\n' 'Microlab Docker local' \
      'up | stop | down | status | check | logs [SERVIÇO] | test' \
      'runner | sync URL_GITHUB SHA DONO/REPO_GITEA | stage SHA | promote SHA | rollback' \
      'monitor | grafana | config CHAVE VALOR | secret CHAVE' \
      'backup | snapshot --confirmed-idle | restore-drill /workspace/backups/db/CONJUNTO/staging.dump' \
      'export DESTINO --confirmed-idle (via lançador, arquivo de recuperação privado)'
    ;;
  *) die 'Comando desconhecido. Execute help';;
esac
