#!/usr/bin/env bash
# Atualização deliberada: substitui somente o lock após resolver todas as imagens.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v docker >/dev/null
umask 077
tmp="$(mktemp "$ROOT/infra/images.lock.env.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
while IFS='=' read -r key image; do
  [[ -z "$key" || "$key" == \#* ]] && continue
  [[ "$key" =~ ^[A-Z_]+$ && "$image" =~ ^[a-zA-Z0-9./:_-]+$ ]] || { echo 'Fonte inválida' >&2; exit 1; }
  docker pull "$image" >/dev/null
  digest="$(docker image inspect "$image" --format '{{index .RepoDigests 0}}')"
  [[ "$digest" =~ @sha256:[a-f0-9]{64}$ ]] || { echo 'Digest ausente' >&2; exit 1; }
  printf '%s=%s\n' "$key" "$digest" >> "$tmp"
done < "$ROOT/infra/image-sources.env"
mv "$tmp" "$ROOT/infra/images.lock.env"
echo 'Lock atualizado. Revise o diff, escaneie as imagens e homologue antes de publicar.'
