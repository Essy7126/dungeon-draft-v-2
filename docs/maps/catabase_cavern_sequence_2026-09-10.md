# Catabase — continuité de la caverne, salles II à IV

La galerie des piliers brisés, la crypte du courant et le gué souterrain prolongent
la première caverne validée. Direction graphique : salle d’émeraude, roche
brun-noir, rivière turquoise, brume périphérique et petits foyers dorés.
Les noms de rencontre et les identifiants historiques restent les mêmes.

## Production

| Salle | Paquet de terrain et d’art | Emprise tactique |
| --- | --- | --- |
| II | `cavern_pillars_v1` | 217 cases, 12 obstacles, 16 cellules de fosse |
| III | `cavern_crypt_v1` | 217 cases, 12 obstacles, 16 cellules de fosse |
| IV | `cavern_ford_v1` | 114 cases, 8 obstacles, 6 cellules de fosse |

Les plans sont dans `data/arenas/`, les peintures et scènes d’atmosphère dans
`assets/catabase/combat/`, les kits Studio figés dans `art/source/maps/`.
Le descripteur de production est `art/source/maps/cavern_sequence_v1/sequence.json`.

La grille canonique précède la peinture : export par `ArenaArtKitExporter`, guide
de composition dérivé de l’emprise Studio et du polygone terrestre. Chaque
génération utilise son guide, `cavern_v1/land_v4.png` et la salle d’émeraude comme
références explicites. Les prompts et sources générées sont conservés.

Les sorties du générateur mesurent 1586 × 992. Avant la réimportation, Godot
normalise l’intégralité de chaque peinture en 1920 × 1200 par Lanczos, sans
recadrage. Les guides, masques et grilles ne sont pas redimensionnés. L’inspection
stricte `ArenaArtRoundTripService` vérifie ensuite le kit et son empreinte ;
`apply_reimport` conserve le sol opaque `ALL_DEFINED`. Le RMS de calibration est
nul pour les trois salles. `ArenaRuntimeBridge` synchronise les ressources liées.

La projection reprend la taille des dalles de la première caverne : axes
(37.83312,18.91656) et (-37.83312,18.91656). Les salles II et III utilisent son
origine (865.18024,268.73502). Le gué garde son emprise distincte et utilise
(1002.91656,246.9602). Après inspection GPU, ce dernier est décalé de (+24,-32)
pixels natifs pour dégager davantage sa berge inférieure gauche. Son kit de
génération reste figé ; `cavern_ford_v1/placement-v2/art-kit/` contient le kit du
placement final, également passé par l’import strict. Les coordonnées logiques, obstacles, fosses, départs,
rencontres et récompenses sont conservés. Les plans imposent 32 pixels natifs
minimum entre les dalles et la limite terrestre ; les peintures laissent aussi
une bande de sol visible autour des arènes.

Les scènes d’atmosphère héritent des effets corrigés de la première caverne.
Les positions des braseros sont réglées sur chaque peinture après génération.
Le shader des flammes anime uniquement les pixels chauds près des foyers, l’eau
utilise le plan Water, et les nappes de brume évitent l’emprise de combat. Les
quatre matériaux partagent une horloge et respectent la réduction des mouvements.
La première salle conserve ses positions de torches par défaut.

## Vérification finale

L’import Godot en recovery mode passe sans erreur moteur. Les 11 tests stricts
passent avec 9111 assertions, dont la conservation des données tactiques des
quatre premières salles. Les contrôles GPU des trois nouvelles salles passent
en 1920 × 1080 et 1200 × 896 : géométrie, support terrestre, bande de sol,
matériaux, cadrage avant/après action, sélection de toutes les cases, déplacement
et garde. Les six captures ont été inspectées ; les entrées sont dégagées et une
bande de roche reste visible entre les dalles et les berges peintes. Les mesures
de retrait des rapports portent sur les polygones déclarés, et ne remplacent pas
cette inspection de la peinture.

La revue de mouvement en 1920 × 1080 passe sur les trois maps et la salle I :
36 images échantillonnées, changement des zones eau/brume/torche, zone témoin de
dalle stable, quatre matériaux, horloge active puis figée par la réduction des
mouvements. La salle I passe aussi les oracles de combat après le paramétrage
des positions de torches partagées. Aucune erreur moteur relevée dans ces revues.

Rapports complets et captures : `artifacts/dev/cavern-sequence-v1/`. Aperçu des
captures réelles : `three-caverns.png`. Chaque paquet d’art conserve son
`manifest.json` avec les empreintes des références et de la peinture, les
positions des braseros et ses résultats, ainsi que `studio-import-report.json`.
La comparaison aux copies des ressources prises avant cette tâche confirme que
seuls les champs de présentation des salles II, III et IV ont changé.

Ne pas prendre l’ancien runner global à cinq salles comme preuve du parcours
actuel : la run contient désormais quinze salles. La revue ciblée réutilise les
oracles de production de géométrie, support, bordure, matériaux, cadrage,
déplacement et garde, sur la véritable scène de combat.
