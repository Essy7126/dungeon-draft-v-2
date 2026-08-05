# Points de restauration et récupération

Les points nommés sont stockés sous
`user://dungeon_draft_studio/arena_restore_points/<map_id>/`. Ils comprennent
un snapshot complet de la working copy et des métadonnées. L'interface permet
de créer, renommer, restaurer et supprimer avec confirmation. Restaurer est une
action d'historique : Undo revient à l'état précédent.

Une sauvegarde crée d'abord une copie de récupération sous
`user://dungeon_draft_studio/arena_studio/recovery/<map_id>.json`. Le fichier
canonique est ensuite écrit et relu pour vérifier O/U/V et les ancres. Le
recovery n'est supprimé qu'après réussite. Au démarrage, les anciens recovery
`user://arena_studio/recovery/` restent détectés pour migration.

Pour une map de production, la sauvegarde recharge la ressource
`PaintedMapVisualData` depuis le disque puis remplace uniquement calibration et
ancres. Foreground, occlusion, caméra, texture, profil et autres champs restent
ceux de la version disque la plus récente. Un fingerprint détecte un conflit
externe et bloque l'écriture silencieuse.

Les tests directs et fixtures utilisent
`user://dungeon_draft_studio/arena_studio/tests/`. Aucun chemin Windows absolu
n'est sérialisé. Une nouvelle arène utilise `res://data/arenas/<id>.tres`.
