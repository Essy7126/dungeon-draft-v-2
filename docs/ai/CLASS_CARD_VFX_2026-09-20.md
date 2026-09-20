# VFX Cartes — première bibliothèque intégrée

**Archive de la première passe.** La demande suivante de l’utilisateur a autorisé la reprise complète des cartes et sorts adverses dans la DA C, uniquement en run Cartes. État actuel : [reprise éthérée](CARDS_ETHEREAL_VFX_2026-09-20.md) ; [galerie et reproduction](../../tools/class_card_vfx/README.md). Les sources Blender et rapports ci-dessous restent historiques.

Décision artistique du 20 septembre 2026 : **C — Éthéré : transparence, lumière et volutes**, choisie explicitement par l'utilisateur sur la planche comparative. La réalisation graphique de cette première bibliothèque est rejetée ; ses vérifications techniques ne valent pas validation artistique. Référence : [charte retenue](../design/achilles/vfx_art_direction_proposal_2026-09-20.md). La planche est un concept fixe, pas un résultat Godot. Aucun asset ni code de combat remplacé pendant ce choix de DA.

Objectif : habiller toutes les cartes de la run Cartes actuelle et les faits associés, sans modifier les règles de combat.

État initial : catalogue en cours d'extension par une autre tâche (60 cartes de base + 28 d'initiation + 24 avancées). Préserver ses modifications ; couverture calculée depuis `ClassCardCatalog.pool()`.

Décisions : bibliothèque originale de géométrie Blender rendue en flipbooks arrière/avant, recettes par carte dans un catalogue VFX séparé, routeur purement visuel raccordé au gestionnaire existant. Réutiliser le soin du laurier approuvé. Les états, dégâts périodiques, boucliers et soins suivent les faits réellement émis. Aucun dégât, délai de combat ou coût changé par les VFX.

Fichiers livrés : `vfx/class_cards/`, `tools/class_card_vfx/`, `assets/vfx/class_cards/`, `art/source/vfx/class_cards/`, `test/unit/test_class_card_vfx.gd`. Seul fichier partagé modifié : ajout du routeur dans `core/vfx_manager.gd` (32 lignes). Aucun changement aux catalogues ni règles en cours de modification par l'autre tâche.

Livraison : 112 cartes + 2 gestes, 29 effets de carte, 12 statuts, 18 familles / 36 atlas ; soin précédent promu dans les assets de production. Maintien/expiration des états et garde, ticks, soins, critiques/esquives/immunités, terrains et arrivées de déplacement raccordés aux faits. Les surfaces persistantes restent gérées par le service de terrain existant.

Vérifications effectives : Blender 5.1.2, export 17 familles + soin, contrôles d'alpha/bords/dimensions ; galerie Godot GPU capturée (112 cartes, 48 frames GIF), sélection/cartes avancées/états inspectés. `./dev.ps1 test test/unit/test_class_card_vfx.gd` : PASS strict, 11 tests / 634 assertions, zéro erreur, rapport `artifacts/dev/20260920-184211-test-test_unit_test_class_card_vfx.gd-12e12c0f/`. Régression élargie 155 tests / 5413 assertions satisfaits, mais erreurs de nettoyage anciennes (elfe/GUT, Studio, Achille/Paris) : pas de PASS strict pour l'ensemble. Les fuites Achille/Paris sont reproduites à l'identique avec le VFXManager de HEAD ; la suite Cartes seule ne fuit pas.

Accès : `./tools/class_card_vfx/preview.ps1` ; guide détaillé `tools/class_card_vfx/README.md`. GIF `artifacts/dev/class_card_vfx/gallery/card_vfx_preview.gif`.

Suite : réaliser trois animations pilotes dans la DA C — Éclat de braise, Garde brève et Soin du laurier — avec des silhouettes et rythmes distincts. Les montrer dans Godot à taille de jeu, sur fonds clair/sombre et en superposition ; obtenir un accord sur ces résultats en mouvement avant de décliner le catalogue. Conserver les règles, le routeur et les contrôles fonctionnels. La galerie actuelle présente un mannequin fixe et les applications individuelles ; les parcours et zones sont vérifiés par les casts réels et les tests de lifecycle.
