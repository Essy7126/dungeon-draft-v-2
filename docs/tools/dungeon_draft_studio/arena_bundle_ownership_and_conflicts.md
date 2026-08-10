# Ownership et conflits des bundles Arena

Statut : **WORKTREE_CANDIDATE**.

`ArenaBundleInspectionService` classe un dossier en EMPTY, OWNED_COMPLETE, REFERENCED_COMPLETE, OWNED_INCOMPLETE, REFERENCED_INCOMPLETE, OWNED_DIRTY, FOREIGN_CONTENT, CORRUPT_MANIFEST ou LEGACY_BUNDLE. L’ownership exige un manifeste compatible et des hashes exacts ; la simple présence de `arena.tres` ne suffit pas à une production canonique.

Un bundle incomplet non référencé est présenté comme `UNREFERENCED_INCOMPLETE_PRODUCTION_BUNDLE`. Il peut être archivé puis reconstruit uniquement après une action utilisateur. Un bundle référencé, étranger, dirty ou corrompu bloque l’écrasement. Les archives portent un reçu, conservent les hashes et peuvent être restaurées dans une destination vide. Il n’existe aucune suppression automatique.

La divergence gelée `res://data/arenas/produced/room_01_forest/` contient seulement `arena.tres` et `modular_visual_profile.tres`. Elle est inspectée mais ne doit être ni déplacée, ni normalisée, ni sauvegardée, ni utilisée par le runner Tester.
