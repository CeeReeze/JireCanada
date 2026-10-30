# Conformité : points à valider

> ⚠️ **À VALIDER PAR DES HUMAINS. Ce document n'est pas un avis juridique.** Il reprend les
> exigences listées dans le brief du projet, dit ce que l'infra fait (ou ne fait pas) à leur
> sujet, et pose les questions à trancher par Célian et, au besoin, par un conseiller
> juridique ou les autorités concernées. Rien ici ne doit être lu comme une interprétation
> des textes.

Rappel : pendant la phase de test, la stack ne contient **que des données fictives**. Les
points ci-dessous deviennent bloquants **avant** d'y mettre une seule donnée réelle.

## Où vivent les données personnelles

| Lieu | Données | Opérateur | Localisation |
| --- | --- | --- | --- |
| Site (formulaire) | Prospects : nom, courriel, téléphone, message | Vercel, Resend | **À confirmer** (hors dépôt) |
| Courriel et agenda | Échanges avec les clients | Google Workspace | **À confirmer** |
| Stack jire | CRM, dossiers, pièces, mandats, factures | Auto-hébergé sur `drogon-bazzite` | **À confirmer** (pays de l'hôte) |
| NAS (après bascule) | Dossiers clients | Auto-hébergé | **À confirmer** |
| Sauvegardes Restic | Tout l'état et les dossiers, chiffrés par Restic | Bucket compatible S3 (`op://JireEnv/restic/*`) | **À confirmer** (fournisseur et région) |

Ce tableau conditionne les trois sections sur les transferts (ARTCI, Loi 25).

## 1. Conservation des dossiers : 6 ans (CICC)

| | |
| --- | --- |
| **Exigence (brief)** | Conserver les dossiers clients 6 ans, au titre des règles de la CICC |
| **Ce que fait l'infra** | `seed-dossiers.sh` écrit, pour chaque dossier fermé, un `FERMETURE.txt` avec la date de fermeture et « Conservation jusqu'au » = fermeture + 6 ans. Les dossiers fermés vont dans `clients-fermes/` |
| **Ce qu'elle ne fait pas** | Rien ne détruit un dossier à échéance, rien ne prévient quand l'échéance approche. Le `FERMETURE.txt` est créé par le script de seed seulement, pas par le parcours réel |

Questions à trancher :

- [ ] Le texte exact de la CICC et le **point de départ** du délai (fermeture du dossier, fin du mandat, dernier service rendu ?).
- [ ] La règle s'applique-t-elle aussi aux dossiers de la branche Côte d'Ivoire, ou une règle ivoirienne s'y ajoute-t-elle ?
- [ ] Ce qui doit être conservé : le dossier Nextcloud seulement, ou aussi la fiche EspoCRM, les factures Invoice Ninja et les mandats Documenso ?
- [ ] Qui détruit, comment, et comment on trace la destruction.
- [ ] **Sauvegardes** : `backup.sh` garde 7 instantanés annuels. Un dossier détruit à 6 ans reste donc lisible dans les sauvegardes jusqu'à environ 7 ans de plus. Est-ce acceptable, ou faut-il aligner la rétention Restic sur la destruction ?

## 2. Compte en fiducie : deux comptes, Fiducie et Opérations

| | |
| --- | --- |
| **Exigence (brief)** | Deux comptes bancaires : **Fiducie** et **Opérations** |
| **Ce que fait l'infra** | Invoice Ninja émet des factures d'acompte, d'étape et de solde et enregistre les paiements. Le seed contient des acomptes marqués « Payée » |
| **Ce qu'elle ne fait pas** | Invoice Ninja ne tient pas de comptabilité en fiducie : il ne sait pas sur quel compte un paiement est arrivé, ni quand un montant passe de la fiducie aux opérations |

Questions à trancher :

- [ ] Quels montants doivent passer par le compte Fiducie (acomptes reçus avant le service rendu ?) et quand ils peuvent être transférés aux opérations.
- [ ] Comment le tracer : champ personnalisé ou mode de paiement dans Invoice Ninja, registre séparé, outil comptable ?
- [ ] La branche Côte d'Ivoire a-t-elle la même obligation, et avec quels comptes ?
- [ ] Le cas des dossiers liés facturés par une seule branche (exemple fictif : `CA-2026-0002` ↔ `CI-2026-0004`, facturé par CA).

## 3. Côte d'Ivoire : autorisation de l'ARTCI (loi n° 2013-450)

| | |
| --- | --- |
| **Exigence (brief)** | Obtenir l'autorisation de l'ARTCI, au titre de la loi ivoirienne n° 2013-450 sur la protection des données à caractère personnel, **avant** d'héberger des données réelles de clients ivoiriens hors de la CEDEAO |
| **Ce que fait l'infra** | Rien de spécifique. Les dossiers CI sont rangés à part (`ci/`), ce qui permettrait de les traiter différemment, mais ils sont sur le même hôte, le même NAS et dans les mêmes sauvegardes que les dossiers CA |
| **Ce qu'elle ne fait pas** | Aucune donnée CI n'est hébergée dans la CEDEAO |

Questions à trancher :

- [ ] Démarche et délai pour l'autorisation ; elle conditionne la mise en production côté CI.
- [ ] **Le site est-il déjà concerné ?** Un prospect ivoirien qui remplit le formulaire envoie ses données à Vercel et Resend, puis à EspoCRM : cela arrive dès aujourd'hui, avant même la stack.
- [ ] Les sauvegardes et Google Workspace comptent-ils comme des transferts à déclarer ?
- [ ] Faut-il, à terme, un hébergement séparé pour la branche CI ?

## 4. Québec : Loi 25

| | |
| --- | --- |
| **Exigence (brief)** | Respecter la Loi 25 pour les clients québécois |
| **Ce que fait l'infra** | Accès limité au tailnet, secrets hors du dépôt, sauvegardes chiffrées, données fictives pendant le test |
| **Ce qu'elle ne fait pas** | Aucun registre, aucune procédure documentée sur les points ci-dessous |

Points que le brief ne détaille pas et qui sont à examiner, sans préjuger de ce que la loi
exige réellement :

- [ ] Désignation d'une personne responsable de la protection des renseignements personnels, et publication de ses coordonnées (site).
- [ ] Évaluation des facteurs relatifs à la vie privée avant de communiquer des renseignements hors du Québec : Vercel, Resend, Google, bucket Restic, et la branche CI elle-même.
- [ ] Registre et procédure en cas d'incident de confidentialité (qui est prévenu, sous quel délai).
- [ ] Durée de conservation et destruction, à concilier avec la section 1.
- [ ] Consentement et information au moment de la collecte (formulaire du site, liens de dépôt Nextcloud).

## 5. Rôles : conseil réservé aux consultants agréés

| | |
| --- | --- |
| **Exigence (brief)** | Seuls les consultants agréés donnent des conseils. Le personnel non agréé fait l'accueil et la collecte de documents |
| **Ce que fait l'infra** | Rien : aucun rôle n'est configuré dans les applications |

- [ ] Traduire cette règle en droits dans EspoCRM, Nextcloud, Documenso et Invoice Ninja (voir [runbooks/onboarding.md](runbooks/onboarding.md)).

## Ce qui est déjà en place côté technique

| Mesure | Où |
| --- | --- |
| Données fictives seulement pendant le test, marquées « FICTIF » | `seed/`, `scripts/seed-dossiers.sh` |
| Aucun courriel ne sort pendant le test | Tout le SMTP va à mailpit |
| Aucun port exposé hors de `127.0.0.1` ; accès par le tailnet | `docker-compose.yml` |
| Secrets uniquement dans 1Password, scan gitleaks sur tout l'historique | `.env.template`, `.github/workflows/ci.yml` |
| Sauvegardes chiffrées, dépôt distinct du homelab, test de restauration scripté | `scripts/backup.sh`, `scripts/restore-test.sh` |
| L'état des bases ne va jamais sur NFS | `ansible/playbook.yml` |

Ces mesures sont des bonnes pratiques techniques. Elles ne valent pas conformité à elles
seules.
