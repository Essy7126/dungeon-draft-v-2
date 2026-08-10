# Métriques tactiques Arena

Statut : **WORKTREE_CANDIDATE**.

L’analyse pure projette la grille puis calcule composantes, diamètre, rayon, distribution des distances, impasses, corridors de largeur un, ponts, articulations et cellules inaccessibles. La matrice complète héros × ennemis fournit minimum, médiane, moyenne, P90, maximum, positions, LoS et tours de contact à 3/5 PM.

Le rapport couvre aussi capacité des spawns, obstacles bloquants, collisions de poussée, chokepoints, routes entre camps, rencontre et couverture de portée lorsque les données de run le permettent. Les cellules volontairement isolées sont distinguées des erreurs de topologie.

Les métriques sont mises en cache par fingerprint Room/Arena. Une modification de terrain, mur, spawn, rencontre ou propriété gameplay invalide naturellement la clé. Le service ne modifie ni ArenaDefinition, ni GridData canonique, ni règle de combat.
