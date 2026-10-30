# Runbook : départ d'un membre de l'équipe

> **Squelette.** Aucun script ne gère les comptes. À dérouler le jour du départ, dans
> l'ordre : on coupe d'abord l'accès réseau, ensuite les comptes. Les lignes
> **[à trancher]** attendent une décision de Célian.

## 1. Couper l'accès réseau

| Action | Effet |
| --- | --- |
| Retirer la personne et ses appareils du tailnet | Plus aucun accès à `*.jire.ceereeze.dev` : toutes les applications deviennent injoignables pour elle d'un coup |

C'est le geste le plus important : toute la stack n'est joignable que par le tailnet (sauf le
`/webhook` de n8n, qui n'est pas une interface de connexion).

## 2. Désactiver les comptes

| Outil | Action | Ne pas oublier |
| --- | --- | --- |
| Google Workspace | Suspendre le compte | Transférer la propriété de ses fichiers et de son agenda **[à trancher]** : à qui |
| EspoCRM | Désactiver l'utilisateur (ne pas le supprimer) | Réassigner ses prospects et dossiers |
| Nextcloud | Désactiver l'utilisateur | Révoquer ses liens de partage publics (dépôt de pièces) |
| Invoice Ninja | Désactiver l'utilisateur | — |
| Documenso | Désactiver le compte | Les mandats en attente de signature restent valides : les réassigner |
| Cal.diy | Désactiver le compte | Réassigner ou annuler ses rendez-vous à venir |

On **désactive** plutôt que de supprimer : l'historique (qui a fait quoi sur un dossier) doit
rester lisible pendant la durée de conservation.

## 3. Si la personne administrait la stack

- [ ] Retirer son accès au coffre 1Password JireEnv.
- [ ] Faire tourner les secrets qu'elle a pu voir. Une rotation demande de changer la valeur dans JireEnv, puis `scripts/render-env.sh` et un redémarrage des services concernés. Attention : `N8N_ENCRYPTION_KEY`, les clés de chiffrement Documenso et `CALDIY_ENCRYPTION_KEY` chiffrent des données existantes, leur rotation n'est pas un simple changement de valeur **[à trancher]** : procédure par service.
- [ ] Faire tourner `LEAD_WEBHOOK_SECRET` à la fois dans JireEnv et sur Vercel (feu vert de Célian requis pour toucher à Vercel).
- [ ] Retirer sa clé SSH de l'hôte.

## 4. Tracer

- [ ] Noter la date de départ et les accès retirés dans le registre des accès **[à trancher]** : où le tenir.
