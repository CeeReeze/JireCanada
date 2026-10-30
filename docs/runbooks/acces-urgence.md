# Runbook : accès d'urgence

> **Squelette.** Aucune procédure « bris de glace » n'est en place aujourd'hui. Ce document
> dit ce qui existe, ce qui marche si un élément tombe, et ce qu'il faut décider.

## Qui détient quoi aujourd'hui

| Élément | Où | Détenteur connu |
| --- | --- | --- |
| Tous les secrets de la stack | Coffre 1Password JireEnv | Célian |
| Accès SSH à l'hôte `drogon-bazzite` | Clé SSH de l'utilisateur `celian` (inventaire Ansible) | Célian |
| Tailnet | Celui du homelab | Célian |
| Comptes administrateurs des apps | Mots de passe dans JireEnv (`*/admin-password`) | Célian |

Une seule personne détient tout : c'est le principal risque **[à trancher]** (deuxième
détenteur, coffre d'urgence, enveloppe scellée…).

## Si un élément tombe

| Panne | Ce qui marche encore | Comment s'en sortir |
| --- | --- | --- |
| Nginx Proxy Manager ou le tailnet en panne | Les services tournent, sur `127.0.0.1` | Depuis l'hôte, ou par tunnel SSH : `ssh -L 8080:127.0.0.1:8080 celian@drogon-bazzite`, puis `http://localhost:8080` (ports : 8080 EspoCRM, 5678 n8n, 8082 Nextcloud, 8083 Invoice Ninja, 8084 Documenso, 8085 Cal.diy, 8025 mailpit). Le tunnel suppose un accès SSH hors tailnet, **pas documenté** |
| Mot de passe administrateur d'une app perdu | — | Le relire dans JireEnv (`op read op://JireEnv/<app>/admin-password`). Les procédures de réinitialisation propres à chaque app ne sont pas documentées ici **[à construire]** |
| 1Password indisponible | La stack tourne tant qu'elle n'est pas redémarrée avec un nouveau rendu : le `.env` déjà rendu reste sur l'hôte | Aucune procédure. Sans JireEnv : pas de mot de passe Restic, donc **pas de restauration possible**, et pas de `N8N_ENCRYPTION_KEY` pour un hôte neuf **[à trancher]** : copie hors ligne de ces clés, et où |
| Hôte perdu | Les sauvegardes Restic, si 1Password est accessible | [restauration.md](restauration.md) |
| Célian injoignable | Rien d'exploitable par quelqu'un d'autre | **[à trancher]** : qui prend le relais, avec quels accès |

## Après un accès d'urgence

- [ ] Noter qui a utilisé quel accès, quand et pourquoi.
- [ ] Faire tourner les secrets révélés pendant l'incident (voir [offboarding.md](offboarding.md), section 3).
