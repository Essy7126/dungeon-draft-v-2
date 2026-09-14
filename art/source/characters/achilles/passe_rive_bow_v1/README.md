# Passe-rive — Tir céleste à l’arc

11 septembre 2026. Ajout à la palette existante sur la **touche 7**.

[Jouer le tir à l’arc](http://127.0.0.1:8734/files/passe_rive_spells_v1/review.html?spell=sky_bow) · [GIF](../../../../../artifacts/spine_trial/passe_rive_spells_v1/sky_bow.gif) · [atlas RGBA](../passe_rive_spells_v1/delivery/sky_bow_atlas.png).

Six dessins : encocher, lever l’arc, pleine tension, décocher, accompagner, abaisser l’arc. Le bras gauche porte l’arc vers le haut, la main droite ancre la corde près du visage et le coude de traction part derrière l’épaule. Le buste s’incline en arrière ; les pieds conservent une stance large. La lance et le bouclier sont rangés dans le dos.

La pleine tension dure **300 ms** ; la flèche part à **550 ms**, puis suit une trajectoire courbe vers une cible plus éloignée. Durée du geste : **910 ms**, avec retour au repos à l’arc. La flèche vit indépendamment du geste et peut manquer une cible déplacée après la décoche. Les valeurs de dégâts et de portée restent celles du laboratoire.

## Sources et exports

- [bow_rgb.png](bow_rgb.png) : feuille retenue, 1024×1536, deux colonnes et trois lignes. [bow_rgb_v0.png](bow_rgb_v0.png) conserve la première version avec la pointe haute du deuxième arc légèrement coupée.
- [generation_prompt.txt](generation_prompt.txt), [framing_fix_prompt.txt](framing_fix_prompt.txt) : deux appels à **ImageGen intégré**. Aucun rig 3D.
- [layout.json](layout.json) : rectangles, petites exclusions des poses voisines, ancrages, durées et origine du projectile.
- [Six PNG transparents](../passe_rive_spells_v1/delivery/frames/sky_bow_00.png) à `sky_bow_05.png`, [APNG](../passe_rive_spells_v1/delivery/sky_bow.apng), atlas 1536×2304 et [SpriteFrames](../passe_rive_spells_v1/delivery/sprite_frames.tres), animations `sky_bow` et `sky_bow_idle`.

Détourage rembg / birefnet-general-lite autorisé précédemment. Pour cet arc, les composants d’alpha sont tous conservés afin de ne pas supprimer les cordes fines ; les petits fragments des poses voisines sont exclus explicitement avant détourage. Les cellules livrées font 768×768 avec marges, pivot `(320,662)`. Une seule mise à l’échelle 1,06 pour les six poses, sans déformation des membres ni upscale IA.

## Vérifications et limites

Atlas comparé à chaque PNG ; contrôle visuel de la pleine tension dans le décor et sur fond uni. [Vérification navigateur](../../../../../artifacts/spine_trial/passe_rive_spells_v1/verification.json) : 43 images chargées, sept touches, six phases d’inspection, tension tenue sans projectile anticipé, départ de la flèche à la décoche, trajectoire ascendante puis descendante, un impact différé, flèche conservée pendant un sort suivant et raté si la cible se déplace. [Exécution Godot](../../../../../artifacts/spine_trial/passe_rive_spells_v1/godot_smoke.log) : sept actions, pleine tension, décoche, projectile et repos à l’arc.

Une seule direction. Les changements d’équipement entre arc, lance et marche sont instantanés dans l’atelier ; aucune animation d’équipement n’est annoncée. Six poses clés avec quelques variations du dessin et des appuis, pas une animation continue ou des contacts physiquement mesurés. La qualité artistique reste à valider par l’utilisateur. Les six gestes précédents restent disponibles.
