# JireCanada — infra

Infra de la stack « jire » du cabinet J'iréCanada : CRM, facturation, signature,
prise de rendez-vous, automatisations et fichiers clients, auto-hébergés sur un hôte
du tailnet. Pour l'instant c'est un **environnement de test** : données **FICTIVES**
uniquement, et tout le courriel part dans mailpit.

Le site vitrine vit à part, dans [JireCanada-Website](https://github.com/CeeReeze/JireCanada-Website)
(Vercel). Les deux se parlent par un seul point : le webhook signé site → n8n.

## Ce qu'il y a dedans

| Dossier | Rôle |
| --- | --- |
| `hosts/jire/` | Stack Docker Compose (`docker-compose.yml`), modèle `.env.template` (refs `op://JireEnv/...` uniquement), config des BD et du Nginx d'Invoice Ninja |
| `scripts/` | `render-env.sh` (rend le `.env` via `op inject`), `backup.sh` / `restore-test.sh` (Restic), `seed-dossiers.sh` (arbo des dossiers clients) |
| `seed/` | CSV FICTIFS pour EspoCRM et Invoice Ninja (clients CA et CI, factures TPS/TVQ et TVA 18 %) |
| `ansible/` | Préparation de l'hôte : répertoires, garde-fous, montage NFS du NAS (désactivé par défaut) |
| `.github/workflows/ci.yml` | gitleaks sur tout l'historique + shellcheck, yamllint, `docker compose config` |

## La stack

| Service | Rôle | Port (127.0.0.1) | BD |
| --- | --- | --- | --- |
| EspoCRM (+ daemon) | CRM, prospects et clients | 8080 | MariaDB |
| Invoice Ninja (+ Nginx) | Facturation CA et CI | 8083 | MariaDB |
| Nextcloud (+ cron) | Fichiers clients | 8082 | MariaDB |
| n8n | Automatisations, réception du webhook du site | 5678 | Postgres |
| Documenso | Signature électronique | 8084 | Postgres |
| Cal.diy | Prise de rendez-vous (build local, commit épinglé) | 8085 | Postgres |
| mailpit | Capture de tout le SMTP pendant le test | 8025 | — |
| Postgres, MariaDB, Redis | Bases et cache partagés | — | — |

Tout est lié à `127.0.0.1` ; l'exposition passe par Nginx Proxy Manager sur
`*.jire.ceereeze.dev`, tailnet seulement. Les images sont épinglées par digest.

## Les chemins

| Variable | Défaut | Contenu |
| --- | --- | --- |
| `JIRE_STATE` | `/data/jire` | État des apps et des BD. Disque local, **jamais** sur NFS (Ansible refuse) |
| `JIRE_CACHE` | `/cache/jire` | Jetable, jamais sauvegardé |
| `JIRE_FILES` | `/data/jire-files` | Fichiers clients. Seul chemin qui bouge lors de la bascule vers le NAS |

## Démarrer (sur l'hôte)

```bash
# 1. Préparer l'hôte (rien n'est démarré, ni Tailscale ni 1Password ne sont touchés)
cp ansible/inventory.example.yml ansible/inventory.yml   # puis adapter
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml --check --diff

# 2. Rendre le .env depuis 1Password (coffre JireEnv)
scripts/render-env.sh

# 3. Lancer la stack (le premier build de Cal.diy est long)
docker compose -f hosts/jire/docker-compose.yml up -d

# 4. Données de test
scripts/seed-dossiers.sh /data/jire-files
```

Sauvegarde et test de restauration :

```bash
op run --env-file=hosts/jire/restic.env.template -- scripts/backup.sh
op run --env-file=hosts/jire/restic.env.template -- scripts/restore-test.sh
```

## Règles du jeu

- **Aucun secret en clair** : seulement des références `op://JireEnv/...`. Le `.env` rendu
  reste en `0600` et n'est jamais commité. gitleaks tourne sur chaque PR.
- **Données FICTIVES seulement** tant qu'on est en test.
- **Pas de SMTP réel** : le relais Google Workspace est commenté dans `.env.template`.

## Points ouverts

| Sujet | État |
| --- | --- |
| Droits sur `JIRE_FILES` | n8n (uid 1000) et Nextcloud (uid 33) écrivent au même endroit : il faut un groupe partagé (setgid + ACL ou `group_add`). Pas encore tranché |
| Build Cal.diy | Pas d'image publiée, on build depuis le dépôt au commit `2e412471`. Build lourd, pas encore testé sur l'hôte |
| Workflow n8n d'intake | Volontairement absent : il créerait des leads EspoCRM en double avec le push direct de `sendLead` côté site |
| Docs détaillées | `docs/architecture.md` et `docs/runbooks/bascule-nas.md` (cités dans les commentaires) sont à écrire |
| Outillage | `infra.yml`, `justfile` et `renovate.json` (cité dans le compose) à venir |
