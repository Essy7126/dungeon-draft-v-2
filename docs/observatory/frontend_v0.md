# Frontend statique V0

## Objectif

Donner aux concepteurs une lecture locale, fiable et accessible des données de production déjà exportées par la fondation Observatory. L’interface ne modifie jamais le jeu et ne contacte aucune origine externe.

## Architecture

- React et React Router en mode bibliothèque avec `HashRouter` ;
- Vite avec `base: "./"` ;
- TypeScript strict, types locaux et résultat JSON conservé comme `unknown` avant Ajv ;
- chargement, validation, types, index, sélecteurs, composants et pages séparés ;
- CSS natif sombre, responsive et sans police externe ;
- Vitest/Testing Library pour la logique et les pages ;
- Playwright Chromium et Axe pour les parcours, le responsive et WCAG 2.2 AA.

## Flux de données

1. `sync:schema` copie le schéma autoritaire dans `public/generated/`.
2. `validate:data` valide `public/data/latest.json` avant le build.
3. Le navigateur charge uniquement ces deux fichiers locaux.
4. Ajv valide le snapshot avant de le rendre disponible au contexte React.
5. Les pages consultent des index et sélecteurs immuables.

Une erreur réseau, HTTP, JSON, de schéma ou de compatibilité produit un écran structuré avec le type, le nombre d’erreurs, les premières erreurs, la source attendue, la commande de validation et un bouton de nouvelle tentative.

## Interface

La vue globale expose tous les compteurs, y compris les zéros, ainsi que les domaines inclus, reportés et exclus. Les pages Personnages, Sorts, Disciplines, Objets et Récompenses séparent les informations fonctionnelles des chemins source. La page Audit sépare strictement les cibles/observations du contrat et les règles d’audit.

Les filtres sont combinables et les recherches ignorent accents et casse. La vulgarisation se limite aux valeurs exportées ; aucune note, tier list, simulation, DPS, synergie ou probabilité n’est inventée.

## Accessibilité et sécurité

Le document est en français, propose un lien d’évitement, une navigation nommée, un `main` unique, des labels, captions, titres hiérarchiques et styles de focus visibles. Statuts et sévérités sont communiqués par texte, symbole et couleur. Les mises en page ciblent 1920×1080, 1366×768, 768×1024, 390×844 et 320×568 sans débordement global.

Le code n’emploie ni `dangerouslySetInnerHTML`, ni `eval`, ni iframe, CDN, analytics, cookie, secret, token, backend ou authentification. Les tests refusent les requêtes externes et `res://`.

## Mise à jour et prochaine étape

Régénérer `latest.json` uniquement avec l’exporteur Godot de fondation, puis exécuter `npm run check`. Runs détaillées, salles, vagues, ennemis, architecture complète et theorycraft avancé nécessitent d’abord une extension versionnée du manifeste, du schéma et de l’exporteur. Intentions de mise à jour, feedback testeurs, authentification, hébergement privé et ChatGPT Sites restent hors périmètre.
