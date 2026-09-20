# Éclat de braise — premier pilote Éthéré

Prototype animé de la direction C choisie le 20 septembre 2026 : cœur incandescent, feu translucide, quelques braises, puis fumée. [Charte artistique](../../../docs/design/achilles/vfx_art_direction_proposal_2026-09-20.md).

## Rejouer

Depuis la racine du dépôt :

```powershell
./tools/labs/ethereal_ember_study/preview.ps1
```

Ou ouvrir le `project.godot` de ce dossier avec Godot 4.7.1. Le laboratoire est autonome et charge le personnage, le décor et les polices du dépôt. Les boutons proposent pause, rejeu, vitesse normale, ralenti ×0,5 et comparaison avec/sans effet. La barre permet de choisir un instant ; les flèches avancent ou reculent de 1/60 seconde.

La grande vue présente le sanctuaire à une échelle agrandie ; les deux petites vues permettent de comparer un décor clair et sombre. Ces vues d'atelier utilisent un personnage fixe et ne constituent pas une capture d'un combat. La taille exacte devra être ajustée à la caméra du combat lors de l'intégration.

## Capturer

```powershell
./tools/labs/ethereal_ember_study/preview.ps1 -Capture
node tools/labs/ethereal_ember_study/encode.cjs
```

Sorties dans `artifacts/dev/ethereal_ember_study/` : `ember_preview.gif` (2,4 s), `ember_slow.gif` (4,8 s), `poster.png`, 72 captures PNG, rapports de capture et d'encodage. Les GIF reprennent les images du viewport Godot ; seule la palette est quantifiée. L'encodage vérifie les dimensions, les 72 images, leur évolution et le retour du décor à son état initial après extinction.

L'encodeur utilise Sharp depuis le runtime local Codex ; `SHARP_PATH` permet d'indiquer une autre installation. Le lanceur utilise le moteur configuré dans `artifacts/dev-tools/local.json`, ou `-GodotPath`.

## Fabrication et limites

Deux shaders originaux composent un champ de flux, des voiles lumineux et la fumée. Le corps se déforme et se dissout continuellement ; il ne s'agit pas d'une image fixe agrandie. Les neuf braises suivent des trajectoires déterministes. Le temps est fourni par `ember.gd.sample(seconds)` : pause, retour arrière et rejeu ne dépendent pas de l'état d'une simulation de particules. L'effet disparaît entièrement à 1,9 s ; la boucle d'atelier dure 2,4 s.

Ce pilote utilise directement Godot, sans étape Blender ni génération d'image. Le comportement est destiné à un impact local de la carte Éclat de braise ; il n'est pas encore raccordé au routeur de combat. Aucun coût, dégât ou délai de jeu n'a été modifié. Le rendu de référence est ici Compatibility/OpenGL ; la composition sur plusieurs cibles et dans le renderer Forward+ du jeu reste à vérifier lors de l'intégration.

Statut : **PROTOTYPE À ÉVALUER ARTISTIQUEMENT**. La réussite de la capture technique ne vaut pas approbation du rendu.
