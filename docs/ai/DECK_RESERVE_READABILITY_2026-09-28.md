# Deck et réserve — lisibilité du dossier

## Décisions et périmètre

- Deux collections simultanées, avec quantités propres et défilement indépendant.
  Le regroupement par sort reste utile pour compter les exemplaires, mais ne mélange
  plus les cartes préparées et stockées. Transfert d'un exemplaire par bouton.
- Fiche à droite, actions fixes, filtres communs (nom, rôle, affinité, rareté).
  Chaque pile montre l'asset existant, le coût, l'affinité, la rareté et sa quantité.
  Bordure colorée + nom de rareté : la couleur n'est pas le seul repère.
- Affinité = origine de classe ; famille = exemplaires d'un même sort. Le catalogue
  n'a pas de famille élémentaire autonome. Le guide décrit les règles existantes,
  y compris l'emprunt de cartes et le maintien du bonus de classe initial.
- Pas de migration, nouveau gameplay ou changement d'équilibrage. Les transactions
  restent celles du workshop et de l'état de cartes ; sauvegarde et verrou de combat
  restent centralisés.

## Audit page par page

| Page | Vérification / décision |
| --- | --- |
| Sorts & deck | Refonte en deck, réserve et fiche. Rechercher n'altère pas le contenu ; vider un résultat affiche une explication. Boutons bloqués aux plafonds et pendant le combat. |
| Personnage & inventaire | Vue équipée, sac et comparaison déjà séparés. Conservation de la comparaison avant/après et de l'action fixe. Contrôle visuel en 720p ; les effets longs défilent sans masquer Équiper. |
| Caractéristiques | Totaux à gauche, points à répartir avec avant/après à droite. Origine des statistiques à la demande ; aucun nouveau vocabulaire de famille à ajouter ici. |
| Classe & améliorations | Style, passif réel, spécialisation et paliers sont disponibles. Les textes longs défilent ; ne pas dupliquer le catalogue de cartes dans cette page. |
| Sortie de combat | Contrôle de non-régression du reçu, des cartes en butin et des infobulles. Pas de modification du déclenchement loot/niveau. |

## Fichiers

- `ui/expedition/consumable_deck_inventory.gd` : projection sans mutation.
- `ui/expedition/consumable_player_dossier.gd` : collections, filtres, fiche et aide.
- `test/unit/test_consumable_cards_deck_inventory.gd` : partition, transferts,
  limites, ouverture, verrou de combat et absence de mutation à l'inspection.
- `tools/consumable_cards/dossier_capture.gd`, `verify_dossier.ps1` : actions natives,
  filtres, comptage exact, débordements de libellés et captures en deux résolutions.

## Validation

Premier test ciblé : 4 tests, 8086 assertions, strict PASS dans
`artifacts/dev/20260928-210812-test-test_unit_test_consumable_cards_deck_inventory.gd-508494fb/`.
Les captures intermédiaires ont révélé et permis de corriger un bouton trop large
et un titre long débordant. Une exécution ultérieure a été invalidée par une erreur
de compilation VFX d'un chantier concurrent ; elle ne vaut pas validation finale.

Validation native finale : **PASS**, 4 scénarios et 34 captures, sans diagnostic
moteur, dans `artifacts/dev/20260928-212158-player-dossier-bdbbbd07/report.json`.
Le deck, le guide et les autres pages ont été inspectés visuellement ; les tests
natif vérifient aussi les transferts depuis les boutons des piles et l'absence
de débordement des libellés de l'ensemble du catalogue.
Le test GUT complet des cartes a été exécuté sans réimport dans un profil isolé,
car une autre validation utilise le verrou d'import. Ce contrôle runtime ne
remplace pas un import global ni les gates CI du moteur commun.
Résultat : **184/184 tests, 18 699 assertions, 23 scripts**, code de sortie 0,
aucun diagnostic moteur relevé. Sélection complète et JUnit dans
`artifacts/dev/20260928-212338-deck-regression-runtime-08a1c947/`.
Le contrôle de format ciblé et `git diff --check` passent.
