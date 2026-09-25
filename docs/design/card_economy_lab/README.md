# Reprise — laboratoire d'économie des cartes

**Entrée du dossier à donner à l'autre ordinateur : ce fichier.** Tout est relatif au dépôt ; aucun chemin personnel, service distant ou moteur Godot n'est nécessaire pour refaire les calculs.

**Dernière livraison : [V1 théorique complète](../consumable_v1/README.md)** — catalogue fermé, combat simulé, économie, progression, tests de tous les effets et comparaisons de runs. Commencer par cette V1 pour reprendre la construction.

L’[audit systémique du 25 septembre](research_2026-09-25/README.md) conserve ses 21 références, l’analyse des drops/raretés/économie, des classes/reliques/équipements/progression et de la run tactique. Il sert de fondation à la V1 ; ses coefficients restent historiques.

Le [rapport initial](REPORT.md) conserve les premières expériences. L'étude du 25 septembre corrige deux interprétations : `early_supply` n'est pas une courbe monotone, et le stress à 70 % ne prouve aucune restriction de classe. Ce laboratoire décrit un concept, pas une fonctionnalité déjà développée.

## Fichiers

| Fichier | Usage |
|---|---|
| [REPORT.md](REPORT.md) | Rapport complet et plan de reprise |
| [SOURCES.md](SOURCES.md) | Six références commentées, transferts et limites |
| [baseline.json](baseline.json) | Tables de drop, effectifs, profils de dépenses et prix modifiables |
| [simulate.mjs](simulate.mjs) | Espérances, variances, probabilités exactes et simulations de stock |
| [simulate.test.mjs](simulate.test.mjs) | Huit tests indépendants des règles de combat |
| [RESULTS.csv](RESULTS.csv) | Instantané transportable des 36 expériences exécutées |
| [cards.csv](cards.csv) | Vingt propositions de cartes avec coût, effet et risque |
| [MATH_AND_EXPERIMENTS.md](MATH_AND_EXPERIMENTS.md) | Cahier de calcul et protocole des prochaines expériences |
| [WORKLOG.md](WORKLOG.md) | Contexte court, décisions et base Git inspectée |

## Refaire les calculs

Depuis la racine du dépôt, avec Node 24 (testé : v24.19.0), aucune installation npm :

```powershell
node --test --test-isolation=none docs/design/card_economy_lab/simulate.test.mjs
node docs/design/card_economy_lab/simulate.mjs --runs 20000 --seed 24092026 --out artifacts/dev/card-economy-lab
```

Les sorties détaillées `results.json` et `experiments.csv` sont régénérées sous `artifacts/dev/card-economy-lab/`. Elles incluent les hypothèses, graine, version Node, empreintes du script et de la configuration, intervalles de Wilson, échecs par premier combat concerné et quantiles conditionnels. Le dossier artifacts peut être ignoré par Git ; les résultats importants sont transcrits dans le rapport et dans RESULTS.csv.

Pour augmenter la précision Monte Carlo, modifier `--runs`. Pour une autre expérience, modifier le JSON puis conserver les paramètres avec les résultats. La variante `early_supply` est définie explicitement dans le script ; elle ne modifie pas le fichier de base. Le script ne lit pas automatiquement le GDScript : les effectifs sont une transcription datée à revérifier si le jeu change.

## Vérifications effectuées

- Calcul analytique reproduisant les 125,25 normales du scénario historique de 43 mobs, puis correction à 93 normales pour les 32 mobs Airain pré-boss.
- 36 cas de 20 000 parcours de budget, soit 720 000 parcours, graine 24092026.
- Huit tests exécutés avec succès, y compris comparaison avec propagation exacte des probabilités.
- Première tentative avec `node --test` bloquée par `spawn EPERM` avant exécution des tests ; l'option `--test-isolation=none` a permis la validation sans sous-processus. Ce blocage n'était pas un échec des assertions.
- Aucun test de gameplay, import Godot, rendu ou partie humaine : aucun code de jeu n'a changé. Les validations moteur et CI habituelles resteront nécessaires lors d'une future implémentation.

## Fraîcheur et transport

Base de code auditée : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`. Avant reprise :

```powershell
git status --short
git diff 6a500c545f04d3e4c53a99d3643d0c4d844e303f -- core/expedition/catabase_route_v6.gd core/expedition/catabase_monster_encounter_catalog.gd data/encounters/catabase_frail_hellspawn_encounter.tres
```

Vérifier aussi les modifications non suivies pertinentes et les éventuelles autres sources de spawn. Ne pas assimiler ce contrôle statique à un export runtime.

Les fichiers du laboratoire ont été créés localement ; leur présence sur un autre ordinateur exige de synchroniser ce dossier par Git ou de le copier. Aucune publication distante n'est présumée. Les propositions antérieures restent dans `docs/design/` avec leur statut historique.

## Message de reprise prêt à transmettre

> Lis docs/design/card_economy_lab/research_2026-09-25/README.md et ses trois chapitres, puis le laboratoire parent si nécessaire. Préserve la direction utilisateur : progression standard d'abord, sans maîtrise/prospection/reliques/bonus de performance. Vérifie la fraîcheur des effectifs, relance les tests et calculs, puis mesure les consommations réelles et l'utilité du catalogue avant de retenir des taux. Ne confonds pas financement du stock et victoire. Les cartes CSV et prix sont des hypothèses, aucun système n'est implémenté. Préserve les changements des autres tâches et attends une instruction d'implémentation avant de remplacer les règles publiques.
