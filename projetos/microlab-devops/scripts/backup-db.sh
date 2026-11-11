#!/usr/bin/env bash
# Roda dentro da imagem PostgreSQL. Cada conjunto só é publicado após validar os três dumps.
set -Eeuo pipefail
umask 077
[[ "${BACKUP_UID:?}" =~ ^[0-9]+$ && "${BACKUP_GID:?}" =~ ^[0-9]+$ ]]
mkdir -p /backups/db
chown "$BACKUP_UID:$BACKUP_GID" /backups/db
mkdir -p /status
tmp=''
cleanup() { [[ -z "$tmp" || "$tmp" != /backups/db/.run.* ]] || rm -rf -- "$tmp"; }
trap cleanup EXIT
run_backup() {
  local host user password name marker status_marker
  tmp="$(mktemp -d /backups/db/.run.XXXXXX)"
  for name in app staging zabbix; do
    case "$name" in
      app) host=postgres; user=microlab; password="$POSTGRES_PASSWORD";;
      staging) host=postgres-staging; user=microlab; password="$STAGING_DB_PASSWORD";;
      zabbix) host=zabbix-db; user=zabbix; password="$ZABBIX_DB_PASSWORD";;
    esac
    PGPASSWORD="$password" PGCONNECT_TIMEOUT=10 pg_dump -h "$host" -U "$user" -d "$user" -Fc -f "$tmp/$name.dump"
    [[ -s "$tmp/$name.dump" ]]
    pg_restore --list "$tmp/$name.dump" >/dev/null
  done
  (cd "$tmp" && sha256sum ./*.dump > SHA256SUMS)
  chown "$BACKUP_UID:$BACKUP_GID" "$tmp" "$tmp/"*
  mv "$tmp" "/backups/db/$(date -u +%Y%m%dT%H%M%SZ)-${tmp##*.}"
  tmp=''
  marker="$(mktemp /backups/db/.last-success.XXXXXX)"
  date +%s > "$marker"
  mv "$marker" /backups/db/LAST_SUCCESS
  # Arquivo público só contém timestamp para o agente, sem credenciais.
  status_marker="$(mktemp /status/.last-success.XXXXXX)"
  cat /backups/db/LAST_SUCCESS > "$status_marker"
  chmod 644 "$status_marker"
  mv "$status_marker" /status/db-last-success
  find /backups/db -mindepth 1 -maxdepth 1 -type d -name '20*T*Z-*' -mtime +7 -exec rm -rf -- '{}' \;
  echo 'DB_BACKUP_VALIDATED'
}
while true; do
  run_backup
  [[ "${1:-}" != --once ]] || exit 0
  sleep 86400
done
