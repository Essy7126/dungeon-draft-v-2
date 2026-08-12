# Workflow de décor d'Arena Studio

Statut : **WORKTREE_CANDIDATE**.

`ArenaBackdropCatalogService` découvre manifestes, `ArenaDefinition`, `RoomData`
et salles de `RunData`. Il exclut `res://data/arenas/produced/` et les profils de
test non canoniques. Le bundle incomplet `room_01_forest` n'est jamais une source
du catalogue ni de Tester.

`ArenaBackdropTransactionService` travaille sur la working copy, capture un
recovery, compare le fingerprint gameplay avant/après et rollbacke si une donnée
de gameplay change.

| Mode | Copié | Préservé |
|---|---|---|
| Fond uniquement | fond, dimensions | calibration, caméra, gameplay |
| Décor + calibration + caméra | fond, origine, axes, image transform, caméra | topologie, gameplay |
| Pack visuel complet | précédent + foreground, occlusion, polygone, profil | topologie, gameplay |

Une différence de dimensions est affichée ; elle n'adopte jamais une calibration
silencieusement. Un fichier externe est d'abord copié sous
`user://dungeon_draft_studio/backdrop_staging/`. `ArenaSerializer` matérialise
les trois propriétés `background_path`, `foreground_path` et
`occlusion_mask_path` sous `res://data/arenas/assets/{arena_id}/` à la
sauvegarde. La production promeut de même chaque asset transitoire dans le
dossier `assets/` de sa transaction. Tout autre chemin `user://` non possédé est
refusé : aucune Resource canonique produite ne conserve un chemin de staging.

Le dialogue distingue explicitement la preview de l'application : état
`COPIE DE TRAVAIL NON MODIFIÉE`, boutons `Annuler et fermer` et `Appliquer à la
copie de travail`, comparaison `Ancien`/`Nouveau` avec pourcentage. Après
application, la barre de statut affiche `APPLIQUÉ À LA COPIE DE TRAVAIL — NON
SAUVEGARDÉ`. Les dimensions avant/après, l'adoption de la calibration et de la
caméra et la topologie inchangée sont visibles ; le chemin technique reste dans
l'infobulle. L'annulation d'un changement de décor passe par l'historique Arena,
ce qui préserve Undo/Redo multiétapes.

La source grecque est découverte par le manifeste
`res://addons/dungeon_draft_arena_studio/catalog/backdrops/greece.tres`, sans
chemin codé dans l'UI : image 1254x1254, grille 14x14, origine `(626.5, 303)`,
axes `(43.15, 22.15)` / `(-43.15, 22.15)`, zoom caméra `0.92`. La recette confirme
que le visuel change et que gameplay, cellules, terrains, vortex et spawns sont
identiques.
