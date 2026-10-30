# Runbook : arrivée d'un membre de l'équipe

> **Squelette.** Les comptes ne sont créés par aucun script du dépôt et les droits fins de
> chaque application ne sont pas encore définis. Les lignes **[à trancher]** attendent une
> décision de Célian. Pendant le test, n'utiliser que des comptes et des données fictifs.

## Avant de commencer

| Question | Pourquoi |
| --- | --- |
| Quelle branche : Canada ou Côte d'Ivoire (ou les deux) ? | Détermine l'unité organisationnelle Google, l'équipe EspoCRM, l'entreprise Invoice Ninja et le dossier `ca/` ou `ci/` |
| Consultant agréé (CICC) ou personnel non agréé ? | Seuls les consultants agréés donnent des conseils ; le personnel non agréé fait l'accueil et la collecte de documents |
| Besoin d'administrer la stack ? | Seul l'administrateur technique accède au coffre JireEnv et à l'hôte |

## Comptes à créer

| Outil | Consultant agréé | Personnel non agréé | Notes |
| --- | --- | --- | --- |
| Google Workspace | Compte dans `/Canada` ou `/Cote-d-Ivoire` | Idem | Fait dans la console Google, hors de ce dépôt |
| Tailnet | Accès aux sous-domaines `*.jire.ceereeze.dev` | Idem | Aujourd'hui le tailnet du homelab ; le tailnet de la firme n'existe pas encore **[à trancher]** : qui invite, avec quelles ACL |
| EspoCRM | Utilisateur dans son équipe | Utilisateur dans son équipe, rôle restreint | Rôles EspoCRM à définir **[à trancher]** |
| Nextcloud | Accès aux dossiers de sa branche | Accès à `depot-entrant/` et à la collecte | Partage du stockage externe par groupe **[à trancher]** |
| Invoice Ninja | Utilisateur sur l'entreprise de sa branche | Selon besoin | Qui émet les factures n'est pas défini **[à trancher]** |
| Documenso | Compte pour envoyer les mandats | Pas de compte par défaut | Les inscriptions publiques sont fermées (`NEXT_PUBLIC_DISABLE_SIGNUP`) : un administrateur crée le compte |
| Cal.diy | Calendrier relié à son Google Agenda | Accès pour prendre des rendez-vous | Liaison Google Agenda pas encore configurée |
| n8n | Non | Non | Réservé à l'administrateur technique |
| 1Password JireEnv | Non | Non | Réservé à l'administrateur technique |

Les comptes administrateurs initiaux (`admin` d'EspoCRM et de Nextcloud, compte Invoice Ninja
de `INVOICENINJA_ADMIN_EMAIL`) ont leurs mots de passe dans JireEnv. Ne pas les partager :
créer un compte nominatif.

## Après la création

- [ ] La personne se connecte à chaque outil depuis le tailnet.
- [ ] Double authentification activée là où l'outil la propose **[à trancher]** : quels outils, obligatoire ou non.
- [ ] Elle sait où déposer une pièce reçue (`depot-entrant/`) et qu'elle ne doit rien garder en local.
- [ ] Noter la date d'arrivée et les accès accordés **[à trancher]** : registre des accès (où le tenir).
