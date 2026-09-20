# Fenêtres de run — 20 septembre 2026

Demande : bilan du combat avant notification de niveau ; inventaire, personnage,
caractéristiques et cartes dans des fenêtres identifiables et refermables.

Décisions : état `reviewed` dans le reçu sauvegardé (aucune redistribution de butin),
fenêtres de consultation sur fond assombri, inventaire avec aperçu réel d’Achille,
six emplacements, grille et détail. Réutilisation des services d’équipement et de vente.
Anciennes règles de combat et statistiques conservées.

La notification peut être fermée : la carte affiche un rappel reprenant exactement
la décision restante. Les points ne sont ni dépensés ni perdus à la fermeture.
`route_ready` termine le reçu déjà consulté sans afficher le bilan une seconde fois.
Les sauvegardes anciennes sans reçu restent chargeables.

Fichiers : `expedition_flow/session`, reçu `class_cards`, façade `game_manager`,
fenêtres `expedition_screen`, nouveau `class_inventory_view` héritant des transactions
du workshop, fiche détaillée et routage des modales `persistent_run_ui`.

Tests stricts : 42 tests, 2 164 assertions, zéro échec/erreur.
- Classes, sauvegardes et ordre : `artifacts/dev/20260920-120040-test-test_unit_test_catabase_class_run.gd-37f4fa24/summary.json`.
- Parcours historique et clavier : `artifacts/dev/20260920-115844-test-test_unit_test_expedition_guided_flow.gd-0f2c3269/summary.json`.
- Verrouillage du HUD : `artifacts/dev/20260920-115050-test-test_unit_test_persistent_run_combat_hud.gd-477a5f38/summary.json`.

Le contrôle historique du focus vise désormais le bouton visible de la fenêtre,
et non l'ancien bouton global masqué. Le premier contrôle visuel a révélé un texte
de sac vide trop étroit, corrigé ; les titres et résumés redondants de la fiche
ont aussi été retirés pour laisser davantage de place aux statistiques.

Contrôle visuel final : `artifacts/dev/run-windows-final/report.json` — PASS,
296 contrôles, 44 captures en 1280×720 et 1920×1080. Bilan, annonce, sac, deck,
défenses et carte avec rappel inspectés visuellement ; aucun avertissement/erreur
dans les journaux du probe. Équipement réel et report du bonus dans la fiche vérifiés.
Le probe joue une carte et un cycle d'IA réels, puis injecte les frontières de victoire
pour tester l'interface. Il ne prouve pas une nouvelle mesure d'équilibrage de la run.

Terminé. Aucun changement de statistiques ou de règles de combat dans cette tâche.
