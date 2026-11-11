#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v docker >/dev/null || { echo 'Instale e inicie Docker Desktop (Linux containers) ou Docker Engine.' >&2; exit 1; }
[[ "$(docker info --format '{{.OSType}}')" == linux ]] || { echo 'Docker deve estar iniciado em modo Linux.' >&2; exit 1; }
base="$(sed -n 's/^CI_BASE_IMAGE=//p' "$ROOT/infra/images.lock.env" | tr -d '\r')"
[[ "$base" =~ @sha256:[a-f0-9]{64}$ ]] || { echo 'Lock inválido' >&2; exit 1; }
docker build --build-arg "BASE_IMAGE=$base" -t microlab-ops:local -f "$ROOT/infra/Dockerfile.ops" "$ROOT"
if ! docker network inspect microlab-proxy >/dev/null 2>&1; then docker network create microlab-proxy >/dev/null; fi
args=(run --rm --name microlab-ops -i --network microlab-proxy -e MICROLAB_CONTAINER_MODE=1 -e ZBX_API_TOKEN -e ZBX_USER \
  -v microlab-workspace:/workspace -v microlab-backups:/workspace/backups -v microlab-runtime-config:/runtime \
  -v /var/run/docker.sock:/var/run/docker.sock)
[[ ! -t 0 || ! -t 1 ]] || args+=(-t)
if [[ "${1:-}" == export ]]; then
  [[ $# == 3 && "$3" == --confirmed-idle ]] || { echo 'Uso: microlab.sh export CAMINHO.tgz --confirmed-idle' >&2; exit 1; }
  destination="$2"
  [[ ! -e "$destination" ]] || { echo 'Destino já existe; escolha outro arquivo' >&2; exit 1; }
  docker "${args[@]}" microlab-ops:local export --confirmed-idle
  helper="$(docker create -v microlab-workspace:/workspace --entrypoint /bin/true microlab-ops:local)"
  trap 'docker rm "$helper" >/dev/null' EXIT
  mkdir -p "$(dirname "$destination")"
  docker cp "$helper:/workspace/export/recovery.tgz" "$destination"
  chmod 600 "$destination"
  echo 'Arquivo exportado. Contém credenciais: mantenha privado.'
else
  docker "${args[@]}" microlab-ops:local "$@"
fi
