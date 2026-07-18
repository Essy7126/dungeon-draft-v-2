# Validation d’import — personnage elfe

## Verdict

`IMPORT_VALIDATED_WITH_WARNINGS`

L’import est exploitable dans Godot : le squelette, le skin, le matériau, la texture et les neuf animations sont présents, et l’audit ne relève aucune influence invalide ni somme de poids incorrecte. Les avertissements concernent la normalisation automatique des suffixes `-loop`, la conservation de huit influences par sommet et le déplacement important de `Hips` pendant `Elf_Death`.

## Projet et environnement

- Racine du projet : `C:\Users\paolo\Documents\dungeon-draft-v-2`
- Version exécutée : Godot `4.6.3.stable.official.7d41c59c4`
- Feature déclarée par le projet : Godot `4.6`
- Renderer : `Forward+` (`forward_plus`)
- Pilote de rendu Windows configuré : `d3d12`
- Scène principale du projet : inchangée
- `project.godot` : inchangé ; aucun Input Action ajouté
- Scènes et scripts de gameplay : inchangés

## Source GLB

- Source : `C:\Blender_AI_Test\Output\godot_export\elf_character_v01.glb`
- Destination : `res://assets/characters/elf/elf_character_v01.glb`
- Taille : `33 955 284` octets
- SHA-256 attendu : `A9FECCA234EC89D5309421F16B5E33D5B1D7D00C183423BB51DD3100CFD76931`
- SHA-256 source : `A9FECCA234EC89D5309421F16B5E33D5B1D7D00C183423BB51DD3100CFD76931`
- SHA-256 destination : `A9FECCA234EC89D5309421F16B5E33D5B1D7D00C183423BB51DD3100CFD76931`
- Résultat : copie binaire conforme ; le fichier source n’a été ni déplacé ni modifié.

Godot a effectué l’import normalement. Aucun fichier interne de `.godot/` n’a été modifié manuellement. Le GLB et ses ressources d’import suivies ne présentent aucune différence Git après l’import.

## Arborescence importée

```text
GODOT_EXPORT [Node3D]
  EXP_Elf_Rig [Node3D]
    Skeleton3D [Skeleton3D]
      EXP_Elf_Mesh [MeshInstance3D]
  AnimationPlayer [AnimationPlayer]
```

- Nœud racine : `Node3D` nommé `GODOT_EXPORT`
- `Skeleton3D` : 1
- Os : 24
- Racine unique : `Hips`
- `MeshInstance3D` : 1
- Surfaces : 1
- Skin : présent
- Matériau : `Material_1.003`, présent
- Texture d’albédo : présente
- `AnimationPlayer` : 1

Os importés :

```text
Hips, LeftUpLeg, LeftLeg, LeftFoot, LeftToeBase,
RightUpLeg, RightLeg, RightFoot, RightToeBase,
Spine02, Spine01, Spine,
LeftShoulder, LeftArm, LeftForeArm, LeftHand,
RightShoulder, RightArm, RightForeArm, RightHand,
neck, Head, head_end, headfront
```

## Animations

Godot utilise conventionnellement le suffixe `-loop` comme instruction d’import, active la boucle, puis retire ce suffixe du nom exposé par `AnimationPlayer`. La correspondance observée est donc :

| Nom dans le GLB attendu | Nom exposé dans Godot | Durée | Boucle | Pistes |
|---|---|---:|---|---:|
| `Elf_Idle-loop` | `Elf_Idle` | 1,866667 s | oui, linéaire | 46 |
| `Elf_Walk-loop` | `Elf_Walk` | 1,000000 s | oui, linéaire | 46 |
| `Elf_Run-loop` | `Elf_Run` | 0,600000 s | oui, linéaire | 46 |
| `Elf_Cast_Full` | `Elf_Cast_Full` | 3,333333 s | non | 46 |
| `Elf_Cast_Start` | `Elf_Cast_Start` | 1,066667 s | non | 46 |
| `Elf_Cast_Hold` | `Elf_Cast_Hold` | 1,466667 s | non | 46 |
| `Elf_Cast_End` | `Elf_Cast_End` | 0,800000 s | non | 46 |
| `Elf_Hit` | `Elf_Hit` | 2,833333 s | non | 46 |
| `Elf_Death` | `Elf_Death` | 3,500000 s | non | 46 |

Les neuf contenus attendus sont présents. Seules Idle, Walk et Run bouclent. La différence de nom des trois boucles est une normalisation de l’importeur, pas une animation manquante.

## Surface et géométrie vues par Godot

- Mesh : `GODOT_EXPORT_char1_003`
- Nombre de surfaces : 1
- Format de surface : `34493963287`
- Sommets : `83 284`
- Indices : `311 391`
- AABB position : `(-0,576467216 ; -0,000000007 ; -0,275491655)`
- AABB taille : `(1,152934432 ; 1,699999928 ; 0,550983071)`
- AABB : cohérente pour un personnage d’environ 1,70 m

## Audit des influences de skin

- `Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS` : présent
- Entrées `Mesh.ARRAY_BONES` : `666 272`
- Entrées `Mesh.ARRAY_WEIGHTS` : `666 272`
- Nombre réel d’emplacements enregistrés par sommet : 8
- Maximum de poids non nuls sur un sommet : 8
- Sommets sans influence : 0
- Poids négatifs : 0
- Références à un os inexistant : 0
- Somme minimale des poids : `0,9998931969`
- Somme maximale des poids : `1,0000000298`
- Sommets dont la somme s’écarte de 1 de plus de 0,001 : 0

Distribution des influences non nulles :

| Influences | Sommets |
|---:|---:|
| 1 | 9 065 |
| 2 | 16 088 |
| 3 | 6 841 |
| 4 | 6 307 |
| 5 | 21 916 |
| 6 | 9 253 |
| 7 | 6 905 |
| 8 | 6 909 |

`44 983` sommets utilisent effectivement plus de quatre influences. Aucune conversion à quatre influences n’a été effectuée et le mesh n’a pas été reconstruit.

## Scène de validation isolée

Scène : `res://tests/characters/elf/ElfAnimationValidation.tscn`

La scène contient uniquement un environnement neutre, une lumière directionnelle, un sol, un pivot immobile à l’origine, une instance du GLB, une caméra trois-quarts, une caméra latérale et une interface de revue. Elle ne contient ni `CharacterBody3D`, ni physique de déplacement, ni `AnimationTree`, ni `BoneAttachment3D`, ni arme.

Le contrôleur :

- trouve dynamiquement l’`AnimationPlayer`, le `Skeleton3D` et le mesh ;
- récupère dynamiquement les animations importées ;
- démarre sur `Elf_Idle`, correspondant à `Elf_Idle-loop` dans le GLB ;
- propose précédent/suivant, pause/reprise, recommencer, changement de caméra, accès direct 1–9 et vitesse +/- ;
- affiche nom, nom GLB des trois boucles, durée, boucle, temps courant, vitesse et caméra ;
- exécute et imprime l’audit complet au lancement.

Les événements clavier sont traités directement dans cette scène de test ; aucun contrôle global n’a été ajouté au projet.

## Revue visuelle

Une passe graphique finale en 1280 × 720 a joué les animations pendant les durées minimales demandées, soit environ `20,533 s` de lecture utile :

| Animation | Observation | Résultat visuel échantillonné |
|---|---:|---|
| `Elf_Idle` | 2 boucles | Stable, pieds au sol, tenue et cape cohérentes. |
| `Elf_Walk` | 2 boucles | Déformation cohérente des jambes, genoux, hanches et cape ; pas d’éclatement visible. |
| `Elf_Run` | 3 boucles | Silhouette, épaules, bras et jambes cohérents ; pas de sommet aberrant visible. |
| `Elf_Cast_Full` | 1 lecture | Bras, poignets et mains lisibles ; tenue et cape suivent la pose. |
| `Elf_Cast_Start` | 1 lecture | Transition de départ cohérente ; pas de déformation anormale observée. |
| `Elf_Cast_Hold` | 1 lecture | Pose de maintien stable et lisible. |
| `Elf_Cast_End` | 1 lecture | Retour cohérent ; pas de rupture visible. |
| `Elf_Hit` | 1 lecture | Réaction lisible ; hanches, cape et membres restent cohérents. |
| `Elf_Death` | 1 lecture + vue latérale | Chute lisible, pose finale au sol et entièrement cadrée ; déplacement global important. |

Pour chaque animation, des captures début/milieu/fin ont été examinées. Des captures latérales supplémentaires ont été prises pour Death. Les textures sont présentes, l’échelle et l’orientation sont cohérentes, et aucun mesh explosé, sommet tiré vers un os incorrect ou pénétration manifeste du sol n’apparaît dans les échantillons. Le glissement fin des pieds reste plus fiable à confirmer en lecture interactive continue ; la scène est laissée prête pour ce contrôle.

### Déplacement de Hips

La piste de position de `Hips` de Death varie de `(−10,3324 ; 95,7044 ; 12,5837)` à `(−7,9264 ; 22,2080 ; 121,2427)` dans l’espace de piste importé, soit un delta `(2,4060 ; −73,4964 ; 108,6590)` et une norme `131,2032` unités de piste. Avec l’échelle d’import du rig, cela correspond visuellement à environ `1,312 m`. Ce déplacement est intentionnellement conservé et constitue l’avertissement principal avant intégration au gameplay.

À titre de comparaison, les deltas début/fin de Walk et Run ne mesurent respectivement qu’environ `1,7624` et `1,9622` unités de piste, soit environ `0,0176 m` et `0,0196 m` à l’échelle importée.

## Erreurs et avertissements

Erreurs automatiques : aucune.

Avertissements :

1. Godot retire automatiquement `-loop` des noms exposés pour Idle, Walk et Run, tout en conservant correctement leur boucle.
2. La surface est importée avec huit emplacements de poids, et `44 983` sommets utilisent plus de quatre influences. C’est une mesure du GLB réellement conservé, pas une corruption.
3. `Elf_Death` déplace nettement `Hips` et le personnage par rapport au point initial. Aucun recentrage n’a été appliqué.
4. Les captures ne remplacent pas un contrôle humain continu du glissement subtil des pieds ; la scène interactive permet ce dernier contrôle.
5. Un processus externe a créé puis publié un commit pendant la validation ; voir la section Git. Codex n’a exécuté aucune commande d’écriture Git.

## Fichiers du projet créés ou utilisés

Créés dans le périmètre de test :

- `res://tests/characters/elf/ElfAnimationValidation.tscn`
- `res://tests/characters/elf/elf_animation_validation.gd`
- `res://tests/characters/elf/elf_import_audit.gd`
- `res://tests/characters/elf/ELF_IMPORT_VALIDATION.md`
- `res://tests/characters/elf/elf_animation_validation.gd.uid` (généré par Godot)
- `res://tests/characters/elf/elf_import_audit.gd.uid` (généré par Godot)

Ressources vérifiées, sans différence Git finale :

- `res://assets/characters/elf/elf_character_v01.glb`
- `res://assets/characters/elf/elf_character_v01.glb.import`
- `res://assets/characters/elf/elf_character_v01_texture_0.png`
- `res://assets/characters/elf/elf_character_v01_texture_0.png.import`

Artefacts de diagnostic hors projet :

- `C:\Blender_AI_Test\Output\godot_elf_import_probe.json`
- `C:\Blender_AI_Test\Output\godot_elf_hips_motion.json`
- `C:\Blender_AI_Test\Output\godot_elf_review\visual_review.json`
- 30 captures PNG sous `C:\Blender_AI_Test\Output\godot_elf_review\`

## État Git

Avant intervention, l’état consigné était :

```text
## main...origin/main
?? asset/map/iso/
?? battle/floating_text.gd.uid
?? battle/floating_text_spawner.gd.uid
?? battle/impact_juice.gd.uid
?? test/unit/test_iso_grid_view.gd.uid
```

Pendant la validation, à `2026-07-18 15:03:58 +02:00`, un commit externe est apparu dans le reflog :

```text
e1cce882ac74812db9eb28cb75ead6daedd4802c
test(elf): add import and animation validation scenes
```

Ce commit suit les trois fichiers `ElfAnimationValidation.tscn`, `elf_animation_validation.gd` et `elf_import_audit.gd`. `HEAD` et `origin/main` pointent tous deux sur ce commit, ce qui indique qu’il a également été publié. Aucune commande `git add`, `git commit` ou `git push` n’a été exécutée par Codex, et l’historique n’a pas été réécrit automatiquement.

À la clôture, `git status --short --untracked-files=all` signale :

```text
## main...origin/main
?? tests/characters/elf/ELF_IMPORT_VALIDATION.md
?? tests/characters/elf/elf_animation_validation.gd.uid
?? tests/characters/elf/elf_import_audit.gd.uid
```

Les chemins initialement non suivis ne sont plus signalés et sont désormais reconnus par `git ls-files`. Aucun commit ni push n’a été effectué par Codex.
