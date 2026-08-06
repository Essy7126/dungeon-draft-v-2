# Frontend Observatory V1.1

- Statut : **CURRENT**
- Branche : `feature/observatory-truth-v1-1`, puis `feature/observatory-frontend-v1-1` pour l’implémentation UI.
- Commit de référence : commit snapshot V1.1 servant de base à la branche frontend.
- Date UTC : `2026-08-06T10:45:38Z`
- Validation : Vitest, Playwright Chromium, Axe, contrôle responsive et absence de requêtes externes ou `res://`.

La V1.1 conserve toutes les routes V0/V1. Elle ajoute un indicateur global de fraîcheur, sépare profils de vague et vagues jouées, sépare les trois multiplicateurs, complète les statistiques de personnages et les détails de sorts, contextualise les capacités par rencontre et groupe les audits par règle, sévérité et nature de preuve.

Les traductions d’enums sont centralisées. L’identifiant technique reste visible dans un détail repliable lorsque le libellé lisible pourrait masquer la provenance.
