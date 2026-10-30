#!/bin/bash
# Crée une base et un utilisateur par application au premier démarrage de mariadb
# (docker-entrypoint-initdb.d ne s'exécute que sur un répertoire de données vide).
set -euo pipefail

sql_escape() {
  printf '%s' "${1//\'/\'\'}"
}

create_db() {
  local name=$1 password
  password=$(sql_escape "$2")
  mariadb --user=root --password="$MARIADB_ROOT_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS \`$name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$name'@'%' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON \`$name\`.* TO '$name'@'%';
SQL
}

create_db espocrm "$ESPOCRM_DB_PASSWORD"
create_db invoiceninja "$INVOICENINJA_DB_PASSWORD"
create_db nextcloud "$NEXTCLOUD_DB_PASSWORD"
mariadb --user=root --password="$MARIADB_ROOT_PASSWORD" -e 'FLUSH PRIVILEGES;'
