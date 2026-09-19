# Butin, deck et contrôle de puissance — 19 septembre 2026

Demande : reprendre les cinq captures Dofus fournies (tableau de victoire, ligne de gains, icônes et infobulles), rendre les cartes et le HUD compréhensibles, mesurer la puissance actuelle. Travail ajouté aux modifications de classes déjà présentes ; aucun remplacement du chantier antérieur.

## Décisions

- Bilan dédié, séparé de l'inventaire : personnage, niveau et XP, oboles gagnées, butin regroupé par définition, adversaires et statistiques du combat.
- Reçu sauvegardé lors de la victoire : vendre ou équiper ne modifie pas la liste historique des gains.
- Icônes originales existantes et cadres peints du projet ; aucune image Dofus reprise.
- Bouton Mon deck en combat, consultation seule ; cartes lisibles avec PA, dégâts/garde, portée et règle courte. Fiche complète à la sélection et au survol.
- Pas de baisse globale sans preuve : les 18 simulations initiales montrent surtout un écart corps à corps/distance. Rapport brut `artifacts/dev/class-balance-baseline/report.json`. Politique automatique commune, trois graines ; ce ne sont pas des taux de victoire humains.

## Fichiers

`core/expedition/class_cards.gd`, `expedition_session.gd`, `core/game_manager.gd` : reçus et persistance.
`ui/expedition/class_combat_results.gd`, `class_loot_icon.gd`, `class_card_presentation.gd`, `class_card_tile.gd`, `class_workshop.gd`, `catabase_card_hand.gd`, `expedition_screen.gd`, `ui/run/persistent_run_ui.gd`, `ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd` : présentation et navigation. La hauteur supplémentaire du HUD ne s'applique qu'aux nouvelles faces de cartes ; la disposition classique conserve sa hauteur.
`tools/build_system_lab/class_balance_probe.gd`, `class_ui_probe.gd` : mesures et parcours.

## Vérifications

- Classes : `artifacts/dev/20260919-153920-test-test_unit_test_catabase_class_run.gd-7c3cb737/summary.json`, PASS strict, 15 tests, 1 389 assertions. Reçus après vente/équipement/rechargement, statistiques, durée et conservation des tours avant remise à zéro des ressources.
- Interface finale : `artifacts/dev/class-ui-verified/report.json`, **240 contrôles et 36 captures**, PASS ; sortie moteur sans erreur ni fuite. Captures inspectées : bilan compact, fiche au survol, main/ciblage à 1280×720, deck à 1920×1080, fiche persistante lors du défilement, butin élite et fiche d'équipement entièrement visible au-dessus du bouton de continuation.
- Corrections issues des essais : nom Godot réservé, colonnes de largeur nulle, texte chevauchant les boutons de cartes, hauteur des infobulles, nombres JSON restaurés en entiers, tours conservés avant le nettoyage de combat.
- Compatibilité : PASS strict pour `test_catabase_cards.gd` (24 tests, 600 assertions, dossier `20260919-153303-test-test_unit_test_catabase_cards.gd-cceba0b7`), `test_recraft_combat_hud_v1.gd` (11 tests, 96 assertions, `20260919-153514-test-test_unit_test_recraft_combat_hud_v1.gd-fe44ebdf`), `test_persistent_run_combat_hud.gd` (6 tests, 201 assertions, `20260919-153559-test-test_unit_test_persistent_run_combat_hud.gd-66991f8c`). Total avec les classes : **56 tests et 2 286 assertions**, aucun échec ni diagnostic moteur bloquant sur ces quatre suites.
- Reçu élite : cartes, équipement, rune et relique présents ; aucun adversaire repris de la salle précédente si le combat n'a pas été démarré. Les victoires de cette partie de la sonde sont contrôlées, pas des mesures tactiques. Tests et inspection terminés.

Le verdict d'équilibrage et ses chiffres sont dans `docs/design/class_balance_readability_audit_2026-09-19.md`. Aucun coefficient de combat n'a été modifié pour masquer l'écart distance/contact.
