# Règles de validation Arena Studio

## Erreurs bloquantes

Identifiant ou nom absent, identifiant dupliqué, background absent ou externe au projet, dimensions invalides, axes non inversibles, calibration incomplète, aucune case jouable, cellule dupliquée ou hors grille, bordure marquée jouable, obstacle hors arène, spawn hors arène/sur bordure/sur obstacle, collision de spawns, moins de trois positions héros, aucun spawn ennemi, rencontre absente, scène runtime absente, camps déconnectés et schéma incompatible.

## Avertissements

Bordure absente, zone jouable isolée non déclarée volontaire, passage d'une cellule, erreur de calibration supérieure à 3 px et grille supérieure à la cible vérifiée 64 × 64.

## Informations

Dimensions, cases définies, jouables et de bordure, obstacles, composantes connexes, distance minimale entre camps, spawns et terrains utilisés.

La validation construit un `GridData` réel par `RoomGridLayout.apply_to_grid()` puis utilise `Pathfinder`. Elle ne possède aucun algorithme alternatif de navigation ou de LOS.
