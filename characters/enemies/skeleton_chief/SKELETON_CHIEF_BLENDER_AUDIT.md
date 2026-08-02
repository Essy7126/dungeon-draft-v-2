# Audit Blender — Chef squelette

## Source sécurisée

- Source active relevée dans Blender 5.1.2 : `C:\Blender_AI_Test\input\chef_squelette.blend`
- Taille originale : 11 080 477 octets
- Date originale : 2026-08-02 10:38:45
- SHA-256 original : `63CD92A92F9675E687C0F402F0E455E925428B892F9714A550C37FCEE3C9E84F`
- Copie de travail : `C:\Blender_AI_Test\Output\Skeleton_Chief_Current_Source_01.blend`
- Scène active : `Scene`
- Collection active : `Collection`
- Rapport embarqué : `SKELETON_CHIEF_AUDIT_REPORT`

La source originale n’a jamais été écrasée. La copie de travail a ensuite reçu le Text datablock d’audit, ce qui explique que son hash final diffère du hash original.

## Inventaire principal

La scène source contient quatre objets : `Armature`, `char1`, `Camera` et `Light`. Le couple personnage est `Armature` + `char1`; le mesh est parenté au rig et son modificateur `Armature` cible ce rig. Il n’existe aucun accessoire séparé. Le casque, le cimier rouge, l’armure, la cape et les brassards font partie du mesh skinné. Aucune épée ni aucun bouclier n’est réellement présent.

Mesh :

- 2 287 sommets, 3 354 faces et 3 354 triangles;
- UV `uv`, normales personnalisées;
- un matériau `Material_1`;
- texture `texture_0.png`, 2 048 × 2 048, sRGB, packed;
- dimensions objet : `(0,963707 ; 1,515451 ; 0,968086)`;
- AABB monde : min `(-0,621052 ; -0,608492 ; 0,065042)`, max `(0,342655 ; 0,359594 ; 1,580493)`;
- 0 sommet non pondéré, 0 poids négatif;
- somme des poids exactement 1,0;
- maximum 5 influences;
- histogramme : 1 influence = 1 035 sommets, 2 = 767, 3 = 155, 4 = 233, 5 = 97.

Rig :

- 24 os, racine unique `Hips`;
- hiérarchie Meshy habituelle et compatible avec le pipeline existant;
- mains `LeftHand`/`RightHand`, pieds `LeftFoot`/`RightFoot`, tête `Head`;
- aucune contrainte;
- objet rig à location/rotation nulles, scale `(0,01 ; 0,01 ; 0,01)`;
- aucun retargeting vers le Squelette standard.

Os : `Hips`, `LeftUpLeg`, `LeftLeg`, `LeftFoot`, `LeftToeBase`, `RightUpLeg`, `RightLeg`, `RightFoot`, `RightToeBase`, `Spine02`, `Spine01`, `Spine`, `LeftShoulder`, `LeftArm`, `LeftForeArm`, `LeftHand`, `RightShoulder`, `RightArm`, `RightForeArm`, `RightHand`, `neck`, `Head`, `head_end`, `headfront`.

## Actions sources

Chaque Action source comporte 249 F-Curves : 240 courbes `pose.bones` couvrant les 24 os, plus 9 courbes techniques constantes sur l’objet Armature. Aucun os manquant, NaN, Inf ou scale nulle/négative n’a été trouvé.

| Action source | Frames | Durée à 30 FPS | Classification réelle | Décision |
|---|---:|---:|---|---|
| `Idle_02` | 1–71 | 2,333 s | Idle bouclable | retenue, doublon terminal retiré |
| `Walking` | 1–32 | 1,033 s | Walk in-place | retenue, doublon terminal retiré |
| `Running` | 1–20 | 0,633 s | Run in-place | retenue, doublon terminal retiré |
| `Right_Hand_Sword_Slash` | 1–46 | 1,500 s | balayage principal sans arme | retenue |
| `Charged_Ground_Slam` | 1–91 | 3,000 s | frappe lourde au sol distincte | retenue |
| `Hit_Reaction_1` | 1–38 | 1,233 s | Hit | retenue |
| `Dead` | 1–90 | 2,967 s | chute réelle, pose finale stable | retenue avec plafonnement horizontal |
| `dying_backwards` | 1–68 | 2,233 s | autre mort | rejetée, dérive horizontale supérieure |
| `Block10` | 1–18 | 0,567 s | blocage/déplacement extrême | rejetée |
| `Shield_Push_Left` | 1–73 | 2,400 s | poussée ambiguë sans bouclier | rejetée |
| `Spear_Walk` | 1–34 | 1,100 s | marche nommée lance sans lance | rejetée |
| `Charged_Spell_Cast` | 1–81 | 2,667 s | cast | rejetée, aucun pouvoir magique arbitraire |
| `Axe_Breathe_and_Look_Around` | 1–340 | 11,300 s | respiration longue nommée hache | rejetée, hache absente |

Les revues trois-quarts et latérales sont conservées dans `C:\Blender_AI_Test\Output\skeleton_chief_animation_review\`.

## Production

Fichier : `C:\Blender_AI_Test\Output\Skeleton_Chief_Production_02.blend`  
SHA-256 : `C6DAAB69303156E3311776564DF2F9D638B2C7AA0C671EDE5704C123FF7C4266`

La collection `SKELETON_CHIEF_MASTER` contient `CHR_SkeletonChief_Rig` / `CHR_SkeletonChief_Skeleton` et `CHR_SkeletonChief_Mesh`. Tous les objets sources restent dans `_SKELETON_CHIEF_RAW`, masquée viewport/rendu. Aucune source n’a été renommée, supprimée ou modifiée; leurs empreintes avant/après sont identiques.

Actions produites :

- `DD_SkeletonChief_Idle-loop`, frames 1–70;
- `DD_SkeletonChief_Walk-loop`, frames 1–31;
- `DD_SkeletonChief_Run-loop`, frames 1–19;
- `DD_SkeletonChief_Attack`, frames 1–46;
- `DD_SkeletonChief_HeavyAttack`, frames 1–91;
- `DD_SkeletonChief_Hit`, frames 1–38;
- `DD_SkeletonChief_Death`, frames 1–90.

Les courbes objet techniques ont été supprimées uniquement des copies de production. Aucun Cycles Modifier, strip NLA, bake, `transform_apply`, nouvel os, socket ou accessoire n’a été créé. Walk/Run étaient déjà in-place. Pour Death, seule la portion de dérive horizontale dépassant 0,45 m a été retranchée progressivement; la translation verticale évaluée de Hips (`-0,482407 m`) et toutes les rotations sont strictement conservées. La dérive terminale mesurée est `0,450000 m`.

## Export et round-trip

- Copie d’export : `C:\Blender_AI_Test\Output\Skeleton_Chief_Godot_Export_03.blend`
- GLB : `C:\Blender_AI_Test\Output\godot_export\skeleton_chief_character_v01.glb`
- Taille GLB : 8 882 820 octets
- SHA-256 GLB : `7C407445E2FCE819CA0275E1F706762CFCA18872768D2C36952C41600F7CFF24`
- Contenu : 1 rig, 1 mesh, 1 skin/24 joints, 3 354 triangles, 1 matériau, 1 image et 7 animations;
- `JOINTS_0/WEIGHTS_0` et `JOINTS_1/WEIGHTS_1` présents;
- aucune caméra ni lumière exportée.

Round-trip : `C:\Blender_AI_Test\Output\Skeleton_Chief_GLTF_Roundtrip_03.blend`. Les 24 os, leurs parents, le skin, les triangles, le matériau et les sept durées correspondent. Les poses à 0 %, 25 %, 50 %, 75 % et 100 % ont un écart matriciel monde maximal inférieur à `0,00001`; validation : PASS.
