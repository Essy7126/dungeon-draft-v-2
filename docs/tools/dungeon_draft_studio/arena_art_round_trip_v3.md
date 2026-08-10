# Round-trip artistique Arena v3

Statut : **WORKTREE_CANDIDATE**. Le schéma de manifeste art reste v3 ; la version produit est 2.0.0.

L’export écrit les références PNG, `arena_definition.tres`, le brief, le rapport et `arena_art_manifest.json`. Le manifeste contient fingerprints Arena/gameplay, résolution, crop, transformation, géométrie cellule/mur, rôles, hashes, couches attendues et politique d’occlusion.

La réimportation valide d’abord manifeste, générateur, résolution, fingerprint, géométrie et fichiers. Elle prépare une copie, affiche l’overlay avant/après et attend une confirmation humaine. Background, foreground et occlusion sont appliqués selon leur rôle ; une couche optionnelle invalide annule toute la transaction. La calibration et le gameplay doivent conserver leurs fingerprints.

Les manifestes v2 sont lisibles via migration explicite et marqués historiques 1.3.1 ; ils ne deviennent pas v3 par simple réécriture.
