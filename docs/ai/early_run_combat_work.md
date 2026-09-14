# Première passe de combats — 12 septembre 2026

Demande : tester puis ajuster la run avec les personnages existants uniquement.
Périmètre de la première passe : trois entrées, salles II–VI et raccord au carrefour VII.

État initial : core/expedition/painted_halt_catalog.gd modifié par une autre tâche ;
beaucoup de modifications artistiques/audio préexistantes. Ne pas les reprendre.
Les catalogues d'évolution, de rencontre et d'itinéraires sont initialement propres.

Implémenté : douze compositions par destination dans catabase_early_encounters.gd,
réglages locaux sur ressources indépendantes, Fournaise/Cendre/Égide précoces,
soins bornés et déplacements forcés utiles. Aucun nouveau personnage. Intégration
dans catabase_monster_encounter_catalog.gd. Les autres profondeurs gardent leurs kits.

Quatre cases de lave héritées corrigées via ArenaSerializer/ArenaRuntimeBridge dans
data/rooms/catabase_routes/route_260dc8ac79d8/room.tres. Le sérialiseur a aussi
renouvelé des identifiants internes et omis des valeurs par défaut : bruit de diff
attendu, pas de refonte géométrique. Outil reproductible repair_early_water_floor.gd
et scène associée ; modification uniquement avec argument utilisateur apply.

Connexions inversées : révision de catalogue 5 dans expedition_route_catalog.gd,
correction dans expedition_route_itineraries.gd, restauration v4 préservée dans
expedition_route_state.gd. Anciennes sauvegardes v2/v3/v4 testées ; nouvelle run
nécessaire pour la topologie corrigée. tests/expedition/route_state_test.gd adapté.

Outils ajoutés : early_run_playtest.gd/tscn et early_run_live_probe.gd/tscn sous
tools/catabase_monster_validation. Le premier utilise grilles/formation Studio,
TurnQueue, timing terrain/statuts, SpellCaster et EnemyAI. Politique héroïque simple,
trois kits légaux après deux points, statistiques de niveau, sans équipement.
Les tests indépendants commencent à PV pleins et n'utilisent pas bien Percée.
Le second traverse réellement les scènes I–VII, intents, récompenses, maîtrises
et PV persistants, sans victoires forcées ; attributs vitalité et provisions.

Premier lancement de tests : import bloqué par accès sandbox aux certificats et
à des dépendances locales ; relance autorisée avec les accès locaux. Premier essai
du banc via SceneTree invalide (autoloads non compilés) ; remplacé par scène Node.
Ne pas compter ces exécutions comme des preuves de réussite.

Autres incidents de validation résolus : première version des nouveaux tests avec
erreur d'inférence, puis attentes de cooldown initial insuffisantes, corrigées.
Un import a ensuite échoué sur quatre WebP animés générés par une autre tâche dans
artifacts/spine_trial/veilleur_walk_iso_v1. Recherche des références : uniquement
sorties de tools/veilleur_walk/build_iso.py, aucune référence runtime. Ajout local
d'un .gdignore dans ce dossier d'artefacts pour exclure ces sorties expérimentales
de l'import principal. Aucun média modifié, aucun filtre d'erreurs CI assoupli.

Une tentative de revenir au fichier de salle de HEAD pour réduire le bruit de
sérialisation a été refusée par le contrôle automatique (risque de remplacer des
modifications locales). Action non exécutée, utilisateur informé. Continuation
sûre sur le fichier courant avec correction des quatre cellules seulement.

Preuves présentes dans artifacts/dev/early_run_playtest :
- baseline_v1/report.json : 34 victoires / 36 cas avant réglage.
- tuned_v2/report.json : 108/108 cas réussis, trois graines, zéro erreur moteur.
- live_puits_briseur : victoire VII, 33 activations, 82/360 PV après XP.
- live_porte_chasseur : victoire VII, 35 activations, 97/360 PV après XP.
- live_barque_airain : victoire VII, 34 activations, 172/360 PV après XP.
- route_state.log : 16 418 contrôles, 3 430 chemins complets, aucun échec.

Régression monstres finale : artifacts/dev/20260912-151120-test-monsters-71b416e7/
gut-strict-report.json : PASS, 75 tests, 18 354 assertions. Huit tests ajoutés dans
test/unit/test_catabase_monster_early_routes.gd. Les cinq nouveaux scripts sont
formatés avec vérification de structure ; les anciens catalogues ont déjà un style
non conforme au formatter, non reformatés globalement pour garder un diff ciblé.

Dernière suite ciblée salles/carte/explorateur/nouveaux comportements : PASS,
20 tests, 20 503 assertions, zéro erreur, sous
artifacts/catabase_monsters/checks/early_run_routes_final_20260912. Elle recoupe
huit tests de la suite monstres : ne pas additionner les comptes comme disjoints.
Revue Git ciblée : seuls les fichiers listés ici sont attribués à cette tâche,
painted_halt_catalog.gd reste la modification préexistante. Rapport complété :
docs/design/catabase_early_run_playtest_2026-09-12.md. Aucun commit créé.
Limite : première passe I–VII automatisée ; avantage du tir visible, aucun verdict
sur le plaisir humain ni l'équilibrage de VIII–XX. Aucun changement du kit d'Achille.
