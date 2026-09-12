# Passe-rive — Moisson vitale

Ajout du 11 septembre 2026, **touche 9**. [Essayer Moisson vitale](http://127.0.0.1:8734/files/passe_rive_spells_v1/review.html?spell=vital_harvest).

Six poses sans arme visible : bras bas légèrement pliés, torse ouvert vers l’avant et tête rejetée en arrière. Les paumes deviennent vertes, les jambes se relâchent et les pieds se rapprochent pendant une brève lévitation. Une petite explosion rouge jaillit du torse et se prolonge en traînée vers l’adversaire. Retour doux au sol, mains libres.

| Pose | Durée |
| --- | --- |
| Se recueillir | 140 ms |
| Éveiller les paumes | 180 ms |
| S’élever | 300 ms |
| Libérer la vie | 95 ms |
| Rester suspendu | 260 ms |
| Se poser | 225 ms |

Émission à **620 ms**, durée totale **1200 ms**. La montée atteint 36 pixels dans la cellule, soit environ 20 pixels à l’échelle du laboratoire. L’ombre reste au sol, le point de déplacement ne change pas. Le projectile rouge va du torse vers une cible devant le personnage, en 360 ms ; l’impact applique 34 dégâts de test une seule fois. Ces valeurs servent au laboratoire, sans modification des règles de campagne.

## Sources et sorties

- [vital_rgb.png](vital_rgb.png) : feuille de six poses, 1024×1536, deux colonnes et trois lignes. **Un appel ImageGen intégré**, guidé par le canon Passe-rive ; [prompt complet](generation_prompt.txt).
- [layout.json](layout.json) : découpes, ancrages, durées, courbe de lévitation et points d’attache des paumes et du torse. Définition également intégrée au manifeste commun.
- Détourage logiciel précédemment autorisé : rembg / birefnet-general-lite, décontamination ; même échelle 0,94 pour les six dessins, sans reconstruction des membres. Cellules RGBA 768×768, pivot `(320,662)`.
- [Six PNG](../passe_rive_spells_v1/delivery/frames/vital_harvest_00.png) à `vital_harvest_05.png`, [atlas 1536×2304](../passe_rive_spells_v1/delivery/vital_harvest_atlas.png), [APNG des poses](../passe_rive_spells_v1/delivery/vital_harvest.apng), [SpriteFrames](../passe_rive_spells_v1/delivery/sprite_frames.tres) : `vital_harvest` et `vital_harvest_idle`.
- [Aperçu animé en jeu](../../../../../artifacts/spine_trial/passe_rive_spells_v1/vital_harvest_live.gif) : capture du personnage et de sa cible, incluant lévitation, lueurs, traînée et impact.

Les paumes sont teintées dans les dessins. La montée, la lueur verte, l’explosion et la traînée rouges sont des effets séparés, attachés aux poses et pilotés par la même chronologie. [Rendu navigateur](../../../../../tools/passe_rive_spells/vital_fx.mjs), [calque d’effets Godot](../../../../../tools/passe_rive_spells/vital_effect_layer.gd). Les PNG et APNG seuls ne contiennent pas ces effets ni le déplacement vertical ; utiliser les scripts et le manifeste pour retrouver le résultat complet.

## Vérifications

[Rapport navigateur](../../../../../artifacts/spine_trial/passe_rive_spells_v1/verification.json) : 55 images chargées, neuf touches, lévitation bornée et retour à zéro, origine sur le torse surélevé, aucun projectile anticipé, déplacement vers l’adversaire, un impact différé, raté si la cible se déplace et nettoyage à la réinitialisation. Contrôle visuel de la traînée rouge activée/désactivée, fond clair et affichage mobile. Les vérifications des huit gestes précédents restent exécutées.

[Tests Godot](../../../../../artifacts/spine_trial/passe_rive_spells_v1/godot_smoke.log) : neuf gestes, sprite en lévitation avec point au sol conservé, émission à la bonne pose, impact même effets désactivés et retour au repos sans arme. [Capture native](../../../../../artifacts/spine_trial/passe_rive_spells_v1/vital_godot.png), [contrôle GPU des effets](../../../../../artifacts/spine_trial/passe_rive_spells_v1/vital_gpu.log). Atlas comparés pixel par pixel aux 42 poses du kit.

Une seule direction, six poses peintes et raccords stylisés à juger en mouvement. La disparition des armes au changement de geste reste instantanée, comme le changement d’équipement des tirs précédents. Il s’agit d’un essai d’animation et d’effets ; aucune intégration du sort au combat de campagne n’est annoncée.
