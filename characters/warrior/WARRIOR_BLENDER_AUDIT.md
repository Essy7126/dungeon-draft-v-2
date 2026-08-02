# Audit Blender et export du Guerrier

Verdict Blender : **VALIDÉ AVEC AVERTISSEMENTS**.

## Source autoritaire

- Fichier actif reçu : `C:\Blender_AI_Test\input\Guerrier.blend`
- Taille : 268 700 368 octets
- Dernière modification relevée : 2026-08-01 20:40:34 (Europe/Paris)
- SHA-256 : `57E050994BC0A9BAE338F8B5F27E861D350086D95A4FD8603D7196C2F9DD7B47`
- Copie de travail : `C:\Blender_AI_Test\Output\Warrior_Current_Source_02.blend`
- Text datablock : `WARRIOR_CURRENT_SOURCE_REPORT`

La scène active contenait exactement un couple visible `Armature` + `char1`. Aucun ancien objet Mesh ou Armature n'était encore lié à une scène. Aucun second rig n'a été restauré, fusionné ou importé. Douze anciens matériaux sans objet ont été inventoriés et conservés avec fake user ; aucun datablock n'a été supprimé.

## Rig et mesh

- Rig maître : `CHR_Warrior_Rig`
- Datablock : `CHR_Warrior_Skeleton`
- Mesh maître : `CHR_Warrior_Mesh`
- Collection : `WARRIOR_MASTER`
- 24 os, racine `Hips`
- Mains : `LeftHand`, `RightHand`
- Avant-bras : `LeftForeArm`, `RightForeArm`
- Pieds : `LeftFoot`, `LeftToeBase`, `RightFoot`, `RightToeBase`
- Comparaison historique : noms, hiérarchie, racine et matrices de repos strictement identiques à `Warrior_Blender_Audit_01.blend`
- Objet Armature : position et rotation nulles, échelle `0.01`
- Mesh : 46 280 sommets, 92 780 faces/triangles, 22 groupes de sommets, une UV `uv`
- Pondération : jusqu'à 11 influences par sommet ; 0 sommet non pondéré, 0 poids négatif, 0 somme de poids anormale, 0 groupe pondéré sans os
- Matériau : `Material_1.011`, texture 4096 x 4096 empaquetée
- Parentage et modificateur Armature conservés

## Actions sources et sélection de production

Les 29 Actions présentes ont été testées sur le rig actuel avec leur Action Slot Blender 5.1. Les neuf sources retenues sont assignables et évaluables ; leurs 24 os animés existent tous. Aucune Action source n'a été renommée ou modifiée.

| Action de production | Source | Frames | Slot | Traitement |
|---|---|---:|---|---|
| `DD_Warrior_Idle-loop` | `Idle_8` | 1-241 | `OBArmature` | copie, courbes objet retirées |
| `DD_Warrior_Walk-loop` | `Walking` | 1-32 | `OBArmature` | copie, courbes objet retirées |
| `DD_Warrior_Run-loop` | `Running` | 1-20 | `OBArmature` | copie, courbes objet retirées |
| `DD_Warrior_Attack` | `Reaping_Swing` | 1-179 | `OBArmature` | dérive horizontale linéaire retirée |
| `DD_Warrior_SpinAttack` | `Double_Blade_Spin` | 1-171 | `OBArmature` | dérive horizontale linéaire retirée |
| `DD_Warrior_HeavyAttack` | `Sword_Judgment` | 1-132 | `OBArmature` | dérive horizontale linéaire retirée |
| `DD_Warrior_Parry` | `Sword_Parry_Backward_2` | 1-18 | `OBArmature` | dérive horizontale linéaire retirée |
| `DD_Warrior_Hit` | `Hit_Reaction_1` | 1-38 | `OBArmature` | copie, courbes objet retirées |
| `DD_Warrior_Death` | `Dead` | 1-90 | `OBArmature` | correction progressive world-XY in-place |

Chaque Action produite contient 240 F-Curves de pose, 24 groupes et 24 os animés. Validation commune : aucun os absent, aucune F-Curve d'objet, aucun NaN/Inf, aucune échelle nulle ou négative, aucun modifier Cycles et aucun strip NLA.

`Simple_Kick` est **rejetée** : son déplacement vertical de Hips atteint environ 2,22 m et le personnage quitte le cadre tactique utile. `DD_Warrior_Kick` n'a donc pas été créée.

## Mort et impacts

La source `Dead` commence debout, produit une chute réelle, finit couchée sans reprise ni boucle et garde une pose finale stable. Durée : 90 frames à 30 FPS, soit 3,0 s. Déplacement source de Hips : environ 0,693 m horizontal, -0,638 m vertical, 0,942 m total. Le déplacement horizontal dépassant 0,45 m, la copie de production annule progressivement le world-XY tout en préservant la chute verticale, les rotations et tous les autres os. Résidu horizontal final : `1.067e-7 m`.

Vidéos de revue :

- `C:\Blender_AI_Test\Output\warrior_animation_review\warrior_death_threequarter.mp4`
- `C:\Blender_AI_Test\Output\warrior_animation_review\warrior_death_side.mp4`
- `C:\Blender_AI_Test\Output\warrior_animation_review\warrior_death_inplace_threequarter.mp4`
- `C:\Blender_AI_Test\Output\warrior_animation_review\warrior_death_inplace_side.mp4`

| Action | Anticipation | Impact | Récupération | Temps d'impact | Normalisé |
|---|---:|---:|---:|---:|---:|
| Attack | 124 | 129 | 179 | 4,2667 s | 0,719101 |
| SpinAttack | 38 | 40 | 171 | 1,3000 s | 0,229412 |
| HeavyAttack | 31 | 47 | 132 | 1,5333 s | 0,351145 |
| Parry | 5 | 11 | 18 | 0,3333 s | 0,588235 |

## Export et round-trip

- Production : `C:\Blender_AI_Test\Output\Warrior_Production_03.blend`
- Text datablock : `WARRIOR_PRODUCTION_REPORT`
- Staging : `C:\Blender_AI_Test\Output\Warrior_Godot_Export_04.blend`
- Text datablock : `WARRIOR_GODOT_EXPORT_REPORT`
- GLB : `C:\Blender_AI_Test\Output\godot_export\warrior_character_v01.glb`
- Taille GLB : 31 351 800 octets
- SHA-256 GLB : `30A349164DAE5FB63B11C16B6BF0B25C6D8E8174B0337E092928BBFD43D60B69`
- Contenu GLB : 1 scène, 1 mesh/primitive, 92 780 triangles, 1 skin de 24 joints, 1 matériau, 1 image et 9 animations exactes
- Attributs d'influence exportés : `JOINTS_0..2` et `WEIGHTS_0..2`
- Round-trip : `C:\Blender_AI_Test\Output\Warrior_GLTF_Roundtrip_04.blend`
- Erreur maximale de rest matrix : `0.000827789`, sous la tolérance `0.001`
- Erreur maximale de pose monde échantillonnée : `1.10865e-5`
- Structure, hiérarchie, actions, modificateur et limites animées : validés et finis

## Avertissements

- Le modèle source ne contient ni arme ni socket d'arme ; aucun n'a été inventé.
- La chute verticale de Death est volontairement conservée et certaines parties du corps passent sous le plan initial du sol.
- L'exporteur signale plusieurs nœuds de texture dans le matériau, mais ils référencent la même image empaquetée ; le GLB final contient une image.
- L'importeur Blender du round-trip crée un helper `Icosphere`; le JSON GLB ne contient qu'un seul mesh de personnage.

