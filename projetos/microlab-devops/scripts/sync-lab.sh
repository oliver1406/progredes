#!/usr/bin/env bash
# Executar no clone do GitHub oficial. Não usa mirror nem force push.
set -Eeuo pipefail
[[ $# == 1 && "$1" =~ ^[a-f0-9]{40}$ ]] || { echo 'Uso: sync-lab.sh SHA_COMPLETO aprovado no GitHub' >&2; exit 1; }
origin="$(git remote get-url origin)"
[[ "$origin" == https://github.com/* || "$origin" == git@github.com:* ]] || { echo 'origin deve ser o GitHub oficial' >&2; exit 1; }
git remote get-url lab >/dev/null
git fetch origin main
git merge-base --is-ancestor "$1" origin/main || { echo 'Commit fora da main oficial' >&2; exit 1; }
git push lab "$1:refs/heads/main"
echo 'Push concluído. Confirme no Gitea o job do mesmo SHA antes de implantar.'
