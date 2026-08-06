# Dungeon Draft Studio 2.0 — contrat vérifié

Statut : **WORKTREE_CANDIDATE**  
Date de vérification : 2026-08-06  
Dépôt : `C:\Users\paolo\Documents\dungeon-draft-v-2`  
Branche observée : `main`  
HEAD et `origin/main` observés : `bf2d6f7a8b6dabf2c8b74c5743852475f7c84e0a`

Ce document fige le contrat vérifié avant la première modification Studio 2.0. Il ne déclare pas la mission courante livrée : les changements Run Content présents au démarrage et les futurs changements Studio 2.0 restent des candidats de worktree tant qu'ils ne sont pas intégrés par l'utilisateur.

## Méthode et niveau de certitude

- **Observé** : comportement lu dans le code, les ressources ou une exécution reproductible.
- **Décidé** : invariant demandé par la mission et retenu comme frontière d'implémentation.
- **Divergence** : comportement existant incompatible avec le contrat 2.0.
- **Inférence** : conclusion architecturale tirée de plusieurs observations, à valider par les tests de phase.
- **Recommandation** : amélioration non bloquante, sans extension du périmètre gameplay.

## État Git et filet de sécurité

Observé : le dépôt était sur `main`, sans commit d'avance ou de retard, sans fichier indexé et sans conflit. Dix fichiers suivis étaient déjà modifiés et 36 fichiers étaient déjà non suivis ; ils appartiennent au chantier Run Content antérieur et doivent être préservés.

Un checkpoint externe en lecture seule pour ce chantier a été créé dans :

`C:\tmp\dungeon_draft_studio_2_0_checkpoint_20260806_173721`

- patch binaire des fichiers suivis : SHA-256 `662981d15ce1df47341b46912289acd314644798d5075ea60e5dfec502a2f87b` ;
- archive des 36 fichiers non suivis : SHA-256 `1117f0a5f5d4bf5cb84cc625bd21a9f3478868d79b2cb64510fbc2e796feb2dc` ;
- manifeste de baseline : SHA-256 `a30988bc09d90071c7026492903774ae4acae905efcdb6725b8b47269aa1abc5`.

Décidé : aucun `commit`, `push`, `stage`, changement de branche, `reset`, `clean`, `stash`, `checkout`, `rebase` ou `merge` n'est autorisé par cette mission.

## Autorités métier

### Run Content

Observé : `RunContentCatalogService`, `RunHeroResolver`, `RunProgressionCloneService` et `RunContentIsolationAuditService` fournissent déjà la découverte récursive des runs, la résolution des héros, le profil de progression, les usages, le diagnostic de partage et la copie profonde des ressources mutables.

Observé : la run principale possède six salles en mode `SINGLE_ENCOUNTER`; la run de test possède quatre salles en mode `WAVE_CHAIN`. L'audit d'isolation initial ne signale aucun partage mutable interdit.

Décidé : `RunData` est l'autorité de la séquence de salles. Pour les compétences, le document canonique est le `CharacterProgressionProfile` du couple run/héros. Un `UnitData` produit comme vue éditable est un adaptateur transitoire et ne doit jamais être enregistré comme document canonique.

### Contexte Studio partagé

Divergence : le shell actuel partage un unique `StudioWorkspace` entre hébergement intégré et fenêtre native, mais Arena, Encounter et Skill Tree ne partagent aucun contexte projet. Skill Tree vit dans une fenêtre autonome ; Arena expose une bibliothèque de production codée en dur.

Décidé : une seule instance `StudioProjectContext` porte au minimum run active, index/salle active, héros actif, portée d'édition, état sale, générations, état UI persistant et signaux. Tous les espaces reçoivent cette même instance ; aucun onglet ne maintient une autorité concurrente.

Décidé : tout changement de run, salle, héros ou portée alors qu'un document est sale passe par une transition explicite : enregistrer, conserver comme brouillon, abandonner ou annuler. Un remplacement silencieux est interdit.

Décidé : la barre de contexte demeure visible et expose Run, Salle, Héros, Portée et État, ainsi que chemins, usages, schéma, erreurs et avertissements utiles.

### Graphe de références

Observé : Encounter possède un graphe local et Skills un index local, mais aucun graphe transversal n'indexe runs, salles, héros, profils, arbres, sorts et ressources partagées.

Décidé : `StudioReferenceGraphService` devient l'index partagé. Il doit mettre en cache les nœuds et arêtes, exposer progression/annulation, incrémenter une génération et permettre une invalidation ciblée. Le shell ne doit pas rescanner tout le projet lors de chaque sélection.

### Arena et salles de run

Observé : `ArenaDefinition` dérive de `RoomData`, schéma 2, avec cellules, obstacles, spawns, objectifs, décorations, transforms et modes `PAINTED`, `MODULAR`, `HYBRID`. Les services existants d'historique, récupération, validation, production et rendu modulaire constituent une base à conserver.

Divergence : `ArenaStudioMain.PRODUCTION_LIBRARY` impose Forêt/Volcan/Espace et n'est pas dérivé de `StudioProjectContext.active_run.rooms`.

Décidé : le navigateur de run est dérivé exclusivement de la run active. Il supporte créer, insérer, remplacer, mettre à jour, dupliquer, réordonner et retirer sans supprimer la ressource. Les mutations passent par un plan transactionnel vérifiable, réversible, sauvegardable et rechargeable. Les ressources partagées sont signalées avant édition ; la copie spécifique à une run utilise la politique Run Content existante.

### Grille, art et rendu

Observé : la chaîne HYBRID et `ArenaTerrainVisualRenderer` savent déjà présenter de vraies textures pour sol normal, eau, glace, lave, vide et murs, au-dessus d'un fond peint. La mise à jour visuelle par cellule et le cache sont présents.

Divergence : l'export actuel redimensionne vers 1280×720 et produit quelques images, un brief texte et un rapport, mais aucun manifeste autoritaire avec checksums, géométrie, crop et résolution de round-trip. Il ne peut donc pas garantir une réimportation sans recalibration ni rejeter de manière fiable un kit incompatible.

Décidé : le kit art 2.0 contient manifeste versionné, checksums, géométrie de grille, résolution, crop, transformations et brief. La réimportation valide ces informations, conserve la calibration exacte, refuse les incohérences et propose un fallback explicite.

### État runtime des surfaces

Observé : `DynamicSurfaceService` modélise déjà une séparation base/surface et actualise une cellule. `TerrainEffects` modifie `GridData`; il est hors périmètre de refactorisation.

Divergence : `ArenaRuntimeBridge.sync_runtime_resources()` écrit des ressources runtime dérivées dans `ArenaDefinition`, et `build_grid()` appelle cette synchronisation. Cela brouille l'autorité de l'asset édité et de l'état de combat.

Décidé : une projection runtime copie les données nécessaires dans un état de combat séparé. Les surfaces temporaires ne mutent jamais `ArenaDefinition`. Une mise à jour de cellule conserve la parité logique/visuelle et n'impose pas une reconstruction globale.

### Skill Tree

Observé : le Studio Skills actuel découvre directement les `UnitData`, et `SkillTreeEditSession` utilise `source_unit`/`working_unit` comme racines. Undo/Redo, brouillons, réservations de chemins, index, orphelins, transaction/rollback, validation et prévisualisation réelle via `SpellCaster` sont déjà substantiels.

Divergence : cette racine `UnitData` est incompatible avec l'autorité Run Content. L'interface n'affiche pas run/héros/profil/portée, le graphe est difficile à lire, les cartes se chevauchent et la preview expose surtout du JSON brut.

Décidé : la session 2.0 est ouverte sur run + héros + `CharacterProgressionProfile`. Une vue `UnitData` peut alimenter les composants legacy, mais elle reste non sauvegardable. La comparaison entre runs explicite profil, nœuds, rangs, sorts et divergences. La prévisualisation réutilise les résolveurs runtime réels et résume scénario, résultat, changements d'état, erreurs et avertissements.

### Effets de compétence

Observé : `SpellModSkillTreeEffect` définit 33 `EffectType`, cinq portées et trois modes de statut. Le projet contient aussi 14 sous-classes de `SpellModifier` cœur. Le validateur de durcissement assure une couverture de résumé/capacité, pas une description métier exhaustive éditable.

Divergence : la production affiche encore « effet spécialisé » et n'expose pas uniformément unités, cible, conditions, durée, fréquence et empilement. Eagle Eye/Archer ne peut pas être entièrement authoré sans édition `.tres`.

Décidé : un registre de descripteurs couvre chaque type et chaque classe rencontrée. Un descripteur fournit identité, libellé métier, champs guidés, unité, cible, conditions, durée, fréquence, politique d'empilement, validation et résumé. Aucun effet de production ne retombe sur une catégorie générique « spécialisé ».

## Invariants à conserver

1. Les choix fixes restent Elfe, Mage et Guerrier, 6 AP, 3 MP et quatre sorts ; énergie, Ferveur, Éveil et signature restent exclus.
2. La run principale reste `SINGLE_ENCOUNTER`; la run de test reste `WAVE_CHAIN`.
3. Aucun équilibrage, IA, récompense, intention ennemie ou refactor gameplay non demandé.
4. `SpellCaster`, `SkillTreeResolver`, `DamageResolver`, `GridData`, `Pathfinder`, `TerrainEffects` et le reporting gameplay ne sont pas refactorisés.
5. Encounter ne reçoit que l'intégration minimale au contexte et au graphe partagés.
6. Les services métier restent testables sans UI et les opérations destructives restent transactionnelles ou explicitement récupérables.
7. L'isolation Run Content est testée après chaque grande phase.

## Migrations prévues

- Ajout non destructif du contexte, du graphe et des documents de session 2.0 ; maintien d'adaptateurs legacy pendant la transition.
- Projection des listes Arena depuis `RunData.rooms` ; aucune suppression physique lors d'un retrait.
- Enveloppe de session Skills profile-authoritative ; maintien temporaire de `open(UnitData)` uniquement pour compatibilité/test legacy, avec chemin de sauvegarde canonique distinct.
- Manifeste art versionné et import legacy explicitement marqué comme non round-trip.
- Projection runtime indépendante construite depuis l'arène sans écrire dans la ressource source.

## Critères de sortie

Le verdict final ne peut être que :

- `DUNGEON_DRAFT_STUDIO_2_0_COMPLETE` ;
- `DUNGEON_DRAFT_STUDIO_2_0_COMPLETE_WITH_WARNINGS` ;
- `DUNGEON_DRAFT_STUDIO_2_0_BLOCKED`.

Il exige tests unitaires et intégration, captures 1280×720 et grand viewport, recettes manuelles, preuve d'isolation et documentation mise à jour. Une fonctionnalité seulement maquettée ou documentée n'est pas considérée livrée.
