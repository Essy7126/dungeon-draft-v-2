# Dungeon Draft Observatory — frontend V0

Application React statique et en lecture seule pour explorer le snapshot de conception de Dungeon Draft. Elle ne contient ni backend, ni authentification, ni télémétrie, ni déploiement.

## Source et validation

La source unique est `public/data/latest.json`. Le schéma autoritaire reste `../tools/observatory/schemas/observatory_snapshot.schema.json` : `npm run sync:schema` en crée une copie publique générée et ignorée par Git. Le snapshot reste `unknown` jusqu’à sa validation Ajv Draft 2020-12, au build comme dans le navigateur.

Pour mettre les données à jour, exécuter l’export Godot depuis la racine du dépôt :

```powershell
& Godot --headless --path . --script res://tools/observatory/export_snapshot.gd -- --output=res://observatory/public/data/latest.json
```

Le frontend ne régénère jamais ce fichier.

## Commandes

```text
npm run sync:schema   copie le schéma autoritaire
npm run validate:data valide le snapshot avec Ajv
npm run dev           lance Vite localement
npm run lint          contrôle ESLint et jsx-a11y
npm run typecheck     contrôle TypeScript strict
npm run test          exécute Vitest
npm run build         produit le site statique dans dist/
npm run e2e           exécute Playwright Chromium et Axe
npm run check         exécute toute la chaîne de validation
```

## Routes

L’application utilise `HashRouter` : `#/overview`, `#/characters`, `#/characters/:id`, `#/spells`, `#/spells/:id`, `#/disciplines`, `#/disciplines/:id`, `#/items`, `#/items/:id`, `#/rewards` et `#/audit`. Toute autre route affiche une 404 locale.

Les listes de sorts filtrent par texte, héros, discipline, coût PA, effet, type de dégâts et élément. Les objets filtrent par texte, rareté, catégorie, emplacement, héros compatible, éligibilité à la première run et type.

## Principes de lecture

Les libellés et budgets PA sont dérivés de façon déterministe. Un budget PA ne tient pas compte du cooldown, du ciblage, des limites d’usage ni des autres règles du sort. Une récompense déclarée n’est jamais présentée comme effectivement obtenue. Aucun poids absent n’est transformé en probabilité.

Les chemins `res://` ne sont jamais chargés comme URL ; les visuels utilisent un placeholder. Les descriptions sont rendues comme texte, sans HTML ou Markdown injecté.

## Limites

Runs détaillées, salles, vagues, ennemis, architecture complète et theorycraft avancé restent reportés. La prochaine étape pourra les ajouter au snapshot autoritaire avant toute extension de l’interface. Les intentions de mise à jour, le feedback testeurs, l’authentification, l’hébergement privé et ChatGPT Sites sont hors de cette V0.
