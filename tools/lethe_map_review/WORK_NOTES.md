# Léthé II — adaptation de la map existante

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
