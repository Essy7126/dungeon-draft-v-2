# Incantation du sceau — huit directions

Six cartes : Garde ferme (g01), Bastion vivant (g08), Sommeil marqué (a09), Sceau ombreux (t03), Jardin de givre (t06), Résonance du sceau (t09). Grâce du bronze conserve sa restauration S30.

Douze poses, durée de 1,15 s, effet réel sur l'ouverture des paumes à 590 ms dans les huit orientations. Le SE approuvé reste inchangé. Les sept nouvelles vues ont leurs propres dessins et points de main ; aucun miroir, aucun ancien sceau employé en remplacement.

## Production

Outil imagegen intégré, transparence conservée. Les quatre prompts exacts et quatre atlas sont dans `sources/`, issus des repos natifs de chaque direction. Costume, angles de caméra et anatomie contrôlés dans Godot. Les régions sont mesurées par silhouette ; les PNG source ne sont ni repeints ni redimensionnés par script.

Calibration fixe par atlas, hauteur canonique 214 px, palette par matière via le shader existant. Appui et main suivent la même transformation. Fondus courts vers le repos natif en entrée et sortie. Les cartes conservent leurs recettes VFX et leurs prérequis ; aucun changement de règles.

## Reproduire les contrôles

- `tools/class_card_vfx/passe_rive_incantation_directions/build_metadata.py` : régions, appuis, main et palette.
- `capture_poses.ps1` : 64 images des huit vues ; le point orange diagnostique la main et n'existe pas en jeu.
- `play.ps1 -Capture` : six cartes × base/amélioration × huit orientations dans la vraie scène Battle.
- `./dev.ps1 test passe-rive` : couverture du backend public et des autres gestes.

La revue reste une validation V1 : contours et amplitudes varient entre dessins ; l'occlusion des mains derrière la tête est conservée sur les vues de dos. Les raccords ne prétendent pas reproduire exactement chaque pixel du repos.
