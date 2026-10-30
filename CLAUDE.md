# CLAUDE.md

Guide pour Claude Code dans ce dépôt.

## Le dépôt

Infra de la stack « jire » de J'iréCanada (environnement de test). Pas de code applicatif :
Docker Compose, scripts Bash, Ansible et des CSV de seed. Le site est dans le dépôt séparé
`CeeReeze/JireCanada-Website` ; ne rien y modifier depuis ici. Vue d'ensemble : `README.md`.

## Vérifications (à lancer avant chaque push, c'est ce que fait la CI)

`just lint` lance tout ce qui suit, plus la validation de `renovate.json`.

```bash
shellcheck scripts/*.sh hosts/jire/config/*/*.sh
yamllint --strict -c .yamllint.yml ansible hosts/jire/docker-compose.yml .github
(cd hosts/jire && sed 's#op://[^ ]*#ci-dummy#' .env.template > .env \
  && docker compose config --quiet; rm -f .env)
ansible-playbook -i ansible/inventory.example.yml ansible/playbook.yml --syntax-check
```

`pip install shellcheck-py yamllint ansible` suffit ; Ansible Galaxy peut être bloqué
par le proxy des sessions cloud.

## Règles non négociables

- **Secrets** : uniquement des références `op://JireEnv/...` (jamais le coffre HomelabEnv).
  Jamais de valeur réelle dans un fichier, un commit, un log ou une PR.
- **Données** : FICTIVES seulement (marquer « FICTIF » dans les seeds).
- **Aucun déploiement** ni action sur l'hôte, Tailscale, 1Password, DNS, Vercel ou Resend
  sans le feu vert explicite de Célian.
- **Images** : épinglées par digest (`image: nom:tag@sha256:...`). Cal.diy est l'exception :
  build depuis son dépôt à un commit épinglé.
- **Ports** : toujours `127.0.0.1:<port>:<port>`, jamais exposés sur toutes les interfaces.
- **Chemins** : état sous `${JIRE_STATE}` (local, jamais NFS), cache sous `${JIRE_CACHE}`,
  fichiers clients sous `${JIRE_FILES}` uniquement.
- **SMTP** : tout vers `mailpit:1025` pendant le test.

## Conventions

- Commentaires, docs et PR en français ; messages de commit en anglais, Conventional
  Commits, scope = zone touchée (`stack`, `scripts`, `seed`, `ansible`, `ci`, `docs`).
- Commits atomiques. PR en draft, corps en français (TL;DR, Pourquoi, Quoi, Comment,
  Avant merge, Après merge).
- Scripts : `#!/usr/bin/env bash`, `set -euo pipefail`, chemins relatifs à
  `$(dirname "${BASH_SOURCE[0]}")`, refus explicite quand `JIRE_FILES` n'a pas son
  fichier témoin `.jire-files` (NAS non monté).
- Ansible : les variables de chemin viennent de l'inventaire, jamais de `vars` de play
  (elles écraseraient l'inventaire).

## Contrat avec le site

Webhook site → n8n signé : en-têtes `X-Jire-Timestamp` (secondes unix) et
`X-Jire-Signature: sha256=<hex HMAC(secret, "${ts}.${rawBody}")>`, fenêtre de 300 s.
Le secret est `LEAD_WEBHOOK_SECRET`, identique côté Vercel et dans `.env.template`.
