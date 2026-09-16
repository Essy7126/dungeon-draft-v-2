# Audit expérimental Cartes — terminé, 2026-09-16

Base vérifiée : `main@8d5e7b9c8e68a9699ff74f813f8630f001db4a02` + variante Cartes locale issue de la mission précédente. Aucun changement de règles de production autorisé/entrepris pendant cet audit. Aucun commit/push.

Périmètre : comparer Classique/Cartes à graines et départs égaux ; politiques starter/adaptive/liquidate/swarm/pression ; diagnostics économie, loi de pioche, transactions, UI ; recherche primaire. Les taux sont ceux de bots déterministes, pas de joueurs. Les tests de récompenses forcées ne sont pas des runs gagnées.

## Preuves consolidées

- `audit_cards_starter_20260916` : 36 runs (7201–7203 × Normal/Facile × 6 armes), 16 victoires, zéro erreur moteur. Runner de référence, deck inchangé.
- Total : 180 runs / 1 493 combats dans dix lots PASS. Agrégats et exclusions dans `artifacts/catabase_run_balance_validation/studio_analysis/analysis.json` ; trois CSV rejouables.
- `test_cards_studio_audit.gd` : 7 tests / 71 689 assertions PASS (180 000 tirages conditionnels, 6 000 transactions, 30 000 mains, 1 000 séquences de butin, progression et payload Répercussion).
- `studio_audit_probe.gd` : score heuristique explicite, intégration/remplacement, achats/revente, conservation/recomposition ; non optimal. Modes pilot/adaptive/liquidate/swarm/speed/informed/mobility/curated réellement exécutés.
- UI neuve : 90 contrôles PASS et 12 captures, `audit_ui_20260916`. Main six cartes masque plateau bas à 720p ; textes tronqués même en 1080p ; six copies de Geste saturent les premières lignes de réserve. Mesure FPS non concluante.

## Conclusions / suite

1. Rapport final : `CARDS_STUDIO_AUDIT_2026-09-16.md`, suivi `KNOWN_ISSUES.md`.
2. Ne pas appliquer de buffs à partir du bot historique : Répercussion sous-évaluée, politiques myopes. Contre-test mobilité xiphos : une victoire Normal sans bonus de stats.
3. Priorité UI/prérequis, puis budget des haltes et valeur spatiale des cartes. 16,77 drops / 212,53 oboles de revente moyenne dans la fixture à pool figé ; pas un budget complet de joueur.
4. Reste à faire après cet audit : essais humains contrebalancés, chronométrage 30–45 min, profilage au premier plan, étude causale par kit. Aucun test automatique ne mesure directement plaisir/frustration.

Incidents du nouveau banc corrigés et exclus : contrôle PowerShell du retour, type GDScript du pilote, filtre d'agrégation `ui`/`liquidate`. Aucun changement d'équilibrage pour faire passer les tests. Les profils de sauvegarde sont isolés.

Sources consultées : slides GDC Giovannetti 2019 (métriques + observation), Davis 2019 (contraintes, lisibilité), pages officielles Slay the Spire, Into the Breach, Monster Train, Fights in Tight Spaces ; liens dans le rapport final.
