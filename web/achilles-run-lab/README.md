# Dungeon Draft — Achilles Web Run Lab

Vertical slice Web **expérimental** et autonome d’une run tactique solo avec Achilles. Ce projet n’est ni une baseline d’équilibrage, ni un remplacement du projet Godot, de sa run principale ou du trio Elfe/Mage/Guerrier.

## Lancer sous Windows

Prérequis : Node.js 22 ou plus récent et npm.

Le parcours normal est un double-clic sur `start.cmd`. Le lanceur vérifie Node/npm, exécute `npm ci` si nécessaire, démarre Vite uniquement sur `127.0.0.1:4173` et ouvre le navigateur. L’équivalent PowerShell est `start.ps1`.

Pour jouer le build de production local : double-cliquer `play-built.cmd`.

## Commandes npm

```text
npm run dev                 serveur de développement local
npm run typecheck           TypeScript strict navigateur + scripts
npm run lint                ESLint et frontières du domaine
npm run validate:content    validation Zod du contenu par défaut
npm run inspect:achilles    inspection binaire du GLB et manifeste
npm run test                tests Vitest
npm run test:coverage       couverture du moteur pur
npm run build               build Vite sans CDN
npm run preview             prévisualisation du build
npm run test:e2e            parcours Chromium/WebGL 2
npm run simulate -- --runs 100 --seed 12345
npm run verify:core         vérifications hors navigateur
npm run verify              gate complète, E2E et simulation 100 runs
```

Sous PowerShell avec une politique d’exécution restrictive, utiliser `npm.cmd` à la place de `npm`.

## Jouer

- clic gauche sur une case turquoise : déplacer Achilles ;
- `1` à `4` : sélectionner Estoc, Heurt, Traversée ou Garde ;
- clic gauche sur une cible légale : confirmer l’aperçu exact ;
- `Échap` ou clic droit : annuler ;
- `Espace` : terminer l’activation ;
- molette : zoom ; bouton central : déplacer la caméra ; `Q` / `R` : rotation.

Achilles restaure 6 PA et 3 PM au début de son activation. Chaque capacité coûte 2 PA et ne peut être utilisée qu’une fois par activation. `lastActionTag` est un simple lien contextuel éphémère, sans jauge, charge ou ressource persistante. Les décisions futures ennemies ne sont jamais affichées.

## Run Lab

Le Run Lab permet de régler la seed, la difficulté, le soin inter-salles, l’ordre et la composition des salles, les chiffres des capacités et les PV/armures ennemis. Les données sont validées par Zod avec un chemin d’erreur exact, stockées dans `localStorage`, importables et exportables en JSON. Le navigateur n’écrit jamais dans le dépôt.

## Simulation CLI

Le simulateur utilise le même contenu, le même moteur, les mêmes commandes et les mêmes hashes que le client, sans React ni Babylon :

```text
npm run simulate -- --runs 100 --seed 12345 --out artifacts/validation/simulation-100.json
```

Options : `--runs`, `--seed`, `--config`, `--out`, `--difficulty`. Le bot heuristique V1 sert à détecter les états illégaux et boucles ; il ne remplace pas des playtests humains.

## Rendu et asset

Le client tente WebGPU, puis retombe sur WebGL 2 sans bloquer la run. `?renderer=webgl` force WebGL 2 ; `?model=fallback` force le modèle procédural. Le GLB copié contient un mesh (`base_model_path`), aucun squelette et aucun clip ; le runtime complète donc ses mouvements par des transforms procéduraux. Le fallback représente casque, corps, bouclier et lance.

## Sauvegarde et preuves

La run est sauvegardée automatiquement dans `localStorage` après chaque étape importante. Une donnée absente, corrompue ou incompatible est refusée sans crash et peut être exportée pour diagnostic. Les captures runtime et rapports se trouvent dans `artifacts/validation/`.

Limitations : cible desktop 1280×720 et 1920×1080, aucun mobile/PWA, aucun serveur, aucun cloud save, audio ou VFX de production. La durée 20–30 minutes et l’équilibrage restent à mesurer par des humains.
