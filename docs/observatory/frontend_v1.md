# Observatory frontend V1

La V1 étend l’interface statique existante avec la première run de production et les ennemis atteignables. Elle ne change ni le snapshot, ni le schéma, ni le jeu.

## Routes

- `#/run` présente les métadonnées de la run, l’ordre des salles et une progression factuelle fondée sur les vagues sélectionnées par la seed exportée.
- `#/rooms/:roomId` présente la carte, les zones de spawn, la rencontre, chaque profil de vague, les multiplicateurs, les preuves de calcul et la récompense ultime.
- `#/enemies` filtre les ennemis par texte, faction, rôle, stratégie IA, portée, présence et effet.
- `#/enemies/:enemyId` présente statistiques, résistances, profil IA, passifs, capacités, invocations, présence et audits associés.

Les routes V0 restent disponibles. Les sorts ennemis sont volontairement distincts du catalogue des sorts de héros.

## Données et calculs

Le JSON reste `unknown` jusqu’à sa validation Ajv. Les index sont construits sans mutation et les références inconnues deviennent des états explicites. Les totaux affichés proviennent du snapshot : Observatory ne simule ni placement, ni combat, ni dégâts complets. Les valeurs dépendantes du runtime conservent leur statut et leur preuve.

## Accessibilité et responsive

Les tables ont une légende, les détails techniques utilisent `details/summary`, le lien d’évitement et le focus visible V0 sont conservés. Les scénarios Playwright couvrent 320, 390, 768, 1366 et 1920 pixels ainsi que les quatre nouvelles routes avec Axe.

## Validation locale

Depuis `observatory/` :

```powershell
npm.cmd ci
npm.cmd run check
npm.cmd audit --omit=dev
npm.cmd audit
```

Les captures de référence sont écrites dans `observatory/test-artifacts/screenshots/` et restent ignorées par Git.
