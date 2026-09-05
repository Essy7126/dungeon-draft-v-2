# Spectre errant — préparation mécanique des sprites

Ce script prépare les PNG dessinés avec ImageGen pour Godot. Il ne redessine pas
le personnage, ne retourne aucune direction en miroir et ne génère pas de pose.
Il requiert Node.js et Sharp, avec le même chemin de secours local que le pipeline
d'Achille. `SHARP_PATH` permet de fournir une autre installation de Sharp.

## Entrées

Les quatre sources RGBA sont dans
`art/source/characters/spectre_greatsword/sprites_v1/source_N.png`, puis `E`, `S`, `W`.
Chaque source contient douze dessins, dans quatre colonnes et trois rangées.

`alignment.json`, à côté du script, appartient à la sélection artistique :

```json
{
  "N": {
    "scale": 0.75,
    "roots": [[160, 330], [475, 330], [790, 330], [1105, 330],
              [160, 745], [475, 745], [790, 745], [1105, 745],
              [160, 1160], [475, 1160], [790, 1160], [1105, 1160]]
  }
}
```

Ces nombres illustrent le format, **pas un alignement validé**. Chaque direction
doit fournir sa propre échelle fixe et les douze coordonnées globales de son ancre
dans la source. L'ancre représente la projection au sol du corps suspendu, pas le
pixel le plus bas de la robe ou de l'épée. Le script refuse l'absence d'alignement.
La sortie conserve une seule échelle par direction ; l'arrondi au pixel des
dimensions et des placements est mesuré dans le manifeste.

## Commandes

```powershell
node tools/spectre_sprite_pipeline/build.cjs --inspect --allow-partial
node tools/spectre_sprite_pipeline/build.cjs
```

`--inspect` est strictement en lecture seule et fonctionne sans `alignment.json`.
Il décrit les composantes ordonnées, leurs limites, centres, nombres de pixels et
les éventuelles erreurs de segmentation. `--allow-partial` autorise l'inspection
ou une construction de développement lorsque toutes les directions ne sont pas
encore disponibles ; un jeu partiel reste marqué `complete: false` et ne satisfait
pas le profil runtime final.

Le seuil de taille d'une composante est de 2 000 pixels par défaut. Si les sources
ont des silhouettes plus petites, on peut inspecter explicitement avec
`--min-component-pixels 1000`, puis utiliser le même paramètre pour construire.
Les options inconnues sont refusées pour éviter un résultat involontaire.

## Extraction et contrôles

Le script cherche douze composantes connexes en huit directions avec alpha > 32.
Le centre de chacune doit correspondre à une case distincte de la grille source.
La totalité de la composante est extraite, même si une lame franchit la case
théorique. La couleur et l'alpha source sont copiés sans modification dans le
noyau et les deux pixels autour de son bord ; seul le rééchantillonnage Lanczos
applique ensuite l'échelle explicite commune.

Un fond sans alpha, un fond excessivement opaque, une composante manquante ou
ambiguë, une perte de pixels isolés d'alpha > 32 et un dessin dépassant le canevas
font échouer la construction. Le script ne jette pas discrètement une partie de
l'épée pour continuer. Tous les placements sont contrôlés avant d'écrire les
ressources runtime. Chaque région d'atlas est ensuite relue et comparée au RGBA
de l'image préparée.

## Sorties

Dans `assets/characters/spectre_greatsword/sprites_v1/` :

- `atlas_N/E/S/W.png` : 2 048 × 1 152, douze cases de 512 × 384, ancre (256, 320).
- `spectre_sprite_frames.tres` : douze animations correspondant aux quatre directions.
- `spectre_portrait.tres` : animation `idle_E`, même texture que `idle_E`, sans redessin.
- `manifest.json` : SHA-256 des sources, de l'alignement, des atlas, des frames et
  des ressources Godot ; alpha, limites, placements et vérification des régions.
- `preview_DIRECTION_light.jpg` et `preview_DIRECTION_dark.jpg` : contact sheets
  avec repère d'ancrage rose et indices, uniquement pour la vérification visuelle.
- `walk_DIRECTION_preview.gif` et `attack_DIRECTION_preview.gif` : séquences
  indicatives sur fond clair, aux mêmes cadences que le SpriteFrames. Le GIF
  arrondit ses délais à la centiseconde ; les ressources Godot conservent 6/10 fps.

| Animation | Indices source | Cadence | Boucle |
| --- | --- | ---: | --- |
| `idle_DIRECTION` | 0 | 1 fps, image arrêtée par le runtime | oui |
| `walk_DIRECTION` | 0, 1, 2, 3 | 6 fps | oui |
| `attack_DIRECTION` | 0, 4, 5, 6, 7, 8, 9, 0 | 10 fps | non |

L'attaque dure 0,8 s et atteint sa quatrième image, le marqueur d'impact du
runtime, à 0,3 s. Les dessins source 10 et 11 restent dans les atlas et les
contact sheets pour revue, sans être ajoutés à une séquence non validée.
