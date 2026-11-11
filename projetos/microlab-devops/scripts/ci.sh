#!/usr/bin/env bash
# Executado no checkout exato pelo runner confiável; só publica evidência após smoke aprovado.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
sha="$(git rev-parse HEAD)"
[[ "$sha" =~ ^[a-f0-9]{40}$ ]]
[[ -z "${CI_COMMIT_SHA:-}" || "$CI_COMMIT_SHA" == "$sha" ]]
base="$(sed -n 's/^NGINX_BASE_IMAGE=//p' infra/images.lock.env)"
tools="$(sed -n 's/^CI_BASE_IMAGE=//p' infra/images.lock.env)"
[[ "$base" =~ @sha256:[a-f0-9]{64}$ && "$tools" =~ @sha256:[a-f0-9]{64}$ ]]
for script in scripts/*.sh microlab.sh; do bash -n "$script"; done
node --test tests/core.test.mjs
docker build --pull --build-arg "BASE_IMAGE=$base" --build-arg "VCS_REF=$sha" -t "microlab-app:$sha" app
image="$(docker image inspect -f '{{.Id}}' "microlab-app:$sha")"
name="microlab-smoke-${sha:0:12}-${RANDOM}"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT
docker run -d --name "$name" --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges "$image" >/dev/null
for ((i=0;i<30;i++)); do
  [[ "$(docker inspect -f '{{.State.Health.Status}}' "$name")" != healthy ]] || break
  sleep 2
done
[[ "$(docker inspect -f '{{.State.Health.Status}}' "$name")" == healthy ]]
docker exec "$name" nginx -t
docker exec "$name" wget -qO- http://127.0.0.1:8080/version.json | jq -e --arg sha "$sha" '.revision==$sha and .kind=="demo"' >/dev/null
proof="$(jq -nc --arg sha "$sha" --arg image "$image" --arg time "$(date -u +%FT%TZ)" '{revision:$sha,image:$image,ciPassed:true,time:$time}')"
printf '%s\n' "$proof" | docker run --rm -i --network none -e "REV=$sha" -v microlab-ci-evidence:/evidence "$tools" sh -c 'umask 077; cat > "/evidence/$REV.json.tmp"; mv "/evidence/$REV.json.tmp" "/evidence/$REV.json"'
printf 'CI_PASSED revision=%s image=%s\n' "$sha" "$image"
