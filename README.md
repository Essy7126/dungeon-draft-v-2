# Catabase

[![Godot validation](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/godot-validation.yml/badge.svg)](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/godot-validation.yml)

Tactique roguelite au tour par tour sur grille, développé avec Godot 4.7,
GDScript et des ressources data-driven.

**Catabase** est le nom public et la seule aventure proposée. Le menu principal présente une entrée des Enfers peinte, animée par shader (caméra lente, brume et braseros), avec réduction des animations. La run historique à trois et le scénario d’essai sont mis de côté ; leurs ressources restent conservées pour les laboratoires et tests. Voir [le menu vivant](docs/design/catabase_main_menu_2026-09-10.md).

La priorité actuelle de travail est **Catabase d’Achille**. La [base de reprise du 5 septembre 2026](docs/ai/REPRISE_PROJET_2026-09-05.md) rassemble la direction artistique, les enseignements Dofus, les évolutions présentes dans le code et le prochain axe VFX. La présentation du trio ci-dessous décrit uniquement l’archive historique.

La [Cour des Sources](docs/maps/greek_drawn_courtyard_v1.md) est une nouvelle map grecque dessinée, construite à partir de l’observation directe de Dofus et jouable avec les dalles et le combat communs. Ouvrir `tools/labs/greek_drawn_arena/GreekDrawnCourtyard.tscn` puis **F6** dans Godot.


La run historique, retirée du parcours public, utilise une équipe fixe : **Elfe**, **Mage** et **Guerrier**.
Chaque personnage commence avec 6 PA, 3 PM, quatre sorts et une progression par
discipline. Les PA et PM reviennent au début du tour ; un cast réussi accorde
une fois 1 XP à la discipline du sort, y compris pour un sort multi-cible.

La ressource de production `data/runs/first_run.tres` contient six salles. La
forêt peinte ouvre la run, les salles historiques 2 à 4 conservent leur ordre,
puis viennent la caldeira et la station orbitale finale. Les trois maps peintes
utilisent le moteur commun `GridData`/`Pathfinder` avec des layouts explicites ;
aucune collision n'est dérivée de leurs pixels.

## Sélection de personnage

Le menu ouvre désormais le [nouvel écran de sélection](docs/design/character_selection_2026-09-05.md) : aperçu du personnage, orientations, animations, statistiques et capacités réelles. Seules les deux apparences d’Achille sont proposées ; elles lancent la même aventure Catabase en solo. Le refuge reste accessible depuis cet écran.

Pour le voir directement, ouvrir `ui/selection/CharacterSelectionScreen.tscn` et lancer **F6** dans Godot.

## Catabase : chemin et build recomposable

Le parcours public suit **Nouvelle partie → sélection d’Achille → cinématique →
[Seuil des Ombres](docs/maps/underworld_threshold_2026-09-10.md) → run**. Dans cette
entrée jouable, on peut marcher entre les trois statues et lire leurs souvenirs ;
franchir la porte commence l’aventure. La reprise rejoint directement la sauvegarde existante.

Le premier combat propose quatre sorts fixes, puis le kit se construit en cours
de run. Le parcours à embranchements comprend environ quinze combats et cinq haltes.
Dix nouvelles arènes complètent les cinq historiques ; les haltes proposent des
zones de commerce, de récupération, de lore et de découverte de branches.

La carte sur parchemin s'ouvre aussi pendant le combat avec son icône à côté de
l'inventaire ou la touche **C**. Le kit se recompose entre les rencontres.
La [référence V3](docs/design/achilles/catabase_run_recomposable_v3.md), les
[doctrines et équipements](docs/design/achilles/catabase_build_doctrines_equipment.md),
la [pipeline des maps](docs/maps/catabase_expansion_v1.md) et les
[commandes de validation](tests/expedition/README.md) décrivent le contenu et ses limites.

L'[habillage peint Meshy](docs/design/achilles/catabase_meshy_ui_v1.md) complète les
sorts, équipements, marqueurs et menus. L'inventaire conserve ses actions visibles,
les kits de quatre à six sorts tiennent dans le HUD, et les retours visuels au clic
respectent l'option de réduction des animations.

Le bouton **Explorer les maîtrises** ouvre le [grimoire des sorts](docs/design/spell_codex_2026-09-05.md) du héros et du sort sélectionnés : recherche, filtre des choix prêts, arbre et fiche détaillée. Le même écran reste accessible depuis le HUD pendant la run.

## Lancer les tests

L'[atelier de sprites](tools/sprite_workshop/README.md) compare les clips avec
leurs références, permet de remplacer les dessins, régler les poses et exporter
une revue traçable. Ouvrir `tools/sprite_workshop/SpriteWorkshop.tscn` puis **F6**,
ou lancer `./tools/sprite_workshop/workshop.ps1 open`.

Le [dossier Spine et sa fiche de reprise locale](docs/spine/README.md) rassemble
les recherches, connecteurs MCP, références de mouvement et prochains essais.
Lire cette fiche pour reprendre le travail d'animation dans une autre tâche.

L'[atelier des haltes peintes](tools/halt_workshop/README.md) prépare des maps dans
une même direction artistique avec navigation, eau, feu et atmosphère paramétrés.
Son mode **Haltes peintes** est intégré au Studio avec plan spatial, calibration visuelle et essai de la copie de travail. Le sanctuaire émeraude et la forge sèche partagent les interactions de Catabase à l’étape VIII. Le sanctuaire est aussi jouable en visite isolée dans `hub/painted_halt/LivingHalt.tscn`
(**F6**) ou avec `./tools/halt_workshop/halt.ps1 open`.

Le [pilote Atelier du Bronze](docs/maps/bronze_workshop_pilot_2026-09-10.md) teste
la création de map depuis une maquette Blender métrique, avec proportions d’Achille,
peinture guidée et calques Krita. Ouvrir `tools/labs/bronze_workshop_pilot/BronzeWorkshopPilot.tscn`
puis **F6** pour visiter ce petit atelier.

Le [lanceur de développement](tools/dev/README.md) regroupe diagnostic, tests,
inspection des ressources, formatage et captures avec des rapports compacts :
`./dev.ps1 help` (PowerShell 7.2+). La version moteur de référence est Godot 4.7.1.

Les tests unitaires utilisent [GUT](https://github.com/bitwes/Gut)
(installé dans `addons/gut/`, tests dans `test/unit/`).

Dans l'éditeur : activer le plugin GUT puis utiliser le panneau **GUT**.

En ligne de commande (headless) :

```bash
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit -ginclude_subdirs -gprefix=test_ -gexit
```

La CI bloquante (`.github/workflows/godot-validation.yml`) s’exécute sur chaque
push et pull request. Elle vérifie l’import Godot, les contrats explicites des
éditeurs actuels, la suite GUT globale avec son allowlist historique, la
portabilité des chemins du code des éditeurs audités, l’absence de mutation du
worktree par la suite GUT globale et les smokes Terrain/Rencontres/Objets. Le
workflow historique `.github/workflows/ci.yml` reste uniquement lançable à la
demande.
