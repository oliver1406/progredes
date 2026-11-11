#!/usr/bin/env bash
# Compatibilidade: instalação Debian substituída pelo lançador Docker.
set -Eeuo pipefail
[[ $# == 0 ]] || { echo 'Use ./microlab.sh up, sem sudo e sem opções antigas.' >&2; exit 1; }
exec bash "$(dirname "$0")/../microlab.sh" up
