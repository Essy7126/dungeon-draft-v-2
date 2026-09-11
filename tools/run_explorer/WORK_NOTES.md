# Explorateur de run — livraison du 11 septembre 2026

- Base : e3ad3060. README et audit du 11 septembre déjà modifiés avant cette tâche.
- Objectif : navigateur natif de toutes les destinations, décor/plan et essais jouables isolés.
- Réutiliser ExpeditionRouteCatalog, ExpeditionMapCanvas, ExpeditionRunFactory, les haltes et ArenaDirectTestConfiguration. Aucun changement des règles ni des ressources de production.
- Accès : menu Outils du plugin Studio, scène F6 et lanceur PowerShell.
- Vérifier : données et variantes, identité des rencontres, préparation valide des snapshots de laboratoire, isolation des sauvegardes, rendu 720p/1080p, clic réel, lancement combat/halte/DA.
- État : implémenté et lancé ; aucun commit effectué.
- `./dev.ps1 doctor -GodotPath <Godot 4.7.1>` : PASS, résolution du moteur configurée localement.
- `./dev.ps1 test test/unit/test_run_explorer_catalog.gd -GodotPath <Godot 4.7.1>` : PASS, 6 tests / 1 034 assertions (rapport `artifacts/dev/20260911-104612-test-test_unit_test_run_explorer_catalog.gd-d1c930a6`).
- `./dev.ps1 test test/unit/test_expedition_route_overview.gd -GodotPath <Godot 4.7.1>` : PASS, 3 tests / 3 209 assertions (rapport `artifacts/dev/20260911-105954-test-test_unit_test_expedition_route_overview.gd-99a7ed05`).
- `./tools/run_explorer/verify.ps1 -PreviewsOnly -GodotPath <Godot 4.7.1>` : PASS, huit scènes chargées et capturées en 1280×720 (rapport `artifacts/dev/20260911-105533-run-explorer-verify-01111ccd`).
- `./tools/run_explorer/verify.ps1 -BrowserOnly` : PASS, 154 contrôles, captures 1280×720 et 1920×1080, clics, checkpoints, lancement du processus depuis l'explorateur et restauration de l'environnement parent (rapport `artifacts/dev/20260911-110317-run-explorer-verify-7b8164a6`).
- Inspection visuelle effectuée : navigateur 720p/1080p, premier combat, halle, arène modulaire en mode DA.
- `./artifacts/dev-tools/gdscript-formatter.exe --check tools/run_explorer test/unit/test_run_explorer_catalog.gd` et `git diff --check` : PASS.
- Import Godot validé hors sandbox après erreur initiale du magasin de certificats. Les premiers essais du vérificateur ont révélé un checkpoint partagé et une mauvaise détection de disponibilité de la halle ; corrigés et rejoués avec succès.
- Limites : chargement et contrôles d'ouverture validés, pas de victoire complète ni de campagne jouée. Préparation synthétique du personnage. Le menu éditeur nécessite de recharger le plugin ; son interaction manuelle n'a pas été exercée.

## Suite : dispositions par destination

- Demande : noms d'arènes et dalles distincts selon la destination, conserver décors et ennemis.
- 36 variantes dans `data/rooms/catabase_routes/`, résolveur partagé jeu/explorateur, bouton Décor / dalles. Étapes communes et haltes conservées.
- Génération initiale en mode script : erreurs de compilation des dépendances avant initialisation des autoloads, malgré la sortie des ressources. Outil converti en scène. Refus d'écrasement vérifié ; réparations ciblées des deux doublons réussies via la scène.
- Test `./dev.ps1 test test/unit/test_catabase_route_layouts.gd` : PASS, 2 tests / 15 870 assertions. Rapport `artifacts/dev/20260911-124234-test-test_unit_test_catabase_route_layouts.gd-4019b3c6`.
- Premier contrôle graphique : deux branches II ouvertes ; branche III DA chargée mais fuite à la fermeture. Fermeture différée du laboratoire corrigée.
- Validation finale `./dev.ps1 test test/unit/test_catabase_route_layouts.gd` : PASS, 3 tests / 15 940 assertions, dont placements du roster sur chaque variante de combat de la graine 2401. Rapport `artifacts/dev/20260911-124913-test-test_unit_test_catabase_route_layouts.gd-cd877cf9`.
- `./dev.ps1 test test/unit/test_run_explorer_catalog.gd` : PASS, 6 tests / 1 037 assertions. Rapport `artifacts/dev/20260911-125049-test-test_unit_test_run_explorer_catalog.gd-247111e4`.
- `./tools/run_explorer/verify.ps1 -RouteVariants` : PASS, navigateur 720p/1080p et 154 contrôles, lancement enfant, cinq scènes de variantes (deux branches II jouables, deux branches III en DA, branche XVIII jouable). Rapport `artifacts/dev/20260911-124535-run-explorer-verify-8946b87c`. Captures II/III et navigateur 720p inspectées visuellement.
- Format ciblé et `git diff --check` : PASS. Les métadonnées d'import hors périmètre ont été sauvegardées sous artifacts/dev puis retirées des changements.
- Limite : aucun combat joué jusqu'à la victoire ; les décors, ennemis et points de convergence restent communs conformément au périmètre demandé.
