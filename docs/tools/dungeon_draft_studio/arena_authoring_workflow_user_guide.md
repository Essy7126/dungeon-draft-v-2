# Guide utilisateur : authoring rapide d'une arène

Statut : **WORKTREE_CANDIDATE**.

## Peindre

Choisir Pierre, Neutre, Eau, Glace, Lave, Poison, Vapeur ou Électrique dans la
palette rapide, puis un pinceau 1, 2 ou 3. Glisser : l'affichage réagit et le
runtime se synchronise au relâchement. `Alt + clic` prélève le terrain. Rectangle
et Remplissage restent disponibles. Le remplacement global annonce le nombre de
cellules et l'effet logique. Chaque geste produit une seule action Undo.

## Changer le décor

Ouvrir `Décor…`, choisir une image, une arène, une salle/run ou un manifeste. Pour
la map grecque, sélectionner `Grèce — Agora antique`, puis `Décor + calibration +
caméra`. Vérifier la grille et le comparateur. `Fond uniquement` conserve la
calibration ; `Pack visuel complet` reprend aussi foreground et occlusion.

## Terrains et vortex

Poison et Brûlure tickent au début de l'activation suivante. L'eau électrifiée
termine un mouvement volontaire et ne choque qu'une fois par round.

Ouvrir `Vortex…`, créer/sélectionner un réseau puis cliquer ses dalles ; clic
droit pour retirer. Une dalle donne +1 PM courant, deux téléportent directement,
trois ou plus choisissent une sortie valide de façon déterministe. Le panneau
indique comportement, sorties et probabilités.

## Tester, sauvegarder, intégrer

Tester part de la working copy, crée une copie sous `user://`, écrit
`test_request.json` et lance la vraie scène runtime. Sauvegarder matérialise alors
seulement les images externes. `Sauvegarder et continuer` change de salle sans
perte. L'intégration dans une run reste transactionnelle et rechargée pour
vérification.

