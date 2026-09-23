# Corrections après audit — 23 septembre 2026

Base : `ad1f4c58`. Audit précédent conservé sans le réécrire comme s'il décrivait
les corrections. Pas de modification des fichiers du pull hors intégration des salles.

- Neuf destinations, exactement trois rencontres spéciales par chemin, sans
  modifier les nœuds canoniques ni les sauvegardes de route.
- Chefs par rôle explicite ; Collecteur chef du convoi, deux porteurs seulement,
  molosse combattant ordinaire. Tests contre un changement massif de PV et d'ordre.
- Sablier et réservoirs : topologies distinctes du jardin, projection Studio conservée.
- Presse et sablier persistent après la mort du chef jusqu'à l'élimination du
  dernier ennemi ; les commandes physiques restent utilisables. Le recentrage
  du sablier sur un chef mort est refusé. Jardin et convoi restent liés au chef.
- IA locale partagée par combat public et sonde ; évitement du danger, profils
  téméraires et occupation des réserves, avec coûts et dangers natifs conservés.
- Sonde continue : mêmes règles de salle, livraisons, activation des porteurs,
  stockage, explosions ; commandes élémentaires du bot et métriques dédiées.
- Nouveau contrôle des cinq salles dans la boucle de simulation ; héros de
  départ renforcé explicitement, aucune conclusion d'équilibrage humain.

Vérifications :
- Tests ciblés finaux : `./dev.ps1 test test/unit/test_catabase_tactical_rooms.gd`,
  **PASS**, 15/15, 294 assertions, import valide, aucune erreur stricte.
  `artifacts/dev/20260923-140113-test-test_unit_test_catabase_tactical_rooms.gd-d0d75542/gut-strict-report.json`.
  Couvre aussi les dangers persistants, les chefs, les trajets et les objectifs IA.
- Sonde : cinq cas terminés, zéro erreur, stderr vide ; impacts forge=2,
  sablier=8, livraisons convoi=2, décharge réserve=1.
  `artifacts/dev/20260923-134459-tactical-harness-corrected-a93951f9/`.
  Les métriques supplémentaires sont couvertes par les exécutions ci-dessous.
- Réservoirs public : stockage, décharge, retour des cartes et victoire ; capture
  1280×720 inspectée, stderr vide.
  `artifacts/dev/20260923-134641-corrected-reservoir-1280x720-856030da/`.
- Convoi public : Collecteur 140 PV identifié, molosse attaquant, porteur étourdi
  immobile, cartes et tour rendus ; capture 1280×720 inspectée, stderr vide.
  `artifacts/dev/20260923-134749-corrected-convoy-1280x720-9377828f/`.
- Sablier public : abris, sursis et victoire vérifiés ; capture 1200×896 inspectée,
  stderr vide. `artifacts/dev/20260923-135111-corrected-hourglass-1200x896-321d5e71/`.
- Sonde avec les métriques de réserve : cinq cas, zéro erreur, 3 charges stockées
  et une décharge ; stderr vide.
  `artifacts/dev/20260923-135025-tactical-harness-final-4c3d7990/`.
- Suite Catabase : `./dev.ps1 test catabase -TimeoutSeconds 1800`, **FAIL**,
  585 tests, 78 565 assertions, 17 tests en échec.
  `artifacts/dev/20260923-134608-test-catabase-8aa0614c/gut-strict-report.json`.
  Les 17 identifiants sont tous présents dans le rapport du 22 septembre
  (`20260922-152613-test-catabase-aded9c86`) : icônes/arts, sélection,
  seuil, formations, objets de départ et inventaire/reliques. L'accès à
  `grid_layout` sur Nil et des ressources non libérées restent aussi signalés.
  Aucune validation globale annoncée ; les contrôles ciblés finaux couvrent
  les modifications de persistance réalisées pendant cette longue suite.
- Sonde finale après persistance des dangers : cinq cas terminés, zéro erreur,
  sortie 0 et stderr vide.
  `artifacts/dev/20260923-135448-tactical-harness-persistent-hazards-b34ca810/`.
  Impacts forge=2 et sablier=8, livraisons=2, charges stockées=3, décharges=1.
  Le bot gagne la forge et perd les quatre autres combats : le succès de cette
  sonde signifie que les cinq boucles s'exécutent, pas qu'elles sont équilibrées.

Contrôle final : `git diff --check`, aucune erreur.
Les autres documents d'enquête gameplay apparus pendant le travail ont
été préservés ; ils ne font pas partie de cette correction. Aucun commit créé.

Les propositions de nouvelles cartes de pioche/défausse, d'intégration de Charon
et de recalibrage chiffré restent des travaux de conception distincts ; aucune
modification arbitraire de ces systèmes n'est incluse dans cette correction.
