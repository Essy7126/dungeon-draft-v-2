# Audit Blender du Squelette

## Verdict rectifié

L'ancien verdict `SKELETON_WEAPON_VARIANTS_BLOCKED` est annulé conformément à la rectification utilisateur. L'absence d'armes importées n'empêche pas l'utilisation des deux gestes de combat.

« Les variantes utilisent des animations simulant une attaque de mêlée et un tir à distance. Les équipements visibles ne font pas partie de cette première version. »

Aucune épée, aucun arc, aucune flèche, aucun carquois et aucun accessoire de main n'a été créé.

## Protection de la source

- Original : `C:\Blender_AI_Test\input\squelette.blend`
- Taille originale : 10 519 928 octets
- Modification originale : 2026-08-01 23:56:13 +02:00
- SHA-256 original : `33101993D5E6827A5BA3065C526733EF4F58CA829FA4E5D699FFD1886E36BA94`
- Copie de travail : `C:\Blender_AI_Test\Output\Skeleton_Current_Source_01.blend`
- Taille de la copie : 10 523 890 octets
- SHA-256 de la copie : `1C3033D56FD162402DE070862067312361D830861858253E3207220387EF60A9`
- Fichier de production : `C:\Blender_AI_Test\Output\Skeleton_Production_02.blend`
- Staging export : `C:\Blender_AI_Test\Output\Skeleton_Godot_Export_03.blend`
- Round-trip : `C:\Blender_AI_Test\Output\Skeleton_GLTF_Roundtrip_03.blend`

L'original n'a jamais été écrasé. Les Actions sources sont restées rigoureusement inchangées.

## Mesh, skin et matériaux

- Un mesh visible : `CHR_Skeleton_Mesh`
- 2 165 sommets Blender ; 3 795 sommets après séparation glTF
- 4 054 faces / 4 054 triangles
- Une UV map
- Un matériau : `Material_1`
- Une texture 2048 × 2048 avec alpha
- 23 vertex groups
- Aucun sommet non pondéré
- Aucun poids négatif
- Somme des poids : min 0,999999870 ; max 1,000000142 ; moyenne 1,000000007
- Maximum : 9 influences par sommet
- Export glTF : `JOINTS_0..2` et `WEIGHTS_0..2`, donc toutes les influences utiles sont conservées

## Rig

- Rig maître : `CHR_Skeleton_Rig`
- Datablock : `CHR_Skeleton_Skeleton`
- 24 os
- Racine : `Hips`
- Mains auditées : `LeftHand`, `RightHand`
- Pieds : `LeftFoot`, `RightFoot`, `LeftToeBase`, `RightToeBase`
- Contraintes de pose : aucune
- Slot compatible : `OBArmature`
- Les onze Actions sources référencent uniquement les 24 os existants
- Aucun NaN, Inf, scale nul ou scale négatif

La collection maître est `SKELETON_MASTER`. Les données brutes sont conservées et masquées dans `_SKELETON_RAW`.

## Équipement

- Épée : absente
- Arc : absent
- Flèches : absentes
- Carquois : absent
- Bouclier : absent
- Accessoires distincts ou parentés aux mains : aucun

Les `BoneAttachment3D` Godot créés sur `LeftHand` et `RightHand` servent uniquement d'origines d'effet. Ils ne contiennent aucun équipement.

## Actions de production

| Action | Source | Frames Blender | Correction |
|---|---|---:|---|
| `DD_Skeleton_Idle-loop` | `Idle_11` | 1–58 | copie indépendante |
| `DD_Skeleton_Walk-loop` | `Walking` | 1–31 | répétition finale exclue, horizontal in-place |
| `DD_Skeleton_Run-loop` | `Running` | 1–19 | répétition finale exclue, horizontal in-place |
| `DD_Skeleton_MeleeAttack` | `Thrust_Slash` | 1–91 | dérive horizontale retirée |
| `DD_Skeleton_RangedAttack` | `Draw_and_Shoot_from_Back` | 1–175 | attente 139–199 retirée, dérive horizontale retirée |
| `DD_Skeleton_Hit` | `Electrocution_Reaction` | 1–141 | copie indépendante |
| `DD_Skeleton_Death` | `dying_backwards` | 1–68 | dérive horizontale ramenée de 1,198 m à 0,450 m |

Les neuf F-Curves objet constantes ont été retirées uniquement dans chaque copie. Les 240 F-Curves de pose ont été conservées. Aucun NLA, bake, Cycles Modifier, `transform_apply`, nouvel os Root ou socket Blender n'a été créé.

### Événements artistiques

- Mêlée : impact frame 23, normalisé `0,244444444`
- Distance : libération source frame 210, devenue frame 149 après retrait de l'attente, normalisée `0,850574713`
- Durées Godot mesurées après import : mêlée 1,25 s ; distance 1,45 s ; Hit 0,65 s ; Death 2,00 s

## Export et round-trip

- GLB : `C:\Blender_AI_Test\Output\godot_export\skeleton_character_v01.glb`
- Taille : 8 358 564 octets
- SHA-256 : `048245A6A4A35A97AA73CAE04FD9A4C1C4F693C28ACBE26C8E0AFE30A4BE1827`
- Un mesh, un skin, un matériau, une image, sept animations
- Aucune caméra, lumière, scène de revue, copie brute ou arme
- Erreur matricielle absolue maximale du round-trip aux échantillons 0/25/50/75/100 % : `4,8070389311760664e-05`
- Verdict round-trip : réussi

Godot consomme le suffixe glTF `-loop` : `DD_Skeleton_Idle-loop`, `Walk-loop` et `Run-loop` apparaissent sous les noms `DD_Skeleton_Idle`, `DD_Skeleton_Walk` et `DD_Skeleton_Run`, avec `Animation.LOOP_LINEAR` préservé.

## Revue visuelle Blender

Les planches sources sont dans `C:\Blender_AI_Test\Output\skeleton_animation_review\`. Les images sélectionnées pour le rapport sont copiées dans `res://artifacts/skeleton_first_enemy/`.
