# Audit final — snapshots UI et feedback de combat

Date : 5 août 2026. Verdict technique : **PARTIAL**.

## Résultat livré

Le contrat de combat post-mutation, le feedback centralisé, les styles, le pool, la galerie, le runner, le registre, les manifests, les mesures de layout et les captures réelles Current/After sont opérationnels. Le parcours principal et la scène de démarrage restent inchangés.

Le statut reste PARTIAL car 17 états UI inventoriés n'exposent pas encore de fixture publique isolée, aucune mécanique d'immunité métier n'existe, le plugin Figma n'est pas disponible en écriture et la passe groupée Godot termine avec des warnings de ressources de rendu. Ces limites sont visibles, non contournées.

## Contrat final

`CombatEventFact` porte les IDs, l'ordre et les montants finaux. `Unit` émet les faits après mutation, conserve une compatibilité legacy et rend un impact explicite idempotent. `SpellCaster` corrèle chaque cible. Le rapport et les flashs consomment la perte réelle de PV. Les DoT suivent le même chemin sans être dédupliqués entre deux ticks logiques.

Les tests obligatoires 50/20/30 et 88/100 + soin 30 sont codés. Le contrôleur ne calcule aucun montant et n'écoute pas simultanément le fait de perte PV et sa vue `status_tick`.

## Snapshots

Le registre contient 23 scénarios/états. Six sont automatisés en Current, soit 18 PNG aux trois résolutions. Deux états impactés sont repris en After, soit six PNG. Le manifeste final contient 24 succès et 51 échecs documentés (17 états × trois résolutions). Les échecs sont des absences de fixture publique, pas des PNG présentés comme réussis.

Les captures réelles ont été rendues avec OpenGL Compatibility sur NVIDIA GeForce RTX 4070 Laptop GPU. Les galeries 720p, 1080p et 1440p ont été inspectées ; l'échelle et la distribution multi-impact sont responsives.

## Performance et durée de vie

Pool préchauffé à 24, maximum actif 48, file bornée par le nombre d'événements soumis, déduplication par `event_id`, cibles en `WeakRef`, nettoyage au changement de scène et couche non interactive. Le test de rafale soumet 101 faits (un original + 100), vérifie la borne active puis le retour au pool.

Il ne s'agit pas d'un benchmark FPS. Le smoke de capture a chargé une vraie salle de combat mais n'a pas joué manuellement jusqu'à la salle suivante. La fermeture du runner signale des fuites de ressources du batch 3D, à isoler dans une amélioration du harness.

## Tests

Les tests ciblés finaux passent : 32/32 (359 assertions) pour contrat, cycle de vie des vues 3D et après-combat ; la passe ciblée précédente couvrait aussi le registre, les contrats existants et les ticks Archer (31/31, 602 assertions). Les smokes salle/bataille/transition passent 22/22 (3 211 assertions). La suite complète du worktree final contient 674 tests : 664 passent et 10 échouent. Les dix échecs restants concernent des assets/captures préexistants absents (pause, arènes, forêt, montagne, pool peint) et une comparaison flottante de timeline. Le rapport machine-readable est `artifacts/test_results/full_suite_final_v2.xml`.

## Figma

Le fallback `artifacts/figma_handoff/combat_feedback/` contient les captures, données et spécifications éditables/importables. Current et Proposed V2 y sont distincts. Proposed V2 n'est pas appliqué au jeu et attend une validation utilisateur après reconstruction native dans Figma.

## Hors périmètre et Git

Aucune formule ou donnée d'équilibrage n'a changé. Aucun fichier du chantier Arena Studio n'a été modifié par cette mission. Aucun reset, clean, stash, changement de branche, commit, push, merge ou publication.

## Suites recommandées

1. Valider ou amender Proposed V2 dans Figma avant tout restylage de production.
2. Exposer des fixtures publiques pour le HUD sélection/ciblage, inventaire, arbre, après-combat, récompense et résultat.
3. Brancher le fait `attack_immune` uniquement lorsqu'une règle d'immunité existe réellement.
4. Isoler chaque capture de scène 3D dans un processus Godot court pour supprimer les warnings de fermeture.
5. Effectuer un smoke manuel complet combat → après-combat → salle suivante et une passe de régression quand les assets préexistants manquants sont disponibles.
