#!/usr/bin/env bash
# Rend hosts/jire/.env depuis .env.template (références op://JireEnv/...) et
# écrit le certificat de signature Documenso dans l'état local.
#
# Usage : scripts/render-env.sh
# Prérequis : CLI 1Password (`op`) connectée à un compte qui voit le coffre JireEnv.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
stack="$here/../hosts/jire"
template="$stack/.env.template"
out="$stack/.env"
state=${JIRE_STATE:-/data/jire}

command -v op >/dev/null || { echo "render-env: la CLI 1Password (op) est introuvable" >&2; exit 1; }
op whoami >/dev/null 2>&1 || { echo "render-env: op n'est pas connecté (op signin)" >&2; exit 1; }

umask 077
tmp=$(mktemp "$stack/.env.XXXXXX")
trap 'rm -f "$tmp"' EXIT

op inject --in-file "$template" --out-file "$tmp" --force >/dev/null
if grep -q 'op://' "$tmp"; then
  echo "render-env: des références op:// n'ont pas été résolues" >&2
  exit 1
fi
mv "$tmp" "$out"
echo "render-env: $out écrit (mode 600)"

# Documenso attend un .p12 lisible par l'UID 1001, en mode 400 (doc self-hosting).
cert="$state/documenso/cert.p12"
mkdir -p "$(dirname "$cert")"
op read --force --out-file "$cert" "op://JireEnv/documenso/cert.p12" >/dev/null
chmod 400 "$cert"
if [[ $(id -u) -eq 0 ]]; then
  chown 1001:1001 "$cert"
else
  echo "render-env: lancer « sudo chown 1001:1001 $cert » (propriétaire attendu par Documenso)" >&2
fi
echo "render-env: certificat Documenso écrit dans $cert"
