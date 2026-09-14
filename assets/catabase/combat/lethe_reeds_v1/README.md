# Les roseaux du tireur

Peinture de l’étape V du Léthé : anciens passages de pierre dans une roselière,
fleuve vert froid et barque brune à trois bancs, avec une lanterne ambrée.
Salle : `data/rooms/catabase_routes/route_6d5efdb88ff0/room.tres`.

La peinture `land.png` est le fichier natif de l’outil image_gen intégré.
Le guide canonique provient des 112 cellules de jeu ; `art_calibration.json`
décrit ensuite la peinture effectivement retenue. `apply.py` refuse un nouvel
asset non recalibré. Le runtime conserve la géométrie, les huit obstacles bas,
les points de départ et les règles de rencontre.

Prompts exacts, dans leur ordre de création :

- `PROMPT.md` : composition initiale et références de style/barque.
- `PROMPT-ground-fix.md` : première correction, insuffisante au contrôle sec.
- `PROMPT-ground-footprint.md` : emprise des surfaces sèches élargie.
- `PROMPT-bank-extremities.md` : retouche locale des extrémités restantes.
- `PROMPT-west-bank.md` : suppression explicite des deux encoches occidentales.

Le masque `material_mask.png` est une donnée technique : rouge pour l’eau,
vert pour les contours de roseaux, bleu pour les surfaces et objets rigides.
La petite lanterne utilise un changement local de lumière ; sa silhouette
et la barque restent fixes. Toutes les coordonnées de calibration viennent
des pixels de la peinture, puis sont converties au plan natif 1920 × 1200.

Commandes et limites des validations :
[pipeline de revue](../../../../tools/lethe_reeds_review/README.md).
Empreintes et rapports de la livraison : `manifest.json`.
