#!/usr/bin/env bash
# Restaura apenas em container descartável, sem publicar portas e sem tocar volumes da stack.
# Uso: restore-drill.sh caminho/staging.dump [SQL_VERIFICACAO] [RESULTADO_ESPERADO]
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
preflight; lock_ops
[[ $# -ge 1 && -s "$1" ]] || die 'Informe um dump PostgreSQL existente'
dump="$(realpath "$1")"
sql="${2:-SELECT value FROM microlab_restore_probe WHERE id=1;}"
expected="${3:-microlab-restore-sentinel-v1}"
image="$(sed -n 's/^POSTGRES_IMAGE=//p' "$ROOT/infra/images.lock.env")"
name="microlab-restore-drill-$$"
password="$(openssl rand -hex 24)"
id="$(docker run -d --name "$name" --network none -e POSTGRES_USER=restore -e POSTGRES_DB=restore -e "POSTGRES_PASSWORD=$password" "$image")"
unset password
trap 'docker rm -fv "$id" >/dev/null' EXIT
for ((i=0;i<60;i++)); do docker exec "$id" pg_isready -U restore -d restore >/dev/null 2>&1 && break; sleep 2; done
docker exec "$id" pg_isready -U restore -d restore >/dev/null
docker exec -i "$id" pg_restore --exit-on-error --no-owner --no-acl -U restore -d restore < "$dump"
actual="$(docker exec "$id" psql -v ON_ERROR_STOP=1 -U restore -d restore -Atc "$sql")"
[[ "$actual" == "$expected" ]] || die 'Restauração executada, mas a verificação de dados falhou'
echo 'RESTORE_DRILL_PASSED'
