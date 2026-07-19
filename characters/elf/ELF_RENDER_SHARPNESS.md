# Validation de la netteté de l'elfe

Date de validation : 19 juillet 2026  
Scène testée : vraie salle isométrique, via `ElfSalle1GameplayIntegration.tscn`  
Verdict : `ELF_SHARPNESS_FIXED`

## Diagnostic

Le défaut venait principalement du **cas A** : le rendu natif du `SubViewport` était déjà trop pauvre en détails. Avec une caméra orthographique de taille 16, l'elfe Idle n'occupait que 41 x 54 pixels dans un viewport de 512 x 512, soit `54 / 512 = 10,55 %` de sa hauteur.

Le **cas B** aggravait ensuite le résultat : la `ViewportTexture` de 41 x 54 pixels était agrandie jusqu'à environ 75 x 99 pixels dans la salle, avec un facteur effectif fractionnaire de `1,8241649`. Le filtre hérité était linéaire. Les échelles 2D de `ElfIsoUnitView`, `UnitView`, `YSortedWorld` et `Battle` étaient toutes égales à 1 ; l'agrandissement ne venait donc pas d'une chaîne de parents 2D mal configurée.

La correction consiste à cadrer réellement le modèle dans le rendu 3D, puis à réduire ce rendu détaillé à la taille d'affichage existante. L'elfe n'est plus agrandie à partir d'une source de 54 pixels de haut.

## Pipeline avant correction

| Paramètre | Valeur auditée |
|---|---:|
| `CharacterViewport.size` | 512 x 512 |
| `scaling_3d_scale` | 1,0 |
| `scaling_3d_mode` | bilinéaire, sans upscaling puisque l'échelle vaut 1 |
| `use_taa` | false |
| `screen_space_aa` | disabled |
| `msaa_3d` | MSAA 4X |
| `RenderSprite.texture_filter` | inherit, effectivement linéaire |
| `RenderSprite.scale` | (1, 1) |
| parents 2D | tous à (1, 1) |
| `CharacterPivot.scale` | (1,10 ; 1,10 ; 1,10) |
| `CharacterCamera.size` | 16,0 |
| bbox Idle native | 41 x 54 px |
| ratio de hauteur natif | 10,55 % |
| bbox finale dans la fenêtre | environ 74,79 x 98,50 px |
| redimensionnement source vers écran | x 1,8241649, fractionnaire |
| pixels rendus par frame | 262 144 |

Les captures de référence ont été faites avant toute correction dans la même pose Idle, directement dans le viewport et dans la composition finale. Des crops dédiés ont également été produits.

## Variantes comparées

| Variante | Bbox native Idle | Ratio hauteur | Bbox écran | Filtre | Pixels/frame | FPS moyen / minimum* |
|---|---:|---:|---:|---|---:|---:|
| Avant, 512 x 512 | 41 x 54 | 10,55 % | 74,79 x 98,50 | Linear hérité | 262 144 | 141,52 / 134 |
| 512 x 512 cadré | 313 x 406 | 79,30 % | 75,27 x 97,64 | Linear | 262 144 | 137,36 / 127 |
| 512 x 512 cadré | 313 x 406 | 79,30 % | 75,27 x 97,64 | Nearest | 262 144 | 136,58 / 123 |
| 768 x 768 cadré | 468 x 607 | 79,04 % | 75,03 x 97,32 | Linear | 589 824 | 135,71 / 115 |
| 768 x 512 large, retenu | 298 x 387 | 75,59 % | 75,44 x 97,97 | Linear | 393 216 | 139,49 / 138 |

\* Les FPS sont des échantillons courts sur la même machine et varient avec le démarrage du rendu. Le dernier relevé visible est inférieur d'environ 1,4 % en moyenne au relevé initial, avec un minimum supérieur de 4 FPS. Le test gameplay complet final a mesuré 146,95 FPS de moyenne et 73 FPS minimum pendant toute la séquence Cast/Hit/Death. Le coût déterministe passe de 262 144 à 393 216 pixels par frame, soit +50 %.

Le filtre **Nearest** rend les transitions de pixels plus sèches, mais ajoute des contours crénelés et est moins stable pour un personnage 3D non pixel-art. **Linear** conserve les détails apportés par le cadrage resserré tout en donnant des contours plus réguliers ; il a donc été retenu.

Le test 768 x 768 n'apporte pas d'amélioration visible significative à la taille finale d'environ 98 pixels. Un test 1024 x 1024 n'était donc pas justifié. MSAA 4X ne montre ni crénelage excessif, ni halo gênant ; MSAA 8X n'a pas été adopté. Aucun FXAA, shader de sharpen, mipmap ou upscaler n'a été ajouté.

Le cadrage 512 x 512 à 80 % coupait certaines poses de Cast, Hit, Walk ou Death. Le format final 768 x 512 conserve une hauteur utile de 75 à 76 % et fournit la marge horizontale nécessaire à Death, sans réduire inutilement l'elfe.

## Réglage final retenu

| Paramètre | Valeur finale |
|---|---:|
| `CharacterViewport.size` | 768 x 512 |
| `CharacterCamera.size` | 2,220395 |
| hauteur visée par la caméra | 0,87 m |
| `scaling_3d_scale` | 1,0 |
| `scaling_3d_mode` | bilinéaire, aucune mise à l'échelle 3D |
| `use_taa` | false |
| `screen_space_aa` | disabled |
| `msaa_3d` | MSAA 4X |
| `RenderSprite.texture_filter` | Linear explicite |
| `RenderSprite.scale` | 0,1387747 uniforme |
| échelles des autres parents 2D | (1, 1) |
| `CharacterPivot.scale` | (1,10 ; 1,10 ; 1,10), inchangée |
| bbox Idle native | 298 x 387 px |
| ratio de hauteur natif | 75,59 % |
| bbox finale dans la fenêtre | environ 75,44 x 97,97 px |
| facteur effectif vers l'écran | 0,2531479, réduction fractionnaire intentionnelle |

`RenderSprite` n'est pas agrandi pour simuler le résultat. Sa réduction maintient la taille finale de production pratiquement identique à l'ancienne, tandis que la source possède environ sept fois plus de pixels en hauteur. La position du sprite tient maintenant compte de cette échelle afin que le pixel projeté des pieds reste exactement sur `Vector2.ZERO`.

## Validation des animations et du cadrage

Les bornes alpha ont été échantillonnées sur les animations. Aucune n'atteint le bord du viewport final :

| Animation | Union des bornes | Marges gauche / haut / droite / bas |
|---|---:|---:|
| Idle | 298 x 387 px | 231 / 49 / 239 / 76 px |
| Walk | 361 x 439 px | 203 / 32 / 204 / 41 px |
| Cast | 385 x 395 px | 176 / 31 / 207 / 86 px |
| Hit | 371 x 407 px | 241 / 4 / 156 / 101 px |
| Death | 470 x 456 px | 52 / 48 / 246 / 8 px |

La salle réelle a ensuite validé :

- Idle et Walk dans les quatre directions ;
- Cast, Hit et Death sans réapparition du flou ni coupe ;
- absence de scintillement, de fort crénelage et de halo visible ;
- alignement des pieds conservé ;
- VFX de Cast toujours issu de la main droite, avec un écart mesuré de 0 px ;
- Y-sort et sélection inchangés ;
- cellule libérée à la mort, racines `UnitView` et `ElfIsoUnitView` immobiles à 0 px ;
- visuel conservé jusqu'à `death_animation_finished`.

Avertissements conservés, sans lien avec la netteté : l'Action Death contient environ 1,312 m de déplacement interne de `Hips` et la pose déborde visuellement sur la case adjacente. Aucun root motion ni gameplay n'a été modifié.

Les avertissements de fuite de RID affichés à la fermeture forcée du banc de test concernent la destruction immédiate de la scène de validation ; aucun échec fonctionnel n'a été relevé.

## Captures produites

- `res://tests/characters/elf/screenshots/sharpness_before_viewport.png`
- `res://tests/characters/elf/screenshots/sharpness_before_viewport_crop.png`
- `res://tests/characters/elf/screenshots/sharpness_before_composite.png`
- `res://tests/characters/elf/screenshots/sharpness_before_composite_crop.png`
- `res://tests/characters/elf/screenshots/sharpness_512_linear_viewport.png`
- `res://tests/characters/elf/screenshots/sharpness_512_nearest_viewport.png`
- `res://tests/characters/elf/screenshots/sharpness_768_linear_viewport.png`
- `res://tests/characters/elf/screenshots/sharpness_768x512_linear_viewport.png`
- `res://tests/characters/elf/screenshots/elf_sharpness_comparison.png`
- `res://tests/characters/elf/screenshots/elf_sharpness_final_idle.png`
- `res://tests/characters/elf/screenshots/elf_sharpness_final_walk.png`
- `res://tests/characters/elf/screenshots/elf_sharpness_final_cast.png`

Les variantes disposent aussi de leurs captures composite et de leurs crops.

## Fichiers modifiés pour cette correction

- `res://characters/elf/ElfIsoUnitView.tscn`
- `res://characters/elf/elf_iso_unit_view.gd`
- `res://tests/characters/elf/elf_salle1_gameplay_integration.gd` (audit automatisé et captures)
- `res://characters/elf/ELF_RENDER_SHARPNESS.md`
- captures PNG et fichiers d'import Godot correspondants sous `res://tests/characters/elf/screenshots/`

Ni `ElfVisual3D.tscn`, ni la salle, ni le GLB, ni les textures, matériaux, squelette, animations, poids, grille, dégâts, taille logique des cases ou logique de déplacement n'ont été modifiés pour cette correction.

## État Git final

Le dépôt reste volontairement non propre : il contenait déjà les changements de l'intégration de l'elfe et une modification préexistante de `elf_character_v01_texture_0.png.import`. Les fichiers de l'intégration, les captures et ce rapport sont non suivis ou modifiés selon leur état antérieur. `git diff --check` ne signale aucune erreur d'espaces. Aucun commit et aucun push n'ont été effectués.
