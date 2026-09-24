# Stabilisation Observatory V1.1

- Statut : **CURRENT**
- Branche : `feature/observatory-truth-v1-1`
- Commit de référence : HEAD contenant ce document ; le `SOURCE_HEAD` exact est inscrit dans le snapshot V1.1.
- Date UTC : `2026-08-06T10:45:38Z`
- Validation : import Godot 4.7.1, GUT Observatory et complet, Ajv, ESLint, TypeScript, Vitest, Vite, Playwright et npm audit.

## Périmètre

Cette stabilisation porte l’Observatory V1 sur `origin/main` sans modifier le jeu. Elle corrige la provenance Git, le contrat XP, le modèle de vérité, le vocabulaire de run, la couverture des champs et la lisibilité des audits. Elle ne crée ni backend, ni télémétrie, ni théoriecraft, ni historique de snapshots.

## Baseline après intégration

- `origin/main` : `94fcdc700cf576a15ee4134d9f3dee680626827a`.
- Cinq commits V1 exclusivement Observatory ont été reportés, sans conflit.
- Import headless : code 0 en 113,764 s, avec erreurs de parsing gameplay préexistantes dans `persistent_run_ui.gd` et `battle.gd`.
- GUT Observatory : 31/42 tests, 566/577 assertions, 11 échecs causés par l’UID invalide préexistant de `frappe_lourde.tres`.
- GUT complet : 717/728 tests, 50 353/50 516 assertions, 11 échecs hors Observatory.
- Frontend : 40/40 Vitest, 23/23 Playwright, lint/typecheck/build verts, zéro vulnérabilité npm.

## Séquence de livraison

1. Committer exporteur, schéma, contrat, tests et documentation hors `latest.json`.
2. Vérifier le worktree propre et enregistrer `SOURCE_HEAD`.
3. Exporter le snapshot ; vérifier SHA Git et dirty flag faux.
4. Committer le snapshot séparément.
5. Créer la branche frontend depuis ce commit exact.
