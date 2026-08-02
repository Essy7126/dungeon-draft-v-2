# Audit Blender — Centurion squelette des neiges

Date de consolidation : 2026-08-02

Ce document reprend les résultats des audits Blender déjà produits. Blender n'a pas été relancé pendant la validation finale Godot.

## Fichiers validés

- Source de production : `C:\Blender_AI_Test\Output\Snow_Centurion_Production_04.blend`
- Copie d'export : `C:\Blender_AI_Test\Output\Snow_Centurion_Godot_Export_05.blend`
- Round-trip glTF : `C:\Blender_AI_Test\Output\Snow_Centurion_GLTF_Roundtrip_05.blend`
- GLB : `C:\Blender_AI_Test\Output\godot_export\skeleton_snow_centurion_character_v01.glb`
- SHA-256 du GLB : `3353E7EF8341E46B691BBB1DC315F519543D050AD8692E9E8C07A851D38E9761`
- Taille du GLB : 9 790 772 octets

## Structure exportée

- Un rig `CHR_SnowCenturion_Rig` et un mesh skinné `CHR_SnowCenturion_Mesh`.
- 24 os, racine `Hips`, hiérarchie conforme au rig source.
- Écart maximal de rest pose après round-trip : `8.36e-06` sur les matrices monde.
- 3 513 triangles source et après export.
- 4 955 sommets après séparation glTF.
- Skin valide, aucun sommet sans poids, maximum 7 influences.
- Un matériau, une image 2048 × 2048.
- Aucune caméra et aucune lumière exportées.

Os : `Hips`, `LeftUpLeg`, `LeftLeg`, `LeftFoot`, `LeftToeBase`, `RightUpLeg`, `RightLeg`, `RightFoot`, `RightToeBase`, `Spine02`, `Spine01`, `Spine`, `LeftShoulder`, `LeftArm`, `LeftForeArm`, `LeftHand`, `RightShoulder`, `RightArm`, `RightForeArm`, `RightHand`, `neck`, `Head`, `head_end`, `headfront`.

## Actions de production

Le GLB contient exactement sept animations :

- `DD_SnowCenturion_Idle-loop`
- `DD_SnowCenturion_Walk-loop`
- `DD_SnowCenturion_Run-loop`
- `DD_SnowCenturion_Attack`
- `DD_SnowCenturion_HeavyAttack`
- `DD_SnowCenturion_Hit`
- `DD_SnowCenturion_Death`

Toutes ciblent les 24 os avec 240 F-Curves de pose, sans F-Curve objet, valeur non finie ou scale nul/négatif. Les Actions sources ont conservé leurs empreintes avant/après production.

Le Hit est natif au rig Snow : frames 1–22, durée Godot 0,70 s, 240 F-Curves, 24 groupes et 24 os animés. Son déplacement horizontal maximal de `Hips` est de 0,025627 m, son déplacement vertical maximal de 0,006453 m et sa rotation maximale mesurée de 33,889°. La revue trois-quarts et latérale l'a accepté pour la production.

Le round-trip glTF retrouve les sept Actions sans animation manquante ou inattendue. Les échantillons de pose restent dans la tolérance de 0,012 ; le plus grand écart du Hit est de 0,008139.

## Verdict Blender

`SNOW_CENTURION_BLENDER_EXPORT_VALIDATED`

