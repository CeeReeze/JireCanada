# Documentation de l'infra jire

| Document | Pour quoi faire |
| --- | --- |
| [architecture.md](architecture.md) | Le parcours client de A à Z, le rôle de chaque service, la séparation état / fichiers, les deux branches CA et CI |
| [conformite.md](conformite.md) | Rétention CICC, compte en fiducie, ARTCI, Loi 25 : **à valider par des humains, pas un avis juridique** |
| [runbooks/bascule-nas.md](runbooks/bascule-nas.md) | Déplacer `JIRE_FILES` vers le NAS (NFS 4.1 par Tailscale) |
| [runbooks/restauration.md](runbooks/restauration.md) | Restaurer un dossier ou toute la stack depuis Restic |
| [runbooks/onboarding.md](runbooks/onboarding.md) | Arrivée d'un membre de l'équipe |
| [runbooks/offboarding.md](runbooks/offboarding.md) | Départ d'un membre de l'équipe |
| [runbooks/acces-urgence.md](runbooks/acces-urgence.md) | Que faire si 1Password, le tailnet ou l'hôte tombe |

## Lire ces documents

- **[à construire]** : absent du dépôt, à faire.
- **[à trancher]** : une décision de Célian est attendue.
- Aucun runbook n'a encore été déroulé sur l'hôte. Chacun le dit en tête de page.
- Toute action sur l'hôte, Tailscale, 1Password, le DNS, Vercel ou Resend demande le feu
  vert explicite de Célian.
