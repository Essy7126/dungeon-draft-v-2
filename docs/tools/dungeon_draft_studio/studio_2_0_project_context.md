# Studio 2.0 — contexte projet partagé

Statut : **WORKTREE_CANDIDATE**  
Date : 2026-08-06

`StudioProjectContext` est l’unique autorité de sélection de Dungeon Draft Studio 2.0. L’instance est construite par le plugin puis transmise au shell, à Arena, à Encounter et à Skill Tree.

## État porté

- `active_run`, `active_room_index`, `active_hero` ;
- portée `RUN_SPECIFIC`, `SHARED` ou `DRAFT` ;
- domaines sales et métadonnées associées ;
- générations `context`, `references`, `arena`, `encounter`, `skills` ;
- état UI persistant.

La barre `StudioContextBar` affiche le même état dans le shell et la fenêtre Skills : run, salle, héros, portée, état sauvegardé/modifié, chemins, usages et génération de l’index.

## Transition d’un document sale

Un changement de run, salle, héros ou portée n’est jamais appliqué tant qu’un domaine sale n’a pas reçu une décision explicite :

1. `SAVE` appelle le handler transactionnel du domaine ;
2. `DRAFT` écrit une récupération sous `user://` ;
3. `DISCARD` recharge la source canonique ;
4. `CANCEL` conserve sélection et working copy.

Un handler absent ou en échec bloque la transition. Le test `test_project_context_is_run_aware_and_blocks_silent_dirty_replacement` vérifie ce contrat.

## Persistance

Le plugin persiste le snapshot de contexte dans son état de layout. La restauration redécouvre les runs, puis sélectionne le chemin et le héros demandés ; elle ne sérialise jamais les Resources métier dans l’état UI.

