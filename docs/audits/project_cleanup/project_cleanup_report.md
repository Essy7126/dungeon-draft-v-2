# Dungeon Draft — Rapport de nettoyage complet

## 1. Snapshot audité

- Branche initiale : `main`.
- HEAD initial : `f9ae5bc81d4dfb1a356c3779367957cca7e79d11`.
- État Git initial : propre; aucun fichier modifié, non suivi ou staged.
- Sous-modules / Git LFS : aucun.
- Version déclarée : Godot 4.7 / Forward Plus; validation avec `4.7.stable.official.5b4e0cb0f`.
- Date : 2 août 2026, fuseau Europe/Paris.
- Garde-fou Git : branche locale `refactor/project-clean-slate` et tag local `archive/pre-project-cleanup-2026-08-02` créés sur le HEAD initial.

## 2. Contrat cible appliqué

- Personnages : équipe fixe Elfe, Mage, Guerrier, chacun à 6 PA, 3 PM et quatre sorts de départ.
- Ressources : `UnitData`, scènes visuelles et previews consommées, modèles, animations, portraits, icônes, HUD et modificateurs nécessaires conservés.
- Sorts : casts payés uniquement en PA; attaque de base et `attack_power` conservés par prudence après audit.
- Progression : `CharacterRunState`, `SpellLoadoutState`, disciplines, arbres et `SkillTreeResolver` conservés; un cast réussi donne une XP à sa discipline, une seule fois même en multi-cible; résolution post-combat et persistance inter-salles conservées.
- Run : une ressource `res://data/runs/first_run.tres`; quatre salles existantes réellement utilisables sur la cible produit de cinq, sans cinquième salle inventée.
- Ennemis : squelette de mêlée, squelette à distance et chef squelette, avec leurs scènes, modèles, animations, IA et tests.
- Systèmes conservés : statistiques, résolution centrale des dégâts, grille, pathfinding, terrain, poussées/collisions, tours, transitions, progression et UI de combat active.
- Systèmes abandonnés : énergie, Ferveur, Éveil, Empreinte énergétique, draft historique, anciens héros/ennemis/boss, récompenses, reliques, équipements, événements et graphe de run obsolètes.

## 3. Méthode

- Inventaire récursif préalable de tous les fichiers et dossiers, tailles, extensions, catégories, fichiers volumineux et état Git.
- Construction des racines depuis `project.godot`, les autoloads, scènes, ressources, scripts, UID, noms de classes, tests et chemins construits.
- Classification individuelle `KEEP`, `MIGRATE`, `DELETE`, `GENERATED` ou `UNKNOWN` dans `manifest_before.json` avant toute suppression.
- Suppressions par lots ciblés et récupérables depuis Git; aucune suppression aveugle, aucun `git clean`, reset, stash, commit ou push.
- Garde-fou automatique final : toute entrée absente classée `UNKNOWN` fait échouer la génération des manifestes.
- Validations par recherche de références, import Godot, démarrage headless, GUT complet et contrôle du diff.

## 4. État avant nettoyage

- Fichiers : 4 121.
- Dossiers : 368.
- Taille : 1 545 150 446 octets.
- Catégories : 1 997 generated, 645 assets, 432 resources, 392 scripts, 149 tests, 134 scènes, 41 documents et 331 autres fichiers.
- Le dépôt contenait 2 120 entrées `GENERATED`, 791 `DELETE`, 133 `MIGRATE`, 906 `KEEP` et les éléments non prouvés laissés `UNKNOWN`.
- Systèmes legacy présents : énergie/Ferveur/Éveil, traits énergétiques, draft, récompenses/reliques/équipements/événements, anciennes classes, familles gobelines, boss mythologiques, ancienne Bible MVP, anciennes runs/maps et volumes importants d'artefacts visuels/imports.

## 5. Fichiers conservés

- Racines exécutables : `project.godot`, `ui/TitreEcran.tscn`, autoloads `DebugLogger`, `EventBus`, `CombatLogger`, `DebugOverlay`, `GameManager`, `AudioManager` et `VFXManager`.
- Production : `battle/`, `core/`, `units/`, `data/characters/`, les trois `data/units/alliés/`, les trois `data/units/ennemie/`, les quatre salles `first_run_room_*`, leurs maps et `first_run.tres`.
- Présentation : menu, écran de présentation fixe, HUD actif, progression, transitions et résultats encore consommés.
- Assets : uniquement les modèles, textures, animations, icônes, portraits, sons, VFX et environnements atteignables par la production ou les tests conservés.
- Tests : suite GUT cohérente avec la cible et tests d'intégration non générés. Les documents historiques classés `UNKNOWN` ont été conservés par le garde-fou.
- La liste et les justifications individuelles figurent dans `manifest_after.json` et les racines détaillées dans `dependency_roots.md`.

## 6. Fichiers supprimés

- Total : 1 874 fichiers, 818 541 261 octets.
- Contenu généré et captures — 1 104 fichiers, 425 064 885 octets : caches/imports, `artifacts/`, `output/`, captures, contact sheets et backups Blender reproductibles; le mapping d'icônes utile a d'abord été migré vers `docs/reference/`.
- Autre contenu orphelin — 346 fichiers, 201 852 527 octets : assets et modèles sans consommateur, dont les anciens imports de chevalier; aucune référence active à migrer.
- Anciens personnages jouables — 101 fichiers, 122 226 533 octets : Gardien, Soigneur autonome, Assassin autonome, Nécromancien, Hoplite et prototypes; les mécaniques génériques consommées ont été conservées dans les systèmes neutres.
- Anciens ennemis et boss — 61 fichiers, 10 919 584 octets : gobelins, Méduse, Perséphone, Colosse et comportements dédiés; l'IA générique et les trois squelettes ont été conservés.
- Draft et pools de contenu — 106 fichiers, 63 923 octets : draft, récompenses, reliques, équipements, événements, malus et nœuds de run sans consommateur; initialisation directe migrée dans `GameManager`.
- Énergie et traits — 83 fichiers, 74 404 octets : types d'énergie, jauge, traits, Ferveur et Éveil; les contrats PA/progression utiles ont été migrés.
- Anciennes salles et runs — 26 fichiers, 100 012 octets : anciennes ressources et branches; quatre contenus utiles migrés vers `first_run_room_*` et `first_run.tres`.
- Tests, outils et documents obsolètes — 47 fichiers, 58 239 393 octets : labs, scènes/captures de revue et scripts liés uniquement au contenu supprimé; les tests de contrats actifs ont été adaptés ou remplacés.
- Chaque chemin supprimé figure dans `deleted_paths.txt`; chaque entrée avait le statut préalable `DELETE`, `GENERATED` ou `MIGRATE`, jamais `UNKNOWN`.
- Les dépendances utiles ont été déplacées ou réécrites avant suppression : mapping d'icônes vers `docs/reference`, salles vers `first_run_room_*`, run vers `first_run.tres`, et logique générique vers les systèmes neutres conservés.

## 7. Dossiers supprimés

- Total : 215 dossiers du manifeste initial ne subsistent plus.
- Liste exhaustive : `deleted_directories.txt` (un chemin `res://` par ligne). Cette annexe fait partie de l'audit afin d'éviter une liste tronquée dans le rapport.
- Familles principales : `artifacts/`, `output/`, `traits/`, anciens `data/energy`, `data/rewards`, `data/relics`, `data/equipment`, `data/events`, `data/boss_malus`, `data/run_nodes`, anciennes classes, anciens ennemis/boss, anciennes maps/runs, captures et outils de revue obsolètes.
- Justification : contenu généré reproductible ou contenu sans consommateur dans les racines du jeu cible. Les parents devenus réellement vides ont été supprimés après vérification.

## 8. Fichiers migrés ou déplacés

- Mapping : `res://artifacts/skill_tree_refined_v2/node_icon_mapping.json` → `res://docs/reference/skill_tree_node_icon_mapping.json`; test de définitions mis à jour.
- Run : anciennes ressources historiques → `res://data/runs/first_run.tres`; présentation d'équipe, GameManager et tests mis à jour.
- Salles : `le_gue.tres`, `terrain_2.tres`, `la_forge.tres`, `elite_brute.tres` → `first_run_room_01.tres`, `first_run_room_02.tres`, `first_run_room_03.tres`, `first_run_room_04_boss.tres`; seule la nouvelle run les référence.
- Les migrations fonctionnelles de `Unit`, `Spell`, `SpellCaster`, `EventBus`, `StatusData`, `RunData` et du Guerrier ont conservé leurs chemins pour limiter le risque UID.
- Le détail ancien/nouveau, la raison et les consommateurs mis à jour figurent dans `migrated_paths.md`.

## 9. Nettoyage fonctionnel

- Énergie : jauge, ressources d'école, champs runtime, coûts, signaux, tooltips, UI, réactions, Éveil et effets de terrain supprimés du gameplay actif.
- Draft : écrans et logique de choix héros/école/trait supprimés; `GameManager.start_run()` crée directement Elfe, Mage et Guerrier avec leurs états persistants.
- Personnages : seuls les trois héros cibles et leur contenu consommé restent; le Guerrier expose désormais quatre sorts et trois disciplines existantes.
- Salles/runs : une run de production, quatre salles existantes migrées; anciennes routes, Bible MVP, cartes et salles sans consommateur supprimées.
- Récompenses, reliques, équipements, événements : anciens pools et systèmes retirés; aucun ancien pool incohérent ne pilote la run cible.
- Boss : boss mythologiques et comportements exclusivement associés supprimés; chef squelette conservé.
- UI : jauges/indicateurs énergétiques, écrans de draft/récompense et previews obsolètes retirés; menu, présentation fixe, HUD, progression et transitions conservés.

## 10. Corrections techniques

- PA/PM : `reset_combat_resources` restaure les deux ressources et remet à zéro les modificateurs « prochain tour ».
- PV maximum : une baisse de `max_hp` borne immédiatement `current_hp`; une hausse ne soigne pas implicitement.
- Critiques : chance finale bornée à `[0, 1]`; `Spell.crit_multiplier`, sans consommateur, supprimé.
- Dégâts/boucliers : `damage_dealt` représente le coup résolu après mitigation avant absorption; `health_damage_taken` représente la perte réelle de PV; les observateurs ont été migrés.
- Statuts : identifiant stable ajouté; application initiale et rafraîchissement sont séparés; un refresh n'émet plus un faux événement de nouveau statut.
- Dégâts périodiques : type, élément, défense ignorée et esquive autorisée sont portés par la donnée; Brûlure, Poison et Saignement conservent leurs valeurs et sémantiques antérieures.
- Progression : XP une fois par cast; modifier « Lame venimeuse » reconnecté à son nœud; application dans les salles suivantes validée.
- Force : composante énergétique retirée; stat conservée pour les poussées/collisions encore actives.
- Attaque de base : chemin encore présent dans le HUD/combat; `attack_power` conservé et signalé comme décision de design à confirmer.

## 11. État des trois personnages

- Elfe — `res://data/units/alliés/elfe.tres`; Tir précis, Frappe sournoise, Boule de feu et Soin sylvestre; disciplines Archer, Assassin, Mage et Soigneur; scènes combat/preview actives; progression et visuels couverts par GUT. Plusieurs branches au-delà des données présentes restent volontairement non inventées.
- Mage — `res://data/units/alliés/mage.tres`; Boule de feu, Mur de glace, Orage et Onde sismique; disciplines Feu, Glace, Foudre et Terre; scènes combat/preview actives; lifecycle, contrat, éléments, profil visuel et progression couverts. Les disciplines restent au rang réellement défini par les données.
- Guerrier — `res://data/units/alliés/Guerrier.tres`; Bourrade, Marque de guerre, Exécution de guerre et Piétinement; disciplines Briseur, Bourreau et Saccageur; scènes combat/preview actives; construction, lifecycle, HUD, progression et intégration couverts. Briseur et Saccageur restent partiels; aucun rang 3 n'a été inventé.

## 12. État de la première run

- Ressource : `res://data/runs/first_run.tres`.
- Salles : quatre ressources de production, `first_run_room_01.tres` à `first_run_room_04_boss.tres`, sur une cible de cinq.
- Ennemis : uniquement squelette de mêlée, squelette à distance et chef squelette. La salle 4 est explicitement la salle de chef; la salle 2 conserve aussi le chef déjà présent dans le contenu migré, sans modification d'équilibrage.
- Boss : chef squelette avec sa ressource, sa scène, ses animations, son sort et ses tests.
- Transitions : orchestration asynchrone et persistance des trois héros testées; aucune référence manquante.
- Parcours : menu et présentation fixe démarrent; construction de run, combats/salles et transitions sont couverts par la suite automatique. Il n'existe pas de test E2E autonome parcourant les quatre combats jusqu'au résultat final.
- Limite produit : la cinquième salle n'est pas définie; aucune ancienne salle n'a été gardée ni aucune nouvelle salle fabriquée pour masquer ce manque.

## 13. Tests exécutés

- Caractérisation préalable : 420 tests, 412 succès, 8 échecs préexistants, 6 730/6 752 assertions; ligne de commande complète et durée non persistées, limite documentée.
- GUT final : commande exacte dans `test_results.md`; code 0; 39 scripts, 335 tests, 335 succès, 0 échec, 29 097 assertions; 22,318 s GUT / 26,7 s murales. Échecs préexistants dans la suite conservée : 0; nouveaux échecs : 0.
- Import final : `Godot_v4.7-stable_win64_console.exe --headless --editor --quit --path <repo>`; code 0; 6,9 s; aucune ressource manquante ni erreur de parsing.
- Scène principale : `Godot_v4.7-stable_win64_console.exe --headless --path <repo> --quit-after 5`; code 0; 1,8 s; menu chargé; avertissement de fuite à l'arrêt forcé.
- Références : scanner local, `MISSING 0` après exclusion de cinq chemins volontairement inexistants dans des tests négatifs.
- `git diff --check` : succès, code 0, aucune anomalie.
- Toutes les commandes exactes disponibles, résultats, durées et avertissements figurent dans `test_results.md`.

## 14. Recherche des vestiges legacy

Recherche insensible à la casse sur les sources restantes, hors `.git/`, `.godot/`, imports/binaires et le présent dossier d'audit pour éviter l'auto-comptage :

| Mot-clé | Occurrences | Chemins restants | Justification |
| --- | ---: | --- | --- |
| `energy` | 72 | `addons/godot_ai_workbench/commands/workbench_domain_world_ops.gd`<br>`addons/godot_ai_workbench/commands/workbench_resource_ops.gd`<br>`characters/elf/ElfIsoUnitView.tscn`<br>`characters/enemies/skeleton/SkeletonIsoUnitView.tscn`<br>`characters/enemies/skeleton_chief/SkeletonChiefIsoUnitView.tscn`<br>`characters/mage/MageIsoUnitView.tscn`<br>`characters/warrior/WarriorIsoUnitView.tscn`<br>`docs/audits/elf_progression_reset_inventory.md`<br>`test/unit/test_fixed_trio_mage_contract.gd`<br>`test/unit/test_skill_tree_resolver.gd`<br>`tests/characters/elf/ElfAnimationValidation.tscn`<br>`tests/characters/elf/ElfInGamePreview.tscn`<br>`tests/characters/elf/ElfVisualComponentValidation.tscn`<br>`ui/characters/CharacterPreview3D.tscn`<br>`ui/TitreEcran.tscn` | Propriétés Godot de lumière `light_energy`/`ambient_light_energy` et support générique de l'addon : faux positifs; deux assertions/test names prouvent l'absence de gameplay énergétique; audit historique volontaire. |
| `fervor` | 6 | `docs/audits/elf_progression_reset_inventory.md` | Documentation historique volontaire. |
| `ferveur` | 12 | `characters/enemies/skeleton_chief/SKELETON_CHIEF_INTEGRATION.md`<br>`docs/audits/elf_progression_reset_inventory.md` | Contrat historique affirmant explicitement l'absence de Ferveur; audit historique volontaire. |
| `awakening` | 4 | `docs/audits/elf_progression_reset_inventory.md` | Documentation historique volontaire. |
| `eveil` | 0 | — | Aucun vestige. |
| `éveil` | 11 | `docs/audits/elf_progression_reset_inventory.md` | Documentation historique volontaire. |
| `charge_threshold` | 0 | — | Aucun vestige. |
| `signature` | 29 | `addons/gut/method_maker.gd`<br>`addons/gut/test.gd`<br>`battle/impact_juice.gd`<br>`core/event_bus.gd`<br>`docs/audits/elf_progression_reset_inventory.md`<br>`tests/characters/elf/elf_visual_component_validation.gd`<br>`tools/ui/prepare_character_hud_assets.py`<br>`tools/ui/prepare_dark_menu_assets.py` | Signatures de méthodes, PNG et empreintes visuelles, ou adjectif « moment signature » : faux positifs sans ressource spéciale; audit historique volontaire. |
| `imprint` | 4 | `docs/audits/elf_progression_reset_inventory.md` | Documentation historique volontaire. |
| `empreinte` | 10 | `characters/enemies/skeleton_chief/SKELETON_CHIEF_BLENDER_AUDIT.md`<br>`docs/audits/elf_progression_reset_inventory.md` | Empreinte de fichier/objet Blender : faux positif; audit historique volontaire. |
| `EnergyGauge` | 8 | `docs/audits/elf_progression_reset_inventory.md` | Documentation historique volontaire. |
| `EnergyTypeData` | 9 | `docs/audits/elf_progression_reset_inventory.md` | Documentation historique volontaire. |
| `Gardien` | 8 | `docs/audits/elf_progression_reset_inventory.md`<br>`test/unit/test_fixed_trio_mage_contract.gd`<br>`tests/characters/elf/ELF_SALLE1_GAMEPLAY_INTEGRATION.md` | Audit/archive historique; test négatif vérifiant l'absence de la ressource; bannière signalant que l'ancien scénario n'est plus la production. |
| `healer` | 57 | `asset/ui/character_hud/generated/v2/hud_v2_manifest.json`<br>`core/enemy_ai.gd`<br>`data/characters/elf/disciplines/healer.tres`<br>`data/characters/elf/spells/sylvan_heal.tres`<br>`data/characters/elf/upgrades/abundant_sap.tres`<br>`data/characters/elf/upgrades/protective_bark.tres`<br>`data/ui/elf_hud_theme.tres`<br>`data/ui/skill_tree_icon_catalog_refined.tres`<br>`data/unit_data.gd`<br>`data/units/alliés/elfe.tres`<br>`docs/audits/elf_progression_reset_inventory.md`<br>`docs/audits/skill_tree_legacy_assets_audit.md`<br>`docs/reference/skill_tree_node_icon_mapping.json`<br>`test/unit/test_character_progression_foundation.gd`<br>`test/unit/test_elf_archer_skill_tree.gd`<br>`test/unit/test_elf_multiple_progression_queue.gd`<br>`test/unit/test_elf_rank_two_disciplines.gd`<br>`test/unit/test_progression_lifecycle.gd`<br>`tools/ui/prepare_character_hud_v2_assets.py`<br>`ui/progression/ASSET_REQUIREMENTS.md`<br>`ui/progression/components/skill_tree_effect_glyph.gd` | Discipline Soigneur active de l'Elfe, assets/tests associés et comportement IA générique; ne désigne pas l'ancien héros autonome. Documents historiques signalés. |
| `Assassin` | 79 | `asset/ui/character_hud/generated/v2/hud_v2_manifest.json`<br>`asset/ui/dungeon_draft/arbre_compétences/preview.html`<br>`data/characters/elf/disciplines/assassin.tres`<br>`data/characters/elf/spells/sneak_strike.tres`<br>`data/characters/elf/upgrades/backstab.tres`<br>`data/characters/elf/upgrades/venomous_blade.tres`<br>`data/ui/elf_hud_theme.tres`<br>`data/ui/skill_tree_icon_catalog_refined.tres`<br>`data/units/alliés/elfe.tres`<br>`docs/audits/elf_progression_reset_inventory.md`<br>`docs/audits/skill_tree_legacy_assets_audit.md`<br>`docs/audits/skill_tree_refined_ui_audit.md`<br>`docs/reference/skill_tree_node_icon_mapping.json`<br>`test/unit/test_character_progression_foundation.gd`<br>`test/unit/test_elf_archer_skill_tree.gd`<br>`test/unit/test_elf_multiple_progression_queue.gd`<br>`test/unit/test_elf_rank_two_disciplines.gd`<br>`test/unit/test_progression_lifecycle.gd`<br>`tools/ui/prepare_character_hud_v2_assets.py`<br>`ui/progression/ASSET_REQUIREMENTS.md`<br>`ui/progression/components/skill_tree_effect_glyph.gd` | Discipline Assassin active de l'Elfe, assets/tests associés; ne désigne pas l'ancien héros autonome. Documents historiques signalés. |
| `Necromant` | 2 | `docs/audits/elf_progression_reset_inventory.md` | Documentation historique volontaire. |
| `Hoplite` | 4 | `docs/audits/elf_progression_reset_inventory.md`<br>`docs/audits/skill_tree_refined_ui_audit.md` | Documentation historique volontaire. |
| `Meduse` | 3 | `docs/audits/elf_progression_reset_inventory.md` | Documentation historique volontaire. |
| `Méduse` | 0 | — | Aucun vestige hors audit de nettoyage. |
| `RunDraftScreen` | 7 | `docs/audits/elf_progression_reset_inventory.md` | Documentation historique volontaire. |

- Les occurrences dans `manifest_before.json`, `candidate_deletions.md`, `deleted_paths.txt`, `remaining_unknowns.md` et ce rapport sont des preuves d'audit volontaires.
- Les occurrences dans des documents d'audit/intégration conservés `UNKNOWN` sont de la documentation historique volontaire.
- Les identifiants de discipline Elfe `assassin` et `healer` sont actifs à l'intérieur de l'Elfe; ils ne désignent pas les anciens héros autonomes supprimés.
- Le terme `force` restant relève de la poussée/collision active, pas de l'énergie.
- Toute occurrence de chemin absent dans un test `FileAccess.file_exists(...) == false` est un test négatif volontaire.
- Aucun vestige recherché n'agit sur le gameplay énergétique actif; le scanner de références ne trouve aucun chemin de production manquant.

## 15. Réduction obtenue

- Fichiers : 4 121 → 2 284, soit 44,58 % de réduction nette. Les 1 874 suppressions sont partiellement compensées par les fichiers de run, tests et preuves d'audit créés.
- Dossiers : 368 → 157, soit 57,34 % de réduction nette; 215 dossiers initiaux supprimés et 4 nouveaux conteneurs utiles créés.
- Taille : 1 545 150 446 → 734 278 857 octets, soit 52,48 % de réduction nette. La somme exacte des fichiers supprimés est 818 541 261 octets; les nouveaux fichiers/migrations expliquent l'écart avec la réduction nette de 810 871 589 octets.
- Scènes : 134 → 112.
- Ressources : 432 → 155.
- Tests : 149 fichiers d'inventaire → 61; suite GUT 420 → 335 cas, tous verts après retrait des tests exclusivement legacy et migration des contrats actifs.
- Les caches `.godot` reproductibles sont classés `GENERATED`; leur présence après import n'est pas comptée comme contenu source conservé dans la réduction logique, mais reste visible dans les manifestes physiques.

## 16. Risques et inconnues

- `UNKNOWN` restants : 514 fichiers, tous conservés; liste exhaustive et raisons dans `remaining_unknowns.md`.
- Décision produit : attaque de base et `attack_power` sont encore consommés; leur retrait éventuel nécessite une décision de game design.
- Contenu manquant : cinquième salle de la première run non définie.
- Progression : arbres Guerrier Briseur/Saccageur partiels et autres limites de contenu existantes; aucun nœud inventé.
- Validation : pas de test E2E unique jouant manuellement la run entière; couverture automatique par contrats de construction, salles, combat, progression et transitions.
- Arrêt headless : deux instances ObjectDB et une ressource signalées encore en usage lors de `--quit-after 5`.
- Documents historiques et contenu hub non relié à la cible ont été conservés lorsque leur statut initial n'autorisait pas une suppression sûre.

## 17. État Git final

- Branche : `refactor/project-clean-slate`.
- HEAD : `f9ae5bc81d4dfb1a356c3779367957cca7e79d11` (aucun nouveau commit).
- `git status --short` : worktree volontairement modifié et non suivi pour revue humaine; relevé exact final incorporé dans les preuves de clôture.
- Fichiers modifiés : 105.
- Fichiers supprimés suivis : 1 273.
- Fichiers non suivis : 37.
- Fichiers staged : 0.
- Aucun commit, push, force-push, rebase, stash, reset global ou nettoyage Git aveugle n'a été effectué. Le tag de sécurité est local.

## 18. Verdict

`PROJECT_CLEANUP_COMPLETE_WITH_WARNINGS`

Le nettoyage structurel et fonctionnel demandé est appliqué, les références actives sont résolues, l'import et le menu passent, et les 335 tests conservés sont verts. Les avertissements sont explicites et ne sont pas masqués : la cinquième salle n'existe pas encore, l'attaque de base reste une décision produit, les arbres Guerrier sont partiels, il n'existe pas de test E2E intégral de la run, des documents/contenus `UNKNOWN` ont été conservés, et l'arrêt headless forcé remonte de petites fuites ObjectDB.
