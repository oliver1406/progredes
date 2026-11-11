#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
preflight
if [[ -z "${ZBX_API_TOKEN:-}" && -z "${ZBX_PASSWORD:-}" ]]; then
  read -r -s -p 'Senha atual do usuário administrativo Zabbix (sem padrão presumido): ' ZBX_PASSWORD; echo
  export ZBX_PASSWORD
fi
trap 'unset ZBX_PASSWORD ZBX_API_TOKEN' EXIT
node "$ROOT/scripts/zabbix-bootstrap.mjs"
