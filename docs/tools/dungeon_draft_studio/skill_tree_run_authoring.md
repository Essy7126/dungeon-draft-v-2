# Skill Tree Studio 2.0 — authoring run-aware

Statut : **WORKTREE_CANDIDATE**  
Date : 2026-08-06

Le document canonique est le `CharacterProgressionProfile` choisi par `RunData -> RunContentProfile -> RunHeroProfile`. Le catalogue, le titre et la barre partagée affichent run, héros, profil et portée.

`SkillTreeEditSession.open_progression(run, hero)` fabrique une vue `UnitData` uniquement pour réutiliser les éditeurs existants. Cette vue n’a pas de chemin et n’est jamais une entrée écrivable. `canonical_source()`, `canonical_working()` et `canonical_source_path()` pointent vers le profil.

La transaction :

1. synchronise la vue dans la working copy du profil ;
2. valide le graphe ;
3. calcule créations, mises à jour, détachements, orphelins et conflits ;
4. écrit manifeste, récupération, staging et backups ;
5. applique dans l’ordre de dépendance ;
6. recharge chaque ressource et compare son fingerprint ;
7. recharge la RunData et retrouve le héros ;
8. rollback en cas d’échec.

La fixture 2.0 écrit réellement un profil temporaire, vérifie que la RunData et la vue `UnitData` ne sont pas sauvegardées, puis recharge le couple run/héros. La comparaison de runs présente chemins de profil, sorts, disciplines, rangs, nœuds et effets divergents.

