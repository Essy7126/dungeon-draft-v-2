# Sentinelle — première passe d'habillage

> Retour ultérieur de l'utilisateur : habillage trop éloigné du sprite original,
> donc écarté comme direction artistique. La suite utilise Blender comme référence
> de mouvement et le sprite peint comme référence de dessin. Voir
> [l'essai guidé](../../sprite_workshop/sentinelle_guided_v1/README.md).

## Décision du 10 septembre 2026

Après le gain de cohérence du pilote Blender et la correction du bouclier,
l'utilisateur demande : « Ok continue la mission ». La suite porte sur
l'habillage d'un seul estoc, avant la déclinaison du kit et le transfert Spine.

Le fichier `source_pose.blend` conserve une copie de la scène interactive au
début de cette étape, y compris son état non sauvegardé. Le pilote original
`../sentinelle_blocking_v1/sentinelle_blocking_v1.blend` reste disponible.
Le nouveau fichier de travail est `sentinelle_armor_v1.blend`.

## Contenu

- Même rig de 27 os, mêmes actions Estoc_Preview et Estoc_Blocking, même bouclier
  diagonal. L'empreinte des clés, tangentes et interpolations est comparée
  avant/après l'habillage dans `build_report.json`.
- Casque à ouverture en T, plaques pectorales et dorsales, ceintures abdominales,
  bordures des épaulières, charnières de coude et de genou, gantelets et bottes.
- Bouclier : bronze patiné, lambda turquoise, fissures, rivets et supports arrière.
- Détails dans la collection `Armor_details`, attachés aux os. Les surfaces
  cachées restent présentes dans la géométrie ; elles ne sont pas inventées
  depuis une découpe de l'image visible.
- Les plaques du casque et du torse épousent leur surface grâce à une subdivision
  projetée sur le volume ; des polygones plans s'enfonçaient dans les volumes.
- Matériaux procéduraux stables sur les pièces. C'est une étude d'habillage 3D,
  pas encore les dessins peints finaux ni un rig Spine livré.

## Revue

[Comparaison animée](http://127.0.0.1:8734/files/sentinelle_armor_v1/review.html)
entre mannequin et habillage, même caméra et même image. Quatre directions,
25 images chacune, lecture, pause, ralenti et séparation avant/après.
Le contact reste à 0,40 s sur un estoc de 0,80 s.

Les rendus originaux sont dans `artifacts/dev/sentinelle-armor-v1/` à la racine
du dépôt. `review/` conserve quatre GIF, une planche, la garde et le contact E,
ainsi que les empreintes dans `manifest.json`. Les GIF ajoutent une pause de
500 ms en fin de lecture ; elle ne fait pas partie de l'animation source.

## Reproduction

Scripts dans `tools/blender_sentinelle/` :

1. `build_armor.py` s'exécute depuis `source_pose.blend` en arrière-plan.
   Il refuse un fichier de sortie existant. `--replace-generated` est réservé
   à une reconstruction explicite de cette proposition non retouchée à la main.
2. `render_armor.py` s'exécute depuis le fichier habillé, puis la copie source.
   Le mode `--preview` ne rend que cinq images et ne valide pas la séquence.
3. `package_armor.py` exige les 200 rendus complets, dimensions et dates conformes,
   puis assemble la revue et ses médias.
4. `verify_armor_web.mjs` exerce les quatre vues synchronisées, lecture,
   ralenti, pause, comparateur et largeur mobile. Les preuves complètes sont
   dans `artifacts/dev/sentinelle-armor-v1/web_validation.json`.

## Vérifications de cette passe

Base Git observée : `2473c335`, avec les travaux concurrents préservés.
Construction et rendus Blender terminés avec code de sortie 0. Les empreintes
avant/après des deux actions sont identiques. Les 200 images (100 par version)
ont été contrôlées : présence, dimensions, fraîcheur après sauvegarde et hachages.

Les 11 contrôles de la revue web passent, sans erreur : synchronisation et
lecture dans les quatre directions, ralenti/pause, modes avant/après,
séparation et absence de débordement horizontal sur une largeur de 390 px.
La planche finale, les vues arrière Blender et la présentation web ont été
inspectées. Les rapports techniques ne valent pas approbation artistique.

L'inventaire `armor_groups.json` regroupe 152 objets visibles sur 18 os porteurs,
dont 122 nouveaux détails. Il décrit des pièces Blender, pas des calques Spine.
Aucun changement de ressource de combat ; aucune validation Godot nouvelle
n'est revendiquée pour cette passe d'habillage.

## Suite

Examiner l'identité du casque, la lisibilité des plaques et les raccords pendant
l'estoc à taille de jeu. La cohérence du mouvement a été appréciée sur le
mannequin ; cette nouvelle proposition d'habillage attend son propre retour.
Après cette revue, poursuivre les pièces peintes/Spine ou comparer le rendu
en sprites dans Godot selon le résultat. Les autres actions, dont marche,
sort et explosion noire, et l'intégration au combat restent à produire.
