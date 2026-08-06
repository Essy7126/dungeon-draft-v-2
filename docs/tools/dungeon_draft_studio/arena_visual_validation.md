# Validation visuelle Arena 1.3.1

`ArenaVisualAssemblyReport` est la preuve commune de l'assemblage. Il contient mode/politique, comptes attendus et rendus par terrain, murs et décorations, assets absents, cellules ignorées, avertissements, erreurs et verdict.

## Règles de validité

- MODULAR : chaque dalle obligatoire et chaque mur obligatoire existe avec sa texture.
- HYBRID : le compte suit exactement la politique du profil.
- PAINTED : zéro dalle est valide uniquement avec `base_floor_intentionally_painted=true`.
- Un terrain inconnu, une texture manquante, un nœud supprimé ou un écart de compte invalide le rapport.

La signature attendue vient du plan. La signature réelle vient de la scène : métadonnées cellule/terrain, chemin texture, position, transform, visibilité, murs et décorations. La suppression artificielle d'une dalle fait échouer `parity_with_runtime`.

## Production

`ArenaProductionService.plan` exige validation logique + rapport visuel valide + absence de conflit. `produce` sauvegarde, recharge sans cache, réinspecte les vrais nœuds, capture/écrit les previews et inscrit le rapport dans validation et manifeste. L'interface affiche « SALLE NON PRODUITE » si le sol manque, sinon « SALLE PRÊTE » avec comptes terrain/murs, previews et rechargement.

## Preuves visuelles

Le runner `studio_v131_arena_pipeline_capture_runner.tscn` produit 72 PNG (24 cas × 1280×720, 1920×1080, 2560×1440) et `capture_metrics.json` sous `res://artifacts/studio_1_3_1/screenshots/after/`. La passe retenue se termine par `ARENA_131_CAPTURE_MATRIX_COMPLETE 72` sans erreur de script. L'inspection confirme textures stone/water/ice/lava, trous VOID, murs, Art, Jeu, conversion PAINTED, HYBRID, Lab, transfert et production.

L'avertissement UID de `Guerrier.tres` et les leaks de sortie existaient au baseline ; ils sont consignés sans modification des ressources personnages.
