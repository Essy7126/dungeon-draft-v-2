# Audit final de présence des unités et d'occlusion

## Périmètre

Cet audit couvre exclusivement la présentation des unités sur les trois maps
peintes de la première run. Il ne modifie ni `GridData`, ni `Pathfinder`, ni les
layouts, spawns, terrains, sorts, rencontres ou transitions de la run.

Les sorties de référence sont regroupées dans
`artifacts/maps/unit_presence_audit/`. Le rapport mesuré faisant foi est
`final_metrics.json` ; `validation_summary.json` en fournit une synthèse.

## Calibrations finales

Les coordonnées sont exprimées dans les pixels source des images 1376×768.

| Map | Origine | `axis_x` | `axis_y` | Offset caméra de base | Zoom de base |
|---|---:|---:|---:|---:|---:|
| Forêt | (688 ; 164,97778) | (34,4 ; 17,066667) | (-34,4 ; 17,066667) | (0 ; 34) | 1,10 |
| Volcan | (695 ; 172,5) | (34,65 ; 17,5) | (-34,65 ; 17,5) | (0 ; 32) | 1,10 |
| Espace | (693,5 ; 137) | (34,825 ; 17,5) | (-34,825 ; 17,5) | (0 ; 30) | 1,10 |

La calibration est répétée dans les métriques de chaque résolution afin de
permettre une vérification automatique des PNG régénérés.

## Profils de caméra et échelles visuelles

| Map | Profil | Multiplicateur caméra | Ajustement offset | Multiplicateur de salle |
|---|---|---:|---:|---:|
| Forêt | `room_01_forest_presence` | 1,10 | (0 ; 8) | 1,05 |
| Volcan | `room_05_volcano_presence` | 1,12 | (0 ; 10) | 1,08 |
| Espace | `room_06_space_presence` | 1,15 | (0 ; 12) | 1,10 |

L'offset total est donc (0 ; 42) sur les trois maps. La formule appliquée au
visuel enfant reste :

```text
scale finale = clamp(scale de famille × multiplicateur de salle, min, max)
```

La racine `UnitView`, sa scale 0,58 et le pied logique ne changent pas.

| Famille | Base | Forêt | Volcan | Espace |
|---|---:|---:|---:|---:|
| Elfe | 1,72 | 1,806 | 1,8576 | 1,892 |
| Mage | 1,76 | 1,848 | 1,9008 | 1,936 |
| Guerrier | 1,88 | 1,974 | 2,0 (cap) | 2,0 (cap) |
| Achille | 1,58 | 1,659 | 1,7064 | 1,738 |
| Squelettes standards | 1,58 | 1,659 | 1,7064 | 1,738 |
| Squelettes élites | 1,58 | 1,659 | 1,7064 | 1,738 |

Les identifiants runtime `odyssey_skirmisher`, `odyssey_guard` et
`odyssey_champion` sont explicitement rattachés à ces familles. Les billboards
squelette compensent en plus leur cadrage 3D natif plus petit ; le test de
production exige une hauteur rendue comprise entre 95 % et 105 % de celle
d'Achille.

## Règles d'occlusion

Le background, les unités et l'occluder restent dans le même repère image.
`YSortedWorld` est Y-sorté. Chaque tour fournit :

- un polygone qui recopie les pixels correspondants du background dans un
  `Polygon2D` Y-sorté ;
- un seuil Y propre à la structure ;
- un rectangle intérieur de masquage intégral.

Une unité dont le pied entre dans le rectangle intérieur devient invisible.
Elle redevient visible dès que son pied sort du rectangle, y compris devant ou
sur les côtés. Le test ciblé couvre séparément arrière, avant, côtés gauche et
droit, plusieurs unités, changement de Y, entrée/sortie, vue libérée et
reconstruction. L'ancien occluder est libéré immédiatement avant la création du
nouveau, ce qui garantit une seule instance lors d'un reload dans la même frame.

Limite volontaire : la zone intérieure masque intégralement l'unité ; elle ne
simule pas une découpe partielle du corps. Le polygone texturé assure la
continuité visuelle de la tour sans nouvelle texture ni modification gameplay.

## Captures et métriques

Chaque dossier `<map>/<résolution>/` (`720p`, `1080p`, `1440p`) contient les
mêmes coordonnées de test et exactement les états suivants :

- `final.png` ;
- `debug_grid.png` ;
- `unit_behind_occluder.png` ;
- `unit_side_of_occluder.png` ;
- `unit_in_front_of_occluder.png` ;
- `several_units_occlusion.png` ;
- `movement_overlay.png` ;
- `spell_overlay.png` ;
- `active_unit.png`.

`before.png` et `occlusion_off.png` sont des entrées supplémentaires réservées
aux planches comparatives. En 1080p, `walk_animation.png`,
`cast_animation.png` et `hit_animation.png` figent aussi les trois états animés
principaux. Les planches par map sont `before_after.png`,
`occlusion_off_on.png`, `occlusion_scenarios.png`, `animation_states.png` et
`resolution_comparison.png`. Les planches globales sont :

- `all_maps_comparison.png` ;
- `all_maps_occlusion_off_on.png` ;
- `all_maps_resolution_comparison.png`.

Pour chaque map et résolution, `final_metrics.json` enregistre origine et axes,
taille apparente de cellule, zoom effectif, scales alliées et ennemies,
dimensions visibles des héros, ratios unité/cellule, erreur du pied, occupation
de la zone tactique, FPS moyen/minimum sur 24 frames, nombre d'unités du test et
résultats booléens d'occlusion.

Les FPS proviennent du rendu d'audit local. Ils permettent de repérer une
régression entre ces trois profils sur la même machine ; ce ne sont pas des
benchmarks matériels universels.

## Résultats finaux du 3 août 2026

Les mesures avant/après ci-dessous utilisent le même état de combat et la même
résolution 1920×1080. La hauteur est la moyenne des trois héros visibles ; le
zoom indiqué est le zoom canvas effectif, adaptation du viewport comprise.

| Map | Zoom avant → après | Scale alliée moy. avant → après | Scale ennemie moy. avant → après | Hauteur héros avant → après | Zone tactique avant → après |
|---|---:|---:|---:|---:|---:|
| Forêt | 1,5469 → 1,7016 | 1,0 → 1,876 | 1,0 → 1,68 | 48,56 → 99,98 px | 32,79 → 39,68 % |
| Volcan | 1,5469 → 1,7325 | 1,0 → 1,9195 | 1,0 → 1,638 | 48,56 → 104,20 px | 33,87 → 42,48 % |
| Espace | 1,5469 → 1,7789 | 1,0 → 1,9427 | 1,0 → 1,6683 | 48,56 → 108,34 px | 34,04 → 45,01 % |

Sur les neuf combinaisons map/résolution, l'erreur maximale du pied logique est
0 px. Le scénario derrière est masqué, les deux côtés et l'avant restent
visibles, et le scénario à quatre unités donne toujours
`[masquée, visible, visible, visible]`. Un seul occluder est présent et le
Y-sort reste actif. Les moyennes mesurées sont comprises entre 164,8 et
165,4 FPS ; le minimum des 216 intervalles mesurés est 146,7 FPS.

La revue des planches confirme pour chaque map que les unités ne ressemblent
plus à de petits pions, que silhouettes, armes et états marche/incantation/impact
restent lisibles, que les pieds sont centrés, et qu'aucune unité latérale ou
devant la tour n'est masquée. La grille de debug et les overlays de déplacement
et de sort suivent les cellules peintes. Aucune cellule logique essentielle
n'est coupée ; le décor garde son identité sans prendre le dessus sur l'action.

## Résultats des tests

- Ciblé présence/occlusion : 20/20, 257 assertions, 1,841 s.
- Tests Python export/cache/probe : 5/5.
- Régressions ciblées : 120/125, 2 334/2 344 assertions, 32,045 s.
- Suite GUT complète : 486/493, 39 919/39 940 assertions, 46,442 s.

Aucun nouvel échec lié à cet audit. Les cinq échecs ciblés viennent des trois
images absentes de `artifacts/maps/pool_map/` et de l'UID historique invalide
de `data/units/alliés/Guerrier.tres`. Les sept échecs de la suite complète sont
externes ou préexistants : un style du menu pause, l'aller-retour fichier de
l'inventaire pendant le travail concurrent sur les objets, quatre exports
absents de `artifacts/maps/mountain_pass_blueprint/`, et l'export pool-map déjà
cité. Les erreurs GUT d'écriture de `user://gut_temp_directory/versions.json`,
de certificat Windows et les avertissements d'allocations à la fermeture sont
environnementaux et surviennent après les résumés de tests.

Les journaux de référence sont :

- `artifacts/maps/unit_presence_audit/logs/gut_painted_unit_presence_targeted_final.log` ;
- `artifacts/maps/unit_presence_audit/logs/gut_targeted_regressions.log` ;
- `artifacts/maps/unit_presence_audit/logs/gut_full_final.log` ;
- `artifacts/maps/unit_presence_audit/logs/runtime_capture_windowed_final.log`.

## Cache et régénération forcée

La cause du cache historique se trouvait dans
`tools/export_painted_run_integration.py` : un PNG existant était réutilisé dès
qu'il était lisible et possédait les dimensions attendues. Ni la calibration ni
le contenu de la ressource n'étaient comparés, ce qui conservait un ancien PNG
après une modification d'origine ou d'axes.

Le comportement normal reste inchangé. L'option explicite suivante ignore ce
cache et réécrit atomiquement tous les PNG gérés par l'exporteur, sans se baser
sur les dates et sans supprimer d'autres artifacts :

```powershell
python tools/export_painted_run_integration.py --force
```

L'observateur runtime accepte également `--force` ou
`force_regenerate=true`. Dans ce mode, il ne fusionne pas l'ancien
`final_metrics.json` et réécrit toutes les captures sélectionnées.

Les références `res://` et `uid://` sont toutes deux acceptées par l'exporteur.
Dans le second cas, le chemin source est résolu à partir des métadonnées Godot
`.import`, de manière déterministe.

## Décision sur `probe_painted_grid.py`

La logique de détection des deux familles de lignes est conservée parce qu'elle
est réutilisable pour de futures maps. Le script temporaire a été remplacé par
`tools/calibration/probe_painted_grid.py` : aucun chemin ni ROI n'y est codé en
dur, tous les paramètres utiles sont disponibles en CLI et la sortie est un JSON
déterministe. Les entrées, sorties et un exemple sont documentés dans
`tools/calibration/README.md`. Un test léger vérifie le parsing et la stabilité
de la détection des pics répétés.

## Commandes de génération

L'observateur doit être lancé dans une instance Godot dédiée :

```powershell
& 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64.exe' `
  --path . res://tools/UnitPresenceAudit.tscn -- --force

python tools/export_unit_presence_audit.py
```

L'import et les tests GUT doivent ensuite être exécutés avec le même Godot 4.7.
