# Bilan du butin — 27 septembre 2026

Demande : rétablir le tableau de victoire inspiré de Dofus, cartes visibles comme drops et fiche agrandie au survol, dans la DA existante.

Constat : la branche publique Cartes consommables V2 ouvrait le workshop de deck dans le bilan. La branche historique avait conservé son reçu dédié.

Décisions : nouvelle projection UI des reçus et engagements de loot immuables ; aucune modification des règles, probabilités, sauvegardes ou statistiques. Cartes verticales utilisant les illustrations peintes et le cadre existant. Fiche passive au survol/focus. Fermeture et enchaînement vers le niveau conservés.

Fichiers : ui/expedition/consumable_loot_receipt.gd, consumable_loot_tile.gd, consumable_combat_results.gd ; raccord ciblé dans expedition_screen.gd. Le dépôt contenait déjà de nombreuses modifications V2 et artistiques, conservées.

Les identités et quantités proviennent du reçu, indépendamment du sac courant. Les effets affichés tiennent compte des améliorations actuelles de la famille. Les engagements de butin acceptent les clés numériques sérialisées sous forme `1` ou `1.0` sans migration de sauvegarde.

Validation finale :

- `artifacts/dev/20260927-192133-loot-unit-final-fd5dd9d1/report.json` : 4 tests GUT, 389 assertions, aucun diagnostic moteur. Regroupement, exclusion du butin sacrifié, vente réelle d'une copie, restauration, art des 48 familles et 26 objets, améliorations de famille, survol passif et sans mutation.
- `artifacts/dev/20260927-192119-loot-render-final-adfc952e/report.json` : PASS, 10 captures natives sur la vraie ExpeditionScreen, 1280×720 et 1600×900. Les 96 formes (base et améliorée) tiennent dans le viewport. Clic réel de fermeture, enchaînement de progression, vente/rechargement, survol carte/équipement, 48 familles de drops, absence de drop, bouton de fermeture accessible. Captures inspectées visuellement. Victoires préparées comme fixtures : ce contrôle ne mesure pas l'équilibrage des combats.
- Format vérifié sur les cinq nouveaux scripts GDScript. Aucun formatage global.

Limite de validation générale : la première suite `cards` a rencontré des erreurs corrigées depuis dans ces fichiers et des échecs concomitants dans les effets/VFX. Une relance partagée a expiré sans rapport complet (`20260927-144912-test-cards-0656c8ae`). Elle n'est pas déclarée réussie. Une autre tâche exécute sa validation globale ; les résultats ci-dessus utilisent des processus de test isolés, sans import concurrent ni sauvegarde joueur.

Reproduction : `./dev.ps1 test test/unit/test_consumable_cards_loot_receipt.gd`, puis `./tools/consumable_cards/verify_loot.ps1` (verrou moteur partagé). Aucun changement des règles de combat ou des probabilités de loot.
