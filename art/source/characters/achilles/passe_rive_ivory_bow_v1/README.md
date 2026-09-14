# Passe-rive — Trait d’ivoire

Ajout du 11 septembre 2026, **touche 8**. [Essayer le tir chargé](http://127.0.0.1:8734/files/passe_rive_spells_v1/review.html?spell=ivory_bow).

Un tir presque horizontal : Passe-rive descend sur sa jambe arrière fléchie, garde la jambe avant étendue et tire le coude derrière lui. L’arc de bronze s’épaissit en arc d’ivoire ; le bras de traction devient plus musclé. La charge tient une seconde, avec un léger tremblement local, avant la décoche et le retour à l’arc de bronze. Le costume et le reste de la silhouette conservent le canon élancé. Lance et bouclier sont dans le dos.

| Pose | Durée |
| --- | --- |
| Encocher | 140 ms |
| Descendre sur l’appui | 180 ms |
| Transformer l’arc | 300 ms |
| Tenir la puissance | 1000 ms |
| Décocher | 65 ms |
| Relâcher | 240 ms |

Décoche à **1620 ms**, durée totale **1925 ms**. Comparaison : Tir céleste à 550 ms / 910 ms. La nouvelle flèche part à 5° au-dessus de l’horizontale, avec une trajectoire directe ; les 52 dégâts et la portée sont des valeurs du laboratoire.

## Sources et méthode

- [ivory_rgb.png](ivory_rgb.png) : six dessins retenus, 1024×1536, deux colonnes et trois lignes.
- [generation_prompt.txt](generation_prompt.txt) et [stance_fix_prompt.txt](stance_fix_prompt.txt) : **ImageGen intégré**, un appel de création puis une correction ciblée des appuis. [ivory_rgb_v0.png](ivory_rgb_v0.png) conserve le premier résultat, dont les jambes étaient trop droites.
- [layout.json](layout.json) : découpes, ancrages, durées, origine du projectile et zone du tremblement. Copie de cette définition dans le manifeste de production.
- Détourage logiciel précédemment autorisé : rembg / birefnet-general-lite, décontamination. Conservation de tous les composants d’alpha pour les cordes fines. Une seule échelle 1,06 pour tout le clip, aucune reconstruction des membres.
- [PNG RGBA](../passe_rive_spells_v1/delivery/frames/ivory_bow_03.png), [atlas 1536×2304](../passe_rive_spells_v1/delivery/ivory_bow_atlas.png), [APNG](../passe_rive_spells_v1/delivery/ivory_bow.apng), [SpriteFrames](../passe_rive_spells_v1/delivery/sprite_frames.tres). Cellules 768×768, pivot `(320,662)` ; les marges sont comprises dans cette résolution. Animations `ivory_bow` et `ivory_bow_idle`.

Le tremblement est une déformation locale de moins d’un pixel à l’échelle de jeu, limitée au bras arrière et croissante pendant la pleine charge. Il s’arrête à la décoche. [Shader Godot](../../../../../tools/passe_rive_spells/charge_tremor.gdshader) et [rendu navigateur](../../../../../tools/passe_rive_spells/tremor.mjs) appliquent la même zone et le même mouvement. Les pieds et la main qui porte l’arc ne bougent pas sous cet effet. Les PNG, SpriteFrames seuls et APNG décrivent les poses peintes : utiliser le shader et son pilotage pour retrouver le tremblement dans un autre projet.

[Aperçu enregistré avec tremblement](../../../../../artifacts/spine_trial/passe_rive_spells_v1/ivory_bow_live.gif) ; le GIF `ivory_bow.gif` issu de l’assemblage standard montre seulement les poses peintes.

## Contrôles et limites

[Rapport navigateur](../../../../../artifacts/spine_trial/passe_rive_spells_v1/verification.json) : 49 images, huit touches, charge sans projectile anticipé, décoche synchronisée, un impact, expiration hors portée, contrôle des autres gestes et absence de débordement mobile. Comparaison des rendus de pleine charge : changements limités au bras, pieds et arc identiques. L’inspecteur utilise un contexte de dessin stable pour éviter les écarts d’un niveau de couleur lors des lectures de pixels du navigateur.

[Tests Godot](../../../../../artifacts/spine_trial/passe_rive_spells_v1/godot_smoke.log) : huit gestes, charge, activation et arrêt du tremblement, décoche, flèche rapide, récupération ; test conservé du Tir céleste. Les atlas sont comparés pixel par pixel aux 36 poses du kit complet.

[Contrôle du rendu GPU Godot](../../../../../artifacts/spine_trial/passe_rive_spells_v1/ivory_gpu.log), OpenGL sur RTX 4070 : 730 pixels modifiés dans le bras, aucun changement significatif hors de cette zone. [Capture native](../../../../../artifacts/spine_trial/passe_rive_spells_v1/ivory_godot.png). Contrôle navigateur : 2224 pixels modifiés dans la zone du bras, zéro ailleurs.

Une seule direction et six dessins clés. Les raccords du costume, l’apparition de la musculature et la descente restent stylisés et à juger en mouvement ; le contrôle du tremblement ne prouve pas des contacts parfaits entre tous les dessins. Le changement d’équipement vers la marche et les autres armes reste instantané dans l’atelier. Aucune règle de campagne modifiée.
