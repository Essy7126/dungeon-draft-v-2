# Sentence du rempart — source Blender

Modèle original construit le 26 septembre 2026 dans Blender 5.1.2 : 24 pièces
polygonales, contrôleur animé et caméra orthographique. Aucun modèle, texture ou
son Ankama importé. La scène de démarrage du fichier a été conservée séparément.

Ouvrir `sentence_rempart.blend`, scène **Sentence du rempart - CEL**. La timeline
contient les repères APPEAR, ARMED, CONTACT, REBOUND, WITHDRAW et CLEAR. Les
transformations du contrôleur sont enregistrées image par image, sans handler
Python nécessaire à la lecture. 48 images à 30 images/s ; contact image 16.

Le script reproductible est `tools/class_card_vfx/sentence/build_hammer.py`.
Il refuse de remplacer une scène dédiée existante. Le lancer dans un Blender
vierge ou utiliser une copie du fichier pour les retouches.

Le rendu transparent du marteau est assemblé sans redimensionnement par
`tools/class_card_vfx/sentence/pack.py`. Ce script conserve les empreintes des
48 rendus et produit aussi un son original de masse et résonance métallique.
Les trajectoires, l'éclat, la traînée et les débris sont assemblés dans Godot.

Les références étudiées et limites sont dans
`docs/design/vfx_v2_research_ankama_2026-09-26.md`. Ce pilote est une proposition
artistique à comparer en jeu, pas une reproduction certifiée d'un sort Ankama.
