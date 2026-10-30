#!/usr/bin/env bash
# Test de restauration : restaure le dernier instantané dans un dossier temporaire et
# vérifie qu'il est exploitable. Ne touche jamais à la stack en service.
#
# Usage : op run --env-file=hosts/jire/restic.env.template -- scripts/restore-test.sh
set -euo pipefail

: "${RESTIC_REPOSITORY:?définir RESTIC_REPOSITORY (op run --env-file=...)}"
: "${RESTIC_PASSWORD:?définir RESTIC_PASSWORD (op run --env-file=...)}"
# shellcheck source=scripts/_paths.sh
source "$(dirname "${BASH_SOURCE[0]}")/_paths.sh"
state=$JIRE_STATE
files=$JIRE_FILES

target=$(mktemp -d)
trap 'rm -rf "$target"' EXIT
fail=0
check() {
  if "$@"; then echo "  ok   $*"; else echo "  ÉCHEC $*" >&2; fail=1; fi
}

echo "restore-test: intégrité du dépôt (échantillon de 5 % des données)"
restic check --read-data-subset=5%

echo "restore-test: restauration du dernier instantané dans $target"
restic restore latest --tag jire --target "$target"

echo "restore-test: vérifications"
check test -f "$target$files/.jire-files"
check test -d "$target$files/ca/clients-actifs"
check test -d "$target$files/ci/clients-actifs"

pg=$(find "$target$state/_dumps" -name 'postgres-*.sql.gz' | sort | tail -n 1)
maria=$(find "$target$state/_dumps" -name 'mariadb-*.sql.gz' | sort | tail -n 1)
check test -n "$pg"
check test -n "$maria"
if [[ -n "$pg" && -n "$maria" ]]; then
  check gzip -t "$pg"
  check gzip -t "$maria"
  for db in n8n documenso caldiy; do
    check zgrep -q "CREATE DATABASE $db" "$pg"
  done
  for db in espocrm invoiceninja nextcloud; do
    check zgrep -q "CREATE DATABASE /\*!32312 IF NOT EXISTS\*/ \`$db\`" "$maria"
  done
fi

if [[ $fail -ne 0 ]]; then
  echo "restore-test: ÉCHEC" >&2
  exit 1
fi
echo "restore-test: OK"
