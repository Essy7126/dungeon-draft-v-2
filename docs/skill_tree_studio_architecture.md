# Architecture du Studio des compétences

## Intégration retenue

Le module appartient au plugin unique `dungeon_draft_arena_studio`, mais son interface
est une fenêtre autonome créée paresseusement. Cette décision remplace la proposition
initiale d’un troisième onglet après validation du projet : elle protège l’espace de
travail Arènes/Rencontres et ne charge ni catalogue, ni graphe, ni simulateur tant que
le Studio des compétences n’est pas ouvert.

Les deux points d’entrée — menu **Projet > Outils** et bouton **Compétences** — appellent
le même `SkillTreeStudioWindowHost`. La fermeture libère tout le sous-arbre de Controls.

## Répartition des responsabilités

- `domain/skill_tree_edit_session.gd` possède la copie de travail, la sélection et les
  actions atomiques Undo/Redo. Il ne connaît aucun Control.
- `domain/skill_tree_validation_message.gd` représente un diagnostic français et sa
  cible navigable.
- `services/skill_tree_catalog_service.gd` découvre uniquement les héros jouables et
  leurs Resources.
- `services/skill_tree_copy_service.gd` duplique le graphe éditable en conservant
  l’identité des références partagées.
- `services/skill_tree_snapshot_service.gd` distingue le changement logique du contenu
  qui appartient physiquement à chaque fichier.
- `services/skill_tree_path_service.gd` et
  `services/skill_tree_simulation_service.gd` interrogent `SkillTreeResolver` et
  `DisciplineProgressState` ; aucune règle de progression n’est recodée dans l’UI.
- `services/skill_tree_save_service.gd` valide, détecte les conflits, sauvegarde les
  dépendances, vérifie leur relecture et restaure après échec.
- `validators/skill_tree_editor_validator.gd` traduit l’autorité runtime et complète
  ses diagnostics pour l’édition.
- `ui/` contient uniquement la présentation, les gestes utilisateur et le routage des
  intentions vers la session ou les services.

## Working copy et Resources partagées

À l’ouverture, chaque `UnitData`, `Spell`, `DisciplineData`, `DisciplineRankData`,
`SkillUpgradeData` et `SpellModifier` éditable reçoit une copie. Deux références vers la
même Resource source pointent vers une seule copie de travail : le partage reste donc
observable et réversible. Les textures, scènes et autres Resources non éditées restent
partagées en lecture seule.

Les dictionnaires `source_to_work` et `work_to_source` servent au plan de sauvegarde et
à la détection des modifications externes. Une Resource choisie depuis le projet est
elle aussi copiée avant d’être ajoutée au document.

## Préservation embarqué/externe

Une copie externe conserve son `resource_path` dans son cache, sans être enregistrée
dans le cache global. Une sous-resource embarquée reste sans chemin propre. Le snapshot
de stockage développe le contenu embarqué, mais représente une dépendance externe par
son chemin. Ainsi :

- une discipline monolithique est réécrite lorsque l’un de ses rangs embarqués change ;
- l’Archer sauvegarde seulement le modificateur, le nœud ou le rang externe concerné ;
- aucune migration silencieuse n’a lieu entre les deux formats.

## Undo/Redo et identifiants

Dans Godot, la session utilise `EditorUndoRedoManager`; les tests utilisent `UndoRedo`.
Une opération composée déclare toutes ses propriétés avant un unique `commit_action`.
Le renommage d’une discipline met à jour la discipline, ses nœuds et son sort. Le
renommage d’un nœud met à jour les prérequis et exclusions connus. Les libellés affichés
restent indépendants des identifiants.

## Sauvegarde transactionnelle

Le plan ne contient que les Resources modifiées et encore accessibles depuis le
personnage. Il est trié dans cet ordre : modificateurs, nœuds, rangs, sorts, disciplines,
personnage. Avant l’écriture :

1. la validation technique doit être sans erreur ;
2. chaque fichier source est relu sans cache et comparé à son état d’ouverture ;
3. les fichiers existants sont copiés sous `user://` ;
4. la working copy complète est enregistrée comme récupération.

Après chaque écriture, la Resource est relue. Un échec restaure les sauvegardes et
retire uniquement les nouveaux fichiers créés par cette tentative. Une réussite recharge
le document depuis le disque et demande un rafraîchissement à `EditorFileSystem`.

## État d’interface et performances

La position de fenêtre, le mode guidé, le dernier personnage et les positions du graphe
sont stockés dans `user://`, séparément des Resources runtime. Les calculs de chemins
sont bornés à 100 000 par le service général et à 1 000 dans le test interactif. Le
catalogue ne parcourt que `data/units/alliés`; les Resources ennemies ne sont jamais
chargées par ce module.
