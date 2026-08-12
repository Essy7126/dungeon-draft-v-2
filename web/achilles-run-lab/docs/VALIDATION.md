# Validation

- Date : 2026-08-12 (Europe/Paris)
- Dépôt : `Essy7126/dungeon-draft-v-2` (copie locale)
- Branche : `main`
- HEAD initial/final : `8bd9d455bced1c68acf98843e6f6d4844d4174e8`
- Node : `v26.3.1`
- npm : `11.16.0`
- Statut : `WORKTREE_CANDIDATE`

## Dépendances principales épinglées

Vite 8.2.1, React/React DOM 19.2.8, TypeScript 6.0.3, Babylon.js core/loaders 9.20.0, Zod 4.4.3, Vitest 4.1.10, Playwright 1.62.1, tsx 4.23.12 et ESLint 10.8.1. Le lockfile npm est l’autorité complète.

## Résultats

- `npm run typecheck` : PASS.
- `npm run lint` : PASS.
- `npm run validate:content` : PASS, 5 salles, 4 capacités, 12 récompenses.
- `npm run inspect:achilles` : PASS.
- `npm run test` : PASS, 54 tests.
- `npm run test:coverage` : PASS, 54 tests ; domaine à 97,02 % de lignes, 80,55 % de branches, 90,13 % d’instructions et 92,66 % de fonctions.
- `npm run build` : PASS ; avertissement non bloquant sur la taille du chunk Babylon.
- `npm run test:e2e` : PASS, 8 scénarios Playwright couvrant les 23 assertions runtime demandées (environ 2 min).
- `npm run simulate -- --runs 100 --seed 12345 --out artifacts/validation/simulation-100.json` : PASS ; 47 victoires, 53 défaites, 47 % de victoire, 29,24 rounds moyens, p50 31, p90 34, 7,36 PV moyens restants sur les victoires, 0 run invalide et 0 erreur de simulation.
- `npm run verify` : PASS en 186,4 s ; typecheck, lint, validation de contenu, inspection GLB, 54 tests, build, 8 scénarios E2E et 100 simulations.
- Parcours client complet : PASS dans Chromium, seed `12347`, victoire en salle 5 après 35 rounds et 147 commandes, 2 PV restants, aucune erreur console.
- `start.cmd` : PASS ; démarrage local et réponse HTTP 200 sur `http://127.0.0.1:4173/?renderer=webgl`.

## Runtime Chromium

Chromium headless Playwright, WebGL 2 forcé, 1280×720 et 1920×1080. Menu, run par défaut, déplacement, ciblage, dégâts, tour ennemi, récompense, salle suivante, sauvegarde/reprise, Run Lab, import, victoire, défaite et modèle fallback ont été exercés. La console ne contient aucune exception et aucune requête runtime n’a quitté `127.0.0.1:4173`.

Les captures inspectées sont `menu-1280x720.png`, `combat-1280x720.png`, `targeting-1280x720.png`, `reward-1280x720.png`, `run-lab-1280x720.png`, `combat-1920x1080.png`, `fallback-model-1280x720.png` et `victory-1280x720.png` sous `artifacts/validation/`.

## GLB

Source : `assets/characters/Achilles/asset_7Lk6DnzzJFLFGSvx7rQkSa1U.glb`, 619 144 octets, SHA-256 `1be9a64b39f510e694657521ad6f99914c17fcc0df57a30ae009c6e74e0c66fc`. Inspection : mesh `base_model_path`, zéro squelette, zéro animation. Le mesh est chargeable dans Babylon ; tous les mouvements utilisent les procédurales de secours. `?model=fallback` a été validé.

## Problèmes connus

- Le GLB ne porte aucune animation et son matériau original n’offre pas une lisibilité tactique suffisante ; le runtime applique un matériau expérimental.
- Le bundle Babylon produit un avertissement de taille, sans appel CDN ni défaut fonctionnel.
- La durée cible et l’équilibrage n’ont pas été validés par un humain.
- La suite Godot globale n’est pas exécutée dans cette mission et reste connue non verte pour des raisons historiques hors périmètre.
