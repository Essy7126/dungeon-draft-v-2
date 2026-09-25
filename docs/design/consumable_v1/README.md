# V1 théorique — cartes consommables et run tactique

**Point d’entrée à reprendre sur l’autre ordinateur.** Version `1.0.1-theory`, construite sur le dépôt au commit `6a500c545f04d3e4c53a99d3643d0c4d844e303f`.

Cette V1 propose des règles fermées, un catalogue complet, une économie et un modèle tactique exécutable. Elle garde les quinze cartes initiales, leur consommation lors de l’usage, les sacs sur les mobs, la croissance du drop et le maximum de trente cartes préparées. Elle n’est pas encore intégrée au jeu public et son plaisir de jeu n’a pas été validé par des joueurs.

| Élément | Contenu livré |
|---|---|
| Identités | 4 classes, 8 spécialisations, 3 caractéristiques |
| Cartes/sorts | 48 familles, 6 raretés, une amélioration explicite pour chacune |
| Objets | 18 équipements dans 6 emplacements ; 8 reliques, 2 actives |
| Run | 20 profondeurs, 12 rencontres, 7 archétypes ennemis, 7 plateaux dont 5 mécanismes de salle |
| Économie | 7 canaux de drop par mob, sacs, achat ciblé, troc, vente de cartes, soins et réaffectation de famille |
| Règles | Pioche, réserve, consommation, ordre des effets, contrôles, boss, progression, sauvegarde et fin de run |
| Preuves finales | 2 304 cas de cartes, 672 comparaisons d’objets/spécialisations, 640 runs, 336 répartitions de statistiques, 192 calculs de drop par famille/classe |

Le résultat le plus structurant est économique : une classe défensive doit contribuer à la victoire sans consommer une carte d’attaque pour chaque petit progrès. Les expériences ont conduit à un renvoi limité du Gardien, à un petit sac normal garanti par mob et à une montée initiale moins brutale. Les chiffres avant/après sont conservés ; la version finale n’efface pas les essais défavorables.

## Lire et décider

1. [Règles V1](REGLES_V1.md) — toutes les décisions de fonctionnement.
2. [Catalogue](CATALOGUE.md) — chaque carte, amélioration, équipement, relique et spécialisation.
3. [Maths et run](MATHS_ET_RUN.md) — niveaux, XP, PV, dégâts ennemis, dilution du deck, budget et drops.
4. [Bilan des essais](BILAN.md) — résultats, interprétation, limites et points de vigilance.
5. [Grille d’équilibrage](GRILLE_EQUILIBRAGE.md) — ce qui est comparé et ce que chaque chiffre permet de conclure.
6. [Recherche et décisions](RECHERCHE_ET_DECISIONS.md) — sources de créateurs, questions successives et principes transposés.
7. [Journal des itérations](ITERATIONS.md) — pénuries, mauvaise politique de jeu, révision du Gardien.
8. [Reprise dans le dépôt](REPRISE_REPO.md) — commandes, intégration Godot et tests humains préparés.

## Données transportables

[manifest.json](manifest.json) contient toutes les définitions. [card_summary.csv](card_summary.csv), [item_summary.csv](item_summary.csv), [run_summary.csv](run_summary.csv), [stat_allocations.csv](stat_allocations.csv), [family_drop_math.csv](family_drop_math.csv), [drop_expectations.csv](drop_expectations.csv) et [drop_probabilities.csv](drop_probabilities.csv) permettent de comparer les valeurs sans relire le code. [metadata.json](metadata.json) relie les résultats à leurs entrées par empreintes.

Les sources de calcul sont `content.mjs`, `combat.mjs`, `run.mjs`, `market.mjs`, `fixtures.mjs`, `analyze.mjs` et `export_tables.mjs`. Les deux suites de tests V1 contiennent 199 contrôles ; avec les 13 contrôles du laboratoire précédent, la vérification exécutée compte **212 tests réussis**. Les 135 paires d’équipement, 729 ensembles complets et 28 paires de reliques sont des cas internes à ces tests, pas 892 tests supplémentaires annoncés artificiellement.

Les fichiers détaillés se régénèrent dans `artifacts/dev/consumable-v1/`. Pour vérifier la fraîcheur du paquet livré :

```powershell
node docs/design/consumable_v1/verify_delivery.mjs
```

Les études précédentes restent accessibles dans [le laboratoire d’économie](../card_economy_lab/README.md). Cette V1 les prolonge et remplace leurs coefficients provisoires pour ce scénario ; elle ne réécrit pas l’historique ni les règles publiques de Catabase.
