# Arena Studio 2.0 — pipeline grid-first et art

Statut : **WORKTREE_CANDIDATE**  
Date : 2026-08-06

## Autorité

La topologie, les terrains, murs, spawns, objectifs et transforms de `ArenaDefinition` sont établis avant le décor. Les modes sont :

- `MODULAR` : toutes les dalles définies sont rendues ;
- `HYBRID` : background peint sous les dalles tactiques sélectionnées ;
- `PAINTED` : compatibilité legacy, avec migration explicite seulement.

Les textures proviennent de `ArenaTerrainRegistry` et `ArenaWallRegistry`. Le renderer pose les visuels avec `mouse_filter` non bloquant et maintient une entrée par cellule.

## Round-trip normal

1. construire et valider la grille ;
2. exporter la référence artistique ;
3. livrer `background.png`, et facultativement `foreground.png`/`occlusion.png`, sans crop ni redimensionnement ;
4. sélectionner `arena_art_manifest.json` dans Importer le décor ;
5. revoir avant/après et choisir les dalles au-dessus du décor ;
6. confirmer l’attachement sans recalibration ;
7. vérifier les vues Art et Jeu ;
8. produire, avec ou sans rattachement à une run.

Le réimport valide manifeste, checksums de références, ID, fingerprint, résolution, crop logique, taille, origine, axes et ancres. Il force `HYBRID`, copie le background sous `res://data/arenas/art_imports/<arena_id>/` et conserve exactement `grid_origin`, `axis_x`, `axis_y`, `image_offset` et `image_scale`.

Le dialogue expose trois politiques : décor seul, terrains spéciaux, ou **TOUTES LES DALLES TACTIQUES**. Cette dernière applique `ALL_DEFINED` et conserve `normal`/`stone` avec `stone.png` dans le canvas, Art, Jeu, runtime et production. Ajouter un décor à une map MODULAR présélectionne cette politique pour éviter la disparition silencieuse de son sol ; le défaut sérialisé historique NON_BASE_TERRAINS n'est pas modifié globalement.

Une divergence affiche `IMPORT À VÉRIFIER` avec code, résolutions et fallback. La calibration trois clics reste disponible pour un asset legacy ou volontairement transformé, jamais comme correction silencieuse.
