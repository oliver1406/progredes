#!/usr/bin/env bash
# stage SHA | promote SHA | rollback. Sempre usa image ID já testado; não faz build.
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
preflight; lock_ops
cmd="${1:-}"; sha="${2:-}"
tools="$(sed -n 's/^CI_BASE_IMAGE=//p' "$ROOT/infra/images.lock.env")"
[[ "$tools" =~ @sha256:[a-f0-9]{64}$ ]] || die 'Imagem de ferramentas sem digest'
state="$ROOT/state"
set_release() { node "$ROOT/scripts/release-state.mjs" "$state" set "$1" "$2"; }
check_app() {
  local service="$1" revision="$2" db="$3" port="$4" expected_image="$5" id
  wait_health "$service" || return 1
  id="$(dc ps -q "$service")"
  [[ "$(docker inspect -f '{{.Image}}' "$id")" == "$expected_image" ]] || return 1
  docker exec "$id" wget -qO- http://127.0.0.1:8080/version.json | jq -e --arg sha "$revision" '.revision==$sha' >/dev/null || return 1
  [[ "$(dc exec -T "$db" psql -v ON_ERROR_STOP=1 -U microlab -d microlab -Atc 'SELECT 1')" == 1 ]] || return 1
  curl --connect-timeout 3 --max-time 10 -fsS "$(service_url "$service")/health" | grep -qx ok
}
apply_image() { set_release "$1" "$2" || return 1; dc --profile apps up -d --no-deps "$3"; }
case "$cmd" in
  stage)
    [[ "$sha" =~ ^[a-f0-9]{40}$ ]] || die 'SHA completo obrigatório'
    proof="$(docker run --rm --network none -e "REV=$sha" -v microlab-ci-evidence:/evidence:ro "$tools" sh -c 'cat "/evidence/$REV.json"')"
    image="$(jq -er --arg sha "$sha" 'select(.revision==$sha and .ciPassed==true) | .image' <<< "$proof")"
    [[ "$image" =~ ^sha256:[a-f0-9]{64}$ ]] || die 'Imagem inválida'
    [[ "$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$image")" == "$sha" ]] || die 'Revisão da imagem não confere'
    apply_image STAGING_IMAGE "$image" app-staging
    check_app app-staging "$sha" postgres-staging 8081 "$image" || die 'Homologação falhou: promoção bloqueada'
    jq -nc --arg sha "$sha" --arg image "$image" --arg time "$(date -u +%FT%TZ)" '{revision:$sha,image:$image,validatedAt:$time}' > "$state/staging.json.tmp"
    mv "$state/staging.json.tmp" "$state/staging.json"
    echo 'STAGING_VALIDATED'
    ;;
  promote)
    [[ "$sha" =~ ^[a-f0-9]{40}$ ]] || die 'SHA completo obrigatório'
    [[ -s "$state/staging.json" ]] || die 'Sem homologação aprovada'
    image="$(jq -er --arg sha "$sha" 'select(.revision==$sha)|.image' "$state/staging.json")"
    current="$(dc ps -q app-staging)"
    [[ -n "$current" && "$(docker inspect -f '{{.Image}}' "$current")" == "$image" ]] || die 'Homologação mudou desde a validação'
    check_app app-staging "$sha" postgres-staging 8081 "$image" || die 'Homologação deixou de estar saudável'
    if [[ -s "$state/production.json" ]] && jq -e --arg image "$image" --arg sha "$sha" '.image==$image and .revision==$sha' "$state/production.json" >/dev/null; then
      check_app app-prod "$sha" postgres 8082 "$image" || die 'Versão já registrada, mas produção está divergente ou sem saúde'
      echo 'PRODUCTION_ALREADY_VALIDATED: versão anterior preservada'; exit 0
    fi
    read -r -p "Responsável pelo aceite (nome sem dados sensíveis): " approver
    [[ -n "$approver" ]] || die 'Aceite vazio'
    [[ ! -f "$state/production.json" ]] || cp "$state/production.json" "$state/previous.json"
    if ! apply_image PROD_IMAGE "$image" app-prod || ! check_app app-prod "$sha" postgres 8082 "$image"; then
      if [[ -s "$state/previous.json" ]]; then
        previous="$(jq -er .image "$state/previous.json")"; revision="$(jq -er .revision "$state/previous.json")"
        apply_image PROD_IMAGE "$previous" app-prod
        check_app app-prod "$revision" postgres 8082 "$previous" || die 'Falha no deploy E no rollback: incidente requer ação'
        die 'Deploy falhou; imagem anterior restaurada e validada'
      fi
      dc --profile apps stop app-prod
      set_release PROD_IMAGE microlab-app:unreleased
      die 'Primeira implantação falhou; não há versão anterior. Serviço parado'
    fi
    jq -nc --arg sha "$sha" --arg image "$image" --arg time "$(date -u +%FT%TZ)" --arg approver "$approver" '{revision:$sha,image:$image,deployedAt:$time,approvedBy:$approver}' > "$state/production.json.tmp"
    mv "$state/production.json.tmp" "$state/production.json"
    cat "$state/production.json" >> "$state/releases.jsonl"
    echo 'PRODUCTION_VALIDATED'
    ;;
  rollback)
    [[ -s "$state/previous.json" ]] || die 'Não há versão anterior'
    image="$(jq -er .image "$state/previous.json")"; sha="$(jq -er .revision "$state/previous.json")"
    apply_image PROD_IMAGE "$image" app-prod
    check_app app-prod "$sha" postgres 8082 "$image" || die 'Rollback não passou pela validação'
    cp "$state/previous.json" "$state/production.json"
    jq -nc --arg sha "$sha" --arg time "$(date -u +%FT%TZ)" '{action:"rollback",revision:$sha,time:$time}' >> "$state/releases.jsonl"
    echo 'ROLLBACK_VALIDATED'
    ;;
  *) die 'Uso: release.sh stage SHA | promote SHA | rollback';;
esac
