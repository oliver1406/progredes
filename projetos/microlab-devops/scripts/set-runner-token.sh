#!/usr/bin/env bash
# Nome mantido por compatibilidade. Não grava token no .env; registro único efêmero.
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
preflight
lock_ops
wait_health gitea
tools_base="$(sed -n 's/^CI_BASE_IMAGE=//p' "$ROOT/infra/images.lock.env")"
[[ "$tools_base" =~ @sha256:[a-f0-9]{64}$ ]] || die 'Imagem de ferramentas sem digest'
docker build --pull --build-arg "BASE_IMAGE=$tools_base" -t microlab-ci-tools:local -f "$ROOT/infra/Dockerfile.ci" "$ROOT/infra"
tools_id="$(docker image inspect -f '{{.Id}}' microlab-ci-tools:local)"
cat > "$ROOT/infra/runner-config.runtime.yaml" <<EOF
log:
  level: info
runner:
  file: /data/.runner
  capacity: 1
  timeout: 30m
  insecure: false
  labels:
    - microlab:docker://${tools_id}
cache:
  enabled: false
container:
  network: microlab-ci
  privileged: false
  valid_volumes: [microlab-ci-evidence]
  docker_host: ""
  force_pull: false
  sweep: false
EOF
chmod 600 "$ROOT/infra/runner-config.runtime.yaml"
cp "$ROOT/infra/runner-config.runtime.yaml" /runtime/runner-config.runtime.yaml
chmod 600 /runtime/runner-config.runtime.yaml
docker volume create microlab-ci-evidence >/dev/null
if ! dc --profile ci run --rm --no-deps --entrypoint sh gitea-runner -c 'test ! -s /data/.runner'; then
  die 'Runner já registrado. Configuração atualizada; reinicie o runner. Revogação/reregistro são operações distintas, descritas no manual.'
fi
read -r -s -p 'Token de registro do runner de REPOSITÓRIO confiável: ' TOKEN; echo
[[ -n "$TOKEN" ]] || die 'Token vazio'
trap 'unset TOKEN' EXIT
dc --profile ci run --rm --no-deps -e "GITEA_RUNNER_REGISTRATION_TOKEN=$TOKEN" --entrypoint sh gitea-runner -c 'exec gitea-runner --config /runtime/runner-config.runtime.yaml register --no-interactive --instance http://gitea:3000 --name microlab-trusted --token "$GITEA_RUNNER_REGISTRATION_TOKEN"'
unset TOKEN
dc --profile ci up -d gitea-runner
echo 'Registro enviado. Revogue o token de registro no Gitea e confirme runner Idle e um job CI_PASSED. Container iniciado não prova job executado.'
