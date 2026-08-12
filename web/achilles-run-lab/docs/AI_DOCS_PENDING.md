# Propositions `docs/ai` en attente

Les trois fichiers racine `docs/ai/CURRENT_STATE.md`, `docs/ai/DECISIONS.md` et `docs/ai/KNOWN_ISSUES.md` ont reçu des modifications concurrentes pendant la mission. Conformément à la règle de non-fusion, aucune proposition Achilles Web Run Lab n’y est appliquée. Les blocs ci-dessous sont prêts pour une intégration humaine ultérieure.

## Proposition pour `docs/ai/DECISIONS.md`

### ACHILLES_WEB_RUN_LAB_V1 — laboratoire vertical slice web isolé

- Date : 2026-08-12
- Branche vérifiée : `main`
- HEAD de base vérifié : `8bd9d455bced1c68acf98843e6f6d4844d4174e8`
- Statut : **EXPERIMENTAL / WORKTREE_CANDIDATE**

Le prototype web vit exclusivement sous `web/achilles-run-lab/` et n’altère aucun script, asset ou contrat gameplay Godot. Il sert à mesurer une proposition de run solo d’Achille et à produire des preuves reproductibles ; il ne constitue pas une nouvelle baseline de gameplay.

Le moteur de domaine TypeScript pur est l’autorité unique pour l’UI, le bot déterministe, les tests et le simulateur. Les commandes et événements sont sérialisables, les décisions aléatoires viennent d’un PRNG seedé, et le Run Lab importe/exporte des configurations validées par schéma. Babylon.js ne porte que la représentation 3D et les animations procédurales.

Le GLB d’Achille est réutilisé localement lorsque chargeable. Comme il ne contient ni squelette ni animation, la V1 assume des transformations procédurales et conserve un modèle géométrique de secours explicitement testable. L’absence de WebGPU ne bloque pas la slice : WebGL 2 est le backend de validation réel.

## Proposition pour `docs/ai/CURRENT_STATE.md`

### Achilles Web Run Lab V1 (WORKTREE_CANDIDATE, 2026-08-12)

- Baseline locale : `main` à `8bd9d455bced1c68acf98843e6f6d4844d4174e8`.
- Livrable isolé : `web/achilles-run-lab/` ; aucun fichier gameplay Godot n’est modifié par cette mission.
- Stack : Vite, React, TypeScript strict, Babylon.js, Zod, Vitest et Playwright, avec dépendances épinglées par `package-lock.json`.
- Slice jouable : run solo d’Achille en cinq salles, déterministe par seed, avec déplacement/ciblage tactiques, quatre capacités liées, récompenses persistantes, sauvegarde locale, Run Lab, télémétrie et simulateur CLI.
- Preuves : `npm run verify` PASS ; 54 tests unitaires, 8 scénarios E2E/23 assertions runtime, build PASS, 100 simulations sans run invalide ni erreur, victoire client complète en salle 5 et captures multi-résolution inspectées.
- Validation renderer : WebGL 2 réelle dans Chromium. WebGPU est tenté par le runtime mais n’était pas disponible dans le navigateur de validation.
- Statut : **EXPERIMENTAL / WORKTREE_CANDIDATE** ; la durée et l’équilibrage demandent encore un playtest humain. Ce candidat ne devient ni la baseline gameplay ni l’état `CURRENT` du jeu Godot.

## Proposition pour `docs/ai/KNOWN_ISSUES.md`

### Achilles Web Run Lab V1 — réserves du candidat

- Le GLB source d’Achille contient un mesh, mais aucun squelette et aucune animation. La V1 applique un matériau de lisibilité et des transformations procédurales ; `?model=fallback` force le modèle géométrique de secours validé.
- WebGPU est tenté au démarrage, mais seul WebGL 2 a pu être exercé dans Chromium headless sur la machine de validation.
- Le bundle de production contient Babylon.js dans un chunk volumineux ; Vite émet un avertissement non bloquant. Aucun CDN ni appel réseau runtime n’est requis.
- Le bot/simulateur confirme la complétude et l’absence d’état invalide, pas l’équilibrage final. Les 100 runs de seed 12345 gagnent à 47 %, avec une forte attrition en salle 5.
- La cible de durée et la qualité du pacing n’ont pas encore été chronométrées par un joueur humain.
- La suite Godot globale n’a pas été relancée pour ce laboratoire web ; ses échecs historiques documentés restent hors périmètre et inchangés.
