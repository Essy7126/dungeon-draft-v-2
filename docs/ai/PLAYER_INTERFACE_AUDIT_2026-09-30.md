# Audit des interfaces joueur — 30 septembre 2026

## Direction et périmètre

Poursuite de l’audit visuel dans une direction moderne, brune et sobre. Les
captures DOFUS 3 et Monster Train réellement regardées et leurs sources sont
consignées dans [l’étude précédente](ROOM_SCALE_DECK_MATERIALS_2026-09-29.md).
On reprend la hiérarchie des zones, la stabilité des repères et la distinction
des actions, avec les assets propres au projet. Aucun changement de règles,
d’équilibrage, de sauvegarde ou d’échelle du personnage dans cette passe.

## Constats et corrections

| Surface | Problème constaté | Correction intégrée |
| --- | --- | --- |
| Sélection Cartes | Le décor concurrence le texte ; l’action de départ ressemble aux actions secondaires. | Panneau de lecture opaque et texturé, cadres cohérents, action principale bronze clair, onglet actif souligné. |
| Fenêtres du personnage | Cadres, champs de recherche et onglets utilisent des traitements différents. | Matière brune partagée, champs mats, sélection par bordure et couleur, barres de défilement contrastées. |
| Inventaire | Équiper ne ressort pas ; les comparaisons demandent de lire toutes les valeurs. | Action Équiper mise en avant ; gains verts et pertes saumon, avec valeurs avant/après et explication textuelle conservées. |
| Deck | Le champ de recherche rompt avec les autres champs ; les actions ne sont pas hiérarchisées. | Champ partagé et action d’ajout mise en avant dans la fiche. Deck et réserve restent séparés, fiche stable à droite. |
| Caractéristiques | Les nouveaux onglets augmentent la hauteur et repoussent l’aperçu à 720p. | Espacement réduit, libellé des points simplifié, confirmation mise en avant quand disponible. Les six éléments et le début de l’aperçu restent visibles à 720p. |
| Résultats de combat | Les miniatures de butin n’ont pas toutes la même matière que les cartes. | Matière des cartes partagée, ligne du gagnant encadrée et destination du butin précisée. Ordre butin puis montée de niveau conservé. |
| HUD Cartes | Les quatre icônes utilitaires seules sont difficiles à reconnaître. | Libellés Sac, Deck, Stats et Carte sous les icônes ; enfants passifs et retrait des libellés au retour au HUD classique. |
| Interactions communes | États appuyé, actif et clavier insuffisamment distincts. | États explicites, focus non opaque, texte désactivé lisible. Contraste calculé sur les couleurs effectivement utilisées. |

La matière reste discrète autour des contenus ; les éléments et raretés portent
les couleurs sémantiques. Les grandes zones conservent leurs rôles et les actions
secondaires ne prennent pas toutes la couleur du bouton principal.

## Fichiers principaux

- `ui/expedition/player_dossier_skin.gd` : thème, surfaces, boutons et navigation.
- `ui/selection/cards_character_setup.gd` : sélection et préparation.
- `ui/expedition/expedition_screen.gd` : branchement du thème aux fenêtres Cartes.
- `ui/expedition/consumable_player_dossier.gd` : actions et comparaisons.
- `ui/expedition/consumable_progression_editor.gd` : répartition et aperçu.
- `ui/expedition/consumable_combat_results.gd`, `consumable_loot_tile.gd` : butin.
- `ui/expedition/card_hud_labels.gd`, `ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd` : raccourcis nommés.

## Preuves nouvelles

- Thème et raccourcis : **PASS, 3 tests, 37 assertions**, import propre.
  `artifacts/dev/20260930-052436-test-test_unit_test_consumable_cards_interface_theme.gd-fd1ca8c7/gut-strict-report.json`
  Contraste texte/fond >= 4,5 pour les états des boutons testés, le texte indicatif
  des champs et les onglets actifs ; libellés HUD passifs, idempotents et réversibles.
- Identité des cartes : **PASS, 2 tests, 1 733 assertions**.
  `artifacts/dev/20260930-052659-test-test_unit_test_consumable_cards_visual_identity.gd-de80f390/gut-strict-report.json`
- Sélection native : **PASS, 387 contrôles, 39 captures** à 1280×720,
  1920×1080 et 1200×896. Apparences, classes, préparation, difficulté, récapitulatif,
  interactions souris, retour clavier et données de lancement contrôlés.
  `artifacts/dev/20260930-051843-selection-interface-audit-8f31b0a8/report.json`
- Dossier et butin : **PASS, 34 captures**, à 1280×720 et 1600×900.
  Nouvelle exécution après les dernières corrections d’espacement et de recherche.
  `artifacts/dev/20260930-052712-player-dossier-5eb2ba20/report.json`
- HUD natif : **PASS, 24 captures**, mêmes deux résolutions ; mains de cinq et
  sept cartes, survols, cartes indisponibles et bornes des nouveaux libellés.
  `artifacts/dev/20260930-051843-combat-readability-61d2c2b4/report.json`
- Inspection visuelle ciblée des captures : sélection Assassin, comparaison
  d’équipement, butin, main de sept cartes ; caractéristiques et collection à
  720p inspectées de nouveau après le dernier ajustement.
- Formatage ciblé avec vérification de structure ; contrôle de format réussi.
  Les deux grands scripts d’intégration gardent des modifications localisées.
  `git diff --check` : aucune erreur d’espacement.

Ces 97 captures sont produites par les parcours natifs ; elles n’ont pas toutes
fait l’objet d’une inspection visuelle individuelle. Les tests de contraste ne
constituent pas un audit d’accessibilité complet. Les captures de butin utilisent
une fixture ; cette passe ne mesure pas l’équilibrage d’une run complète.
Les modifications concurrentes du combat tactique et du prototype sont conservées.
