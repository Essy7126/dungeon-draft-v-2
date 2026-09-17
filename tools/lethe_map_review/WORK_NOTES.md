# Léthé II — adaptation de la map existante

- Dernier retour utilisateur (11 septembre 2026) : eau insatisfaisante et effets
  torche/lampe imperceptibles. Le PASS GPU ci-dessous reste uniquement technique.
  Recherche primaire Valve/Godot consignée dans
  `docs/maps/lethe_shader_research_2026-09-11.md`. Reprise visuelle à faire, une
  composante à la fois ; aucune nouvelle implémentation dans cette recherche.

- Cible confirmée par l'utilisateur : Les traces du Léthé, étape II,
  `data/rooms/catabase_routes/route_f51a86b714b9/room.tres`.
- Une seule map adaptée. Le tronçon exclusif de cinq escales reste à construire
  salle par salle ; aucun changement de liaison n'est livré ici.
- Pipeline lue : `docs/maps/registered_terrain_pipeline.md` et
  `docs/maps/combat_da_2026-09-10.md`.
- Géométrie préservée : 112 dalles, 13 obstacles, départs et rencontre.
  Guide préparé depuis le manifeste, puis peinture image_gen guidée par ce plan,
  avec Autel et Étal comme références directes ; barque latérale et milieu aquatique.
- `prepare.py` sauvegarde une référence avant changement dans artifacts/dev/lethe-traces/before
  et produit le guide ; `apply.py` applique uniquement le plan visuel de cette salle.
- `PrepareRoom.tscn` utilise ArenaRuntimeBridge et ArenaSnapshotService pour
  sauvegarder le profil de présentation local : zoom 1.0, décalage X -80 borné.
  Empreinte gameplay avant/après : 6c270a92cbce87dae00ba15dfa4bcd9177556bf603df76bb53dd024654364f02.
- Référence avant : artifacts/dev/20260911-154606-lethe-traces-review-8b09ebfb.
  Le premier essai avait révélé que Review exigeait un bandeau même désactivé
  explicitement. Le reviewer respecte maintenant ce cas déclaré, sans ignorer
  une erreur d'un bandeau activé.
- Import + test_catabase_route_layouts : PASS, 3 tests / 15940 assertions,
  artifacts/dev/20260911-155346-test-test_unit_test_catabase_route_layouts.gd-4900f0e6.
- Première QA graphique PASS aux deux résolutions, mais inspection visuelle
  insatisfaisante : aplats noirs des vides et barque coupée en format étroit.
  Corrections : fond des vides transparent, parois conservées, caméra locale.
- Vérification finale en cours : verify.ps1 utilise le reviewer et les oracles
  partagés ; ajoute la comparaison des proportions entre les deux résolutions.
- Aucun commit ; préserver les modifications des étapes antérieures.

- Vérification finale PASS : artifacts/dev/20260911-161538-lethe-traces-review-759df23c, deux résolutions, géométrie/support/matériaux/clics/déplacement/garde/cadrage et comparaison inter-résolutions. Captures 1080p après garde et 1200x896 inspectées : barque entière, pas d'aplat noir. Test après préparation PASS 3/15940 : artifacts/dev/20260911-162029-test-test_unit_test_catabase_route_layouts.gd-6eafd9c6. Aperçu jouable ouvert via open.ps1, rapport 20260911-162332-lethe-traces-play-4a79ad61. Métadonnées d'import hors périmètre sauvegardées et retirées.

- Shaders eau/torche/lanterne : PASS, rapport 20260911-165646-lethe-traces-review-ccb4bc95. 8 images GPU, eau 1932/1935 échantillons modifiés, torche 543/570, lanterne 509/510, sol 0/84. Horloge et gel en mouvement réduit validés. Oracles de combat et comparaison des proportions PASS aux deux résolutions. Capture motion-04 inspectée. Room et manifeste géométrique restent inchangés. Premier essai échoué car contrôleur placé dans YSortedWorld ; corrigé par layer=foreground conformément au contrat de décor.

- Reprise implémentée : water_flow.json décrit le contour aquatique et dix
  exclusions ; courant RG et masque B construits au chargement. Deux phases
  déplacent la peinture, sans nouvelles caustiques. Pied de flamme fixe,
  verre/halo/reflet de lanterne modulés séparément.
- Premier contrôle 20260911-174220-lethe-traces-review-e00b1f45 échoué : témoin
  de mur hors écran (zéro échantillon). Témoin replacé dans une zone visible.
- QA GPU finale PASS : 20260911-175102-lethe-traces-review-063c4286,
  1920x1080 et 1200x896. 48 états ; sol/coque/mur témoins stables,
  horloge et mouvement réduit valides. Captures fixes inspectées.
- Processus, limites et réutilisation documentés dans
  docs/maps/painted_combat_effects_pipeline.md. Pas de validation artistique
  utilisateur déclarée, pas de benchmark ni de test d'export.
- Import et test de parcours final PASS : 3 tests, 15940 assertions,
  20260911-175909-test-test_unit_test_catabase_route_layouts.gd-ea2f8f47.
  Métadonnées produites par l'import sauvegardées sous
  artifacts/dev/lethe-shader-import-backup, exclues de la livraison.
