# Pipeline mécanique du kit Achille V2

`build.cjs` prépare les atlas du kit étendu sans dessiner, détourer par couleur, retourner ou retoucher le personnage. Les huit feuilles sont des PNG à véritable transparence créés en amont. La sélection artistique et les ancrages restent explicites dans `alignment.json`.

## Sources et correspondances

Les sources vivent dans `art/source/characters/achilles/sprites_kit_v2/`. Chaque direction `N`, `E`, `S`, `W` possède ses propres dessins, jamais un miroir d'une autre direction. Les indices suivent l'ordre de lecture de la grille et commencent à zéro.

| Source | Grille | Indices | Animation |
| --- | --- | --- | --- |
| `source_base_DIR.png` | 4 × 3 | 0–3 | `dash_DIR` |
| idem | idem | 4–7 | `bow_DIR` |
| idem | idem | 8–11 | `guard_DIR` |
| `source_extra_DIR.png` | 4 × 4 | 0–3 | `sweep_DIR` |
| idem | idem | 4–7 | `volley_DIR` |
| idem | idem | 8–11 | `hit_DIR` |
| idem | idem | 12–15 | `death_DIR` |

Le kit complet compte 112 nouveaux dessins, soit 28 par direction. Les 12 animations historiques `idle_DIR`, `walk_DIR`, `attack_DIR` viennent directement du fichier `assets/characters/Achilles/sprites_cour_des_sources_v1/achilles_sprite_frames.tres` : définitions, textures, rectangles, durées, vitesses et boucles sont conservés. Seuls les identifiants internes des ressources reçoivent le préfixe `Legacy_` pour éviter les collisions. Les anciens atlas ne sont ni reconstruits ni recadrés dans la ressource de production.

Les nouvelles animations `bow`, `guard`, `sweep`, `volley` comptent six images : **idle V1 de la même direction, quatre nouveaux dessins, idle V1 identique**. `dash`, `hit` et `death` comptent quatre images. La ressource complète expose donc 40 animations, toutes avec quatre directions originales.

## Ancrage obligatoire

Créer `tools/achilles_kit_sprite_pipeline/alignment.json` après mesure des dessins. Format accepté :

```json
{
  "base_E": {
    "scale": 0.7,
    "roots": [[180, 310], [550, 315], [925, 270], [1280, 320], [180, 680], [545, 680], [905, 680], [1265, 680], [180, 1045], [550, 1045], [910, 1045], [1280, 1050]]
  }
}
```

Les valeurs ci-dessus illustrent uniquement le format ; elles ne constituent pas un alignement artistique validé. Chaque entrée `base_DIR` exige 12 couples, chaque entrée `extra_DIR` en exige 16. Le format imbriqué `{ "base": { "E": { "scale": ..., "roots": [...] } } }` est également accepté.

Un couple est l'ancre au sol du personnage en **coordonnées globales de la feuille source**, avant redimensionnement. Il devient le point `(256, 320)` du canvas de sortie `512 × 384`. Chaque feuille utilise une seule échelle fixe, choisie par l'artiste pour correspondre au volume d'Achille V1. `0.7` est une valeur de départ possible, jamais une valeur appliquée automatiquement. Aucun recalage sur le bas du pied, le vêtement, le bouclier ou l'arme n'est effectué. Le pipeline refuse une racine manquante et tout dessin qui sortirait du canvas.

## Exécution

Depuis la racine du projet, avec Node.js et `sharp` disponibles :

```powershell
node tools/achilles_kit_sprite_pipeline/build.cjs --inspect --allow-partial
node tools/achilles_kit_sprite_pipeline/build.cjs --allow-partial
node tools/achilles_kit_sprite_pipeline/build.cjs
```

`--inspect` ne produit aucun fichier et ne nécessite pas `alignment.json`. Le JSON affiche les composantes ordonnées, boîtes source, centres, transparence et erreurs ; `valid: false` indique une source refusée au build. `--allow-partial` autorise les seules feuilles déjà présentes, pour le travail préparatoire. Un build partiel remplace la ressource de sortie par ce sous-ensemble, avec `complete: false` dans le manifeste : il ne constitue pas un kit jouable validé. Le build normal exige les huit feuilles. Les arguments inconnus sont refusés.

`--min-component-pixels 1000` peut servir à inspecter un dessin plus petit après examen. Le défaut est 2000 pixels. Abaisser ce seuil ne désactive jamais le contrôle des pertes opaques et ne fusionne pas artificiellement deux dessins.

Le script charge d'abord `sharp` dans l'environnement Node courant, puis utilise `SHARP_PATH` si défini ; un chemin vers le runtime Codex local sert de dernier emplacement prévu sur ce poste. Il n'appelle pas Godot et n'effectue aucune génération d'image.

## Conservation de l'image

La segmentation utilise les composantes connexes à huit voisins pour les pixels d'alpha supérieur à 32, puis conserve les valeurs RGBA originales dans le cœur et son voisinage de deux pixels. Le dessin entier reste attaché à sa composante même si une arme dépasse sa cellule source nominale. Aucune suppression de couleur de fond n'est effectuée.

Chaque feuille doit fournir exactement 12 ou 16 personnages complets, chacun dans une cellule unique, et au moins 35 % de pixels totalement transparents. Une perte de pixel d'alpha supérieur à 32 provoque un échec, y compris pour une corde d'arc, une flèche ou un morceau d'arme isolé. Les particules très peu opaques éloignées peuvent être écartées ; leur nombre, somme d'alpha et alpha maximal sont consignés. Un fond quadrillé dessiné dans un PNG opaque est refusé.

Après un unique redimensionnement Lanczos à l'échelle explicite, les pixels sont copiés en RGBA brut dans le canvas, puis dans l'atlas. Le conditionnement n'effectue aucune composition avec nouvelle prémultiplication de l'alpha. Chaque région d'atlas décodée est comparée octet pour octet au RGBA de son canvas, et toute différence provoque un échec. SHA-256 des sources, alignements, régions et ressources permet de retrouver les entrées exactes d'un build.

## Sorties et lecture temporelle

Les fichiers sont écrits dans `assets/characters/Achilles/sprites_kit_v2/` : huit atlas `atlas_base_DIR.png` de `2048 × 1152` et `atlas_extra_DIR.png` de `2048 × 1536`, `achilles_sprite_frames.tres`, `manifest.json`, contacts sur fond clair/sombre et GIF de chaque nouvelle famille/direction. Les contacts montrent la croix d'ancrage ; ils ne sont jamais utilisés comme textures du jeu.

| Famille | Images | Durée dessinée | Marqueur de libération |
| --- | --- | --- | --- |
| `bow`, `sweep`, `volley` | 6 | 0,72 s, soit 8⅓ images/s | entrée image 3, 0,36 s |
| `guard` | 6 | 0,48 s, soit 12,5 images/s | entrée image 3, 0,24 s |
| `dash` | 4 | contrôlée par l'arrivée réelle | entrée image 2, 0,10 s |
| `hit` | 4 | 0,24 s, soit 16⅔ images/s | aucun |
| `death` | 4 | 0,48 s, soit 8⅓ images/s | aucun ; fondu runtime de 0,12 s ensuite |

Les métadonnées `dash` indiquent 20 images/s. Le backend pilote la charge, conserve l'image 2 aérienne pendant toute la translation et dispose d'un budget de secours de 1,2 s. À l'arrivée réelle, il libère le verrou du sort puis affiche l'image 3 de réception pendant 0,08 s, sans nouveau marqueur ; une nouvelle action, marche, réaction ou mort peut interrompre cette réception. Les demandes de repos la laissent se terminer. Le GIF de préparation utilise 50/50/400/80 ms : anticipation sur les images 0–1, charge aérienne maintenue sur l'image 2 puis réception sur l'image 3. Il illustre une charge de trois cases arrondie au centième de seconde, pour un total de 0,58 s ; le jeu conserve son arrivée réelle et adapte donc la durée de maintien à la distance. Le manifeste indique explicitement `hold_frame: 2`, `landing_frame: 3` et `landing_seconds: 0.08`. Les autres GIF arrondissent les délais au centième de seconde en conservant leur durée totale.

Les atlas et leur manifeste vérifient la préparation des textures. La cohérence artistique, la vitesse perçue, la synchronisation de la libération avec les dégâts, le déplacement réel et la fin des actions doivent ensuite être vérifiés par les tests du jeu et par la capture en combat, sous le contrôle de l'intégration centrale.

## Substitutions explicites de pose dans les clips

Le champ facultatif `clip_overrides` d’`alignment.json` remplace uniquement une référence de texture dans le fichier `SpriteFrames` final. Il ne modifie ni dessin, ni atlas, ni rectangle source, ni durée. Aucune substitution n’est appliquée en l’absence de ce champ.

```json
{
  "clip_overrides": {
    "volley_N": {
      "3": {
        "group": "base",
        "direction": "N",
        "index": 6,
        "reason": "Conserver le bouclier dessiné dans le dos à la libération."
      }
    }
  }
}
```

Cet objet s’ajoute aux entrées d’alignement des feuilles. La clé `3` est l’indice **commençant à zéro dans le clip final**, après ajout des images idle aux extrémités. Pour `bow_N` et `volley_N`, le clip contient six images : `idle`, pose 0, pose 1, pose 2 de libération, pose 3, `idle`. Ainsi `volley_N[3]` référence normalement l’image 6 d’`extra_N` ; l’exemple remplace cette seule référence par l’image 6 de `base_N`, déjà dessinée et conditionnée.

Les groupes sources valides sont `base` et `extra`, les directions `N`, `E`, `S`, `W`. L’indice source doit être un entier de 0 à 11 pour `base`, de 0 à 15 pour `extra`, et la feuille doit être présente dans le build. Les noms de clips inconnus, les indices hors limites, les champs inconnus et les références à une feuille absente sont refusés avant écriture. Les douze clips historiques et les deux extrémités idle des clips qui en possèdent restent immuables. `reason` est un texte facultatif de traçabilité.

Le manifeste `clip_overrides` consigne le clip, son indice final, l’ancienne image, l’image de remplacement, l’atlas source et la raison éventuelle. Les atlas et les contacts/GIF de préparation conservent les dessins et l’ordre source ; pour cette substitution de référence, le fichier `.tres` et les captures du jeu décrivent la séquence jouée.

Tests de ce contrat, sans chargement ni modification des dessins :

```powershell
node --test tools/achilles_kit_sprite_pipeline/clip_overrides.test.cjs
```
