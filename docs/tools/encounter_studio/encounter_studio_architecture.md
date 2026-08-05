# Architecture du Studio de rencontres

## Intégration retenue

Le Map Studio local sous `res://addons/dungeon_draft_arena_studio/` était fonctionnel et couvert par ses tests. Le cas A a donc été retenu : un seul plugin « Dungeon Draft Studio » et un seul écran principal, avec deux onglets `ARÈNES` et `RENCONTRES`. Le `plugin.cfg` existant est conservé à son emplacement; l’ancien `res://tools/arena_map_editor/` n’est pas modifié.

`DungeonDraftStudioMain` compose `ArenaStudioMain` et `EncounterStudioMain`. Le plugin ajoute ce Control au viewport principal public de l’éditeur, le masque/affiche via `_make_visible`, conserve son état via `_get_state`/`_set_state`, n’écrit rien implicitement dans `_apply_changes` ou `_save_external_data`, puis libère la racine dans `_exit_tree`.

## Couches

```text
UI
├── DungeonDraftStudioMain
├── EncounterStudioMain
└── EncounterMapPreview
        │
Domaine isolé
├── EncounterEditSession
└── StudioValidationMessage
        │
Services purs/testables
├── catalogue / graphe de références / copie / migration
├── validation / comparaison / projection / analyse de seeds
├── sauvegarde / rapport / lancement de test
└── preview (appelle le planificateur runtime)
        │
Services runtime partagés
├── EncounterGridFactory
├── EncounterSeedResolver
├── RunWaveCountResolver
└── RoomRewardProjectionService
        │
Runtime existant
├── GridData / Pathfinder
├── EncounterFormationPlanner
├── EncounterRuntimeState
└── GameManager / Battle
```

Les scripts UI assemblent les contrôles et traduisent les intentions. Les décisions de validité, copie, placement, projection, conflit et sauvegarde sont dans les services appelables en headless.

## Copie de travail et Undo/Redo

À l’ouverture, `EncounterCopyService.copy_run()` copie explicitement Run/Room/Wave/Encounter. Les `UnitData`, textures, scènes et autres ressources externes restent partagées; tableaux et dictionnaires éditables sont indépendants. La relation de partage entre EncounterDefinition est reproduite dans la copie.

Dans l’éditeur, les propriétés passent par `EditorUndoRedoManager` avec l’objet édité comme contexte. Hors éditeur, un `UndoRedo` de repli rend la même UI testable. Les opérations de timeline remplacent le tableau de vagues en une action atomique.

## Asynchronisme

L’analyse multi-seeds est déclenchée explicitement, travaille par lots, rend la main au `SceneTree`, publie sa progression et utilise un identifiant de génération. `cancel()` invalide immédiatement la génération précédente. Aucun recalcul lourd n’est exécuté à chaque frame.

## État et lifecycle

L’état persistant de l’UI contient le chemin de run, les indices salle/vague, la seed, l’onglet de propriétés et l’onglet principal. À la sortie, l’analyse est annulée et le signal du filesystem est déconnecté; les Controls enfants sont libérés avec la racine.

## Choix V1

- GDScript uniquement, sans dépendance ni réseau.
- Pas de format parallèle.
- Pas de score global de difficulté ni de probabilité de victoire.
- Les métriques restent descriptives et les temps restent non estimés faute de télémétrie.
- Les politiques spécialisées du planificateur squelette ne sont pas généricisées artificiellement.

