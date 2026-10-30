#!/bin/bash
# Point d'entrée de nextcloud et nextcloud-cron : met www-data dans le groupe des fichiers
# clients (GID JIRE_FILES_GID), puis passe la main à la commande d'origine de l'image.
#
# group_add ne suffit pas pour Nextcloud : Apache, su et crond démarrent en root puis
# passent à www-data avec initgroups(), qui recharge les groupes depuis /etc/group et
# efface ceux ajoutés par Docker. Il faut donc que /etc/group du conteneur le dise.
# /etc/group est recréé avec le conteneur : ce script repasse à chaque démarrage.
set -euo pipefail

gid=${JIRE_FILES_GID:?JIRE_FILES_GID manquant}

group=$(getent group "$gid" | cut -d: -f1 || true)
if [[ -z $group ]]; then
  groupadd --gid "$gid" jire-files
  group=jire-files
fi

if ! id -nG www-data | tr ' ' '\n' | grep -qxF "$group"; then
  usermod --append --groups "$group" www-data
fi

exec "$@"
