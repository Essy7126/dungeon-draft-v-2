# Contre préparé — production F, 28 septembre 2026

Demande : « ok passe au prochain projet », après Convergence. Production de la planche F déjà validée (lot 2), uniquement `cc2_g05` de la run Cartes.

Décisions : deux morceaux de bronze, assemblage bref, jeton compact séparé de la garde ; revers ivoire uniquement sur la riposte adjacente réellement résolue. Expiration silencieuse, aucune fausse frappe sur la sauvegarde/reprise. Animation corporelle garde S27 conservée ; son accent de garde remplacé seulement pour cette carte. Pas de nouvelles règles ni de changement de classification des dégâts. Marqueur `status_id=cc2_counter` sur le fait de riposte pour distinguer passif Gardien et Miroir.

Réalisé : source Blender éditable et 32 poses (armement 14, jeton 1, revers 9, contact 8), export Studio des quatre clips, contrôleur/joueur dédiés. Source sauvegardée reproduite pixel pour pixel (32/32), quatre exports Studio avec aller-retour exact.

L'inspection de la première capture a montré que le grand bouclier générique masquait le croissant. Correction ciblée : provenance `ability_id=cc2_g05` du fait d'octroi de garde ; seul son ancien déploiement est omis, son signe compact reste présent. Le croissant suit le point de la main fourni par la vue pendant la garde S27.

Validation intermédiaire : suite Cards 334 tests / 21 727 assertions, passée (`20260928-195516-test-cards-b9b33ee2`), avant suppression du bouclier générique et suivi de la main.

Validation finale : suite Cards `20260928-201103-test-cards-27a5deca`, 338 tests / 24 447 assertions, 337 tests réussis. Les 17 tests du script Contre (dont les tests hérités des effets Cartes) passent. Le seul échec concerne le nouveau test de vocabulaire UI `test_every_printed_card_explains_its_effect_without_internal_math`, modifié en parallèle. Le rapport partagé terminé `20260928-202507-player-language-final-regressions-f5298417/report.json` a été lu directement : 24 tests / 4 157 assertions réussis, incluant ce test, les aperçus, le reçu, la lisibilité et l'intégration. La suite complète n'a pas été rejouée une troisième fois. La tentative ciblée de cette tâche a rencontré l'import concurrent des textures S29, puis le verrou moteur ; elle n'est pas présentée comme un succès.

Deux captures rejetées et journaux conservés sous `artifacts/dev/class_card_vfx/contre/attempts/` : la première contenait une erreur UI indépendante ; la deuxième a traversé une modification concurrente de l'interface. Leurs 281 assertions fonctionnelles passent, mais ni l'une ni l'autre ne certifie une capture finale propre.

Troisième capture réussie : 180 images natives 1440 × 950, 281 contrôles, aucune erreur moteur, sources stables pendant l'enregistrement commencé le 28 septembre à 18:19:44 UTC. Commande publique et véritable attaque du runtime ennemi, reprise armée/dépensée, expiration, bilan/reprise. Victoires de préparation et de bilan = fixtures, pas équilibrage. Inspection visuelle du croissant, du jeton séparé, du contact et des vues normale/reprise effectuée.

Correctif de compilation nécessaire, minimal, sur les travaux UI concurrents : `card_player_language.gd` déclarait `reference(power)` en conflit avec `RefCounted.reference()`. Renommage `power_reference` et mise à jour de ses trois appels dans `consumable_combat_card_view`, `consumable_loot_tile`, `consumable_player_dossier`. Aucun autre changement UI de cette tâche.

GIF final : `artifacts/dev/class_card_vfx/contre/combat/contre.gif`, 180 images / 6 s, SHA256 `c39aa9f72d3468a702ffcb58d92b4945ec18074debe538f8a0e8ada409d216bb`. Clips séparés `detail.gif` et `combat.gif`. Demande d'ouverture dans Codex enregistrée par l'application (onglet en attente d'affichage).

Synthèse des preuves : `artifacts/dev/class_card_vfx/contre/integration_report.json`, empreintes `validation_inputs.json`. Les fichiers Contre sont inchangés depuis la dernière suite. Des modifications UI et S29/blink ont continué après la capture : préserver ces travaux ; la preuve visuelle certifie les sources enregistrées, pas ces modifications ultérieures. Aucun résultat de Convergence ne tient lieu de preuve pour cette passe. Production Contre terminée ; aucun commit créé.

Git initial : Convergence non commité (spells/router/docs/tools/source/tests), modifications en cours du dossier joueur/loot/preview et docs/current/cards_v2.md ; préserver ces travaux.
