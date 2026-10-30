# Runbook : bascule des fichiers clients vers le NAS

> **Jamais exécuté.** Ce runbook n'a pas encore été déroulé sur l'hôte. Chaque action sur
> l'hôte, Tailscale ou le NAS demande le feu vert explicite de Célian.

## Ce qui change, ce qui ne change pas

| | Avant | Après |
| --- | --- | --- |
| `JIRE_FILES` | `/data/jire-files` (disque local) | `/var/mnt/jire-nas` (NAS en NFS 4.1 par Tailscale) |
| `JIRE_STATE`, `JIRE_CACHE` | Disque local | **Inchangés** (jamais sur NFS) |
| Chemins dans les conteneurs | Nextcloud `/mnt/jire-files`, n8n `/files` | **Inchangés** : la config de Nextcloud et des workflows n'a pas à bouger |

Sur Bazzite, `/mnt` pointe vers `/var/mnt` : on utilise toujours `/var/mnt/...`.

## Prérequis

| Prérequis | Comment le vérifier | État connu |
| --- | --- | --- |
| Le NAS est joignable sur le tailnet | `tailscale ping <nom-du-nas>` | **Inconnu** : l'export de l'inventaire d'exemple (`nas.tailnet-jire.ts.net:/volume1/jire`) est un nom factice |
| Le NAS exporte en NFS 4.1 vers l'hôte | Montage manuel en lecture seule dans un dossier temporaire : `sudo mount -t nfs4 -o vers=4.1,ro <nas>:/<export> "$(mktemp -d)"` | **Inconnu** |
| Les uid 33 (Nextcloud) et 1000 (n8n) peuvent écrire sur l'export | Dépend des options d'export (squash, mappage) | **À trancher** avec le schéma de droits de `JIRE_FILES` |
| `mount.nfs4` est dans l'image Bazzite | Le playbook le vérifie | Pas encore vérifié sur l'hôte |
| Une sauvegarde récente et un test de restauration OK | `scripts/backup.sh` puis `scripts/restore-test.sh` | — |

## 1. Préparer l'hôte avec Ansible

Dans `ansible/inventory.yml` (copie locale, non commitée) :

```yaml
jire_nas_enabled: true
jire_nas_export: "<nas>:/<export>"     # vrai nom, pas celui de l'exemple
jire_nas_mountpoint: /var/mnt/jire-nas
```

Puis, d'abord à blanc :

```bash
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml --check --diff
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml
```

Le playbook fait, dans cet ordre :

| Tâche | Pourquoi |
| --- | --- |
| Vérifie que `mount.nfs4` existe | Bazzite est immuable : on n'installe pas de paquet, on refuse si le client manque |
| Crée `/var/mnt/jire-nas` | Point de montage |
| `chattr +i` sur le point de montage **s'il est vide et non monté** | Si le NAS n'est pas monté, toute écriture échoue au lieu de remplir le disque local en silence |
| Ajoute la ligne fstab | Voir ci-dessous |

La ligne fstab produite (une seule ligne) :

```text
<nas>:/<export> /var/mnt/jire-nas nfs4 vers=4.1,hard,_netdev,noauto,x-systemd.automount,x-systemd.mount-timeout=30,x-systemd.requires=tailscaled.service,x-systemd.after=tailscaled.service 0 0
```

| Option | Rôle |
| --- | --- |
| `vers=4.1` | NFS 4.1, comme prévu par le brief |
| `hard` | Une coupure réseau **bloque** les écritures au lieu de les faire échouer à moitié : pas de fichier client tronqué |
| `_netdev` | Le montage attend le réseau |
| `noauto,x-systemd.automount` | Monté au premier accès plutôt qu'au démarrage : l'hôte démarre même si le NAS est absent |
| `x-systemd.mount-timeout=30` | Abandonne la tentative de montage après 30 s |
| `x-systemd.requires/after=tailscaled.service` | Le NAS n'est joignable que par Tailscale |

Le module `ansible.posix.mount` avec `state: present` écrit fstab **sans** recharger
systemd. Il faut donc :

```bash
sudo systemctl daemon-reload
sudo systemctl start "$(systemd-escape -p --suffix=automount /var/mnt/jire-nas)"
ls /var/mnt/jire-nas            # déclenche le montage
findmnt /var/mnt/jire-nas       # doit montrer nfs4, pas autofs seul
```

## 2. Arrêter ce qui écrit dans `JIRE_FILES`

```bash
docker compose -f hosts/jire/docker-compose.yml stop nextcloud nextcloud-cron n8n
```

Les autres services ne montent pas `JIRE_FILES` et peuvent rester en marche.

## 3. Copier avec rsync

```bash
# Premier passage (peut se faire à chaud, avant l'étape 2, pour réduire l'arrêt)
sudo rsync -aHAX --numeric-ids --info=progress2 /data/jire-files/ /var/mnt/jire-nas/

# Passage final, services arrêtés : ne copie que les écarts
sudo rsync -aHAX --numeric-ids --delete --info=progress2 /data/jire-files/ /var/mnt/jire-nas/

# Contrôle : aucune différence attendue
sudo rsync -aHAXn --numeric-ids --delete --itemize-changes /data/jire-files/ /var/mnt/jire-nas/
```

| Option | Pourquoi |
| --- | --- |
| barre oblique finale sur la source | Copie le **contenu** de `/data/jire-files`, pas le dossier lui-même |
| `-a --numeric-ids` | Garde les uid 33 et 1000 tels quels, sans traduction par nom |
| `-H -A -X` | Liens durs, ACL, attributs étendus (utile si le schéma de droits retient des ACL) |
| `--delete` (passage final) | Le NAS devient le reflet exact de la source |

**Piège** : si l'export NFS applique `root_squash`, un `rsync` lancé en root ne pourra pas
fixer les propriétaires. Les options d'export du NAS sont à vérifier avant **[à trancher]**.

## 4. Vérifier le fichier témoin

```bash
test -f /var/mnt/jire-nas/.jire-files && echo "témoin OK"
```

Sans lui, `scripts/backup.sh` refusera de tourner (c'est voulu).

## 5. Changer `JIRE_FILES`

Compose lit `JIRE_FILES` dans `hosts/jire/.env`. Ajouter la ligne au `.env` rendu :

```bash
echo 'JIRE_FILES=/var/mnt/jire-nas' >> hosts/jire/.env
```

**Piège** : `scripts/render-env.sh` réécrit tout le `.env` depuis `.env.template`. Au prochain
rendu, la ligne disparaît et la stack repart sur `/data/jire-files` sans erreur. Il faut donc
ajouter `JIRE_FILES=/var/mnt/jire-nas` à `.env.template` (valeur non secrète) dans une PR
dédiée au moment de la bascule **[à faire]**.

**Piège n° 2** : `backup.sh` et `restore-test.sh` ne lisent pas le `.env` ; ils prennent
`JIRE_FILES` dans l'environnement du shell (défaut `/data/jire-files`). Après la bascule, il
faut les lancer avec `JIRE_FILES=/var/mnt/jire-nas`, sinon la sauvegarde porte sur l'ancienne
copie locale.

## 6. Redémarrer et rescanner Nextcloud

```bash
docker compose -f hosts/jire/docker-compose.yml up -d nextcloud nextcloud-cron n8n
docker compose -f hosts/jire/docker-compose.yml exec -u www-data nextcloud php occ files:scan --all
```

`files:scan --all` remet à jour l'index de Nextcloud pour le stockage externe : sans lui,
Nextcloud ne connaît pas l'état réel des fichiers sur le NAS.

**À vérifier** : un bind mount Docker sur un point d'automount systemd peut ne pas voir le
montage NFS s'il se fait **après** le démarrage du conteneur (propagation des montages
`rprivate` par défaut). Avant de relancer les conteneurs, s'assurer que `findmnt` montre bien
le NFS. Si le problème se présente au redémarrage de l'hôte, il faudra une propagation
`rslave` sur ces volumes dans le compose **[à trancher]**.

## 7. Contrôles après bascule

```bash
docker compose -f hosts/jire/docker-compose.yml exec nextcloud test -f /mnt/jire-files/.jire-files && echo "nextcloud voit le NAS"
docker compose -f hosts/jire/docker-compose.yml exec n8n test -f /files/.jire-files && echo "n8n voit le NAS"
JIRE_FILES=/var/mnt/jire-nas op run --env-file=hosts/jire/restic.env.template -- scripts/backup.sh
JIRE_FILES=/var/mnt/jire-nas op run --env-file=hosts/jire/restic.env.template -- scripts/restore-test.sh
```

Puis, dans Nextcloud, ouvrir un dossier client fictif et y déposer un fichier : il doit
apparaître dans `/var/mnt/jire-nas/...` côté hôte.

## Retour arrière

L'ancienne copie `/data/jire-files` n'est **pas** supprimée par ce runbook. Pour revenir :

1. Arrêter `nextcloud`, `nextcloud-cron`, `n8n`.
2. Si des fichiers ont été écrits sur le NAS depuis la bascule, les recopier :
   `sudo rsync -aHAX --numeric-ids /var/mnt/jire-nas/ /data/jire-files/`.
3. Retirer `JIRE_FILES=/var/mnt/jire-nas` du `.env`.
4. Relancer les services, puis `occ files:scan --all`.

Supprimer `/data/jire-files` seulement après quelques sauvegardes réussies sur le NAS, et
avec l'accord de Célian.
