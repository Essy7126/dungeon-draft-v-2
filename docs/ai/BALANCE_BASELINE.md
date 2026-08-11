# Baseline d’équilibrage structurelle

## L’Odyssée — baseline expérimentale, non production

Ces valeurs décrivent le prototype Achille solo et ne remplacent pas la baseline
de production. La slice contient trois salles, un seul héros et une rencontre
unique par salle. Achille possède 110 PV, initiative 14, 6 PA, 3 PM et attaque 18,
sans attaque générique. Ses quatre actions, limitées à une utilisation par
combat, sont Estoc (2 PA, portée 1–2, 9 dégâts), Avancée (2 PA, ligne 3,
5 dégâts puis déplacement), Balayage (3 PA, adjacent, 6 dégâts et poussée 1) et
Garde (2 PA, bouclier 10).

Les trois rencontres sont fixes : deux tirailleurs ; deux tirailleurs et un
garde ; un champion et un tirailleur. Le tirailleur vaut 45 PV / 10 initiative /
4 PA / 4 PM / 10 attaque ; le garde 70 / 8 / 4 / 3 / 12 avec 20 armure ; le
champion 115 / 9 / 4 / 3 / 16 avec 30 armure. La cible de durée reste
18–25 minutes pour trois rencontres, à mesurer lors de la revue humaine.

L’économie expérimentale accorde deux potions de soin mineures et un parchemin
d’action mineur au départ, aucun équipement et aucune récompense d’équipement.
Aucune de ces valeurs n’est transférée automatiquement à la principale.

> Statut : **candidate locale, non promue CURRENT**.

Cette migration ne modifie aucune statistique de héros, d’ennemi, de sort,
d’équipement, d’XP ou de seuil de progression.

## Run principale de production

- 6 salles.
- 1 rencontre complète par salle.
- 6 combats projetés au total, indépendamment du seed.
- Multiplicateur lié aux vagues : `1.0` (neutre).
- Chance ultime liée aux vagues : `0 %` (désactivée).
- Aucun choix de continuation dans la même salle.

## Run de test

La run `WAVE_CHAIN` est exclue de la baseline d’équilibrage de production. Elle
conserve ses profils, ses plages, ses multiplicateurs, sa chance ultime et ses
rapports cumulés afin de tester le moteur historique de vagues.

La réduction structurelle du nombre de combats de production implique une mesure
ultérieure de la durée, de la cadence XP et de l’attrition ; ces valeurs ne sont
pas recalibrées dans `RUN_FLOW_ISOLATION_V1`.

## Note Item Studio V1 — WORKTREE_CANDIDATE

- Date : 2026-08-07 ; branche `main` ; HEAD de base
  `29f307b5ff61822f266bbd2d14636ca8dcea2d95`.
- Tests : empreinte agrégée comparée par GUT ; 30/30 tests Item Studio,
  190 assertions. Suite globale finale : 836/849, sans nouvelle catégorie
  d’échec par rapport à la baseline.
- Non vérifié : aucune nouvelle baseline d’équilibrage n’est proposée.

Aucune valeur d’objet de production n’est modifiée par le candidat. Les deltas,
EHP, breakpoints et budgets affichés sont des diagnostics ou estimations
exploratoires ; ils ne constituent pas une nouvelle baseline et ne réécrivent
jamais les données.
