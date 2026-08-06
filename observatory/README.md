# Dungeon Draft Observatory — frontend V1.2

- Statut : **CURRENT**
- Branche : `feature/observatory-live-v1-2`
- Snapshot : contrat 3.0, provenance Git générée depuis le checkout courant

Application React statique et en lecture seule pour explorer le snapshot de conception de Dungeon Draft. Elle ne contient ni backend, ni authentification, ni télémétrie, ni déploiement.

## Source, provenance et fraîcheur

La source unique est `public/data/latest.json`. Le schéma autoritaire reste `../tools/observatory/schemas/observatory_snapshot.schema.json` : `npm run sync:schema` en crée une copie publique générée et ignorée par Git.

`scripts/generate-build-meta.mjs` compare localement le commit source du snapshot à `HEAD`, puis à `origin/main` si cette référence existe. Les chemins exclusivement Observatory sont exclus. Le fichier ignoré `public/generated/build_meta.json` alimente l’indicateur global : courant, en retard, divergent ou inconnu. Le navigateur ne contacte aucune API GitHub.

Le frontend ne régénère jamais `latest.json`. Pour mettre les données à jour, exécuter l’export Godot depuis un worktree propre à la racine du dépôt :

```powershell
& Godot --headless --path . --script res://tools/observatory/export_snapshot.gd -- --output=res://observatory/public/data/latest.json
```

## Commandes

```text
npm run generate:build-meta  calcule la fraîcheur Git locale
npm run sync:schema         copie le schéma autoritaire
npm run validate:data       valide le snapshot avec Ajv
npm run dev                 lance Vite localement
npm run lint                contrôle ESLint et jsx-a11y
npm run typecheck           contrôle TypeScript strict
npm run test                exécute Vitest
npm run build               produit le site statique dans dist/
npm run e2e                 exécute Playwright Chromium et Axe
npm run check               exécute toute la chaîne frontend
```

## Routes et fonctions

L’application utilise `HashRouter` :

- `#/overview`, `#/runs`, `#/runs/:id`, `#/run` et `#/rooms/:id` ;
- `#/enemies` et `#/enemies/:id` ;
- `#/characters` et `#/characters/:id` ;
- `#/spells` et `#/spells/:id` ;
- `#/disciplines` et `#/disciplines/:id` ;
- `#/items` et `#/items/:id` ;
- `#/rewards` et `#/audit`.

La V1.2 sépare la run principale `SINGLE_ENCOUNTER` de la run de test `WAVE_CHAIN`. Les profils, seeds et multiplicateurs restent visibles uniquement sur la chaîne de vagues. Les personnages exposent toutes leurs statistiques exportées. Les sorts exposent leurs contraintes, effets, modificateurs et avertissements. Les capacités ennemies sont contextualisées par rencontre.

La page Audit est groupée par défaut sur `rule_id + severity + truth_status`. Elle conserve les occurrences brutes dans un panneau repliable, propose des filtres combinables conservés dans l’URL et crée uniquement des liens vers des routes existantes.

## Principes de lecture

Les traductions d’enums sont centralisées dans `src/data/translations.ts`. Les IDs et chemins techniques restent visibles dans les détails de provenance. Les faits runtime, décisions de conception, recommandations et niveaux de santé ne sont jamais confondus.

Les chemins `res://` sont rendus comme texte et ne sont jamais chargés comme URL navigateur. Les visuels indisponibles utilisent le libellé « Visuel non exporté dans ce snapshot ».

## Limites

Observatory reste un instantané statique. Un statut « en retard » prouve uniquement que des chemins hors Observatory diffèrent ; il ne prétend pas connaître leur effet fonctionnel avant un nouvel export. L'hébergement LAN V1.2 sert uniquement une release locale validée en lecture seule.
