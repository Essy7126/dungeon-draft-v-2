# Intégration des maps peintes dans la première run

## Décision et périmètre

La première run comporte désormais six salles. Les entrées qui occupaient déjà
les index 2, 3 et 4 restent dans le même ordre. La forêt peinte remplace la
présentation et le layout de la salle 1 ; le volcan et l'espace deviennent les
salles 5 et 6. La salle 6 reste soumise au comportement terminal générique de
`GameManager` : après le post-combat, l'index dépasse la liste de six salles et
le flux ouvre `RunResultScreen`, sans salle 7.

L'intégration ne déduit aucune règle depuis les pixels. Les images sont des
fonds visuels ; `RoomData`, `RoomGridLayout`, `GridData`, `Pathfinder`,
`TerrainEffects` et `DeploymentController` restent les autorités gameplay.

## Inventaire du pool

| Fichier | Dimensions / ratio | Format / alpha | Lecture visuelle | Grille | SHA-256 | Import Godot |
|---|---:|---|---|---|---|---|
| `map_forêt.png` | 1376×768 / 1,791667 | PNG / non | grande plateforme de ruines moussues, montagne forestière, centre libre | visible | `B51E233F989B667039757E4D145E1AC8F9514CA34B3820C52F0446BA58B5E8EB` | texture importée, lossless, sans mipmaps ni réduction |
| `map_lave.png` | 1376×768 / 1,791667 | PNG / non | pierre volcanique, trois bassins de lave, route à gauche, ruine à droite, volcan | visible | `C45902EE8412899DC6714465FC571AB482E7CF50764054AC026736768328D054` | texture importée, lossless, sans mipmaps ni réduction |
| `map_espace.jpg` | 1376×768 / 1,791667 | JPEG / non | plateforme technologique, espace, murs métalliques, plaques claires | visible | `07A4990B46169A11E2CB31EBC20DB710B8DC29FA2591B23E59400A03FCF63629` | texture importée, lossless côté Godot, sans mipmaps ni réduction |
| `map_neige.jpg` | 1672×941 / 1,776833 | JPEG / non | plateforme enneigée | visible | `DEF289B1E085A08869B94EEF1FFA613FE86ED4C9CBC60633A140420F650E7BA6` | texture importée, lossless côté Godot, sans mipmaps ni réduction |

Les trois premières images correspondent sans ambiguïté aux descriptions de la
mission. `map_neige.jpg` demeure intacte dans le pool et hors de cette run.

Les copies de production suivent la convention existante `asset/map` :

- `asset/map/painted/room_01_forest/forest_background_v2.webp`
- `asset/map/painted/room_05_volcano/volcano_background_v2.jpg`
- `asset/map/painted/room_06_space/space_background_source.jpg`

Les copies sont bit-à-bit identiques aux sources (mêmes tailles et hashes). Le
JPEG spatial reste un JPEG : aucune recompression n'a été effectuée.

## Architecture

`RoomData` référence un `RoomGridLayout` et un `PaintedMapVisualData` optionnels.
La scène partagée `painted_battle.tscn` utilise `PaintedBattle`, qui étend le
`Battle` de production. C'est toujours `Battle` qui crée l'unique instance de
la classe commune `GridData` et les systèmes existants associés. Le layout ne
fait qu'écrire des types explicites dans cette instance.

`PaintedGridView` est une façade de rendu compatible avec les signaux et les
conversions attendus par `Battle`. Elle reçoit le `GridData` commun dans
`setup()` et n'en instancie pas. Seul le laboratoire `@tool` crée un `GridData`
de prévisualisation, de la même classe commune, hors run.

Les chemins de textures sont chargés paresseusement par la ressource visuelle.
Ainsi, charger `first_run.tres` ne charge pas les trois grandes images : seule
la texture de la salle courante est résolue par sa scène.

## Topologie et layouts explicites

Les trois images proviennent du même blockout 14×14. Elles partagent donc une
seule topologie de base, puis les ressources dérivées ajoutent uniquement leurs
terrains. Comptage commun : 153 cellules normales praticables, 7 murs `#`, une
ruine 2×2 soit 4 cellules `R`, et 32 `VOID`, pour 196 cellules typées. Les six
positions `A` et les six positions `E` sont des zones de déploiement superposées
à des cellules praticables.

Légende : `.` praticable, `#` mur, `X` VOID, `~` terrain spécial praticable,
`A` spawn allié, `E` spawn ennemi, `R` ruine bloquante.

### Salle 1 — forêt

```text
XXXX......XXXX
XX..........XX
X.......EEE..X
........EEE...
.........RR...
....#....RR...
..##..........
..............
XX.......#....
XX..A.....#...
...AAA..##....
X..AA........X
XX..........XX
XXXX......XXXX
```

### Salle 5 — volcan (`~` = LAVA)

```text
XXXX......XXXX
XX..........XX
X.~~....EEE..X
.~~~....EEE...
.........RR...
....#....RR...
..##..........
.....~~...~~..
XX...~~..#~~~.
XX..A.....#...
...AAA..##....
X..AA........X
XX..........XX
XXXX......XXXX
```

### Salle 6 — espace (`~` = ICE)

```text
XXXX......XXXX
XX..........XX
X.~~....EEE..X
.~~~....EEE...
.........RR...
....#....RR...
..##..........
.....~~...~~..
XX...~~..#~~~.
XX..A.....#...
...AAA..##....
X..AA........X
XX..........XX
XXXX......XXXX
```

Le volcan déclare 14 cellules `LAVA` et l'espace 14 cellules `ICE`. Ces deux
types existaient déjà dans `GridData`, sont praticables et n'ont actuellement
aucun effet automatique statique dans `TerrainEffects`. L'intégration conserve
donc cette classification sans inventer dégâts, glissade ou autre mécanique.

## Calibration affine

Les trois images ont été mesurées indépendamment. Leurs grilles peintes sont
très proches, mais les axes et origines restent propres à chaque image :

| Map | Origine source | `axis_x` | `axis_y` | Ancres | RMS à 1920×1080 | Max à 1920×1080 | Caméra |
|---|---|---|---|---:|---:|---:|---|
| forêt | (688 ; 164,97778) | (34,4 ; 17,066667) | (-34,4 ; 17,066667) | 9 | 0,000014 px | 0,000022 px | offset (0 ; 34), zoom 1,1 |
| volcan | (695 ; 172,5) | (34,65 ; 17,5) | (-34,65 ; 17,5) | 9 | < 0,000001 px | < 0,000001 px | offset (0 ; 32), zoom 1,1 |
| espace | (693,5 ; 137) | (34,825 ; 17,5) | (-34,825 ; 17,5) | 9 | < 0,000001 px | < 0,000001 px | offset (0 ; 30), zoom 1,1 |

Les bounding boxes logiques en pixels source sont respectivement
`(206,4 ; 147,911113 ; 963,2 ; 477,866676)`,
`(209,9 ; 155 ; 970,2 ; 490)` et `(205,95 ; 119,5 ; 975,1 ; 490)`.
Les erreurs non nulles ci-dessus proviennent uniquement de l'arrondi décimal
des ressources texte et restent très inférieures aux limites de 2 px RMS /
4 px maximum. Les rendus 1280×720, 1920×1080 et 2560×1440 conservent le ratio,
couvrent le viewport et gardent la zone tactique visible.

Le laboratoire `painted_map_calibration.tscn` expose l'image, la grille, le
foreground, les types, spawns, coordonnées, centres, ancres, erreurs, axes et
bounds. Il permet également l'export d'une capture depuis l'inspecteur.

## Rendu, Y-sort et occlusion

Ordre de rendu : background peint, terrains/overlays, monde des unités Y-sorté,
foreground optionnel, VFX puis HUD. Les conversions cellule ↔ écran reposent
sur la même affine pour les clics, déplacements, sorts, spawns et ancrage des
pieds. La grille technique est transparente en production ; la grille visible
est celle déjà peinte dans l'image.

Chaque tour dispose désormais d'un polygone texturé qui recopie les pixels du
background dans `YSortedWorld`, ainsi que d'une zone intérieure de masquage
intégral. Une unité derrière la structure est masquée ; une unité devant ou sur
les côtés reste visible. L'occluder est remplacé immédiatement lors d'un reload,
sans accumulation. Les coordonnées et limites exactes ainsi que les captures
off/on sont documentées dans `docs/maps/unit_presence_audit.md`.

Les fissures, mousse, racines et détails sont décoratifs. Sur la map spatiale,
certains sols visibles au-delà de la silhouette logique restent non jouables.
Sur le volcan et l'espace, les 14 cellules spéciales couvrent le cœur des zones
visuelles ; leurs franges peintes restent décoratives. Aucune surface visible
supplémentaire n'est devenue praticable.

## RunData et rencontres

Séquence finale :

1. `first_run_room_01.tres` — forêt peinte ;
2. `first_run_room_02.tres` — inchangée ;
3. `first_run_room_03.tres` — inchangée ;
4. `bible/la_rune.tres` — inchangée et au même index ;
5. `room_05_volcano.tres` — volcan ;
6. `room_06_space.tres` — espace final.

La salle 1 conserve exactement son roster pédagogique : deux squelettes mêlée
et un squelette distance. Les salles 2 à 4 ne sont pas modifiées. Pour les deux
nouvelles salles tardives, le roster déjà éprouvé de l'ancienne cinquième salle
est réutilisé sans nouvelle valeur d'équilibrage : trois chefs squelettes, deux
centurions des neiges et un squelette distance.

La validation runtime confirme aussi une divergence historique de « La Rune »
laissée intacte conformément au périmètre : sa `RoomData` déclare trois ennemis,
mais deux coordonnées de `enemy_spawn_zone` sont hors de sa grille. Le squelette
distance ne trouve donc aucune case libre et seuls le chef et le mêlée sont
instanciés. L'observateur de run complète attend cet état effectif et conserve
l'avertissement pour qu'il ne soit pas masqué.

## Mémoire et imports

Une image 1376×768 décodée en RGBA8 représente 4 227 072 octets, soit environ
4,03 Mio. Les trois simultanément représenteraient environ 12,09 Mio, hors
overhead et éventuelles copies GPU. Le chargement paresseux maintient seulement
le background courant référencé par la bataille. Les sources occupent ensemble
4 564 510 octets (environ 4,35 Mio) sur disque.

Les imports de production utilisent les conventions constatées dans le pool :
texture non VRAM, compression mode 0 sans perte supplémentaire, pas de mipmaps,
`size_limit = 0`, canaux RGBA standard et pas de répétition configurée par la
scène. Les trois originaux du pool restent inchangés.

## Fonds V2 et présence visuelle des unités

La forêt et le volcan utilisent maintenant les variantes demandées du pool :
`map_foret_v2.jpg` et `map_lave_v2.jpg`. Le premier fichier porte une extension
JPEG mais contient réellement un flux WebP ; sa copie de production utilise donc
l'extension correcte `forest_background_v2.webp`, sans conversion ni perte. La
copie volcan reste un JPEG sous le nom `volcano_background_v2.jpg`. Les sources
du pool et les anciens fonds de production restent intacts ; seules les
références des ressources visuelles ont été remplacées.

La présence des personnages est pilotée par deux ressources de présentation,
sans toucher au `UnitView` racine ni à son pied logique. L'échelle appliquée au
visuel enfant suit la formule :

```text
échelle_visuelle_finale = échelle_de_base_de_la_famille × multiplicateur_de_salle
```

Les héros utilisent des bases de 1,72 (Elfe et Achille), 1,76 (Mage) et 1,88
(Guerrier). Les squelettes standards et élites utilisent désormais eux aussi
une base de 1,72. Les identifiants réels des trois ennemis de L'Odyssée sont
explicitement rattachés à ces profils, et leurs billboards compensent leur
cadrage natif afin de partager la hauteur rendue d'Achille. Les multiplicateurs
de salle sont 1,05 pour la forêt, 1,08 pour le volcan et 1,10 pour l'espace.
Les zooms de présentation sont 1,10, 1,12 et 1,15. Les valeurs finales par
famille, caps compris, figurent dans `docs/maps/unit_presence_audit.md`. Une
ombre de contact et des liserés vectoriels sobres renforcent la lecture sans
modifier les textures des modèles, les collisions, les spawns ou la grille.

L'audit `artifacts/maps/unit_presence_audit/` contient les captures avant/après,
les variantes d'échelle, les trois résolutions, les états d'action et le rapport
de mesures. Il confirme une erreur maximale de pied logique de 0 px et une
échelle racine inchangée sur les trois salles.

## Validation et artefacts

Le dossier `artifacts/maps/painted_run_integration/` contient 15 captures par
map : background, calibration et unités aux trois résolutions ; mouvement et
sort en 720p/1080p ; types et comparaison foreground en 1080p. Il contient en
plus les quatre comparaisons/transitions demandées et
`calibration_error_report.json`, soit 50 fichiers au total.

Les tests ciblés vérifient les fichiers et hashes, la séquence de six salles,
le partage de topologie, l'instanciation du `GridData` commun, les 196 cellules
typées, les spawns, les obstacles, les VOID, les allers-retours affine, la
connectivité et les chemins, les terrains neutres, l'absence de création de
grille dans les adaptateurs de production, la terminaison vers
`RunResultScreen` et la protection contre une double victoire.

Validation du 3 août 2026 : les exports forcés d'intégration et de présence sont
lisibles et complets. Le test final de présence/occlusion passe 20/20 avec
257 assertions. Les régressions ciblées passent 120/125 et la suite GUT complète
486/493 ; aucun des échecs restants ne concerne la présence, le Y-sort,
l'occlusion, les overlays ou la calibration. Le détail et les journaux faisant
foi sont consignés dans `docs/maps/unit_presence_audit.md`. Les messages de
certificats Windows, UID historique et allocations au quit sont
environnementaux ou préexistants.
