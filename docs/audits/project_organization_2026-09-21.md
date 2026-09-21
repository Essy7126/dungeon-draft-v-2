# Audit d’organisation et de coût de contexte — 21 septembre 2026

## Conclusion

Une architecture plus lisible aiderait à travailler avec moins de recherches, de contexte chargé et de risques de régression. Le meilleur premier investissement est la clarification du produit actuel, des points d’entrée et des validations. Une réorganisation complète des chemins aurait un coût immédiat élevé et un bénéfice incertain.

Les gros assets ne consomment pas automatiquement des tokens. Le coût de contexte vient surtout des documents et sorties effectivement lus, des recherches ambiguës, des fichiers qui mélangent les responsabilités et des reprises de diagnostic. Le poids disque, le temps d’import et la consommation de tokens doivent être mesurés séparément.

## Périmètre et méthode

- Référence : `fadd1449f51d90ec76714ff14d1e3113d100ee5e` ; worktree initial propre.
- Inventaire de tous les fichiers suivis présents, tailles du checkout et lignes des principaux formats textuels. Ces tailles ne sont ni celles des objets Git ni celles d’un export du jeu ; elles incluent les éventuels fichiers LFS matérialisés.
- Inspection ciblée du README, des règles locales, de la configuration, de la CI, du lanceur, des principaux orchestrateurs, des dépendances vers le Studio et des candidats historiques.
- Recherche des références littérales `res://` entre guillemets ; contrôle complémentaire des UID des trois scripts/scènes candidats de racine. Cela ne couvre pas intégralement les chemins construits, les identifiants de classes globaux, les références binaires ou les outils externes.
- Recherche SHA-256 des doublons exacts parmi les fichiers de plus de 1 000 000 octets ayant une taille identique.
- Mesure des répertoires locaux `.godot`, `artifacts` et `output` ; diagnostic environnement, auto-tests du harnais et tentative de smoke.
- Pas de suppression, déplacement ou refactorisation. Ce document est le seul ajout destiné au dépôt. Les données de mesure sont dans `artifacts/project_audit/2026-09-21/`, ignoré par Git.

Il s’agit d’un audit transversal fondé sur un inventaire exhaustif des chemins suivis et des lectures ciblées. Ce n’est pas une revue sémantique ligne par ligne des 12 877 fichiers ni une certification d’inutilité de toutes les ressources.

## Mesures

| Indicateur | Mesure avant ajout de ce rapport |
|---|---:|
| Fichiers suivis présents | 12 877 |
| Volume correspondant | 2,740 Go décimaux |
| Markdown dans tout le dépôt | 567 |
| Markdown dans `docs/` | 342 |
| Notes dans `docs/ai/` | 51 |
| Fichiers de tests `.gd` sous `test/unit/` | 311 |
| Répertoires immédiats sous `tools/` | 78 |
| Fichiers suivis sous `artifacts/` | 320 / 202,6 Mo |
| Groupes de doublons exacts > 1 Mo | 40 |
| Octets redondants de ces groupes | 229,3 Mo, avant analyse d’usage |
| Cache local `.godot/` | 9 740 fichiers / 2,738 Go |
| `artifacts/` local, suivi et ignoré | 32 176 fichiers / environ 4,804 Go |
| `output/` local | 545 fichiers / 174,2 Mo |

Les mesures locales sont un instantané ; des outils peuvent continuer à produire des fichiers. Le total `artifacts/` comprend les fichiers suivis : ne pas additionner ces deux chiffres. Les doublons comprennent des copies source/livrable parfois intentionnelles.

## Ce qui est déjà bien organisé

- `AGENTS.md` est court (28 lignes) et dirige vers des commandes concrètes. Il ne faut pas le transformer en manuel complet.
- `dev.ps1` centralise les sorties compactes, les journaux détaillés, le contexte Git, la découverte du moteur et le verrou des commandes moteur.
- `tools/dev/toolchain.json` fixe les versions ; le diagnostic distingue correctement disponibilité du moteur et import.
- Les ressources de contenu, le moteur de combat, la présentation et les outils ont déjà des répertoires distincts.
- `core/expedition/` possède des objets dédiés : session, route, build, sauvegarde et catalogues. Il faut poursuivre cette séparation, pas recréer un framework parallèle.
- Le Studio possède des services de sauvegarde et des contrats transactionnels à réutiliser.
- La CI conserve des contrats ciblés, une suite globale, une liste exacte d’échecs historiques et un contrôle de mutation du worktree.
- `web/` et `meshy_output/` sont déjà isolés de l’import par `.gdignore` ; plusieurs sources artistiques le sont également.

## Problèmes et recommandations prioritaires

### 1. Le point d’entrée produit sert aussi d’historique — priorité haute

Le README fait 222 lignes et 15 794 octets. Il juxtapose produit actuel, trio historique, laboratoires, anciennes étapes de conception et nombreux rapports. Il désigne encore la reprise du 5 septembre comme référence de travail, alors que les règles Cartes ont évolué jusqu’au 20 septembre. Le texte nomme aussi `first_run.tres` « ressource de production » après avoir décrit cette run comme historique.

Conséquence : une tâche simple demande de réconcilier plusieurs versions du produit avant de toucher au code.

Proposition : un README court indiquant le parcours actuel, les deux variantes, le lancement, les tests et quelques liens ; une référence stable `docs/current/product.md` pour les règles actuelles ; un index d’architecture et une matrice de validation. Les notes datées restent des preuves historiques avec un statut clair, jamais une seconde vérité courante.

### 2. La recherche de contexte peut masquer le code utile — priorité haute

`dev.ps1 context` filtre les noms de chemins, trie alphabétiquement et renvoie les 30 premiers. La commande exécutée `./dev.ps1 context catabase` trouve 370 chemins ; ses 30 premiers résultats sont tous sous `art/` ou `assets/`. Aucun fichier `core/` n’apparaît dans cette première page.

`./dev.ps1 context cards` reste utile, mais une recherche littérale de ce mot ne constitue pas une carte complète des fichiers `class_card_*`.

Proposition : conserver cette commande, ajouter une sélection par domaine et par type (`code`, `tests`, `docs`, `art`), une pagination, et un petit registre des points d’entrée. Faire remonter les sources actives et leurs tests avant les prompts artistiques. Ne pas injecter tous les résultats ni un index gigantesque dans chaque tâche.

### 3. Quelques orchestrateurs coûtent cher à comprendre — priorité haute

| Fichier | Lignes | Séparation proposée |
|---|---:|---|
| `addons/dungeon_draft_arena_studio/ui/arena_studio_main.gd` | 8 983 | Contrôleurs d’édition, calibration, publication, historique et aperçu ; conserver une coque UI |
| `battle/battle.gd` | 3 082 | Résolution d’action, cycle de combat, fin de combat et coordination des choix |
| `addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd` | 2 841 | Document, commandes d’édition et présentation |
| `core/game_manager.gd` | 2 747 | État de run, navigation, persistance et coordination des écrans |
| `ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd` | 2 678 | Présentation du HUD, main de cartes et interactions |
| `addons/dungeon_draft_arena_studio/services/arena_terrain_type_save_transaction_service.gd` | 2 611 | Examiner les étapes de transaction sans casser son atomicité |
| `units/unit.gd` | 1 975 | Examiner les responsabilités d’état, effets et comportement |

Le nombre de lignes est un signal, pas une preuve suffisante de mauvais code. Les fonctions inspectées montrent néanmoins plusieurs responsabilités dans les trois orchestrateurs principaux : par exemple `GameManager` restaure l’inventaire, gère les écrans, pilote la progression et expose l’expédition.

Proposition : extraire une responsabilité à la fois, en conservant temporairement les API existantes et leurs tests. Éviter de remplacer un grand fichier par des dizaines de petits fichiers qu’il faudrait tous lire ensemble. Le critère de réussite est la réduction du contexte nécessaire pour une modification réelle.

### 4. Les frontières runtime / édition sont incomplètes — priorité moyenne

Références observées :

- `battle/battle.gd` charge `arena_direct_test_configuration.gd` dans le Studio.
- `battle/painted/painted_battle.gd` charge son service de cadrage dans le Studio.
- `hub/painted_halt/living_halt.gd` charge le service de manifestes du Studio.
- `core/expedition/catabase_painted_icon_catalog.gd` charge `ui/theme/catabase_icon_library.gd`.

La réutilisation évite la duplication, ce qui est positif. En revanche, l’emplacement des contrats partagés oblige à parcourir le code éditeur pour comprendre le jeu. Le couplage du `GameManager` aux écrans est cohérent pour un orchestrateur applicatif ; ce n’est pas une raison de rendre tout `core/` abstrait.

Proposition : expliciter les couches. À terme, déplacer les petits contrats et calculs réellement communs vers un emplacement partagé, avec façades de compatibilité ; laisser les opérations d’édition dans l’addon. Réutiliser les services existants, ne pas les dupliquer.

### 5. Les raccourcis de validation ne représentent pas toujours leur nom — priorité haute

- `smoke` ne sélectionne que `test_champion_codex.gd` et `test_spell_codex_detail.gd`. Il ne prouve pas le parcours public titre → préparation → combat → récompense → reprise.
- `studio` ne sélectionne que `test_dungeon_draft_studio_2_0.gd`, alors que la CI possède un ensemble nettement plus large de contrats Studio.
- `catabase` inclut bien `test_catabase_class_run.gd`, mais ses motifs ne sélectionnent pas des tests tels que `test_class_card_vfx.gd`, `test_class_painted_icons.gd` ou `test_cards_studio_audit.gd`.
- `dev.ps1 format` exclut tout `addons/`, y compris l’addon du projet ; sa documentation parle seulement d’addons tiers exclus.
- La CI encode les versions et l’installation du moteur à plusieurs endroits alors que le lanceur dispose déjà d’un manifeste.
- La CI autorise encore un chemin précis sous `output/validation-feedback-candidate/...` dans son filtre d’erreurs d’import ; `output/.gdignore` existe maintenant. Candidat à réexamen, pas preuve que cette exception est encore nécessaire.

Proposition : une matrice versionnée domaine → tests → scénario runtime → contrôle visuel, des noms de suites explicites et des exceptions de formatage limitées aux dépendances tierces. Conserver intégralement les gates actuelles pendant la transition. Ne pas remplacer la suite globale par une sélection « économique ».

### 6. Les dépendances de travail sont encore partiellement propres au poste — priorité moyenne

Le diagnostic moteur passe ici, mais `python` résout vers le raccourci Microsoft Store sans interpréteur disponible ; `node` n’est pas trouvé par `Get-Command`. L’inventaire a utilisé le Python fourni par l’application Codex.

Des chemins locaux persistent notamment dans `tools/blender_halt_lab/open_lab.ps1`, `tools/blender/achilles_meshy_v3/build_achilles_meshy_v3.py` et `tools/passe_rive_motion/verify_review.mjs`. Ce sont parfois des valeurs par défaut ou scripts ponctuels ; cela ne prouve pas que tous ces outils échouent.

Proposition : résolution centralisée des exécutables, paramètres de chemins et diagnostic optionnel par métier (art, web, Blender). Ne pas imposer toutes les dépendances artistiques à une tâche gameplay.

## Dossiers et fichiers à conserver, archiver ou nettoyer

| Ensemble | Diagnostic | Traitement conseillé |
|---|---|---|
| `core/`, `battle/`, `units/`, `items/` | Moteur et orchestration actifs | Conserver ; clarifier les responsabilités |
| `data/` | Contrats et contenu, actifs et historiques | Identifier les racines publiques, fixtures et compatibilités |
| `ui/`, `characters/`, `hub/`, `vfx/`, `cinematics/` | Présentation et parcours de jeu | Conserver ; indexer les points d’entrée |
| `asset/` et `assets/` | Tous deux utilisés par les ressources actuelles | Unifier les règles de destination des nouveaux assets ; migrer progressivement les anciens chemins |
| `art/source/` | 3 147 fichiers, 782,8 Mo ; sources, versions et provenance | Définir livrable retenu et variantes archivées ; ne pas supprimer globalement |
| `imported_models/` | Modèle d’archiviste réellement utilisé, avec copie exacte | Cibler le doublon `_1`, conserver le modèle référencé |
| `meshy_output/` | Générations isolées de Godot | Catalogue court des livrables retenus ; conservation selon besoin de provenance |
| `tools/` | 78 sous-dossiers mêlant outils durables et opérations ponctuelles | Index par usage ; statut actif, expérimental ou historique et commande de vérification |
| `addons/dungeon_draft_arena_studio/` | Outil de contenu actif et partagé | Conserver ; réduire les gros contrôleurs sans réécrire les services |
| `addons/gut/`, `addons/godot_ai_workbench/`, `addons/meshy-godot-plugin/` | Dépendances/intégrations | Isoler des recherches ordinaires ; conserver versions et contrats |
| `test/` et `tests/` | Tests unitaires et scénarios, mais aussi scénarios sous `test/achilles/` | Clarifier l’index avant de déplacer ; tous les chemins de CI doivent rester valides |
| `web/achilles-run-lab/` | Prototype explicitement expérimental et autonome | Conserver isolé ; sortir du contexte Godot courant |
| `docs/` | Références, conception, comptes rendus et données générées mélangés | Référence courante courte, archives clairement étiquetées |
| `artifacts/` | Rapports locaux et 320 fichiers déjà suivis | Séparer fixtures, preuves retenues et sorties régénérables |
| `output/` | Sorties locales déjà ignorées par Godot | Politique de rétention, pas de lecture par défaut |
| `.godot/` | Cache régénérable | Conserver normalement : le supprimer force des réimports |
| `debug/`, `.github/`, fichiers de configuration | Infrastructure utile | Conserver ; vérifier les écarts de conventions |

### Candidats précis

1. **`gobtest.tscn` : vestige cassé confirmé.** Charge `res://gobtest.gd` et `res://asset/gobtest.glb`, tous deux absents. Aucune référence entrante littérale/UID trouvée hors anciens manifestes. Candidat fort à suppression après contrôle moteur du lot de nettoyage.
2. **`test_phase_1.tscn` : prototype historique probable.** Son script embarqué dit « À supprimer une fois la Phase 1 validée ». Aucune référence entrante littérale/UID trouvée hors inventaires historiques. Vérifier la couverture GridData/Pathfinder avant retrait.
3. **`main.gd` et son UID : ancien point d’entrée probable.** Le vrai `run/main_scene` se résout vers `ui/TitreEcran.tscn`. Aucune référence entrante littérale/UID trouvée ; ce constat reste statique.
4. **`debug.log`, `artifacts/intro_headless.log` : journaux suivis.** Candidats à désuivi ; vérifier d’abord si une preuve historique doit être conservée ailleurs.
5. **`imported_models/Lanternbound Archivist_1/` : copie à dédupliquer.** Les principaux binaires sont identiques par SHA-256 à ceux du dossier sans suffixe ; aucune référence `res://` littérale vers `_1` trouvée. `hub/HubArchivist.tscn` et `test_start_hub_vertical_slice.gd` utilisent l’original. Les trois plus gros doublons représentent déjà 100,2 Mo décimaux redondants.
6. **`cinématics/intro/source/` : source ambiguë à reclasser.** Quatre fichiers suivis, dont `intro_storyboard.png.png` et `intro_narration..mp3`. Pas de référence littérale trouvée, mais des sources artistiques peuvent être utiles sans être chargées par le jeu. Archiver/documenter plutôt que déclarer inutiles.
7. **`docs/audits/project_cleanup/` : précédent audit à archiver explicitement.** 116 469 lignes de formats textuels, dont deux manifestes de 64 851 et 45 753 lignes. Ils décrivent un ancien état ; par exemple `gobtest.tscn` figure dans `deleted_paths.txt` mais existe dans le checkout actuel. Ce n’est pas une preuve de suppression actuelle. Garder un résumé et les preuves accessibles hors recherche ordinaire.
8. **`.github/workflows/ci.yml` : workflow historique explicite.** Manuel et fixé sur Godot 4.7, contre 4.7.1 dans la référence actuelle. Archiver seulement si la comparaison historique n’est plus utile ; aucune suppression nécessaire pour économiser significativement des tokens.

**À ne pas déclarer obsolètes sur leur nom :** `first_run.tres` reste référencé par des tests, des smokes du Studio et des outils ; `CatabaseCards` reste la base de `class_cards.gd` et sert à restaurer les anciennes révisions ; les dossiers artistiques `v1`, `v2`, `v3` peuvent être des sources ou livrables encore actifs.

### Précautions de rangement utiles

`.gitignore` n’enlève pas les fichiers déjà suivis. Les exceptions actuelles autorisent même largement `artifacts/arena_studio/**`. Mais `artifacts/item_studio/characterization.json` est une fixture explicitement lue par un test : déplacer toutes les sorties sans distinction casserait la validation.

Il n’y a pas de `.gdignore` global dans `art/source/`, `docs/` ou `artifacts/`. Certaines branches ont leur propre exclusion. Vérifier les besoins de l’éditeur avant d’en ajouter : les manifestes des haltes et les services du Studio référencent certaines sources artistiques. L’effet réel sur le temps d’import reste à mesurer.

Un déplacement Godot doit traiter ensemble chemins `res://`, UID, `.import`, catalogues, références construites et scripts externes. Ne pas renommer massivement `asset/` en `assets/` ou fusionner `test/` et `tests/` comme simple opération cosmétique.

## Architecture cible pragmatique

Conserver les grands dossiers actuels. Clarifier trois rôles : règles et état sous `core/`/`data/` ; application et navigation autour de `GameManager` ; présentation sous `battle/`, `ui/`, `characters/`, `hub/` et `vfx/`. Les outils consomment les contrats communs ; les règles n’ont pas à connaître les écrans.

Créer au maximum quelques références stables :

```text
README.md                         produit actuel et démarrage
AGENTS.md                         règles opérationnelles courtes
docs/current/product.md           parcours et règles actuels
docs/current/architecture.md      domaines, points d’entrée, dépendances
docs/current/validation.md        modification → validations requises
docs/archive/                     comptes rendus historiques indexés
```

Cette arborescence est une proposition, pas une migration exécutée. Les notes datées utiles peuvent d’abord rester à leur chemin actuel avec un statut et un lien vers la référence courante. Éviter de casser leurs liens pour le seul plaisir de déplacer des fichiers.

Pour les outils, préférer un registre court indiquant objectif, propriétaire fonctionnel, commande, entrées/sorties et statut. Ne créer de sous-arborescence `labs`/`pipelines`/`validation` supplémentaire que lorsque le déplacement simplifie réellement une tâche.

## Plan de mise en œuvre

| Ordre | Lot concret | Critère de réussite | Risque |
|---|---|---|---|
| 1 | README court, référence actuelle, index architecture/validation | Une tâche Cartes trouve immédiatement code, règles et tests utiles | Faible, vérifier les liens |
| 2 | Recherche `context` par domaine, résultats classés et paginés | `catabase` fait apparaître la session, la route et leurs tests sans bruit artistique | Faible, tests du harnais |
| 3 | Nettoyage des vestiges identifiés et politique des artefacts | Import, suite globale, smokes et fixtures préservés ; aucun chemin cassé | Moyen |
| 4 | Extraire une responsabilité dans l’orchestrateur le plus souvent modifié | Modification métier nécessitant moins de fichiers/lignes à lire, contrats inchangés | Moyen à élevé |
| 5 | Unifier progressivement assets et contrats partagés | Références et usages runtime/Studio vérifiés après chaque petit lot | Élevé si migration globale |

Pour les lots 3 à 5 : exécuter les validations imposées par la CI, compléter par les scénarios concernés, contrôler les sauvegardes anciennes et le parcours public, inspecter les captures lorsque le rendu change. Le smoke actuel seul ne suffit pas.

Le défaut d’accès aux certificats observé pendant cet audit doit être résolu ou caractérisé dans l’environnement de validation avant de déclarer un nettoyage validé. Ne pas masquer arbitrairement cette erreur pour obtenir un statut vert.

## Économie de tokens : attentes et mesure

Le gain le plus plausible vient de la lecture de moins de documents contradictoires, de résultats de recherche mieux ciblés et d’une modification circonscrite à une responsabilité. Les suppressions de binaires agiront surtout sur disque, checkout et import. Un renommage massif consommera au contraire des tokens de migration et de validation avant de rapporter quoi que ce soit.

Aucun pourcentage d’économie n’est démontré par cet audit. Pour le mesurer, comparer plusieurs tâches similaires avant/après, avec même modèle et mêmes critères d’acceptation : fichiers et lignes lus, nombre de recherches, volume de sorties renvoyées, temps jusqu’au premier changement correct, validations et tokens si disponibles. Séparer aussi les tokens servis depuis un cache des tokens réellement nouveaux.

Un point d’entrée de 50 à 80 lignes remplacerait les 222 lignes actuelles lors de la prise de contexte générale ; il ne réduit pas d’autant le coût total d’une tâche et ne dispense pas de lire les contrats concernés.

## Vérifications exécutées et limites

| Commande / contrôle | Résultat |
|---|---|
| `git status --short`, `git rev-parse HEAD`, `git ls-files -z` | État initial propre ; référence et inventaire établis |
| Inventaire Python via runtime Codex, SHA-256 des candidats > 1 Mo | Mesures et groupes de doublons enregistrés |
| `./dev.ps1 doctor` | Réussi : Godot `4.7.1.stable.official.a13da4feb`, GUT 9.7.1, formatter et workbench présents ; aucun import certifié |
| `./dev.ps1 context cards` | 27 résultats, non tronqués |
| `./dev.ps1 context catabase` | 370 résultats, 30 affichés ; biais de classement observé |
| `./dev.ps1 selftest` | Réussi : 11 vérifications du harnais, 17 cas synthétiques de l’analyseur |
| `./dev.ps1 test smoke` | Échec pendant l’import : `ERROR: Failed to read the root certificate store.` ; 0 test, 0 assertion |

L’erreur d’import concerne l’environnement de certificats ; sa cause précise n’a pas été diagnostiquée. Elle ne permet de conclure ni à une régression gameplay ni à la réussite des tests. Suite globale, parcours manuel, export, performances d’import comparées et validation visuelle non exécutés. La CI distante n’a pas été consultée.

Rapports locaux :

- `artifacts/project_audit/2026-09-21/inventory.json` : chemins, tailles, lignes.
- `artifacts/project_audit/2026-09-21/summary.json` : méthode et statistiques.
- `artifacts/project_audit/2026-09-21/duplicates.json` : 40 groupes exacts.
- `artifacts/project_audit/2026-09-21/references.json` : références littérales, couverture limitée décrite plus haut.
- `artifacts/project_audit/2026-09-21/local_sizes.json` : tailles locales.
- `artifacts/dev/20260921-094509-doctor--24f4216d/summary.json`.
- `artifacts/dev/20260921-094551-selftest--6693cc3e/summary.json` et sorties du harnais/analyseur.
- `artifacts/dev/20260921-094610-test-smoke-d7671144/gut-strict-report.json` et logs d’import.

Ces rapports datés ne deviennent pas une preuve de validation après modification du code. Les inventaires volumineux restent hors des lectures de contexte ordinaires.
