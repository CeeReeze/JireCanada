#!/bin/bash
# Crée une base et un rôle par application au premier démarrage de postgres
# (docker-entrypoint-initdb.d ne s'exécute que sur un répertoire de données vide).
set -euo pipefail

create_db() {
  local name=$1 password=$2
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
    --set=name="$name" --set=password="$password" <<'SQL'
CREATE ROLE :"name" LOGIN PASSWORD :'password';
CREATE DATABASE :"name" OWNER :"name";
SQL
}

create_db n8n "$N8N_DB_PASSWORD"
create_db documenso "$DOCUMENSO_DB_PASSWORD"
create_db caldiy "$CALDIY_DB_PASSWORD"
