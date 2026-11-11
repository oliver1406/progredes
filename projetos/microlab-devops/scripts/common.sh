#!/usr/bin/env bash
# Biblioteca interna: não carrega .env como código shell.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
die() { printf '[erro] %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "Dependência ausente: $1"; }
read_env() { local line; line="$(grep -m1 "^${1}=" "$ROOT/infra/.env")" || return 1; printf '%s' "${line#*=}"; }
dc() {
  env -u BIND_IP -u GITEA_ROOT_URL -u POSTGRES_PASSWORD -u STAGING_DB_PASSWORD -u ZABBIX_DB_PASSWORD \
    -u GRAFANA_ADMIN_PASSWORD -u GRAFANA_SECRET_KEY -u DUPLICATI_UI_PASSWORD -u DUPLICATI_ENCRYPTION_KEY \
    -u NPM_IMAGE -u GITEA_IMAGE -u RUNNER_IMAGE -u POSTGRES_IMAGE -u ZABBIX_SERVER_IMAGE -u ZABBIX_WEB_IMAGE \
    -u GRAFANA_IMAGE -u DUPLICATI_IMAGE -u PORTAINER_IMAGE -u ZABBIX_AGENT_IMAGE -u PROD_IMAGE -u STAGING_IMAGE -u HOST_UID -u HOST_GID \
    docker compose --project-directory "$ROOT/infra" -f "$ROOT/infra/docker-compose.yml" \
    --env-file "$ROOT/infra/.env" --env-file "$ROOT/infra/images.lock.env" \
    --env-file "$ROOT/state/releases.env" "$@"
}
preflight() {
  [[ "${MICROLAB_CONTAINER_MODE:-}" == 1 && "$ROOT" == /workspace ]] || die 'Use ./microlab.sh ou ./microlab.ps1 para operar dentro do Docker'
  need docker; need jq; need node; need flock
  for f in infra/.env infra/images.lock.env state/releases.env; do [[ -f "$ROOT/$f" ]] || die "Arquivo ausente: $f"; done
  node "$ROOT/scripts/config.mjs" check >/dev/null
  dc config -q
  docker info >/dev/null
}
service_url() {
  case "$1" in
    gitea) printf 'http://gitea:3000';;
    grafana) printf 'http://grafana:3000';;
    zabbix-web) printf 'http://zabbix-web:8080';;
    app-prod|app-staging) printf 'http://%s:8080' "$1";;
    *) die 'Serviço HTTP desconhecido';;
  esac
}
lock_ops() {
  mkdir -p "$ROOT/state"
  exec 9>"$ROOT/state/operations.lock"
  flock -n 9 || die 'Outra operação de release ou snapshot está em andamento'
}
wait_health() {
  local service="$1" id status
  for ((i=0;i<60;i++)); do
    id="$(dc ps -q "$service")"
    if [[ -n "$id" ]]; then
      status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$id")"
      [[ "$status" == healthy ]] && return 0
    fi
    sleep 2
  done
  printf 'Timeout aguardando saúde: %s\n' "$service" >&2
  return 1
}
