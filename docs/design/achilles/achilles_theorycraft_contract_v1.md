# Contrat Achilles Theorycraft Foundation V1

## Statut

`ACHILLES_THEORYCRAFT_FOUNDATION_READY_FOR_OWNER_REVIEW`

Le lab est un outil de conception isolé. Il ne constitue ni une progression, ni un build actif, ni un éditeur des Resources de production. Les entrées conceptuelles restent `DRAFT`, `DESIGN_CONCEPT_ONLY` et `NOT_RUNTIME_LOADABLE`.

## Autorité lue

La baseline ne lit pas `achilles.tres` comme une liste autonome de capacités : cette Resource contient volontairement zéro sort et zéro discipline. Le chemin d’autorité est :

```text
res://data/runs/odyssey.tres
  -> odyssey_content_profile.tres
  -> achilles_progression_profile.tres
  -> RunHeroResolver.resolve_runtime_hero_data(run, false)
```

Le snapshot relit donc la même composition que la run. Il enregistre également le dépôt, la branche, le commit, la date du commit et la version de Godot. Sa date ne vient pas de l’horloge locale. Son SHA-256 est calculé sur le JSON canonique avant l’ajout du champ `snapshot_sha` lui-même.

Baseline observée lors de la validation :

- Achille : 110 PV, initiative 14, 6 PA, 3 PM, attaque 18, attaque de base désactivée, quatre slots actifs ;
- Frappe de lance : 2 PA, portée 1–2, 9 dégâts, une fois par activation ;
- Percée : 2 PA, portée 3 en ligne, 5 dégâts, déplacement du lanceur avec chemin libre, une fois par activation ;
- Balayage : 3 PA, zone croix centrée sur soi, 6 dégâts, poussée 1, une fois par activation ;
- Garde d’airain : 2 PA, cible soi, bouclier 10, une fois par activation ;
- disciplines `spear`, `advance`, `sweep`, `guard`, chacune avec un rang 1, seuil 0 et aucun choix ;
- L’Odyssée : seed 2401, durées 18/25 minutes, trois salles, deux potions mineures et un parchemin d’action au départ, récompenses d’équipement désactivées.

Ces valeurs sont observées, pas proposées comme équilibrage futur.

## Architecture

Tout le code vit sous `tools/achilles_theorycraft/`.

- `AchillesTheorycraftSnapshotExporter` lit la chaîne Odyssey, les unités, capacités, disciplines, rencontres, ennemis, économie et topologies disponibles. Il produit le snapshot JSON, sa vue Markdown et l’index de provenance.
- `TheorycraftActionSpec`, `AchillesTheorycraftBuild`, `TheorycraftContext` et `TheorycraftComparisonReport` sont des modèles `RefCounted`. Ils ne sont pas des Resources runtime.
- `AchillesTheorycraftCatalog` construit la baseline depuis les Resources live et fournit les deux templates conceptuels.
- `AchillesActionEconomyAnalyzer` énumère les séquences ordonnées non vides sous le budget `max_ap` résolu depuis Achille via L’Odyssée, en respectant les limites par activation, d’usage et de cooldown. Il ne possède aucun fallback caché à 6 PA ; un budget absent produit `NOT_MEASURED`, et un override explicite est `MANUAL_ASSUMPTION`.
- `AchillesTheorycraftComparisonService` compare jusqu’à trois builds et expose les deltas et axes séparés.
- `AchillesTheorycraftValidator` produit des avertissements bornés, jamais des décisions de design.
- `AchillesTheorycraftStore` écrit uniquement du JSON/Markdown hors production.
- `AchillesTheorycraftLab.tscn` est l’interface autonome de snapshot, builds A/B/C, économie, contextes, deltas, alertes, édition draft et export.

Aucun fichier de production ne référence ces classes. Le lab peut lire les services et Resources existants, mais aucun lien inverse n’est créé depuis L’Odyssée, Achille, la progression, `GameManager`, `RunHeroResolver` ou `CharacterRunState`.

## Provenance

Chaque valeur exportée est accompagnée d’une provenance dans son objet `_provenance` ou dans `snapshot_provenance.json` :

- `OBSERVED_RUNTIME_DATA` : lecture directe d’une Resource ou de l’Engine ;
- `DERIVED_EXACT` : calcul déterministe avec formule et sources ;
- `DRAFT_DESIGN_INPUT` : intention ou valeur éditée dans le lab ;
- `MANUAL_ASSUMPTION` : hypothèse explicitement fournie à un contexte ;
- `NOT_MEASURED` : valeur absente ou non calculable honnêtement.

`NOT_MEASURED` est sérialisé avec une valeur `null`, jamais avec zéro. Une séquence valide par coût reste `ABSTRACT_AP_SEQUENCE`. Elle ne devient `CONTEXTUALLY_LEGAL_SEQUENCE` que lorsqu’un contexte fournit une preuve ou une hypothèse explicite de légalité ; la présence d’une map ne suffit pas.

Les hypothèses saisies dans un build ou un contexte portent `MANUAL_ASSUMPTION` même lorsque le build parent reste `DRAFT`. Les alertes garde, kite, récupération et dominance répercutent cette provenance dans leurs preuves. Chaque delta expose `axis_consequences`; faute de modèle causal validé, sa valeur reste `null` avec provenance `NOT_MEASURED`.

## Économie de 6 PA observés

Pour la baseline actuelle, le budget vaut 6 parce que la vraie `UnitData.max_ap` résolue vaut 6. L’énumérateur produit exactement 22 séquences ordonnées non vides :

- histogramme des PA inutilisés : `{0: 6, 1: 6, 2: 6, 3: 1, 4: 3}` ;
- 12 séquences inclusion-maximales ;
- aucune répétition d’une capacité, car les quatre capacités sont limitées à une utilisation par activation.

Les templates conceptuels n’inventent aucun coût. Leur analyse de séquences reste donc `NOT_MEASURED` jusqu’à saisie d’hypothèses draft explicites.

## Contextes

Le catalogue expose Salle I, Salle II, Salle III et le contexte abstrait. Les Resources de salle et rosters d’ennemis viennent de L’Odyssée. Les identifiants de spawn hérités ne sont jamais utilisés comme roster héros.

Chaque export de contexte porte une provenance explicite pour `context_id`, `room_resource`, `enemy_resources`, `turn_horizon`, `starting_state`, `consumables` et `assumptions`. L’horizon d’un tour est une `MANUAL_ASSUMPTION`; l’état de départ et les consommables restent `NOT_MEASURED` lorsqu’aucun état live n’est fourni.

Les dimensions et nombres de cases accessibles sont lus quand la topologie fournit une API exacte. Restent volontairement `NOT_MEASURED` sans état de tour précis et adaptateur validé :

- tours avant premier contact ;
- distance de chemin entre un départ et une destination ;
- ligne de vue acteur/cible ;
- couverture effective des portées ;
- goulets et routes alternatives ;
- exposition et fiabilité contextuelles ;
- fenêtre réelle de kite ;
- récupération après une mauvaise position.

Les placeholders `0` ou `{}` des métriques qui exigent une RunData ne sont pas interprétés comme des mesures.

## Templates initiaux

`ACHILLES_CURRENT_PROTOTYPE_BASELINE` référence directement les quatre Resources live.

`ACHILLES_SWORD_SHIELD_CONCEPT_TEMPLATE` ne contient que des intentions : entrée au contact, orientation, blocage, contre, protection active, tempo et récupération après erreur.

`ACHILLES_BOW_CONCEPT_TEMPLATE` ne contient que des intentions : ligne de vue, priorité de cible, maintien de distance, préparation spatiale, repositionnement, risque de kite et contreparties de proximité.

Les deux templates ont :

- `status = DRAFT` ;
- les tags `DESIGN_CONCEPT_ONLY` et `NOT_RUNTIME_LOADABLE` ;
- aucune valeur d’équilibrage finale ;
- aucune capacité runtime ;
- aucune référence à un asset visuel d’équipement ;
- aucune Resource de production comme destination d’écriture.

La baseline est `runtime_backed = true` parce qu’elle lit les quatre `Spell` réelles, mais elle reste `runtime_loadable = false` et `active_in_game = false`. Cette distinction vaut pour tous les statuts du lab : aucun statut ne signifie « actif dans le jeu ».

## Avertissements

Les validateurs exposent :

- `POTENTIAL_STRICT_DOMINANCE` ;
- `NUMERIC_ONLY_CHOICE` ;
- `DEAD_AP_RISK` ;
- `AUTOMATIC_GUARD_LOOP_RISK` ;
- `BOW_KITE_RISK` ;
- `NO_RECOVERY_PATH_RISK` ;
- `LOW_BUILD_DISTINCTION` ;
- `REPETITIVE_SEQUENCE_RISK`.

Chaque résultat porte le niveau `WARNING`, un périmètre, des preuves et une provenance. Une donnée absente n’est pas convertie en verdict négatif.

## Persistance et exports

Les brouillons sont des fichiers JSON sous :

```text
user://theorycraft/achilles/
```

Les revues sont exportées sous :

```text
user://theorycraft/achilles/exports/
```

ou vers la racine d’artefacts de cette mission, explicitement configurée et validée par l’API. Les chemins absolus arbitraires, la source Canonical, le worktree Gate A et toute destination de production sont refusés. Le lab n’appelle aucun service de sauvegarde de Resource et n’écrit jamais les `.tres` de production.

Un export de comparaison contient toujours :

```text
comparison.json
comparison.md
build_a.json
build_b.json
build_c.json
```

Le sérialiseur trie récursivement les clés et utilise une représentation JSON canonique. Deux exports consécutifs du même rapport ont été vérifiés octet pour octet, avec le même SHA-256.

Le snapshot exporte :

```text
achilles_theorycraft_snapshot.json
achilles_theorycraft_snapshot.md
snapshot_provenance.json
```

## Utilisation

Lancer directement la scène :

```powershell
& 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' --path . --scene 'res://tools/achilles_theorycraft/AchillesTheorycraftLab.tscn'
```

Dans le lab :

1. vérifier le commit et le SHA du snapshot ;
2. choisir jusqu’à trois builds dans A, B et C ;
   B et C peuvent être placés sur `EMPTY`, afin que l’interface compare réellement un, deux ou trois builds ;
3. choisir une salle ou le contexte abstrait ;
4. lire séparément les séquences, deltas, alertes et données non mesurées ;
5. modifier uniquement un JSON dont le statut reste `DRAFT` et les deux tags d’isolation sont présents ;
6. appliquer le brouillon, qui est enregistré sous `user://theorycraft/achilles/` ;
7. exporter la revue déterministe.

Le bouton d’export ne rend aucun build actif dans le jeu.

## Validation

Commande ciblée exécutée avec Godot `4.7.1.stable.official.a13da4feb` et GUT `9.7.1` :

```powershell
& 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://test/unit/test_achilles_theorycraft_foundation.gd -gexit
```

Résultat final ciblé : **50/50 tests, 448 assertions, zéro échec**.

La suite couvre le snapshot, l’isolation, le budget PA réellement résolu et son override, l’absence de fallback caché, la provenance complète des contextes, les conséquences d’axes honnêtement `NOT_MEASURED`, les validateurs, les destinations d’export bornées, les templates, le checkpoint Gate A en lecture seule, l’interface autonome et le déterminisme des exports.

## Limite de décision

Le lab prépare une prochaine revue `ACHILLES_BUILD_CONCEPTS_V1`. Il ne sélectionne aucun concept, ne fixe aucune valeur finale et ne modifie aucune Resource gameplay.
