# Parcours Cartes progressif — 19 septembre 2026

Demande : répartir les premières décisions dans la sélection du personnage,
puis présenter les cartes une par une après le seuil. Aucun rééquilibrage.

Direction : navigation par rubriques et sous-étapes, personnage visible,
alternatives par nom et effet du seul choix consulté. Référence de structure :
https://www.baldursgate3.game/news/community-update-8-character-creation_9

Avant le seuil : identité (Passe-rive par défaut en Cartes), arme, protection,
relique, objet, difficulté, récapitulatif. Une validation par étape, retour et
révision possibles. Changer d'arme réinitialise explicitement les étapes
d'équipement à revoir car ses valeurs proposées changent.
Après le seuil : cinq familles distinctes choisies une à une, deux copies par
famille, impact et coût affichés à côté des alternatives. Récapitulatif avant
entrée. Sauvegarde du choix et de la prochaine étape après chaque confirmation.
Les profils en attente sans brouillon restent compatibles (départ marteau).

Fichiers : ui/selection/cards_character_setup.gd, cards_choice_page.gd,
character_selection_screen.gd, character_selection_catalog.gd ;
ui/expedition/catabase_cards_departure.gd ; core/game_manager.gd ;
core/expedition/expedition_session.gd. Transmission du brouillon capturée avant
cleanup_run_state, puis stockée dans la sauvegarde de préparation.

Validation :

- Cartes : 24/24 tests, 600 assertions, PASS strict.
  `artifacts/dev/20260919-105356-test-test_unit_test_catabase_cards.gd-2f7c3777/`
- Sélection : 16/16 tests, 294 assertions, PASS strict. Inclut le libellé
  Passe-rive et la préparation des apparences conservées.
  `artifacts/dev/20260919-110435-test-test_unit_test_character_selection_screen.gd-28083b25/`
- Régression Catabase : 487 tests, 472 PASS, 15 FAIL. Liste d'échecs exactement
  identique au rapport du 17 septembre (comparaison des listes JUnit), avec les
  mêmes erreurs grid_layout et ressources non libérées dans les anciennes suites.
  La suite globale reste donc FAIL ; aucune allowlist modifiée.
  `artifacts/dev/20260919-110049-test-catabase-f47397ec/`
- Interface v2 : 38 captures, 302 contrôles PASS. Inspection : fond de panneau
  ajouté pour le contraste, PA doublé retiré. Version finale v4 : 38 captures, 316 contrôles PASS, sans erreur moteur. Identité, arme et choix de cartes inspectés en 720p et 1080p.
- Capture v1 : erreur de typage du harnais corrigée ; v3 interrompue car l'attente
  de rendu ne progressait plus, sans rapport final. Le harnais demande désormais
  explicitement une image avec RenderingServer.force_draw avant la lecture.

- Protection des sauvegardes : 4/4 tests, 77 assertions, PASS strict.
  `artifacts/dev/20260919-110838-test-test_unit_test_selection_replacement_guard.gd-f46b0004/`
  La fixture des aventures archivées utilisait les indices précédant Passe-rive ;
  elle sélectionne maintenant les entrées par leur type et exige toujours quatre
  lancements sans confirmation. Annulation et consentement restent vérifiés.
- Captures finales :
  `artifacts/catabase_run_balance_validation/cards_progressive_setup_v4/`
- `git diff --check` propre. Profils de test isolés, aucune sauvegarde joueur
  modifiée. Changements locaux, aucun commit ni push.

Parcours livré. Pour le voir : relancer le jeu et ouvrir une nouvelle run Cartes.
Les règles et l'équilibrage des combats n'ont pas été modifiés dans cette passe.
