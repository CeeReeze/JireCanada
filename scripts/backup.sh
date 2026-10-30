#!/usr/bin/env bash
# Sauvegarde de la stack jire vers son dépôt Restic dédié.
#
# Usage : op run --env-file=hosts/jire/restic.env.template -- scripts/backup.sh
#
# 1. Dumps logiques de postgres et mariadb dans ${JIRE_STATE}/_dumps (les répertoires
#    bruts des BD ne sont pas cohérents à chaud et sont exclus).
# 2. Sauvegarde de ${JIRE_STATE} et ${JIRE_FILES} (le cache n'est jamais sauvegardé).
# 3. Rétention.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
compose=(docker compose -f "$here/../hosts/jire/docker-compose.yml")
state=${JIRE_STATE:-/data/jire}
files=${JIRE_FILES:-/data/jire-files}

: "${RESTIC_REPOSITORY:?définir RESTIC_REPOSITORY (op run --env-file=...)}"
: "${RESTIC_PASSWORD:?définir RESTIC_PASSWORD (op run --env-file=...)}"

# Un NAS non monté laisse un point de montage vide : ne jamais sauvegarder ça.
if [[ ! -f "$files/.jire-files" ]]; then
  echo "backup: fichier témoin $files/.jire-files absent (NAS non monté ?), abandon" >&2
  exit 1
fi

dumps="$state/_dumps"
mkdir -p "$dumps"
chmod 700 "$dumps"
stamp=$(date -u +%Y%m%dT%H%M%SZ)

echo "backup: dump postgres"
"${compose[@]}" exec -T postgres pg_dumpall --username=postgres | gzip >"$dumps/postgres-$stamp.sql.gz.part"
mv "$dumps/postgres-$stamp.sql.gz.part" "$dumps/postgres-$stamp.sql.gz"

echo "backup: dump mariadb"
# shellcheck disable=SC2016 # $MARIADB_ROOT_PASSWORD est développé dans le conteneur
"${compose[@]}" exec -T mariadb sh -c \
  'mariadb-dump --user=root --password="$MARIADB_ROOT_PASSWORD" --all-databases --single-transaction --routines --events' \
  | gzip >"$dumps/mariadb-$stamp.sql.gz.part"
mv "$dumps/mariadb-$stamp.sql.gz.part" "$dumps/mariadb-$stamp.sql.gz"

# Ne garder localement que les 3 derniers dumps de chaque base.
for db in postgres mariadb; do
  find "$dumps" -maxdepth 1 -name "$db-*.sql.gz" -print0 | sort -z | head -z -n -3 | xargs -0r rm -f --
done

echo "backup: restic"
restic backup --tag jire --exclude "$state/postgres" --exclude "$state/mariadb" "$state" "$files"

# Rétention des sauvegardes (distincte de la rétention CICC des dossiers, voir docs).
restic forget --tag jire --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 7 --prune
echo "backup: terminé"
