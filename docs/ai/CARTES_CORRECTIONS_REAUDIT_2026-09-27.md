# Corrections du réaudit Cartes — terminées

Demande : corriger les quatre défauts du réaudit dans la run existante.
Référence Git vérifiée : `c6ab5a72c1789e4cc285300c9bbae9c78524fa05`. Modifications locales concurrentes préservées ; aucun commit/push.

## Décisions et fichiers
- Mécanismes sur la Battle publique : `core/expedition/consumable_room_rules.gd`, `battle/consumable_room_overlay.gd`, branchements dans `battle/consumable_cards_runtime.gd` et la main/HUD existants.
- Variantes garanties, pression en perte directe de PV et phase de Pâris actualisée sur les pertes périodiques. Moteur commun conservé ; pas de nouvelle run publique.
- Checkpoints intégrés v2 : mécanismes, commandes, réserves, sacrifices, bonus et butin. Reprise v1 acceptée sans rendre de cartes ou de PA. Entiers JSON contrôlés numériquement.
- Scénarios : `test/unit/test_consumable_cards_live_rooms.gd`, test de pression dans `test_consumable_cards_effects.gd`, réaudit des douze scènes dans `tools/consumable_cards/audit_live_integration.gd`.
- Réparations de validation : fixtures Orage (occupation et liaison de session), fixtures de butin (clé d'index réelle), annotation int du pull S25, attente bornée de fin réelle dans les tests de déplacement. Changements concurrents de sprites/VFX/butin/Studio conservés.

## Preuves finales
- Huit tests intégrés / 785 assertions réussis dans le global, dont les six commandes avec effet réel et reprise.
- Réaudit 12 rencontres × 2 résolutions ; 14 images, zéro défaut/erreur : `artifacts/dev/20260927-191415-cards-corrections-final-checks-1dd8205e/`.
- Cartes intermédiaire : 201/16195 réussis (`20260927-141028-test-cards-5976198c`). Global final : 231 cas Cartes, deux fixtures Orage en échec puis corrigées ; relance Orage 20/437 PASS (`20260927-193131-cf-4a492da0`).
- Global `20260927-144950-cards-corrections-all-4a582337` : 3224 tests, 171 échecs contre 166 en référence ; crash de fermeture historique. Pas de validation globale verte.
- Écarts Studio Rencontre et Terrain réussissent avec chemins courts (7 et 31 assertions). Suite Rencontre encore rouge pour d'autres cas. Déplacement 17/101 assertions réussies après correction des attentes ; strict encore rouge (14 ressources à la fermeture).
- Smokes : Rencontre PASS ; Objets et Terrain strict FAIL (détails rapport). Ressources : 12368 fichiers, zéro référence manquante ; sept tests Python passent ; diff/version OK.
- Portabilité : 17 chemins historiques dans provenance.json, inchangé depuis HEAD ; allowlist CI rouge. Empreintes avant/après conservées ; worktree partagé et deux artefacts suivis modifiés pendant les tests.

Rapport complet : `docs/audits/cards_corrections_2026-09-27.md`. Résultats de comparaison : `artifacts/dev/cards-corrections-gates-20260927/`.
Toutes les exécutions de cette tâche sont terminées. Les tentatives bloquées par le verrou moteur et le passage incomplet avec erreur S25 ne sont pas comptés comme réussites. Pas de rééquilibrage des rosters ni de validation de parties complètes dans ce correctif.
