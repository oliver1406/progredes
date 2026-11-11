#!/usr/bin/env bash
# Backup consistente das ferramentas: janela de manutenção, captura com serviços parados.
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
[[ "${1:-}" == --confirmed-idle ]] || die 'Pause novos pushes, confirme runner Idle e execute snapshot-tools.sh --confirmed-idle na janela de manutenção'
preflight; lock_ops
umask 077
tools="$(sed -n 's/^POSTGRES_IMAGE=//p' "$ROOT/infra/images.lock.env")"
stamp="$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$ROOT/backups/tools"
tmp="$(mktemp -d "$ROOT/backups/tools/.capture.XXXXXX")"
active_text="$(dc --profile ci --profile admin ps --status running --services gitea-runner gitea grafana npm duplicati portainer)"
active=()
if [[ -n "$active_text" ]]; then mapfile -t active <<< "$active_text"; fi
recover() {
  local original_status=$? recovery_status=0
  trap - EXIT
  if ((${#active[@]})); then dc --profile ci --profile admin up -d "${active[@]}" || recovery_status=1; fi
  if [[ "$recovery_status" != 0 ]]; then echo 'ERRO: recuperação de ferramentas falhou, intervenção necessária' >&2; exit 1; fi
  if [[ "$original_status" == 0 ]]; then echo 'TOOLS_SNAPSHOT_CREATED: conferir saúde das ferramentas, envio remoto e restauração'; fi
  exit "$original_status"
}
trap recover EXIT
if ((${#active[@]})); then dc --profile ci --profile admin stop "${active[@]}"; fi
config="$(dc --profile ci --profile admin config --format json)"
for key in gitea_data grafana_data npm_data npm_letsencrypt duplicati_data portainer_data runner_data ci_evidence; do
  volume="$(jq -er --arg key "$key" '.volumes[$key].name' <<< "$config")"
  if docker volume inspect "$volume" >/dev/null 2>&1; then
    docker run --rm --network none --read-only -v "$volume:/source:ro" -v microlab-workspace:/workspace -v microlab-backups:/workspace/backups "$tools" tar -C /source -czf "$tmp/$key.tgz" .
    tar -tzf "$tmp/$key.tgz" >/dev/null
  fi
done
tar -czf "$tmp/config.tgz" -C "$ROOT" infra state
images=()
for metadata in staging production previous; do
  [[ -f "$ROOT/state/$metadata.json" ]] || continue
  image="$(jq -er '.image | select(test("^sha256:[a-f0-9]{64}$"))' "$ROOT/state/$metadata.json")"
  if [[ " ${images[*]} " != *" $image "* ]]; then images+=("$image"); fi
done
if ((${#images[@]})); then docker image save -o "$tmp/app-images.tar" "${images[@]}"; fi
(cd "$tmp" && sha256sum ./*.tgz > SHA256SUMS && { [[ ! -f app-images.tar ]] || sha256sum app-images.tar >> SHA256SUMS; })
mv "$tmp" "$ROOT/backups/tools/$stamp"
