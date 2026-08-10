# Achilles 2D POC

Scene de test isolée : `res://tools/achilles_2d_poc/Achilles2DPOC.tscn`.

## Contrôles

- Clic gauche sur une case marchable : déplacement réel par `GridData`,
  `Pathfinder` et `IsoGridView`.
- `A`, `Espace` ou le bouton **Attack** : joue `attack_SE` puis revient
  automatiquement à `idle_SE`.
- Toute direction autre que `SE` produit un avertissement et utilise le fallback
  explicite `SE`. Aucun `flip_h` n'est employé.

## Audit source

Les trois PNG sources sont intacts, en RGBA, organisés en grille régulière 6×6,
sans frame vide ni doublon strict.

| Animation | Spritesheet | Cellule | Frames source | Frames retenues | Marges internes L/T/R/B |
| --- | --- | --- | ---: | ---: | --- |
| Idle | 1608×3672 | 268×612 | 36 | 12 (`0,3,…,33`) | 1–12 / 1–18 / 2–17 / 8 |
| Walk | 1896×4176 | 316×696 | 36 | 18 (`0,2,…,34`) | 22–46 / 8–55 / 1–25 / 1–91 |
| Attack | 2688×4032 | 448×672 | 36 | 18 (`0,2,…,34`) | 0–112 / 0–136 / 10–65 / 42–43 |

Les bas opaques détectés sont `y=603` pour Idle, `y=604–694` pour Walk et
`y=628–629` pour Attack. Walk nécessitait donc une normalisation verticale :
chaque cellule complète conserve son inscription horizontale, sans recentrage
indépendant sur la bounding box, tandis que son contact opaque inférieur est
aligné sur la ligne de pieds commune.

Les frames dérivées font 128×160 px. Leur ancre source commune est `(64, 144)`
et l'offset du `AnimatedSprite2D` la ramène à l'origine `(0, 0)` du
`AchillesVisual2D`. Le paramètre Godot unique `visual_scale` vaut `1.0`.

Le détail machine complet est conservé dans
`res://assets/characters/Achilles/processed/source_audit.json`.

## Animation

| Nom Godot | Frames | FPS | Boucle |
| --- | ---: | ---: | --- |
| `idle_SE` | 12 | 9 | oui |
| `walk_SE` | 18 | 10 | oui |
| `attack_SE` | 18 | 12 | non |

Les textures dérivées utilisent une compression lossless, sans mipmaps, et le
sprite utilise un filtrage nearest à l'échelle 1:1.

## Régénération

1. Exécuter `build_achilles_frames.gd` pour reconstruire les PNG normalisés et
   `source_audit.json`.
2. Laisser l'éditeur importer les PNG.
3. Exécuter `build_achilles_sprite_frames.gd` pour reconstruire
   `achilles_sprite_frames.tres`.

Le mode automatisé `-- --capture-achilles` teste Idle → Walk → Idle puis
Idle → Attack → Idle, écrit les captures dans
`res://artifacts/achilles_2d_poc/` et termine avec
`ACHILLES_2D_POC_VALIDATION_OK` si les transitions, la position d'attaque et le
Y-sort sont conformes.

## Limite visuelle connue

La feuille Attack fournie est plus frontale que les feuilles Idle et Walk,
visuellement orientées SE. Le POC la nomme `attack_SE` comme demandé, mais une
future génération Ludo devra homogénéiser la caméra et la pose entre les trois
exports avant de généraliser le pipeline aux autres directions.

Ce POC n'est branché ni au roster, ni à la run, ni aux statistiques, ni au
combat de production.
