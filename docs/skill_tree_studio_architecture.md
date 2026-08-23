# Architecture du Studio des compétences

Statut : `WORKTREE_CANDIDATE`
Base : `77799ec945071bf91b1bc4996da2b3bd7b6a81e1` (`main`)
Vérifié le : 23 août 2026

## Frontières

Le module vit sous `addons/dungeon_draft_arena_studio/skill_tree/` et reste chargé à la
demande par `SkillTreeStudioWindowHost`. Les Resources runtime demeurent l’autorité. La
mission n’a modifié ni `SkillTreeResolver`, ni `SpellCaster`, ni les données de
production.

## Document et historique local

`SkillTreeEditSession` possède une working copy et un `UndoRedo` local limité à 256
actions. L’ouverture, le rechargement ou la libération d’un document vide explicitement
l’historique et les tables `source_to_work`, `work_to_source`, nouveaux chemins et
réservations. Aucun `EditorUndoRedoManager` ne reçoit une action du Studio.

La propreté compare l’empreinte courante à l’empreinte sauvegardée : Undo après save
redevient dirty, Redo jusqu’au snapshot sauvegardé redevient clean. Les opérations
composées sont atomiques. `commit_pending_edits()` libère le focus des champs et ferme
les color pickers avant validation, preview, diff, save, navigation ou fermeture.

`SkillTreeCopyService` préserve l’identité partagée avec une table source→copie et
fournit des clés logiques stables (`unit`, `spell`, discipline/rang/nœud/modificateur).
Ces clés permettent de restaurer un brouillon sur une source fraîche sans la modifier.

Dans une session ouverte depuis un run, les compétences et sorts appartiennent
au `CharacterProgressionProfile`, tandis que l’apparence et
`CharacterAnimationSetData` appartiennent au `UnitData` de base. La session garde
deux working copies explicites et les réunit dans un seul plan transactionnel ;
l’adaptateur `UnitData` du profil n’est jamais sauvegardé.

La table événement → clip n’est déclarée qu’une fois dans
`CharacterAnimationSetData`. Les scripts visuels référencent cette même Resource
comme fiche par défaut et conservent seulement leurs constantes spécialisées de
lecture, d’impact ou de sort.

## Services de sûreté

- `SkillTreeDraftService` écrit une version immuable complète plus manifeste sous
  `user://`; un dossier n’est reconnu valide qu’après relecture.
- `SkillTreePathReservationService` distingue FREE, réservation de session, disque,
  cache seul, Resource reconnue, chemin dangereux et conflit de type. Les racines sont
  injectables pour les tests.
- `SkillTreeReferenceIndex` indexe Resources, chemins, IDs, fiche d’animations, références de Resource,
  prérequis, exclusions, discipline/sort ciblé et partages. Renommage, suppression,
  lifecycle, orphelins et collisions projet le consultent.
- `SkillTreeLifecycleService` sépare DETACH_REFERENCE, ADOPT, ARCHIVE et DELETE.
  Archive et suppression vérifient les références, créent une copie et un manifeste
  récupérables, puis seulement retirent le fichier.

## Plan et transaction

`SkillTreeSavePlan`, `SkillTreeSavePlanEntry`, `SkillTreeSaveConflict` et
`SkillTreeChangeSet` sont les contrats de revue. Une entrée porte source/cible,
empreintes, dépendances, propriétaire logique, accessibilité, opération, changements,
conflit, avertissements, ordre et capacité de rollback. Une Resource inaccessible
produit DETACH_REFERENCE et ORPHANED et n’est jamais réécrite.

`SkillTreeSaveTransactionService` exécute :

1. validation rapide et plan ;
2. relecture `CACHE_MODE_IGNORE_DEEP` et conflits externes ;
3. dossier de récupération, manifeste PLANNED et working copy complète ;
4. staging de toutes les écritures, relecture et empreintes ;
5. backup des cibles existantes ;
6. application ordonnée (modifier, nœud, rang, sort, discipline, animations, profil/personnage) ;
7. relecture profonde et comparaison ;
8. manifeste appliqué, rechargement complet et comparaison de l’empreinte finale ;
9. manifeste COMPLETED et suppression du brouillon.

Toute panne injectée ou réelle après le backup déclenche la restauration byte-for-byte
et la suppression exclusive des nouveaux fichiers de la tentative. Le rechargement
final fait partie de la transaction ; aucun `mark_saved()` de secours n’existe.

## Propriétés et interface

`SkillTreePropertyRegistry` classe chaque propriété sérialisée atteignable en EDITABLE,
READ_ONLY_JUSTIFIED, HIDDEN_JUSTIFIED ou UNSUPPORTED_ERROR, avec label français,
description, éditeur, contraintes, unité, visibilité et motif. L’audit échoue si une
propriété n’a pas de contrat. Les listes de Resources vides utilisent leur hint de type,
pas seulement leur contenu, pour conserver un éditeur ordonné.

Le graphe délègue sa disposition à `SkillTreeGraphLayoutService` : rang horizontal,
ordre vertical déterministe/barycentrique, taille réelle des cartes et positions
épinglées. Les exclusions sont dessinées en orange pointillé. La copie multiple appelle
une opération atomique de session qui remappe seulement les relations internes.

`SkillTreeGlobalSearchService` renvoie des résultats document/discipline/nœud. Les
dialogues de plan, recherche et orphelins ne modifient pas les règles runtime.

## Validation et analyses

La validation rapide traduit les invariants de `SkillTreeResolver` et les contraintes
de stockage. Le profil `production_2026_08_05.tres` contient l’ancien snapshot
5 rangs / seuils / distributions / 16 chemins ; il est facultatif, daté et associé à la
base historique.

`SkillTreePathService.enumeration_result()` expose count, limite, troncature, complétude,
configurations, durée et raison. `reachability_analysis()` cherche des préfixes valides
indépendamment de l’énumération des feuilles. `SkillTreeDesignAnalysisService` agrège
accessibilité, dominance prudente avec preuves et capstones numériques consultatives.

## Preview runtime

`SkillTreeRuntimePreviewService` construit une grille, un `Pathfinder`, les effets de
terrain, des unités temporaires et le vrai `SpellCaster`. Il exécute base et chemin sur
des scénarios déterministes et sérialise faits, delta, trace et capacité de chaque
modificateur. Les hooks statiques (portée et cellule libre) sont appelés directement ;
les autres passent par la sandbox. Un type inconnu est explicitement visible dans la
trace. Le service déclare et teste `writes_run_progression = false`.

## État personnel et limites

Les brouillons, archives, récupérations, position de fenêtre et layout de graphe vivent
sous `user://`. Aucun de ces éléments n’est une Resource gameplay. Les analyses longues
sont explicites, mais restent synchrones : l’interface affiche un état d’activité sans
encore fournir d’annulation coopérative. Le thème hérite du projet/éditeur ; le runner
autonome ne peut pas injecter les échelles 125 % et 150 %.
