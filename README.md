# Catabase

[![Godot validation](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/godot-validation.yml/badge.svg)](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/godot-validation.yml)

Roguelite tactique au tour par tour sur grille, sous **Godot 4.7.1 / GDScript**.
Catabase est l’aventure publique : Achille traverse les Enfers en solo,
avec trois apparences et deux variantes à sauvegardes indépendantes :
**Classique** (équipement et techniques) et **Cartes** (quatre classes et deck).

## Jouer et développer

Ouvrir `project.godot` avec le moteur défini dans
[toolchain.json](tools/dev/toolchain.json), puis **F5**.
Le point d’entrée est `ui/TitreEcran.tscn`.
PowerShell 7.2+ est requis pour le lanceur :

```powershell
./dev.ps1 doctor
./dev.ps1 context catabase -Kind code
./dev.ps1 test cards
./dev.ps1 selftest
```

`doctor` vérifie les outils, pas l’import. `test cards` vérifie les contrats
Cartes ; ce n’est pas une partie complète. La commande historique `test smoke`
ne couvre que deux suites de codex UI. Voir la matrice ci-dessous pour choisir
les validations nécessaires à une modification.

## Références courantes

- [Produit et parcours](docs/current/product.md) : règles et compatibilité.
- [Architecture](docs/current/architecture.md) : responsabilités et points d’entrée.
- [Validation](docs/current/validation.md) : suites, CI et contrôles runtime/visuels.
- [Personnages, maps et contenu historique](docs/current/content.md) : ce qui sert au jeu, aux tests ou aux laboratoires.
- [Commandes de développement](tools/dev/README.md) : options, rapports et outils locaux.

## Éditer et explorer le contenu

Le plugin `addons/dungeon_draft_arena_studio/` est l’atelier principal.
Réutiliser ses services pour l’édition de contenu.
L’[Explorateur de run](tools/run_explorer/README.md) permet de visiter une
destination et d’examiner son décor. Les ateliers de
[sprites](tools/sprite_workshop/README.md) et de
[haltes](tools/halt_workshop/README.md) complètent le Studio.

Les anciennes aventures restent des fixtures ou des laboratoires ; elles ne
sont pas proposées dans le menu public. Les notes datées décrivent un état
historique. L’[ancienne présentation détaillée](docs/archive/project_overview_2026-09-21.md)
conserve les références artistiques et les comptes rendus de production.
Les crédits sont conservés avec les assets, notamment ceux de la
[musique du titre](assets/audio/title/CREDITS.md) et des
[sons de Catabase](assets/audio/catabase/CREDITS.md).
