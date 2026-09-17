# Catabase r6 — suivi d'intégration

Statut : WORKTREE_CANDIDATE, première passe intégrée. Date : 14 septembre 2026.
La cible humaine n'est pas certifiée ; résultats techniques et limites ci-dessous.
Base vérifiée : main@055584c37f60d99b2f87bdbb4d670895bf8ef2b2 ; worktree propre avant intervention.

## Autorité et objectif

L'utilisateur autorise l'intégration de la proposition de run 30–45 minutes,
les tests de run, l'audit et le rééquilibrage. NORMAL doit être exigeant et
chaque salle doit poser un choix utile. Catabase solo Achille/Passe-rive reste
le périmètre. Aucune autorisation Git (commit, push, branche, reset ou stash).

## Plan et propriété des changements

- Racine : route r6, difficulté persistée, récompenses/haltes, intégration,
  documentation et régression. Conserver les routes r2–r5 sauvegardées.
- Rencontres : budgets fixes, rosters, grades, Factory et clones de Pâris.
- Builds : effets des six armes, réserves, reliques, descriptions et tests.
- Validation : harnais de runs réelles Godot et métriques par rencontre.

Douze combats en I/II/III/V/VI/VIII/X/XII/XIII/XV/XVII/XX ; élites VI/X/XV ;
refuges VII/XI/XVI. Léthé II–VI conserve son trajet et ses lieux. La phase XIX
est une préparation sans gain gratuit. Les valeurs initiales du dossier sont
des hypothèses à corriger d'après les tests, pas des résultats garantis.

## Contrats de sécurité

Pas de nouveau deck, trio, méta-farming, enrage, chronomètre de réflexion ou
adaptation ennemie au build. Les ressources mutables sont isolées. Les
changements hors scope et fichiers utilisateur sont préservés. Tests ciblés,
runs, revue du diff, puis documentation réelle avant déclaration de fin.

## Vérifications successives

- Git initial : propre, branche et SHA ci-dessus.
- Instructions et README relus ; conception et modèle disponibles dans le
  dossier d'audit local de la tâche.
- Route r6, transactions et sélection Normal/Facile intégrées. Les anciennes
  révisions sont conservées ; XIX propose la préparation sans service gratuit.
- Import Godot 4.7.1 et smoke : PASS, 16 tests / 215 assertions,
  `artifacts/dev/20260914-153406-test-smoke-c0c3f1a2/gut-strict-report.json`.
- Contrat r6 : PASS, 5 tests / 4 483 assertions, 81 chemins ordinaires sur
  trois graines, Léthé et secrets, r2–r6, modes, refuges et reprise des reçus,
  `artifacts/dev/20260914-153716-test-test_unit_test_catabase_route_r6.gd-e65ad09e/gut-strict-report.json`.
  Victoires simulées dans cette suite : ce n'est PAS une preuve d'équilibrage.
- Les tests de route ont ensuite été étendus à huit cas : prévisions proches,
  séparation des cartes et transactions de mémoire tardive incluses. Les huit
  passent dans la première régression élargie ci-dessous.
- Effets r6 : PASS 7 tests / 80 assertions,
  `artifacts/dev/20260914-154428-test-test_unit_test_catabase_first_six_scaling.gd-d8a551d2/gut-strict-report.json`.
  Le premier essai avait une cible de test Braise hors portée ; ce défaut de
  fixture a été corrigé, et non compensé par une modification du gameplay.
- Audit statique complémentaire : les mémoires tardives ne doivent pas
  révéler la profondeur déjà choisie ; remplacement par un secours unique.
  Plaque r6 portée à max(24 ; 10 % PV) pour rester une vraie alternative aux
  +2 PM tardifs ; transaction couverte par les tests r6. Pas de nouveau système
  d'objets.

## Deuxième passe : runs et lisibilité

- Rencontres : PASS, 11 tests / 826 assertions, dont placement sur les vraies
  cartes ; `artifacts/dev/20260914-160351-test-test_unit_test_catabase_r6_enemy_balance.gd-7210784f/gut-strict-report.json`.
- Harnais continu V2 : 12/12 exécutions sans erreur moteur, trois routes
  complètes. Détail et interprétation dans
  [l'audit des runs](CATABASE_R6_AUDIT_RUNS_2026-09-14.md).
- Un défaut du pilote refusait les détours au Léthé : corrigé dans le harnais,
  sans changer la carte. Une oscillation résiduelle Lame/Xiphos en VIII est
  réduite par un correctif causal borné, rejoué sur trois cas sans erreur
  moteur. Lame Normal atteint XIII ; Xiphos Facile termine la route ; Xiphos
  Normal perd encore en VIII. Aucun affaiblissement ennemi n'est décidé sur ces
  échecs du bot. Les longs tours restent une limite de sa politique défensive.
- P1 trouvé par audit : les préparations d'attaques existaient en logique,
  mais leur couche visuelle n'était pas raccordée à Battle. Raccordement,
  isolation par grille et nettoyage intégrés. Test ciblé PASS : 1/1,
  17 assertions ; `artifacts/dev/20260914-163614-test-test_unit_test_catabase_tactical_telegraph_integration.gd-59e537e4/gut-strict-report.json`.
- Première régression élargie : 449 tests exécutés, 427 réussis, 22 échoués.
  Les défauts nouveaux de fixtures et de typage du harnais sont corrigés avant
  rejeu ; les attentes historiques d'assets/inventaire ne sont pas effacées.
  Rapport conservé :
  `artifacts/dev/20260914-163953-test-catabase-a56a3a43/gut-strict-report.json`.
- La revue GPU contrôle le départ, la préparation XIX et une vraie attaque
  retardée en 1280 × 720 et 1920 × 1080. Elle a entraîné une correction de
  texte tronqué, puis de taille de texte sous zoom. Les captures de départ/XIX
  utilisent des transactions de progression simulées et ne prouvent pas une
  victoire au combat.
- Deuxième régression : 452 tests, 433 réussis, 19 échoués. Les 35 tests des
  cinq suites ciblant route/effets/rencontres/harnais/télégraphes passent.
- La migration révélait aussi un vrai raccord de lieux encore indexé sur les
  anciennes profondeurs. Corrigé par identité de halte r6, sans remplacer les
  décors ou les services. Le marchand IV conserve sa salle, la forge rejoint IX.
- Rejeux : haltes/sauvegardes PASS 6 tests / 599 assertions ; peintures PASS
  9 tests / 6 004 assertions. Les preuves exactes sont dans le rapport principal.

## Bilan de clôture de cette passe

- Régression finale : 454 tests, 438 réussis, 16 échecs historiques, aucun
  test ignoré. Les sept suites directement liées à l'intégration totalisent
  50/50 tests réussis. Le verdict global reste FAIL, y compris les diagnostics
  de ressources à la fermeture ; ce n'est pas une certification de tout le dépôt.
  Preuve : `artifacts/dev/20260914-173134-test-catabase-014d0040/gut-strict-report.json`.
- GPU final : PASS 127/127, six images inspectées à 720p/1080p, aucune erreur
  moteur ; `artifacts/catabase_run_balance_validation/r6_ui_telegraph_screen_constant_20260914_1810/summary.json`.
- Runs : 12 configurations puis trois contre-tests, sans victoire forcée.
  Leurs résultats ne valident pas une durée humaine ou six presets gagnants.
- `git diff --check` propre. Branche/HEAD inchangés ; aucun commit ou push.
- La première passe d'implémentation, de tests et de rééquilibrage est livrée.
  Les critères humains et limites restantes sont explicites dans le rapport.
