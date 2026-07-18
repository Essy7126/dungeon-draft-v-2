# ElfVisual3D — configuration et validation

## Verdict

`ELF_VISUAL_COMPONENT_VALIDATED_WITH_WARNINGS`

Le composant visuel est instanciable et son API, ses sockets, ses signaux et ses opérations d’attachement ont été validés sans erreur. Les avertissements concernent l’échelle `0,01` héritée du rig importé, la calibration future du signal de libération du sort, le déplacement de `Hips` dans Death et l’absence d’animation Bow Attack.

## Audit préalable du commit `e1cce88`

Commandes exécutées en lecture seule avant les modifications :

```text
git status --short
git branch --show-current
git log -5 --oneline --decorate
git show --no-ext-diff --stat --summary e1cce88
git show --no-ext-diff --format=fuller --name-status e1cce88
git branch -r --contains e1cce88
git branch --contains e1cce88
```

Résultat :

- Commit complet : `e1cce882ac74812db9eb28cb75ead6daedd4802c`
- Sujet : `test(elf): add import and animation validation scenes`
- Auteur : `Essy7126 <paolomontebello81@gmail.com>`
- Date d’auteur : `Sat Jul 18 15:03:58 2026 +0200`
- Committer : `Essy7126 <paolomontebello81@gmail.com>`
- Date de commit : `Sat Jul 18 15:03:58 2026 +0200`
- Branche locale courante : `main`
- Branche locale contenant le commit : `main`
- Branches distantes contenant le commit : `origin/main` et `origin/HEAD -> origin/main`

Fichiers du commit :

```text
A  tests/characters/elf/ElfAnimationValidation.tscn
A  tests/characters/elf/elf_animation_validation.gd
A  tests/characters/elf/elf_import_audit.gd
```

Le commit ajoute 704 lignes dans trois nouveaux fichiers. Il correspond exclusivement au travail d’import et de validation de l’elfe. Il ne contient aucune suppression, aucune modification de gameplay et aucun changement sans rapport. Il ne chevauche pas les nouveaux fichiers de production `res://characters/elf/` ni les nouveaux fichiers de validation du composant. Il a donc été conservé tel quel.

Changements non commités présents avant cette tâche :

```text
?? tests/characters/elf/ELF_IMPORT_VALIDATION.md
?? tests/characters/elf/elf_animation_validation.gd.uid
?? tests/characters/elf/elf_import_audit.gd.uid
```

Ces fichiers ont été préservés. Aucune commande `reset`, `revert`, `checkout`, `restore`, `rebase`, `amend`, suppression de branche ou modification de remote n’a été exécutée.

## Arborescence de production

```text
ElfVisual3D [Node3D] — elf_visual_3d.gd
├── ModelPivot [Node3D]
│   └── ElfModel — instance de elf_character_v01.glb
├── Debug [Node3D]
├── VisualController [Node]
├── WeaponSocketLeft [BoneAttachment3D]
│   └── WeaponMountLeft [Node3D, Transform3D.IDENTITY]
│       └── DebugLeftHandMarker [Node3D, masqué par défaut]
│           ├── Center
│           ├── AxisX
│           ├── AxisY
│           └── AxisZ
└── WeaponSocketRight [BoneAttachment3D]
    └── WeaponMountRight [Node3D, Transform3D.IDENTITY]
        └── DebugRightHandMarker [Node3D, masqué par défaut]
            ├── Center
            ├── AxisX
            ├── AxisY
            └── AxisZ
```

Le GLB est instancié directement et ses ressources ne sont pas dupliquées. Ses enfants n’ont pas été rendus éditables de manière permanente.

Chemins résolus depuis `ElfVisual3D` :

- `AnimationPlayer` : `ModelPivot/ElfModel/AnimationPlayer`
- `Skeleton3D` : `ModelPivot/ElfModel/EXP_Elf_Rig/Skeleton3D`
- `MeshInstance3D` : `ModelPivot/ElfModel/EXP_Elf_Rig/Skeleton3D/EXP_Elf_Mesh`

Le GLB reste inchangé, avec le SHA-256 :

```text
A9FECCA234EC89D5309421F16B5E33D5B1D7D00C183423BB51DD3100CFD76931
```

## Inspection des 24 os

`get_bone_global_rest()` renvoie ici des positions en unités du squelette importé. Le nœud de squelette applique une échelle globale `(0,01 ; 0,01 ; 0,01)` ; les longueurs ci-dessous sont donc également fournies en mètres dans le monde. Lorsqu’un os possède plusieurs enfants, chaque distance est indiquée.

| Index | Os | Parent index | Parent | Position globale au repos, unités squelette | Longueur approximative vers enfant(s), monde |
|---:|---|---:|---|---|---|
| 0 | `Hips` | -1 | — | `(0,0000 ; 101,3597 ; 18,7224)` | LeftUpLeg `0,1601 m` ; RightUpLeg `0,1486 m` ; Spine02 `0,1223 m` |
| 1 | `LeftUpLeg` | 0 | `Hips` | `(12,6268 ; 91,5597 ; 17,8234)` | LeftLeg `0,3973 m` |
| 2 | `LeftLeg` | 1 | `LeftUpLeg` | `(17,9708 ; 52,3599 ; 14,2271)` | LeftFoot `0,4134 m` |
| 3 | `LeftFoot` | 2 | `LeftLeg` | `(23,1041 ; 12,0184 ; 6,8026)` | LeftToeBase `0,1201 m` |
| 4 | `LeftToeBase` | 3 | `LeftFoot` | `(25,7277 ; 3,4292 ; 14,7776)` | — |
| 5 | `RightUpLeg` | 0 | `Hips` | `(-11,2741 ; 91,7064 ; 17,9573)` | RightLeg `0,3904 m` |
| 6 | `RightLeg` | 5 | `RightUpLeg` | `(-16,1389 ; 53,0931 ; 14,8969)` | RightFoot `0,4196 m` |
| 7 | `RightFoot` | 6 | `RightLeg` | `(-22,3734 ; 12,3836 ; 6,8729)` | RightToeBase `0,1233 m` |
| 8 | `RightToeBase` | 7 | `RightFoot` | `(-25,3838 ; 3,4348 ; 14,8042)` | — |
| 9 | `Spine02` | 0 | `Hips` | `(0,1186 ; 113,3473 ; 16,3201)` | Spine01 `0,1223 m` |
| 10 | `Spine01` | 9 | `Spine02` | `(0,2372 ; 125,3348 ; 13,9177)` | Spine `0,1223 m` |
| 11 | `Spine` | 10 | `Spine01` | `(0,3558 ; 137,3224 ; 11,5154)` | LeftShoulder `0,0402 m` ; RightShoulder `0,0412 m` ; neck `0,0544 m` |
| 12 | `LeftShoulder` | 11 | `Spine` | `(3,2916 ; 139,6484 ; 10,0497)` | LeftArm `0,1183 m` |
| 13 | `LeftArm` | 12 | `LeftShoulder` | `(15,0348 ; 139,6484 ; 8,5841)` | LeftForeArm `0,2264 m` |
| 14 | `LeftForeArm` | 13 | `LeftArm` | `(29,7069 ; 122,4110 ; 8,9513)` | LeftHand `0,2468 m` |
| 15 | `LeftHand` | 14 | `LeftForeArm` | `(48,4110 ; 107,7389 ; 15,6016)` | — |
| 16 | `RightShoulder` | 11 | `Spine` | `(-2,6498 ; 139,6484 ; 9,9194)` | RightArm `0,1213 m` |
| 17 | `RightArm` | 16 | `RightShoulder` | `(-14,6721 ; 139,6484 ; 8,3233)` | RightForeArm `0,2143 m` |
| 18 | `RightForeArm` | 17 | `RightArm` | `(-27,8749 ; 122,7762 ; 8,0823)` | RightHand `0,2516 m` |
| 19 | `RightHand` | 18 | `RightForeArm` | `(-47,3123 ; 108,4721 ; 15,1870)` | — |
| 20 | `neck` | 11 | `Spine` | `(0,4788 ; 142,6530 ; 10,4471)` | Head `0,1029 m` |
| 21 | `Head` | 20 | `neck` | `(0,7115 ; 152,7350 ; 8,4266)` | head_end `0,1943 m` ; headfront `0,1607 m` |
| 22 | `head_end` | 21 | `Head` | `(1,0489 ; 170,5668 ; 16,1265)` | — |
| 23 | `headfront` | 21 | `Head` | `(0,7115 ; 152,7350 ; 24,4987)` | — |

Le relevé JSON complet est conservé hors projet sous `C:\Blender_AI_Test\Output\godot_elf_skeleton_rest.json`.

## Os de mains et avant-bras retenus

- Main gauche : `LeftHand`, index 15
- Avant-bras gauche : `LeftForeArm`, index 14
- Main droite : `RightHand`, index 19
- Avant-bras droit : `RightForeArm`, index 18

La sélection est non ambiguë : les deux noms contiennent explicitement `Hand`, chaque main est directement enfant du `ForeArm` correspondant, et les positions latérales au repos sont cohérentes (`x = +48,4110` à gauche et `x = -47,3123` à droite dans les unités du squelette). Aucun os n’a été choisi uniquement parce qu’il termine une chaîne.

## Architecture des sockets

Les `BoneAttachment3D` sont placés dans la scène enveloppe, comme frères de `ModelPivot`, et utilisent :

```text
use_external_skeleton = true
external_skeleton = ../ModelPivot/ElfModel/EXP_Elf_Rig/Skeleton3D
override_pose = false
```

`WeaponSocketLeft.bone_name = "LeftHand"` et `WeaponSocketRight.bone_name = "RightHand"`.

Ce choix évite d’ajouter des enfants au `Skeleton3D` importé et reste robuste au réimport tant que le chemin structurel et les noms d’os du GLB restent stables. Les sockets copient uniquement la transformation des os ; ils ne remplacent aucune pose.

Les `WeaponMountLeft` et `WeaponMountRight` ont position et rotation nulles et `scale = Vector3.ONE`. Leur orientation n’a pas été corrigée à l’aveugle : ils constituent les offsets à calibrer lorsque les véritables scènes d’armes seront disponibles.

Le rig importé possède une échelle globale `0,01`. Les géométries des marqueurs sont donc exprimées en unités centimétriques du squelette afin de produire des axes d’environ 5 cm dans le monde, sans modifier le transform des WeaponMount. Un futur équipement attaché avec une racine identité doit respecter cette même convention d’unité, ou contenir sa compensation visuelle dans ses propres enfants.

## Marqueurs debug

- Propriété exportée : `show_socket_debug`, valeur par défaut `false`
- Marqueur gauche : `DebugLeftHandMarker`
- Marqueur droit : `DebugRightHandMarker`
- Représentation : centre jaune et axes locaux X rouge, Y vert, Z bleu
- Envergure mondiale approximative : 5 cm

Lorsque `show_socket_debug` est faux, les deux racines de marqueur sont invisibles. Aucun faux arc n’a été créé.

## API publique d’animation

Constantes `StringName` :

```text
ANIM_IDLE       = Elf_Idle
ANIM_WALK       = Elf_Walk
ANIM_RUN        = Elf_Run
ANIM_CAST_FULL  = Elf_Cast_Full
ANIM_CAST_START = Elf_Cast_Start
ANIM_CAST_HOLD  = Elf_Cast_Hold
ANIM_CAST_END   = Elf_Cast_End
ANIM_HIT        = Elf_Hit
ANIM_DEATH      = Elf_Death
```

Méthodes :

- `play_idle(blend_time: float = 0.15)`
- `play_walk(speed_scale: float = 1.0, blend_time: float = 0.1)`
- `play_run(speed_scale: float = 1.0, blend_time: float = 0.1)`
- `play_cast_full(speed_scale: float = 1.0)`
- `play_cast_start(speed_scale: float = 1.0)`
- `play_cast_hold(speed_scale: float = 1.0)`
- `play_cast_end(speed_scale: float = 1.0)`
- `play_hit(speed_scale: float = 1.0)`
- `play_death(speed_scale: float = 1.0)`
- `play_animation(animation_name, speed_scale, blend_time)`
- `stop_animation()`
- `reset_to_idle()`
- `get_animation_player()`
- `get_skeleton()`
- `get_left_weapon_mount()`
- `get_right_weapon_mount()`
- `get_current_animation()`
- `is_animation_playing(animation_name = &"")`
- `attach_to_left_hand(item)` / `attach_to_right_hand(item)`
- `clear_left_hand()` / `clear_right_hand()`
- `get_left_hand_item()` / `get_right_hand_item()`

Idle démarre automatiquement dans `_ready()`. Idle, Walk et Run utilisent leurs boucles importées. Hit, Cast Full et Cast End reviennent vers Idle. Cast Start ne lance pas Cast Hold, Cast Hold n’est pas forcé en boucle, et Death ne revient jamais automatiquement vers Idle. Les vitesses sont passées comme vitesse propre à chaque lecture ; `AnimationPlayer.speed_scale` est restauré à 1. Les demandes invalides utilisent `push_warning` et sont ignorées.

Signaux :

- `animation_started(animation_name)`
- `animation_finished(animation_name)`
- `death_animation_finished`
- `cast_release_reached`
- `hit_reaction_finished`

`cast_release_reached` est émis une fois par lecture de Cast Full lorsque la position atteint `cast_release_normalized_time`, initialisé à `0,32`. Aucune piste de l’animation importée n’a été modifiée ou ajoutée. Cette valeur devra être calibrée visuellement avec le futur effet de sort.

## Attachement dynamique

L’API refuse proprement `null`, détache l’objet de son ancien parent, le place sous le WeaponMount demandé et applique `Transform3D.IDENTITY`. Un objet déjà présent est remplacé sans être libéré. Son parent et son transform d’origine sont mémorisés et restaurés lors de `clear_left_hand()` ou `clear_right_hand()` lorsque ce parent existe encore. Le squelette et les BoneAttachment ne sont jamais modifiés.

## Validation du composant

Scène : `res://tests/characters/elf/ElfVisualComponentValidation.tscn`

Contrôles :

```text
1–9 : animations
L   : afficher/masquer les sockets
G   : attacher/détacher l’objet gauche
D   : attacher/détacher l’objet droit
C   : changer de caméra
R   : retour Idle
```

Résultats automatiques :

- `ElfVisual3D` instanciable : réussi
- AnimationPlayer, Skeleton3D et MeshInstance3D trouvés : réussi
- 24 os et neuf animations : réussi
- sockets sur deux os valides et distincts : réussi
- `override_pose=false` et squelette externe résolu : réussi
- WeaponMount identité : réussi
- marqueurs cachés par défaut : réussi
- toutes les méthodes publiques appelées sans erreur : réussi
- demandes nulles/invalides refusées sans erreur : réussi
- remplacement et restauration du parent/transform des objets : réussi
- signaux animation, Death, Hit et Cast Release : réussi
- Cast Release émis exactement une fois par lecture contrôlée : réussi
- objets gauche et droit stables relativement aux mains : réussi pour Idle, Walk, Run, Cast Full, Hit et Death
- aucune variation de scale local ou global pendant ces animations : réussi
- mesh, skin, squelette, poses de repos et GLB inchangés : réussi
- Death conserve le déplacement de Hips sans déplacer `ElfVisual3D` : réussi

Rapport machine : `C:\Blender_AI_Test\Output\godot_elf_visual_component\component_validation.json`.

Captures contrôlées :

```text
C:\Blender_AI_Test\Output\godot_elf_visual_component\elf_idle.png
C:\Blender_AI_Test\Output\godot_elf_visual_component\elf_walk.png
C:\Blender_AI_Test\Output\godot_elf_visual_component\elf_run.png
C:\Blender_AI_Test\Output\godot_elf_visual_component\elf_cast_full.png
C:\Blender_AI_Test\Output\godot_elf_visual_component\elf_hit.png
C:\Blender_AI_Test\Output\godot_elf_visual_component\elf_death.png
```

## Death et limites actuelles

Death conserve intégralement sa translation animée de `Hips`. Le nœud racine `ElfVisual3D`, `ModelPivot` et le squelette externe ne reçoivent aucun déplacement applicatif. Aucun root motion n’a été extrait, recentré ou neutralisé.

Limites :

1. Les offsets et orientations réels des armes restent à calibrer dans les WeaponMount avec les futurs modèles d’équipement.
2. Les équipements doivent respecter l’échelle `0,01` du rig ou encapsuler leur compensation dans leur propre hiérarchie visuelle.
3. `cast_release_normalized_time = 0,32` est une approximation à valider avec le futur VFX/projectile.
4. Aucune Bow Attack n’est disponible dans ce GLB ; aucune API d’attaque à l’arc n’est exposée.
5. Les huit influences de skin importées sont conservées ; aucune conversion à quatre influences n’a été effectuée.

## Fichiers créés et modifiés

Créés pendant cette tâche :

```text
res://characters/elf/ElfVisual3D.tscn
res://characters/elf/elf_visual_3d.gd
res://characters/elf/elf_visual_3d.gd.uid                 (généré par Godot)
res://characters/elf/ELF_VISUAL_SETUP.md
res://tests/characters/elf/ElfVisualComponentValidation.tscn
res://tests/characters/elf/elf_visual_component_validation.gd
res://tests/characters/elf/elf_visual_component_validation.gd.uid  (généré par Godot)
```

Aucun fichier de gameplay, `project.godot`, GLB, mesh, squelette, animation importée ou ressource artistique n’a été modifié.

## État Git final

```text
?? characters/elf/ELF_VISUAL_SETUP.md
?? characters/elf/ElfVisual3D.tscn
?? characters/elf/elf_visual_3d.gd
?? characters/elf/elf_visual_3d.gd.uid
?? tests/characters/elf/ELF_IMPORT_VALIDATION.md
?? tests/characters/elf/ElfVisualComponentValidation.tscn
?? tests/characters/elf/elf_animation_validation.gd.uid
?? tests/characters/elf/elf_import_audit.gd.uid
?? tests/characters/elf/elf_visual_component_validation.gd
?? tests/characters/elf/elf_visual_component_validation.gd.uid
```

Les trois entrées `ELF_IMPORT_VALIDATION.md`, `elf_animation_validation.gd.uid` et `elf_import_audit.gd.uid` étaient antérieures à cette tâche. Aucun commit et aucun push n’ont été effectués.
