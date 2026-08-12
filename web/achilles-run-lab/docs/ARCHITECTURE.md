# Architecture

## Autorité de simulation

`src/domain/**` constitue l’autorité. Il ne dépend ni de React, ni de Babylon, ni du DOM. ESLint interdit les imports du domaine vers `src/ui/**`, `src/render/**`, `react` et `@babylonjs/**`.

Le flux est : contenu Zod → `GameState` sérialisable → `GameCommand` → nouvel état et `GameEvent` → client React/Babylon ou simulateur CLI. Les règles ne dépendent ni du framerate, ni d’un timer. Les délais du client ne servent qu’à verrouiller brièvement l’entrée pendant le feedback visuel.

## Modèle, commandes et événements

Le modèle explicite `RunState`, `BattleState`, `UnitState`, `GridState`, les définitions de capacité/ennemi/récompense/salle et les métriques. Les unions discriminées couvrent démarrage, déplacement, capacité, fin d’activation, récompense, salle suivante et redémarrage. Les événements couvrent mouvement, dégâts, bouclier, poussée, collision, statut, mort, renfort, victoire de salle/run et défaite.

Une commande refusée ne dépense aucune ressource et n’entre pas dans le journal accepté. Une commande acceptée ajoute un hash FNV-1a d’une sérialisation à clés stables. `contentVersion`, `saveVersion` et `engineVersion` voyagent avec l’état.

## Contenu et déterminisme

`src/content/defaults.ts` contient les cinq cartes 12×12, les quatre capacités, cinq définitions ennemies et douze récompenses. `RunLabConfigSchema` valide aussi les cellules, salles actives et capacités de spawn. Aucun script libre ou expression n’est stocké dans le contenu.

Le PRNG xorshift32 seedé gouverne l’ordre des offres. Les règles de départage utilisent distance, `y`, `x` et identifiant stable. `Math.random()` est interdit et testé dans le domaine et le simulateur.

## Combat et IA

La grille, BFS, cases atteignables et ligne de vue sont purs. `abilities.ts` produit d’abord un aperçu exact, puis exécute la même description validée. L’IA consomme des fonctions de grille identiques, exécute chaque ennemi dans un ordre stable et possède des plafonds d’actions. Les renforts du Centurion ajoutent des unités dans le même `BattleState`.

## Client et rendu

React gère les écrans et transmet uniquement des commandes. Babylon projette les positions de grille, réalise le picking, met en évidence déplacements/cibles/chemin survolé, puis reflète le nouvel état. La scène tente WebGPU et garantit un fallback WebGL 2. Le loader glTF inspecte le modèle au runtime ; un personnage procédural complet prend le relais si nécessaire.

## Persistance et rapport

`src/persistence/save.ts` encapsule un état versionné et le revalide à la lecture. Les configurations Lab et rapports possèdent des clés séparées. Le rapport exporte seed, versions, résultat, salle, rounds, commandes, hashes, récompenses, usages, dégâts, PA/PM et backend.

## Tests et évolutions

Vitest couvre le domaine à plus de 80 % lignes/branches. Playwright force WebGL 2 et teste le parcours réel, les écrans terminaux, la persistance, le Lab, le fallback et l’absence de trafic externe. Le CLI joue plusieurs seeds avec la même autorité.

Une synchronisation future avec des Resources Godot pourrait générer ou importer ce contenu via un convertisseur explicite et versionné. Aucune synchronisation ni mutation Godot n’est implémentée dans cette candidate.
