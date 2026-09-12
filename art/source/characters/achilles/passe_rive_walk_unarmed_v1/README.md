# Passe-rive — marche sans armes V1

12 septembre 2026. **Nouveau candidat produit et contrôlé ; avis artistique utilisateur encore attendu.**

[Aperçu animé, quatre orientations](http://127.0.0.1:8734/files/passe_rive_walk_unarmed_v1/review.html)

La marche est reconstruite à partir de pièces 2D stables, sans lance ni bouclier.
Le masque, le torse et les vêtements ne sont plus régénérés pour chaque image.
Les appuis, les genoux, le bassin, le contre-balancement des bras et le retard
des tissus sont réglés séparément. Le rendu est entièrement fait des pièces
dessinées ; les repères spatiaux servent à leur placement et à leurs déformations.

## Contenu

- Quatre vues réellement dessinées : E bas-droite, S bas-gauche, N haut-droite, W haut-gauche. Aucun retournement de personnage entier.
- 48 images RGBA de 768 × 768 par vue, cycle de 0,8 seconde, pivot commun (384, 662).
- Quatre atlas de sortie 8 × 6 sous `artifacts/spine_trial/passe_rive_walk_unarmed_v1/`, avec PNG séparés et WebP animés.
- `E_parts.png`, `S_parts.png`, `N_parts.png`, `W_parts.png` : planches originales, **ImageGen intégré**, aucun fallback API.
- `prompts/` : les quatre prompts exacts. `parts/` : pièces détourées, fond damier retiré avec le détourage logiciel déjà autorisé.
- `E_editable.ora`, `S_editable.ora`, `N_editable.ora`, `W_editable.ora` : poses assemblées en calques, ouvrables dans Krita. Les PNG d'origine restent disponibles sans transformation dans `parts/`.
- `motion.json` et `*_attachments.json` : paramètres du mouvement et attaches artistiques.
- Laboratoire Godot : `tools/passe_rive_unarmed/WalkReview.tscn`, ouvrir puis F6. Vraies grille, collisions et recherche de chemin de la forêt.

## Corrections réalisées pendant la production

Premier angle inspecté avant les suivants. Bassin relevé après constat d'une
démarche trop accroupie ; bras amplifiés ; volume des sandales accru ; recouvrements
aux genoux et coudes corrigés. La cape passe devant les jambes en vue de dos.
La sandale N/14 avait été dessinée à contresens : N utilise explicitement la
sandale arrière correcte N/10 pour les deux pieds, avec leurs attaches distinctes.
La cellule incorrecte originale est conservée pour traçabilité et n'est pas affichée.

Les pièces de pied sur pointe (cellule 11) sont conservées mais **pas utilisées
dans cette version** : le pied plat est déformé à partir de trois attaches
cheville/talon/pointe. Pas de remplacement de dessin prétendument validé.

## Vérifications et limites exactes

- 192 images présentes, transparentes, sans découpe au bord.
- 2 304 échantillons d'articulation ont des pixels opaques dans le voisinage contrôlé ; cela ne prouve pas toute la silhouette sans défaut.
- 9 600 poses intermédiaires contrôlées pour la portée des jambes.
- Raccord dernière/première image : variation de pixels inférieure à la variation médiane du cycle dans les quatre vues (rapports 0,85 à 0,91).
- Contacts talon/pointe stationnaires dans le modèle en phase d'appui, compensation des deux axes isométriques. Ce contrôle porte sur les attaches du dessin, pas sur un suivi indépendant de toute la semelle peinte.
- Navigateur : quatre atlas, lecture/pause, pas d'image et retour de boucle, ralenti, repères et format mobile vérifiés sans erreur JavaScript.
- Godot 4.7.1 : **219 contrôles réussis avec rendu GPU**, 192 textures et déplacements dans les quatre directions, pause commune du trajet et de l'animation, arrivée exacte, obstacles et hors-carte rejetés. Quatre captures natives inspectées.
- Source des preuves : `artifacts/spine_trial/passe_rive_walk_unarmed_v1/asset_verification.json`, `browser_verification.json`, `godot_walk_report.json`, `godot_walk_visual.log`, captures `godot_walk_*.png` et `browser_*.png`.

Le tissu reste animé avec une déformation simple. Le laboratoire fige l'image
à l'arrêt ; les transitions de départ/arrêt et l'idle ne sont pas encore produits.
Les virages changent de dessin instantanément. Ces points ne doivent pas être
annoncés comme finalisés. Les validations techniques ne valent ni validation
artistique ni équivalence avec la qualité de Dofus.

## Reprise ciblée

Outils sous `tools/passe_rive_unarmed/` : `extract_parts.py` (détourage avec cache),
`build_walk.py E|S|N|W` (assemblage et export d'une vue), `verify_assets.py`,
`verify_browser.mjs`, `verify_walk.gd`.

Modifier une attache dans le JSON de la vue ou le mouvement commun puis reconstruire
la vue concernée. `configure_angles.py` contient les valeurs initiales et **écrase
les attaches S/N/W** : ne pas le relancer après une retouche manuelle sans comparer.
Le mannequin analytique de `tools/passe_rive_motion/walk_model.py` reste une
dépendance pour les contacts ; ce n'est pas un nouvel habillage de rig 3D.

Enseignements repris du [dossier Dofus](../../../../../docs/design/achilles/dofus_animation_method_2026-09-11.md) : pièces communes,
projection cohérente, travail aux tailles agrandie et jeu, correction locale,
validation d'une animation avant la suivante. Sources professionnelles :
[charte de Julien Druant](https://www.behance.net/gallery/251142101/charte-graphique-pour-les-personnages-Dofus-3),
[marionnette de Nicolas Détrain](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation).
Aucun pixel Dofus n'est utilisé dans le personnage ou ses exports.

Suite : recueillir le ressenti sur cette marche, corriger l'angle et la phase
identifiés, puis traiter départ/arrêt et idle lorsque cette marche est acceptée.
Les sorts et le catalogue public restent hors de ce lot.
