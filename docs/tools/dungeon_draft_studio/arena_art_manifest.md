# Arena Studio 2.0 — manifeste artistique

Statut : **WORKTREE_CANDIDATE**  
Schéma : **2**

`arena_art_manifest.json` est l’autorité du round-trip. Il contient :

- version du manifeste et du schéma Arena ;
- `arena_id`, nom, chemin du document et fingerprint du snapshot ;
- timestamp, canvas, source, résolution et safe crop ;
- taille de grille, origine, axes, offsets, échelles et ancres ;
- `camera_offset`, `camera_zoom`, politique de couches, comptes de dalles et murs ;
- noms attendus `background.png`, `foreground.png`, `occlusion.png` ;
- SHA-256 et rôle de chaque image de référence.

Le kit contient les références propres, grille, coordonnées, gameplay et murs, les masques jouable/void/mur, les guides foreground/profondeur, un snapshot `ArenaDefinition`, le rapport de validation et `art_brief.md`. Les anciens fichiers `map_*.png` et `art_brief.txt` restent produits pour compatibilité.

Codes de refus principaux : `MANIFEST_MISSING`, `SCHEMA_MISMATCH`, `ARENA_ID_MISMATCH`, `GEOMETRY_MISMATCH`, `FINGERPRINT_MISMATCH`, `ARTWORK_MISSING`, `RESOLUTION_MISMATCH`, `COPY_FAILED`. Tous conservent le background précédent comme fallback.
