# Passe-rive — nouvelle silhouette pour essai AutoSprite

13 septembre 2026. Demande : refaire Passe-rive moins fin et moins grand,
avec une construction plus proche de Dofus, sans le rendre petit, trapu ou enfantin.
Le choix d'AutoSprite vient de l'utilisateur ; son fonctionnement n'a pas été testé ici.

## Fichier à importer

- [Passe-rive PNG transparent](passe_rive.png) : 1024 × 1536, RGBA.
- [Aperçu sur fond uni](preview.jpg).
- [Prompt exact](prompt.txt), exécuté avec ImageGen intégré.

Une seule proposition, sans équipement : bras et jambes visibles, vue trois-quarts
vers la droite, posture debout. Épaules et membres plus solides, proportions
moins étirées ; masque ivoire fendu, capuche pétrole, drapé jade, obole et
touches de bronze conservés. C'est une proposition de design, pas un nouveau
canon accepté ni une preuve de qualité d'animation.

## Provenance et préparation

Référence : `../passe_rive_v1/reference_choisie.png`.
Un appel ImageGen : `exec-d8bc676f-b01a-415f-bdd1-c6b396321067.png`.
Copie brute conservée dans `generated.png` ; le damier était peint dans une image RGB.
Détourage logiciel déjà autorisé, effectué avec BiRefNet general lite installé,
sans reconstruction des jambes ni modification des proportions après génération.
Le script `prepare_png.py` reproduit le détourage et l'aperçu.

Dimensions et alpha contrôlés dans `metadata.json`. Aucun envoi à AutoSprite,
aucune animation générée, aucune intégration Godot dans cet essai.
