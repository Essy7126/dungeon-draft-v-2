# Dungeon Draft v2

[![CI](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/ci.yml/badge.svg)](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/ci.yml)

Tactique roguelite (Godot 4.7, GDScript, data-driven) où l'énergie d'un héros
définit son école de jeu : **Rage** (placement), **Foi** (montée en puissance),
**Ombre** (combo), **Nature** (terrain).

Économie d'action : PA entiers (6) + PM (3) + jauge d'école (Ferveur),
dépensée uniquement sur l'Éveil, l'empreinte et les sorts payoff.

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
