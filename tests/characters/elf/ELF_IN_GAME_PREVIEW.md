# ElfInGamePreview — aperçu tactique isométrique

## Verdict

`ELF_IN_GAME_PREVIEW_VALIDATED_WITH_WARNINGS`

La scène de démonstration affiche correctement `ElfVisual3D` sur une grille tactique 5 × 5, avec caméra isométrique orthographique, caméra latérale, éclairage, ombre, interface, contrôles d’animation et déplacement scripté d’une case. Aucune ressource importée ni scène de gameplay n’a été modifiée.

Les avertissements concernent uniquement la calibration fine du glissement des pieds et le débordement volontaire de Death hors de la case centrale.

## Audit Git préalable

```text
git status --short
?? characters/
?? tests/characters/elf/ELF_IMPORT_VALIDATION.md
?? tests/characters/elf/ElfVisualComponentValidation.tscn
?? tests/characters/elf/elf_animation_validation.gd.uid
?? tests/characters/elf/elf_import_audit.gd.uid
?? tests/characters/elf/elf_visual_component_validation.gd
?? tests/characters/elf/elf_visual_component_validation.gd.uid

git branch --show-current
main

git log -3 --oneline
e1cce88 test(elf): add import and animation validation scenes
19cff5f test
066818b Merge branch 'main' of https://github.com/Essy7126/dungeon-draft-v-2
```

Les fichiers non suivis appartenaient aux tâches précédentes. Les trois nouveaux chemins de preview n’existaient pas ; aucun conflit réel n’a été détecté. Aucun fichier préexistant n’a été supprimé, restauré ou modifié.

## Arborescence

```text
ElfInGamePreview [Node3D] — elf_in_game_preview.gd
├── WorldEnvironment
├── DirectionalLight3D
├── FillLight
├── Floor
├── GridVisual
│   ├── CenterCell
│   ├── GridX0 … GridX5
│   ├── GridZ0 … GridZ5
│   ├── CenterBoundaryLeft/Right/Front/Back
│   └── InitialCellCenter
├── ElfAnchor [Node3D]
│   └── ElfVisual3D — instance de res://characters/elf/ElfVisual3D.tscn
├── IsometricCamera [Camera3D]
├── SideCamera [Camera3D]
└── UI [CanvasLayer]
    └── Panel
        └── Margin/VBox
            ├── Title
            ├── AnimationLabel
            ├── SpeedLabel
            ├── CameraLabel
            ├── MovementLabel
            ├── PerformanceLabel
            └── ControlsLabel
```

La scène est indépendante du gameplay. Elle ne contient ni `CharacterBody3D`, ni collision, ni `NavigationAgent3D`, ni physique, ni root motion applicatif.

## Grille et échelle

- Grille : 5 × 5 cases carrées
- Taille d’une case : `1,5 m × 1,5 m`
- Taille totale du sol : `7,5 m × 7,5 m`
- Case centrale : matériau distinct et contour cyan
- Centre initial : disque jaune au sol
- `ElfAnchor` initial : `(0 ; 0 ; 0)`, transform identité
- AABB du personnage : position `(-0,576467 ; ~0 ; -0,275492)`, taille `(1,152934 ; 1,700000 ; 0,550983) m`
- Hauteur mondiale du personnage : environ `1,70 m`
- Taille affichée en caméra isométrique 1280 × 720 : environ `203 px`
- Taille affichée en caméra latérale : environ `291 px`

Le personnage occupe une proportion lisible de la case centrale. La texture, la silhouette, la cape, les pieds et les bras restent distinguables.

## Caméras

### IsometricCamera

- Projection : orthographique
- Position : `(6 ; 6,4 ; 6)`
- Point visé : `(0 ; 0,72 ; 0)`
- Rotation horizontale : environ `45°`
- Inclinaison vers le sol : environ `33,8°`
- Taille orthographique : `6,0 m`
- Caméra principale au lancement

La vue montre au moins 3 × 3 cases autour du personnage tout en conservant une taille suffisante pour juger les animations.

### SideCamera

- Projection : orthographique
- Position : `(7 ; 1,8 ; 0)`
- Point visé : `(0 ; 0,72 ; 0)`
- Taille orthographique : `4,2 m`
- Usage : Death, contact des pieds et débordement par rapport à la case

La touche `C` alterne les deux caméras.

## Contrôles

```text
1 : Idle
2 : Walk
3 : Run
4 : Cast Full
5 : Hit
6 : Death
7 : Cast Start
8 : Cast Hold
9 : Cast End
R : retour Idle
C : caméra isométrique/latérale
+/- : vitesse de lecture
M : déplacement de démonstration
L : marqueurs des sockets de mains
```

Toutes les animations sont lancées par l’API publique de `ElfVisual3D`. Idle démarre automatiquement. Aucun Input Action n’a été ajouté à `project.godot`.

## Déplacement de démonstration

Propriétés exportées :

```gdscript
@export var walk_cells_per_second: float = 1.0
@export var run_cells_per_second: float = 1.67
```

- Walk : `1,0 case/s`, soit `1,5 m/s` et une case en `1,0 s`
- Run : `1,67 case/s`, soit environ `2,505 m/s` et une case en `0,599 s`

La durée d’une case correspond approximativement à un cycle importé : Walk dure `1,0 s` et Run `0,6 s`. Le mouvement est linéaire, déterministe et provient exclusivement du script de cette scène. Il alterne entre la case centrale et la case adjacente sur l’axe X.

Résultats automatiques :

- fin Walk : `(1,5 ; 0 ; 0)`, exactement la case adjacente ; retour Idle réussi ;
- fin Run : `(0 ; 0 ; 0)`, exactement la case centrale ; retour Idle réussi ;
- aucune téléportation à la fin ; la position est interpolée jusqu’au centre de la case cible.

## Résultat visuel par animation

| Animation | Résultat |
|---|---|
| `Elf_Idle` | Stable, pieds au sol, silhouette et cape lisibles. |
| `Elf_Walk` sur place | Déformation cohérente des jambes et de la cape ; aucun éclatement. |
| `Elf_Walk` avec déplacement | Une case parcourue en un cycle environ ; rythme global crédible, aucun glissement grossier visible dans les échantillons. |
| `Elf_Run` sur place | Posture dynamique, membres cohérents, ombre lisible. |
| `Elf_Run` avec déplacement | Une case parcourue en environ 0,6 s, proche d’un cycle ; synchronisation globale cohérente. |
| `Elf_Cast_Full` | Bras, mains et silhouette lisibles en isométrique ; personnage encore cadré. |
| `Elf_Cast_Start` | Départ du geste lisible et sans anomalie de skin. |
| `Elf_Cast_Hold` | Pose de maintien claire, bras et cape cohérents. |
| `Elf_Cast_End` | Retour lisible, sans rupture ou déformation manifeste. |
| `Elf_Hit` | Réaction claire, mesh et cape cohérents. |
| `Elf_Death` | Chute entièrement visible en isométrique et de côté ; corps au sol, mais débordement important sur la case voisine. |

Les captures statiques et la lecture automatisée ne révèlent ni mesh explosé, ni sommets tirés, ni problème de skin, ni texture manquante. La calibration subtile du contact des pieds doit toutefois être confirmée dans la scène interactive ; les valeurs actuelles sont un bon point de départ.

## Death et limite de case

Avant et après Death :

```text
ElfAnchor début : (0 ; 0 ; 0)
ElfAnchor fin   : (0 ; 0 ; 0)
```

`ElfAnchor` reste donc strictement immobile. Seule la translation animée interne de `Hips` agit. La pose finale dépasse visiblement le contour cyan de la case centrale et occupe une partie de la case adjacente. Aucun recentrage ou correctif n’a été appliqué.

## Marqueurs des mains

La touche `L` appelle l’API publique du composant pour afficher ou masquer les marqueurs. La capture dédiée montre les marqueurs suivant les mains ; ils restent petits à l’échelle isométrique, conformément à leur taille technique d’environ 5 cm. Aucun arc n’a été créé.

## Performance indicative

- Renderer : `forward_plus`
- Triangles du mesh : `103 797`
- FPS moyen observé pendant la passe automatisée : environ `152 FPS`
- Échantillons FPS : environ `2 300`
- Résolution de test : `1280 × 720`

Cette mesure est uniquement indicative et ne constitue pas un benchmark.

## Captures produites

Captures minimales demandées :

```text
res://tests/characters/elf/screenshots/elf_idle_isometric.png
res://tests/characters/elf/screenshots/elf_walk_isometric.png
res://tests/characters/elf/screenshots/elf_death_isometric.png
```

Captures complémentaires :

```text
res://tests/characters/elf/screenshots/elf_walk_in_place_isometric.png
res://tests/characters/elf/screenshots/elf_run_in_place_isometric.png
res://tests/characters/elf/screenshots/elf_run_moving_isometric.png
res://tests/characters/elf/screenshots/elf_cast_isometric.png
res://tests/characters/elf/screenshots/elf_cast_start_isometric.png
res://tests/characters/elf/screenshots/elf_cast_hold_isometric.png
res://tests/characters/elf/screenshots/elf_cast_end_isometric.png
res://tests/characters/elf/screenshots/elf_hit_isometric.png
res://tests/characters/elf/screenshots/elf_death_side.png
res://tests/characters/elf/screenshots/elf_sockets_isometric.png
```

Le rapport machine est disponible hors projet sous `C:\Blender_AI_Test\Output\godot_elf_in_game_preview.json`.

## Fichiers créés

```text
res://tests/characters/elf/ElfInGamePreview.tscn
res://tests/characters/elf/elf_in_game_preview.gd
res://tests/characters/elf/ELF_IN_GAME_PREVIEW.md
res://tests/characters/elf/screenshots/elf_idle_isometric.png
res://tests/characters/elf/screenshots/elf_walk_in_place_isometric.png
res://tests/characters/elf/screenshots/elf_walk_isometric.png
res://tests/characters/elf/screenshots/elf_run_in_place_isometric.png
res://tests/characters/elf/screenshots/elf_run_moving_isometric.png
res://tests/characters/elf/screenshots/elf_cast_isometric.png
res://tests/characters/elf/screenshots/elf_cast_start_isometric.png
res://tests/characters/elf/screenshots/elf_cast_hold_isometric.png
res://tests/characters/elf/screenshots/elf_cast_end_isometric.png
res://tests/characters/elf/screenshots/elf_hit_isometric.png
res://tests/characters/elf/screenshots/elf_death_isometric.png
res://tests/characters/elf/screenshots/elf_death_side.png
res://tests/characters/elf/screenshots/elf_sockets_isometric.png
```

Fichiers existants modifiés : aucun.

En particulier, `ElfVisual3D.tscn`, son script, le GLB, les animations, les scènes de gameplay et `project.godot` n’ont pas été modifiés.

## État Git final

```text
?? characters/elf/ELF_VISUAL_SETUP.md
?? characters/elf/ElfVisual3D.tscn
?? characters/elf/elf_visual_3d.gd
?? characters/elf/elf_visual_3d.gd.uid
?? tests/characters/elf/ELF_IMPORT_VALIDATION.md
?? tests/characters/elf/ELF_IN_GAME_PREVIEW.md
?? tests/characters/elf/ElfInGamePreview.tscn
?? tests/characters/elf/ElfVisualComponentValidation.tscn
?? tests/characters/elf/elf_animation_validation.gd.uid
?? tests/characters/elf/elf_import_audit.gd.uid
?? tests/characters/elf/elf_in_game_preview.gd
?? tests/characters/elf/elf_visual_component_validation.gd
?? tests/characters/elf/elf_visual_component_validation.gd.uid
?? tests/characters/elf/screenshots/elf_cast_end_isometric.png
?? tests/characters/elf/screenshots/elf_cast_hold_isometric.png
?? tests/characters/elf/screenshots/elf_cast_isometric.png
?? tests/characters/elf/screenshots/elf_cast_start_isometric.png
?? tests/characters/elf/screenshots/elf_death_isometric.png
?? tests/characters/elf/screenshots/elf_death_side.png
?? tests/characters/elf/screenshots/elf_hit_isometric.png
?? tests/characters/elf/screenshots/elf_idle_isometric.png
?? tests/characters/elf/screenshots/elf_run_in_place_isometric.png
?? tests/characters/elf/screenshots/elf_run_moving_isometric.png
?? tests/characters/elf/screenshots/elf_sockets_isometric.png
?? tests/characters/elf/screenshots/elf_walk_in_place_isometric.png
?? tests/characters/elf/screenshots/elf_walk_isometric.png
```

Les fichiers hors preview appartiennent aux tâches précédentes et ont été préservés. Aucun commit et aucun push n’ont été effectués.
