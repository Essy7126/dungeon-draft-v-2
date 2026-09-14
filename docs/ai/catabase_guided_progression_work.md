# Progression guidée — 13 septembre 2026

Demande : choix illustrés dans des fenêtres dédiées, guidage du départ, montée de niveau avant le butin et avant la carte.

Décisions : conserver les règles des six constructions ; enregistrer les étapes de montée de niveau pour reprendre après fermeture ; permettre de conserver les points de destin ; dessins vectoriels originaux pour les vingt objets du départ, réutilisés dans l'inventaire et les récompenses.

Implémenté :
- `ExpeditionSession` enregistre annonce → caractéristiques → sorts. Les entrées de salle et le butin ne peuvent pas contourner cette progression. Migration des sauvegardes des six constructions déjà en attente de caractéristiques.
- `ExpeditionScreen` présente des fenêtres encadrées : annonce, caractéristiques, propositions de sorts, confirmation d'apprentissage, butin et réception avec accès à l'inventaire. Retour direct à la carte après réception.
- `catabase_departure_view.gd` : sept étapes locales avant engagement, protections et routes expliquées, quatre sorts récapitulés, reliques et consommables illustrés. Les boutons restent hors de la zone défilante.
- Vingt SVG originaux dans `assets/catabase/preparation/`, générateur déterministe `tools/catabase_monster_validation/create_departure_icons.py`. Ces assets servent aussi aux définitions d'objets, à l'inventaire et aux récompenses.

Preuves :
- `artifacts/dev/20260913-161705-test-test_unit_test_expedition_guided_flow.gd-0e2fdf6a/summary.json` : PASS strict, 17 tests, 508 assertions, aucune erreur moteur. Inclut fenêtres, migration, reprise, conservation des points, stabilité du butin, vingt illustrations distinctes, navigation et inventaire.
- `artifacts/dev/20260913-160615-test-test_unit_test_catabase_first_six.gd-8cae13df/` : 12/12 tests et 1 239 assertions réussies, mais premier verdict strict FAIL pour des demandes de focus différées sur boutons supprimés. Correction dans la fenêtre de départ ; cas précis rejoué dans `artifacts/dev/departure_focus_test/` : 1/1, 7 assertions, journal sans erreur. Ne pas présenter le premier rapport comme PASS strict.
- `artifacts/dev/guided_progression_capture/` : parcours visuel avec les vrais boutons de préparation, apprentissage, butin et inventaire, puis retour carte. Captures examinées à 1280×800 et 1280×720, rapports sans échec. La victoire initiale est injectée : ces captures valident l'interface, pas l'équilibrage des combats.
- Formatage vérifié sur les nouveaux composants ; le formateur refuse la structure de `expedition_session.gd`, fichier conservé sans reformatage global. CI inchangée ; pas de nouvelle exécution de toute la suite historique.

Les fichiers de travail Passe-rive présents en parallèle appartiennent à une autre tâche et restent intacts.

## Correctif après retour joueur — fenêtres masquées par le carrefour

Cause reproduite : `GameManager.get_expedition_destination_scene()` donnait priorité au Seuil après `d01_0`, avant de consulter les décisions obligatoires. Les captures précédentes ouvraient directement `ExpeditionScreen` et ne validaient pas ce consommateur réel. La progression bloquait donc le butin sans présenter son interface.

Correction : priorité aux étapes obligatoires avant le carrefour et les haltes ; bouton de récupération dans un carrefour déjà ouvert ; contrôle de départ incluant les étapes de niveau. La nouvelle régression appelle `on_battle_won()` et `resume_expedition()` puis vérifie les scènes réellement demandées.

Fiche accessible par Menu → Caractéristiques, hors combat comme en combat. Deux onglets : attribution et détail des 17 statistiques (base, bonus, total et modificateurs), XP, ressources, équipement, reliques, sorts et effets. Attribution autorisée seulement entre les rencontres. Bouton de reprise de progression présent même quand les points de caractéristiques ont déjà été dépensés. La projection ne crée aucune résistance manquante sur l'unité.

Vérifications supplémentaires :
- `artifacts/dev/20260913-182420-test-test_unit_test_seuil_crossroads.gd-641c1fcd/summary.json` : PASS strict, 3 tests, 134 assertions, vraie sortie de combat, sauvegarde et trois départs physiques.
- `artifacts/dev/character_menu_regression/` : 21 tests du menu réussis, 26 207 assertions, sortie moteur 0.
- Captures `artifacts/dev/guided_progression_capture/08b_character_details.png` et rapport du parcours : détails visibles, bouton de reprise fonctionnel ; journal de `character_sheet_capture` sans erreur.
- Le premier passage des 19 tests de fiche avait des assertions réussies mais un verdict strict FAIL dû à un playback audio encore actif à l'arrêt. Nettoyage des sons émis ajouté au teardown du scénario, suivant le précédent de `test_context_audio.gd`. Passage final `artifacts/dev/20260913-183028-test-test_unit_test_expedition_guided_flow.gd-4e1a653a/summary.json` : PASS strict, 19 tests, 542 assertions, sans erreur moteur.
