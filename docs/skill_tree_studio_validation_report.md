# Rapport de validation — Studio des compétences

Date : 5 août 2026  
Cible : Godot 4.7 stable, GDScript

## Données de production auditées

- 3 personnages jouables : Elfe, Mage et Guerrier.
- 12 disciplines et 12 sorts racines.
- 216 améliorations, soit 228 éléments en comptant les racines.
- 5 rangs par discipline, seuils `0 / 5 / 12 / 21 / 30`.
- Topologie `0 / 2 / 4 / 8 / 4` et 16 configurations finales par discipline.
- 11 disciplines monolithiques et une discipline Archer à dépendances externes.

L’autorité runtime identifiée est `SkillTreeResolver`; l’état de progression est porté
par `DisciplineProgressState` et `CharacterRunState`.

## Contrôles réalisés

- Baseline ciblée avant implémentation : 5 tests, 4 488 assertions réussies dans
  `test_skill_tree_complete_contract.gd`.
- Import éditeur Godot 4.7 après intégration initiale : plugin compilé sans erreur.
- Vérification statique `git diff --check` : aucune erreur d’espace ou de patch.
- Recherche des traces de développement : aucun `print`, `TODO` ou `FIXME` ajouté au
  module.
- Instanciation hors écran initiale : elle a permis d’identifier puis corriger le
  parcours excessif des Resources ennemies et les ports GraphEdit du rang 2.

Les avertissements observés pendant le chargement de l’éditeur concernent des assets
ennemis et un ancien script `arena_prop_preview.gd` absent ; ils préexistent au module
et ne sont pas référencés par le Studio des compétences.

## Tests ajoutés

`test/unit/test_skill_tree_studio.gd` couvre :

- la découverte limitée aux trois héros ;
- l’isolation de la working copy ;
- l’état modifié et Undo/Redo ;
- la validation du profil de production ;
- les seize configurations et la simulation runtime ;
- la création atomique d’une discipline et de son sort ;
- l’instanciation des panneaux et le chargement d’un vrai graphe.

## État du dernier passage automatisé

Le passage GUT final ajouté pour ce module n’a pas pu être relancé dans la session Codex
après les dernières améliorations : l’environnement a refusé une nouvelle exécution
externe pour limite d’usage. Cette limitation ne provient ni de Godot ni des tests.

Commande de reprise :

```powershell
& "C:\Users\jerem\OneDrive\Bureau\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" `
  --headless --path . -s res://addons/gut/gut_cmdln.gd `
  -gdir res://docs -gtest res://test/unit/test_skill_tree_studio.gd -gexit
```

Après ce test ciblé, relancer `test_skill_tree_complete_contract.gd`, puis la suite de
non-régression du Dungeon Draft Studio. Les captures aux résolutions 1280×720,
1920×1080 et 2560×1440 restent également à produire dans un environnement pouvant
ouvrir et rendre la fenêtre. Le lanceur reproductible est
`addons/dungeon_draft_arena_studio/skill_tree/test/SkillTreeStudioCaptureRunner.tscn` ;
il écrit les PNG et `capture_metrics.json` sous
`artifacts/skill_tree_studio/screenshots/`.
