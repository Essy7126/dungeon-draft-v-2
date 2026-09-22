# Sélection et audit Cartes — 21 septembre 2026

À relire avec le diff courant ; les sorties citées sont les preuves datées.

- Décision : cinq techniques × deux copies, choisies dans la sélection du personnage ; plus de deuxième sélection au seuil pour les nouveaux départs confirmés.
- Quatre jeux distincts de sept cartes d'initiation `i_*`. Les 28 anciennes `s_*` restent résolubles pour les sauvegardes, hors catalogue public et hors drops.
- Identité couleur commune avec le combat : violet Assassin, or Gardien, vert Arpenteur, bleu Thaumaturge. Apparence indépendante ; progression classe et spécialisations expliquées.
- Fichiers : `class_starter_catalog`, `class_card_catalog`, `card_ecosystem_catalog`, `class_cards`, `game_manager`, `cards_character_setup`, tests de classes, sonde UI et analyseur de profondeur.
- Audit détaillé : `docs/design/card_catalog_and_selection_audit_2026-09-21.md`.
- Catalogue : 112 familles publiques, 29 codes d'effet, 7 200 tirages. Export CSV/JSON sous `artifacts/dev/cards-catalog-20260921/`, processus code 0.
- Runs : 12 cas complets, 72 combats, 295 activations, une victoire. Code 0, aucune erreur/avertissement moteur. `artifacts/dev/cards-distinct-starters-20260921/`. Politique automatique gloutonne, pas un taux humain.
- Interface finale : 380 contrôles réussis, code 0, aucune erreur moteur ; `artifacts/dev/cards-selection-ui-20260921-framed/`. Images inspectées, dont sélection en 720p et cadrage du personnage en 1080p.
- Catabase : 546 tests exécutés, 16 échoués ; `artifacts/dev/20260921-194645-test-catabase-c42ee564/`. La liste exacte des 16 échecs et les erreurs de fermeture correspondent au rapport du 20 septembre `20260920-182300-test-catabase-59eace69`. Les 27 tests de classes et les trois tests d'illustrations passent dans cette exécution. Cela ne rend pas la suite globale verte.
- Première passe Cards : erreurs corrigées (nom `Skin` réservé dans la nouvelle UI, test utilisant une sélection effacée par référence, test d'amélioration pointant maintenant une carte de contact). Le test artistique ancien exigeait 64 images uniques pour un catalogue déjà passé à 112 familles : unicité vérifiée sur les 60 bases + 4 emblèmes ; réutilisations déclarées vérifiées séparément.
- Dernière passe Cards : **PASS strict, 84 tests, 7 186 assertions, aucune erreur**, `artifacts/dev/20260921-195632-test-cards-de4aafb4/summary.json`. Elle couvre aussi le parcours public jusqu'au seuil, la difficulté choisie et la restauration des anciennes `s_*`, ajoutés après le chargement des scripts de la passe Catabase.
- Formatage : fichiers ciblés uniquement. Le formateur refuse `class_ui_probe.gd` pour divergence structurelle de sa propre sortie ; aucune sortie divergente n'a été appliquée. `git diff --check` passe. Le formatage sans rapport de `class_cards.gd` a été retiré pour conserver uniquement la correction ciblée.
- Préserver les modifications VFX concurrentes, y compris leurs tests et outils.
- Livraison terminée pour sélection/départs/audit. Les recommandations de profondeur restent des chantiers décrits dans l'audit. Aucun commit, push ou changement de liste d'exceptions CI.
