# Dungeon Draft v2

[![CI](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/ci.yml/badge.svg)](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/ci.yml)

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

La CI (`.github/workflows/ci.yml`) rejoue ces deux étapes sur chaque
push / pull request : import du projet (échec sur erreur de parse),
puis exécution de la suite GUT.
