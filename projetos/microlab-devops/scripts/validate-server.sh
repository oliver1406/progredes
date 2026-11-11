#!/usr/bin/env bash
# Diagnóstico somente leitura. Não substitui o aceite completo, alertas e restauração.
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
preflight
for service in postgres postgres-staging zabbix-db gitea; do wait_health "$service"; done
for target in 'http://zabbix-web:8080/' 'http://grafana:3000/api/health' 'http://gitea:3000/api/healthz'; do
  ready=false
  for ((i=0;i<60;i++)); do
    if curl --connect-timeout 3 --max-time 5 -fsS "$target" >/dev/null 2>&1; then ready=true; break; fi
    sleep 2
  done
  "$ready" || die "Interface não respondeu: $target"
done
for db in postgres postgres-staging; do [[ "$(dc exec -T "$db" psql -v ON_ERROR_STOP=1 -U microlab -d microlab -Atc 'SELECT 1')" == 1 ]]; done
[[ "$(dc exec -T zabbix-db psql -v ON_ERROR_STOP=1 -U zabbix -d zabbix -Atc 'SELECT 1')" == 1 ]]
backup_id="$(dc ps -q backup)"
wait_health backup
[[ -n "$backup_id" && "$(docker inspect -f '{{.State.Health.Status}}' "$backup_id")" == healthy ]]
agent_id="$(dc ps -q zabbix-agent)"
[[ -n "$agent_id" && "$(docker inspect -f '{{.State.Status}}' "$agent_id")" == running ]]
docker exec "$agent_id" /usr/sbin/zabbix_agent2 -t microlab.backup.age -c /runtime/zabbix/agent2.conf | grep -Eq '\[[a-z]+\|[0-9]+\]'
for service in npm gitea postgres postgres-staging zabbix-db zabbix-server zabbix-web zabbix-agent grafana backup duplicati; do
  id="$(dc ps -q "$service")"
  [[ -n "$id" && "$(docker inspect -f '{{.State.Status}}' "$id")" == running ]] || die "Serviço não está em execução: $service"
done
echo 'CORE_DIAGNOSTICS_PASSED: executar ainda os cenários docs/ACEITE.md'
