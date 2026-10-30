# Raccourcis de la stack jire. `just` seul liste les recettes.
#
# Rien ici ne démarre la stack ni ne touche à l'hôte : le lancement reste manuel
# (voir README, « Démarrer »). Les recettes qui ont besoin de 1Password passent par `op`.

set shell := ["bash", "-euo", "pipefail", "-c"]

stack := "hosts/jire"
compose_file := stack / "docker-compose.yml"
restic_env := stack / "restic.env.template"
jire_files := env("JIRE_FILES", "/data/jire-files")

[private]
default:
    @{{ just_executable() }} --list --unsorted

# Toutes les vérifications de la CI, sauf gitleaks
lint: shellcheck yamllint compose-config ansible-syntax renovate-config

shellcheck:
    shellcheck scripts/*.sh {{ stack }}/config/*/*.sh

yamllint:
    yamllint --strict -c .yamllint.yml ansible {{ compose_file }} .github

# Valide le compose avec des valeurs factices (n'écrase jamais un .env rendu)
compose-config:
    #!/usr/bin/env bash
    set -euo pipefail
    env_file=$(mktemp)
    trap 'rm -f "$env_file"' EXIT
    sed 's#op://[^ ]*#ci-dummy#' {{ stack }}/.env.template >"$env_file"
    docker compose -f {{ compose_file }} --env-file "$env_file" config --quiet
    echo "compose-config: OK"

ansible-syntax:
    ansible-playbook -i ansible/inventory.example.yml ansible/playbook.yml --syntax-check

# Valide renovate.json (télécharge Renovate via npx, ~1 min la première fois)
renovate-config:
    npx --yes --package renovate -- renovate-config-validator --strict

# Rend hosts/jire/.env et le certificat Documenso depuis 1Password (coffre JireEnv)
render-env:
    scripts/render-env.sh

# Dumps des BD puis sauvegarde Restic de JIRE_STATE et JIRE_FILES
backup:
    op run --env-file={{ restic_env }} -- scripts/backup.sh

# Restaure le dernier instantané dans un dossier temporaire et le vérifie
restore-test:
    op run --env-file={{ restic_env }} -- scripts/restore-test.sh

# Crée l'arborescence des dossiers clients FICTIFS sous JIRE_FILES
seed root=jire_files:
    scripts/seed-dossiers.sh {{ quote(root) }}
