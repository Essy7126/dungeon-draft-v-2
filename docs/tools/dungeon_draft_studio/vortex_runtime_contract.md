# Vortex apparié — contrat runtime

Statut : **WORKTREE_CANDIDATE, production certifiée par la suite dédiée**.

Un clic A puis un clic B crée une `ArenaVortexPairDefinition` bidirectionnelle,
avec `pair_id` stable et une seule entrée d’historique. Les deux extrémités
doivent être définies, praticables, différentes et non VOID.

Au runtime, `ArenaRuntimeBridge` ajoute deux arêtes à `GridData`. `Pathfinder`
les inclut dans son graphe déterministe. L’arête A→B ou B→A coûte 0 PM ; le coût
pour atteindre l’entrée reste normal. Une destination occupée retire l’arête du
plan. Le même comportement est donc disponible au joueur et à l’IA.

À l’entrée :

- l’effet du terrain d’entrée est résolu une fois ;
- l’unité est relocalisée si la destination est libre ;
- l’effet du terrain de destination est résolu ;
- le mouvement prend fin immédiatement ;
- un garde de résolution interdit le rebond inverse et toute boucle.

Le vortex est un interactif superposé : il ne remplace ni terrain permanent ni
surface temporaire. La destination ne peut être supprimée, VOID ou occupée.
