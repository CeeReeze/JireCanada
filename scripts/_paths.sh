#!/usr/bin/env bash
# À sourcer, pas à lancer. Résout JIRE_STATE, JIRE_CACHE et JIRE_FILES avec la même
# priorité que docker compose : variable du shell, sinon hosts/jire/.env, sinon défaut
# du docker-compose.yml. Sans ça, un chemin surchargé dans le .env seulement serait vu
# par la stack mais pas par les scripts (sauvegarde du mauvais dossier).
#
# Le .env n'est jamais sourcé (il contient des secrets aux caractères arbitraires) :
# on n'y lit que les clés demandées.

jire_env_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../hosts/jire/.env"

# jire_env_value CLÉ : valeur de CLÉ dans le .env (dernière occurrence, guillemets retirés).
jire_env_value() {
  local key=$1 line value
  [[ -r $jire_env_file ]] || return 0
  line=$(grep -E "^[[:space:]]*${key}=" "$jire_env_file" | tail -n 1) || return 0
  value=${line#*=}
  if [[ $value =~ ^\"(.*)\"$ || $value =~ ^\'(.*)\'$ ]]; then
    value=${BASH_REMATCH[1]}
  fi
  printf '%s' "$value"
}

# jire_path CLÉ DÉFAUT
jire_path() {
  local key=$1 default=$2 value
  value=${!key:-}
  [[ -n $value ]] || value=$(jire_env_value "$key")
  printf '%s' "${value:-$default}"
}

JIRE_STATE=$(jire_path JIRE_STATE /data/jire)
JIRE_CACHE=$(jire_path JIRE_CACHE /cache/jire)
JIRE_FILES=$(jire_path JIRE_FILES /data/jire-files)
export JIRE_STATE JIRE_CACHE JIRE_FILES
