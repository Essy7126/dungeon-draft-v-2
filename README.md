# Dungeon Draft v2

[![Godot validation](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/godot-validation.yml/badge.svg)](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/godot-validation.yml)

Tactique roguelite au tour par tour sur grille, développé avec Godot 4.7,
GDScript et des ressources data-driven.

La première run utilise une équipe fixe : **Elfe**, **Mage** et **Guerrier**.
Chaque personnage commence avec 6 PA, 3 PM, quatre sorts et une progression par
discipline. Les PA et PM reviennent au début du tour ; un cast réussi accorde
une fois 1 XP à la discipline du sort, y compris pour un sort multi-cible.

La ressource de production `data/runs/first_run.tres` contient six salles. La
forêt peinte ouvre la run, les salles historiques 2 à 4 conservent leur ordre,
puis viennent la caldeira et la station orbitale finale. Les trois maps peintes
utilisent le moteur commun `GridData`/`Pathfinder` avec des layouts explicites ;
aucune collision n'est dérivée de leurs pixels.

## Lancer les tests

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
