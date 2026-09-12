# Veilleur — marche, quatre vues

Essai du 12 septembre 2026 : **48 images par direction, cycle de 800 ms**, dans
un laboratoire Godot jouable utilisant la vraie carte forêt et ses obstacles.
**Rejet artistique utilisateur reçu le 12 septembre 2026 : personnage mécanique
et sans vie.** Cet essai est conservé pour diagnostic, pas comme base validée.
Lire la [reprise de méthode](../../../../../docs/design/achilles/animation_reset_2026-09-12.md).
Ce n’est pas un kit de combat.

## Essayer

Depuis la racine du projet :

```powershell
./tools/veilleur_walk/iso.ps1 open
```

Ou ouvrir `tools/veilleur_walk/WalkIsoReview.tscn` dans Godot et lancer F6.
Cliquer une case libre pour marcher. Les flèches commandent un pas sur la grille.
« Tour des 4 vues » parcourt les quatre orientations. Espace met en pause.
Le ralenti et la vitesse ×2 affectent ensemble déplacement et cycle des pieds.

[Aperçu animé et comparatif](http://127.0.0.1:8734/files/veilleur_walk_iso_v1/review.html).

## Dessins et construction

- E, bas droite : **pixels de la marche E V5 inchangés**. Seul le repère au sol
  utilisé par le lecteur est recalé sur les semelles (l’ancien pivot se trouvait
  plus bas que le milieu des appuis).
- S, bas gauche : nouvelle vue de face. L’attache de l’écharpe, d’abord inversée
  par le générateur, a été corrigée sur l’épaule droite anatomique, côté éloigné.
- N, haut droite, et W, haut gauche : vrais dessins du dos du casque et de la
  tunique, sans visage ni panneau de poitrine transportés dans le dos.
- Aucun miroir. Les côtés anatomiques L/R gardent une demi-période d’écart,
  même lorsqu’ils changent de côté visible.
- Trois planches directionnelles produites avec **ImageGen intégré**, puis
  détourage logiciel autorisé, annotations d’attaches et déformation des tissus.
  Les bottes restent des dessins rigides : échelle uniforme fixe, rotation,
  translation. Une tentative de calage affine qui écrasait les bottes a été
  abandonnée avant livraison.
- La courbe de pas E V5 est réutilisée : 60 % d’appui par jambe, talon / plat /
  pointe, retour du pied bas, jambes reconstruites dans le plan de marche.
  Les nouvelles vues ont leurs propres attaches de tissus et bras. Ce n’est
  pas le rig propriétaire d’Ankama et aucune image de Dofus n’entre dans le kit.

Sources retenues : [S_sheet.png](S_sheet.png), [N_sheet.png](N_sheet.png),
[W_sheet.png](W_sheet.png). Prompts : [S](S_prompt.txt),
[correction de S](S_fix_prompt.txt), [N](N_prompt.txt), [W](W_prompt.txt).
La planche rejetée S avant correction reste dans le dossier de générations Codex ;
elle n’est utilisée dans aucun export.

Les pièces détourées sont dans `parts/`, les attaches annotées dans
`S_bindings.json`, `N_bindings.json`, `W_bindings.json`.
Le générateur reproductible est `tools/veilleur_walk/build_iso.py` ; il conserve
la V5 originale et ne relance pas ImageGen.
Il relit les pièces PNG existantes et les attaches JSON : une retouche locale
peut donc être reprise à l’export. Garder le canevas des pièces inchangé.
L’option explicite `--reextract` recrée les détourages depuis les planches brutes.

## Livraison Godot

`assets/characters/Achilles/veilleur_walk_iso_v1/` contient quatre atlas RGBA
4096 × 3072, `walk_frames.tres` avec les quatre animations `walk_E/S/N/W`,
et `manifest.json` avec durée, ancres, taille et empreintes.
Le lecteur `characters/achilles/2d/veilleur_walk_player.gd` échantillonne le cycle
à partir de la distance parcourue. Les virages conservent la phase.

La scène d’essai réutilise `GridData`, `Pathfinder`, le fond forêt et son
occlusion de premier plan. Elle n’ajoute pas cette marche incomplète au choix
public des héros et ne remplace pas les sorts existants.

## Vérifications et limites

- Import et rendu GPU Godot : **234 contrôles réussis**, 192 régions chargées,
  quatre directions, bouclage, chemin réel, terrain bloqué, pause, arrivée exacte,
  phase conservée et déplacement proportionnel à la longueur du pas.
- Exports : **46 contrôles réussis**, atlas et animations conformes aux PNG,
  durée exacte, sources acceptées inchangées, raccords des articulations,
  appuis et boucle. Les semelles proches ont été suivies dans les pixels sur
  17 images d’appui à plat par vue. Cela ne prouve pas tous les contacts masqués.
- Les quatre captures natives et les bandes de déplacement sont disponibles
  dans `artifacts/spine_trial/veilleur_walk_iso_v1/` avec les rapports complets.
- Aperçu navigateur : **68 contrôles réussis**, quatre vues synchronisées,
  commande de phase, ralenti, parcours, pause, zoom, liens et affichage mobile.
- La hauteur dessinée varie au cours du pas et avec la perspective : E
  361–381 px, S 366–383 px, N 359–375 px, W 362–377 px, affichage à 0,30.
  Ces variations ne sont pas corrigées par une remise à l’échelle de chaque pose.
- Les transitions de virage sont **instantanées**, sans poses intermédiaires.
  L’arrêt conserve la dernière pose ; un véritable idle et des départs/arrêts
  restent à produire. Les ombres sont peintes dans les vues.
- La réussite technique n’est pas une validation artistique. L’ampleur du pas,
  la cohérence des nouvelles silhouettes et le ressenti doivent être jugés
  dans cet essai avant de produire une autre animation.
