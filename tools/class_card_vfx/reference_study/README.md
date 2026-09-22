# Atelier de références VFX — run Cartes

**Choix du 22 septembre 2026 : A — Animation cel.** La colonne A est mise en
avant dès l’ouverture. [Décision de DA](../../../docs/design/achilles/cards_vfx_cel_2026-09-22.md).

Trois animations observées, reconstruites avec des sprites originaux et comparées
en trois traitements. Page supplémentaire : cinq états simultanés avec les vrais
anciens shaders éthérés, archivés avant la passe cel, des signaux localisés, ou uniquement leurs étiquettes.

Depuis la racine du dépôt, dans PowerShell :

```powershell
./tools/class_card_vfx/reference_study/preview.ps1
```

Le lanceur utilise `artifacts/dev-tools/local.json`. Passer `-GodotPath` pour un
autre binaire Godot 4.7.1. Aucun changement de scène principale, sauvegarde,
règles de combat ou VFX du catalogue. Fenêtre native 1440 × 1040, sans son.

Sélecteur en haut à droite ; lien vers la vidéo/GIF de chaque sort. En bas :
pause, rejouer, vitesse normale/quart, réaction cible, fond clair/sombre, fin
d’activation des états et retrait explicite de l’étendard. La barre de temps et
les flèches permettent l’examen par pas de 1/30 s. Espace : pause ; R : rejouer.
La grande vue agrandit ×1,6 ; la petite conserve l’échelle du personnage choisie
pour l’étude. Ce n’est pas une attestation de toutes les caméras du combat.

## Références et limites

- Épée céleste : DOFUS Unity, démonstration de septembre 2024.
- Deux Doigts : WAVEN, prototype publié en septembre 2018.
- Étendard de bravoure : WAKFU, vidéo officielle de 2015.

[Observations, sources, retours de joueurs et écarts de reproduction](../../../docs/design/vfx_reference_studies_2026-09-22.md).
Les trois DA utilisent les mêmes mouvements ; les durées sont celles de l’étude.
Les deux premières animations se répètent ; l’étendard attend son retrait.
Les états n’expirent que lorsque l’on avance leur fixture d’une activation.

Les six PNG de [art/](art/) sont des sorties originales de l’outil intégré
`image_gen`, copiées sans retouche : [prompts épée/main](art/prompts.json),
[prompts étendard](art/standard_prompts.json), [régions épée/main](art/regions.json).
Le traitement « sculpté » est rendu en 2D ; aucun modèle 3D n’a été produit.

## Captures reproductibles

```powershell
./tools/class_card_vfx/reference_study/preview.ps1 -Capture
node tools/class_card_vfx/reference_study/encode.cjs
```

La capture prend le verrou moteur partagé et vérifie les journaux, les 216 images,
23 contrôles et les empreintes des sources. L’encodage refuse les captures
périmées. Il requiert Sharp ; `SHARP_PATH` permet de choisir son installation
au lieu du runtime local configuré par défaut.

Sorties : `artifacts/dev/class_card_vfx/reference_study/`, dont `celestial.gif`,
`water_hand.gif`, `standard.gif`, `states_five.png`, `states_two.png`,
`states_clear.png`, `report.json` et `capture_manifest.json`.
Les GIF utilisent 72 captures sur 2,4 secondes par étude ; l’encodeur fusionne les
images identiques en conservant leur durée. Leurs boucles ne définissent
pas la durée réelle de maintien de l’étendard dans la fenêtre interactive.

Les vérifications portent sur apparition/extinction, répétabilité, rendu distinct,
maintien/retrait, décompte des états et commandes de l’atelier. Elles ne remplacent
pas une appréciation artistique ou un parcours préparation → combat → bilan →
reprise après intégration. La suite `./dev.ps1 test cards` couvre séparément les
contrats existants du mode Cartes.

Validation du 22 septembre 2026 : 23/23 contrôles natifs, 216 captures ; trois
GIF de 2 400 ms encodés et contrôlés. Suite Cartes : 89/89 tests, 8 273 assertions
(`artifacts/dev/20260922-194251-test-cards-5fb4c0f5/gut-strict-report.json`).
