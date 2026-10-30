# Runbook : restauration depuis Restic

> **Jamais exécuté en vrai.** Seul `scripts/restore-test.sh` (restauration dans un dossier
> temporaire, sans toucher à la stack) existe. La procédure complète ci-dessous découle de ce
> que fait `scripts/backup.sh` ; elle est à valider lors d'un premier exercice sur des
> données fictives.

## Ce que contient une sauvegarde

| Élément | Sauvegardé | Comment |
| --- | --- | --- |
| Bases Postgres (n8n, Documenso, Cal.diy) | Oui | Dump logique `pg_dumpall` dans `${JIRE_STATE}/_dumps/postgres-<horodatage>.sql.gz` |
| Bases MariaDB (EspoCRM, Invoice Ninja, Nextcloud) | Oui | Dump `mariadb-dump --all-databases` dans `${JIRE_STATE}/_dumps/mariadb-<horodatage>.sql.gz` |
| Répertoires bruts `${JIRE_STATE}/postgres` et `mariadb` | **Non** | Incohérents à chaud ; on repart des dumps |
| Reste de `${JIRE_STATE}` (config des apps, Nextcloud, n8n, certificat Documenso…) | Oui | Copie de fichiers |
| `${JIRE_FILES}` | Oui | Copie de fichiers |
| `${JIRE_CACHE}` | Non | Jetable |
| `hosts/jire/.env` | Non | Se re-rend depuis 1Password avec `scripts/render-env.sh` |

Tout passe par les variables du coffre JireEnv : préfixer chaque commande `restic` ou script
par `op run --env-file=hosts/jire/restic.env.template --`. Si `JIRE_FILES` a basculé sur le
NAS, exporter aussi `JIRE_FILES=/var/mnt/jire-nas` (les scripts ne lisent pas le `.env`).

## 0. Test de routine (sans risque)

```bash
op run --env-file=hosts/jire/restic.env.template -- scripts/restore-test.sh
```

Vérifie l'intégrité d'un échantillon de 5 % du dépôt, restaure le dernier instantané dans un
dossier temporaire, contrôle le fichier témoin, l'arborescence `ca/` et `ci/`, et la
présence des six bases dans les dumps. La fréquence de ce test n'est pas fixée
**[à trancher]**.

## 1. Restaurer un seul dossier client

Cas le plus courant (fichier supprimé ou écrasé par erreur) :

```bash
compose=(docker compose -f hosts/jire/docker-compose.yml)
op run --env-file=hosts/jire/restic.env.template -- restic snapshots --tag jire
op run --env-file=hosts/jire/restic.env.template -- \
  restic restore <id-instantané> --target /var/tmp/jire-restore \
  --include "/data/jire-files/ca/clients-actifs/<nom du dossier>"
# Vérifier le contenu, puis recopier sans écraser ce qui existe
sudo rsync -aHAX --numeric-ids --ignore-existing \
  "/var/tmp/jire-restore/data/jire-files/ca/clients-actifs/<nom du dossier>/" \
  "/data/jire-files/ca/clients-actifs/<nom du dossier>/"
"${compose[@]}" exec -u www-data nextcloud php occ files:scan --all
sudo rm -rf /var/tmp/jire-restore
```

Remplacer `/data/jire-files` par la valeur réelle de `JIRE_FILES`. Restic garde les chemins
absolus de l'hôte : la cible contient donc `.../data/jire-files/...`.

## 2. Restauration complète de la stack

Pour un hôte perdu ou un état corrompu. Prévoir l'arrêt complet de la stack.

### 2.1 Choisir l'instantané et le restaurer à part

```bash
op run --env-file=hosts/jire/restic.env.template -- restic snapshots --tag jire
op run --env-file=hosts/jire/restic.env.template -- \
  restic restore <id-instantané> --target /var/tmp/jire-restore
```

### 2.2 Arrêter la stack et mettre l'état actuel de côté

```bash
compose=(docker compose -f hosts/jire/docker-compose.yml)
"${compose[@]}" down
stamp=$(date -u +%Y%m%dT%H%M%SZ)
sudo mv /data/jire "/data/jire.avant-restauration-$stamp"     # on ne supprime rien
```

Sur un hôte neuf, passer d'abord le playbook Ansible (voir le README) pour recréer les
répertoires et leurs droits.

### 2.3 Remettre l'état et les fichiers

```bash
sudo rsync -aHAX --numeric-ids /var/tmp/jire-restore/data/jire/ /data/jire/
sudo rsync -aHAX --numeric-ids /var/tmp/jire-restore/data/jire-files/ /data/jire-files/
test -f /data/jire-files/.jire-files && echo "témoin OK"
scripts/render-env.sh        # .env et certificat Documenso depuis 1Password
```

`${JIRE_STATE}/postgres` et `mariadb` sont absents de la sauvegarde : les deux bases
redémarrent sur un répertoire vide.

### 2.4 Recharger les bases

```bash
"${compose[@]}" up -d --wait postgres mariadb

pg=$(ls /data/jire/_dumps/postgres-*.sql.gz | sort | tail -n 1)
gunzip -c "$pg" | "${compose[@]}" exec -T postgres psql --username=postgres --dbname=postgres

maria=$(ls /data/jire/_dumps/mariadb-*.sql.gz | sort | tail -n 1)
# shellcheck disable=SC2016
gunzip -c "$maria" | "${compose[@]}" exec -T mariadb sh -c 'mariadb --user=root --password="$MARIADB_ROOT_PASSWORD"'
```

**Erreurs attendues, à confirmer au premier exercice** : sur un répertoire vide, les scripts
`config/*/init-databases.sh` créent déjà les bases et les utilisateurs. Le rechargement du
dump Postgres affichera donc des `already exists` sur les rôles et les bases, puis chargera
les tables dans les bases vides. Le dump MariaDB inclut la base système `mysql` : les
utilisateurs reprennent les mots de passe de la sauvegarde. Si un mot de passe a changé dans
1Password depuis, il faudra le réaligner.

### 2.5 Relancer et contrôler

```bash
"${compose[@]}" up -d
"${compose[@]}" ps                          # tout doit finir en healthy / running
"${compose[@]}" exec -u www-data nextcloud php occ files:scan --all
```

| Contrôle | Attendu |
| --- | --- |
| EspoCRM | Les prospects et clients fictifs sont là, avec leurs équipes |
| Invoice Ninja | Les deux entreprises et leurs factures `CA-F-*` / `CI-F-*` |
| Nextcloud | Les dossiers clients s'ouvrent depuis le stockage externe |
| n8n | Les workflows et leurs identifiants (chiffrés par `N8N_ENCRYPTION_KEY`, qui doit être la même) |
| Documenso | Les documents signés s'ouvrent ; le certificat est en place |
| Cal.diy | Les types de rendez-vous existent |

Une fois la stack validée et après accord de Célian :
`sudo rm -rf /var/tmp/jire-restore "/data/jire.avant-restauration-$stamp"`.

## Points ouverts

| Sujet | État |
| --- | --- |
| Planification des sauvegardes | Aucun timer ni cron dans le dépôt **[à construire]** |
| Objectifs RPO / RTO | Non définis **[à trancher]** |
| Emplacement géographique du bucket Restic | Inconnu ; compte pour la conformité (voir [../conformite.md](../conformite.md)) |
| Perte de 1Password | Sans le coffre JireEnv, pas de mot de passe Restic ni de `N8N_ENCRYPTION_KEY` : voir [acces-urgence.md](acces-urgence.md) |
