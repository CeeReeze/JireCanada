#!/usr/bin/env bash
# Crée l'arborescence des fichiers clients JIRE et les 10 dossiers FICTIFS décrits dans
# seed/espocrm-clients.csv. Idempotent : ne réécrit jamais un fichier existant.
#
# Usage : scripts/seed-dossiers.sh <JIRE_FILES>
set -euo pipefail

usage() { echo "usage: $0 <JIRE_FILES>" >&2; exit 2; }
[[ $# -eq 1 ]] || usage
root=$1

# Refuser une racine absente : sur un NAS non monté on créerait l'arbre au mauvais endroit.
if [[ ! -d "$root" ]]; then
  echo "seed-dossiers: la racine $root n'existe pas, abandon" >&2
  exit 1
fi

# Fichiers partagés par n8n et Nextcloud via le groupe de la racine (voir ansible/playbook.yml) :
# rien pour « autres », écriture pour le groupe, même là où l'ACL par défaut manque (NFS).
umask 0007
if [[ ! -g "$root" ]]; then
  echo "seed-dossiers: $root n'a pas le bit setgid : les dossiers ne seront pas dans le groupe" \
    "partagé (lancer le playbook Ansible d'abord). On continue quand même." >&2
fi

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
csv="$here/../seed/espocrm-clients.csv"
[[ -f "$csv" ]] || { echo "seed-dossiers: $csv introuvable" >&2; exit 1; }

subfolders=(01-Mandat 02-Identite 03-Pieces 04-Correspondance 05-Soumis-IRCC 06-Facturation)

write_once() {
  local path=$1 content=$2
  [[ -e "$path" ]] || printf '%s\n' "$content" >"$path"
}

# Ajoute 6 ans (rétention CICC) à une date AAAA-MM-JJ, sans dépendre de GNU date.
plus_six_years() {
  local y=${1:0:4} rest=${1:4}
  printf '%04d%s' "$((10#$y + 6))" "$rest"
}

for branch in ca ci; do
  mkdir -p "$root/$branch/clients-actifs" "$root/$branch/clients-fermes"
done
mkdir -p "$root/depot-entrant" "$root/modeles"
write_once "$root/.jire-files" "Fichier témoin de la racine JIRE_FILES. Ne pas supprimer."
write_once "$root/modeles/LISEZMOI.txt" "FICTIF - modèles de documents (mandat, lettres)."

count=0
while IFS=, read -r dossier branche _equipe nom prenom programme statut ouverture fermeture lie facture_par _rest; do
  [[ $dossier == dossier ]] && continue # en-tête
  branch_dir=$(printf '%s' "$branche" | tr '[:upper:]' '[:lower:]')
  case $statut in
    Ferm*) state_dir=clients-fermes ;;
    *) state_dir=clients-actifs ;;
  esac

  name="$dossier $nom $prenom - $programme"
  if LC_ALL=C grep -q '[^ -~]' <<<"$name"; then
    echo "seed-dossiers: nom de dossier non ASCII : $name" >&2
    exit 1
  fi

  dir="$root/$branch_dir/$state_dir/$name"
  for sub in "${subfolders[@]}"; do
    mkdir -p "$dir/$sub"
    write_once "$dir/$sub/FICTIF.txt" "FICTIF - $dossier - $sub - aucune donnée réelle."
  done
  write_once "$dir/00-FICHE.txt" "FICTIF
Dossier : $dossier
Client : $prenom $nom
Programme : $programme
Statut : $statut
Ouverture : $ouverture
Dossier lié : ${lie:-aucun}
Facturé par : $facture_par"

  if [[ $state_dir == clients-fermes ]]; then
    [[ -n $fermeture ]] || { echo "seed-dossiers: $dossier est fermé sans date de fermeture" >&2; exit 1; }
    write_once "$dir/FERMETURE.txt" "FICTIF
Date de fermeture : $fermeture
Conservation jusqu'au : $(plus_six_years "$fermeture") (rétention CICC de 6 ans)"
  fi
  count=$((count + 1))
done <"$csv"

echo "seed-dossiers: $count dossiers prêts sous $root"
