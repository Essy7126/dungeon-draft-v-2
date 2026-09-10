# Passe-rive — marche peinte V3

Livraison du 10 septembre 2026 : cycle complet dans la direction trois-quarts retenue,
12 dessins PNG RGBA de 320 × 480 pixels, 10 images/s, durée 1,2 s. **Revue artistique
encore nécessaire** : cette fiche ne transforme pas la validation des pieds du
mannequin V2 en validation des pieds peints.

## Voir et utiliser

- [Revue animée](http://127.0.0.1:8734/files/passe_rive_walk_v3/review.html) :
  lecture normale/ralentie, image par image, images voisines, fond clair/sombre,
  déplacement sur le décor Émeraude et planche des pieds.
- [Livraison PNG et ressource Godot](delivery/README.txt).
- [Atlas](delivery/walk_atlas.png), [PNG animé transparent](delivery/walk_transparent.png),
  [SpriteFrames pour le dépôt](delivery/walk_E.tres), [manifeste](delivery/manifest.json).
- ZIP et GIF dans `artifacts/spine_trial/passe_rive_walk_v3/` depuis la racine du dépôt.
  Le ZIP contient aussi un projet Godot autonome. Aucun remplacement du personnage
  principal en combat n'a été effectué.

## Origine des dessins

ImageGen intégré, deux appels avec la référence canonique Passe-rive et une planche
de douze rendus de la marche Blender V2. Le candidat A conserve trop de poses de
jambes semblables et est rejeté. Le candidat B, guidé d'abord par les poses du
mannequin, est utilisé dans la livraison.

- `candidate_a_rejected.png` et `generation_prompt.txt` : tentative écartée.
- `candidate_b_rgb.png` et `generation_prompt_b.txt` : source retenue et prompt exact.
- `blender_12_pose_guide.png` et `guide_manifest.json` : guide et indices des rendus.
- `rgb_frames/`, `rgba_frames/` et `cutout_report.json` : découpage et détourage.

La planche générée mesure réellement 1182 × 1330 pixels, malgré la demande de
résolution supérieure. Les cellules sont découpées à leur échelle native, puis
placées dans un canevas transparent de 320 × 480. Aucun agrandissement artificiel.
Le détourage utilise l'outil logiciel déjà autorisé par l'utilisateur. Les rangées
2 et 3 sont décalées de 6 et 22 pixels vers le bas pour corriger le placement de la
planche ; aucune déformation ni normalisation de taille par pose.

Ludo était à l'écran de connexion. Aucun job Higgsfield n'a été lancé et aucune
génération gratuite n'a été consommée : son utilisation reste sans réponse explicite.
L'envoi externe du guide vidéo n'a pas été confirmé. La livraison présente provient
des deux appels ImageGen, pas d'un transfert vidéo revendiqué comme réussi.

## Vérifications réalisées

- 12 PNG transparents, atlas 4 × 3 de 1280 × 1440 pixels ; chaque cellule relue est
  identique aux pixels du PNG livré. GIF et APNG contiennent chacun 12 images.
- Revue Chromium : 12 images chargées, lecture/pause/ralenti, fonds et images
  voisines, absence de débordement à 390 px, aucune erreur JavaScript ou requête
  échouée. Rapport : `artifacts/spine_trial/passe_rive_walk_v3/browser_report.json`.
- Captures des phases 0, 6 et 11, dont fond clair, inspectées ; planche des pieds
  inspectée. Les contours sont lisibles sur les deux fonds. L'alternance des poses
  est présente ; le déplacement exact des contacts peints n'est pas quantifié.
- Godot 4.7.1 : import et lecture du projet autonome à 30 fps simulés pendant
  90 images, sans erreur dans `godot_import_verified.log` et `godot_run_verified.log`.
  Les premiers lancements confinés ont rencontré des droits d'accès au profil
  utilisateur ; les vérifications réussies utilisent les permissions normales.

Les variations du masque, des pans de tissu et de la lance restent visibles.
Les deux premières poses de l'appui gauche sont proches : vérifier le glissement
résiduel à la vitesse du jeu avant validation artistique. La marche ne contient
ni transition avec l'idle ni autres directions.

## Reproduire

Scripts dans `tools/passe_rive_motion/` : `prepare_walk_v3.cjs` assemble le guide,
`cutout_walk_v3.py` prépare l'alpha, `package_walk_v3.cjs` assemble les ressources,
`export_walk_v3.py` crée GIF/APNG/ZIP et `verify_walk_v3.mjs` vérifie la revue.
Les scripts de génération du guide et de détourage protègent les sources existantes.
Les scripts d'assemblage régénèrent seulement cette livraison V3 et ses aperçus.

Avant de changer la mécanique, lire la [mémoire d'animation](../../../../../docs/ai/animation_memory.md)
et les retours utilisateur les plus récents.
