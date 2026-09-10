# Achille graphique V1 — proposition

10 septembre 2026, base Git `2473c335`. Proposition non validée par l'utilisateur.

L'utilisateur veut un nouvel Achille, plus fin que le peint G et avec une vraie
source en haute résolution. Il a rejeté `../agile_v1/achille_concept_v1.png`,
encore beaucoup trop détaillé, et demandé explicitement de prendre exemple sur
les personnages Dofus : la résolution doit servir des formes simples.

`achille_graphique_v1.png` est une création neuve avec l'outil intégré ImageGen,
à partir du texte exact de `generation_prompt.txt`. PNG RGBA natif 1024 × 1536,
sans agrandissement artificiel. Copie conservée du résultat généré
`exec-03eca867-d726-4a2f-8023-83ea487ac5f5.png`.

La direction utilise une silhouette mince, un visage graphique, une tunique
ivoire simple, du bleu pétrole et une crête rousse. Les muscles, gravures et
textures fines ne constituent plus le langage visuel. La référence Dofus du
projet `artifacts/arena_dofus_greece_2026-09-05/reference/dofus_geometry_review.png`
a été examinée. La galerie d'illustrations Féca a aussi été recherchée :
https://www.creativeuncut.com/gallery-15/dofus-feca-m1.html
Les images du site officiel étaient bloquées ; aucun asset Dofus n'est intégré.

La transparence a été vérifiée par composition sur fond clair. Le fond coloré
visible dans l'aperçu brut ne décrit pas le résultat de la composition RGBA.
La grande majorité du fond est d'alpha 0 ; conserver l'alpha original.

[Revue locale](http://127.0.0.1:8734/files/achille_graphique_v1/review.html) :
grand dessin, réductions à 100/140 px et taille réglable sur une capture existante
de l'Atelier du Bronze. C'est un montage indicatif, sans intégration Godot ni
calibration finale de caméra, de taille ou d'ombre de contact.
Les cinq images chargent ; affichage/masquage vérifié et capture inspectée dans
`artifacts/spine_trial/achille_graphique_v1/review.jpg`.

Suite : recueillir la revue de la silhouette et du niveau de simplification.
Préserver les originaux ; ne pas lancer de kit complet ou de nouvel habillage 3D
avant d'avoir une direction convaincante. Le squelette restera une aide aux poses.
