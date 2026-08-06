# Studio 2.0 — graphe de références

Statut : **WORKTREE_CANDIDATE**  
Date : 2026-08-06

`StudioReferenceGraphService` indexe les relations transversales entre `RunData`, salles, profils de contenu, héros, profils de progression, sorts, disciplines, rangs, nœuds et modificateurs.

## Contrat

- un scan complet construit nœuds, arêtes entrantes et sortantes ;
- un second `scan(false)` renvoie le cache sans incrémenter la génération ;
- `invalidate(resource_or_path)` marque uniquement la source concernée ;
- `usages(resource)` et `references_from(resource)` alimentent les plans et barres de contexte ;
- `is_shared(resource)` distingue un partage transversal réel ;
- progression et annulation sont exposées pendant un scan.

Arena invalide la run après rattachement/sauvegarde. Skills conserve son index local pour les opérations intra-arbre, mais utilise le graphe partagé pour les usages inter-runs. Le test Studio 2.0 vérifie cache, génération, usages et invalidation ciblée.

