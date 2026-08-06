# Baseline d’équilibrage structurelle

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

