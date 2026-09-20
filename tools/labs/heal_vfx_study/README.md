# Souffle du laurier — premier essai de soin

Prototype visuel du 20 septembre 2026 : géométrie animée dans Blender, deux atlas
transparents (devant / derrière), composition dans Godot. Achille reste immobile.
Il s'agit d'une présentation de laboratoire, sans application de soin ni son.

## Voir et comparer

Depuis la racine du dépôt :

```powershell
./tools/labs/heal_vfx_study/preview.ps1
```

Le lanceur réutilise le moteur enregistré par `dev.ps1`. Un autre chemin peut être
fourni avec `-GodotPath`. On peut aussi importer le `project.godot` de ce dossier
dans Godot et lancer ce petit projet. Ne pas utiliser F6 depuis le projet parent.

- Vif / Naturel / Ample : trois rythmes pour le même mouvement.
- Rejouer, pause et curseur temporel : revoir une phase précise.
- Avec / sans effet : contrôler la lecture du personnage.
- Espace : pause ; R : reprise au début ; flèches : pas de 1/30 s.

La grande scène est agrandie ×2,1. Le panneau « Taille de jeu » reprend la taille
de référence du profil Passe-rive (0,22), sans simuler les différents zooms du combat.
Le cadre « Le mouvement » présente les mêmes images sans personnage.

## Sources et reproduction

- `recipe.json` : largeur du ruban, trajectoire, palette implicite des matériaux,
  cadence, dimensions et références du décor/personnage.
- `build_blender.py` : géométrie native et poses cuites avec clés de visibilité.
- `art/source/vfx/heal_laurel_study_v1/heal_laurel.blend` : scène native conservée,
  lisible et animable sans handler Python. Chemin depuis la racine du dépôt.
- `generated/` : deux atlas 6 × 6, images de 384 × 384, 30 images/s, 1,2 seconde.
  Les manifestes suivent les champs de la fondation VFX, statut INTERNAL_TEST.
  La publication Studio et la validation par son service ne sont pas effectuées.
- `study.gd` : lecture au temps absolu, occlusion avant/arrière et halo au sol.

Reconstruction dans un NOUVEAU processus Blender, sans toucher à une scène ouverte :

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --disable-autoexec --python tools/labs/heal_vfx_study/build_blender.py
node tools/labs/heal_vfx_study/assemble.cjs
./tools/labs/heal_vfx_study/preview.ps1 -Capture
```

L'assemblage utilise Node et Sharp déjà présents sur ce poste, ou le chemin
`SHARP_PATH`. Aucun téléchargement. Les sorties de revue sont dans
`artifacts/dev/heal_vfx_study/`. Ces commandes remplacent uniquement les rendus de
cette étude ; ne pas lancer simultanément deux reconstructions/captures.

## Vérifications et suite

Blender 5.1.2 : 72 PNG contrôlés, dimensions cohérentes, première et dernière images
transparentes, absence de rognage au bord, animation présente sur les deux plans.
La correction de largeur 0,105 → 0,072 a été rendue de nouveau depuis la même recette.
Les scènes et rapports intermédiaires ne certifient pas le candidat final.

La capture Godot produit `godot_report.json` et 72 images GPU. Les contrôles portent
sur la présence de l'effet, la relecture identique, la disparition propre, les
deux changements de rythme, la bascule avec/sans et le fond du panneau latéral.
Lire ce rapport ET le journal moteur avant de conclure. `assemble.cjs --encode`
exige un rapport positif et conserve les empreintes des sources dans son rapport.
Le GIF quantifie sa palette et arrondit les durées ; le projet interactif est la référence.

Le moteur graphique est Forward+ / D3D12, comme le projet Windows. Le cache de
shaders est désactivé dans ce laboratoire pour éviter les chemins trop longs de
la capture isolée. Aucun réglage du jeu principal n'est modifié.

Dernière capture du 20 septembre : Godot 4.7.1 / RTX 4070 Laptop, **7 contrôles
graphiques positifs**, 72 images enregistrées, zéro diagnostic ERROR/WARNING dans
`godot-final-console.log`. GIF final : 72 images, boucle de 2,4 secondes.
Inspection visuelle effectuée au pic et pendant la remontée. Le lanceur PowerShell
est vérifié syntaxiquement ; la capture a été exécutée par la commande moteur.

Le formateur 0.25.0 passe en mode `--check`. Son option supplémentaire
`--verify-structure` a signalé une différence lors de la mise en forme ; le diff
a été relu et la version formatée est vérifiée par Godot.

Portée : aucun code de combat changé, aucune validation GUT ou partie complète.
La prochaine décision est artistique : mouvement, couleur, intensité et durée.
Une intégration ultérieure devra observer les événements de soin confirmés et
passer les validations du combat et du Studio. Les autres travaux du worktree
ont été conservés.
