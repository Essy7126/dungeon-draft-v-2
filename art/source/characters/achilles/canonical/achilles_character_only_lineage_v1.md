# Lignée canonique Achilles — personnage seul V1

## Décision

Cette lignée extrait uniquement le personnage Achilles de la source canonique figée. Elle ne sélectionne, ne copie et n'intègre aucune arme.

```text
snapshot canonique, ancre de provenance uniquement
96ADBB3ECE86600EAA142561CF241DADD30E9838CC35BF6412540D80B4AE214B
└─ master personnage sans arme
   F64F1F78269E3520F1383490D9428E56CC6454E1492B581253B4840E85095D78
   └─ GLB personnage sans arme
      CA162138B9BE6693210619C06BBDABF0FD486E3DC75460A2566CBE140B4A774F
```

Le snapshot de 116 416 542 octets a été rehashé depuis le package canonique en lecture seule. Il sert d'ancre, mais n'est pas copié dans ce dépôt car il contient des lignées mixtes. Le master personnage et le GLB sont les seuls binaires copiés ; leurs tailles et hashes ont été recalculés sur la source et la destination.

## Master personnage

Source canonique : `06_canonical_derivation/achilles_character_master_candidate.blend`.

- Taille : 16 189 396 octets.
- SHA-256 : `F64F1F78269E3520F1383490D9428E56CC6454E1492B581253B4840E85095D78`.
- Contenu : une armature, 52 os, un mesh, quatre Actions, un matériau et trois images.
- Exclusions démontrées par le manifeste canonique : arme, caméra, lumière, rigs/meshes dupliqués et meshes de validation.
- Rig historique : `8ABC3F665C9DEF1E7A855879A590702656FA56CC8B0F475152AC1942B734E512`.
- Rest pose : `705626075561CB5BF62058450CBF1C96515A0F6331FDE51B5CC7E1A1D513E39E`.

Actions préservées, sans attribution de sens gameplay :

| Action | Hash source exact |
|---|---|
| `Anim_0.001` | `46A833E6F0242B8B004AE6CF0B9EB440B0CC70A641357CF597B6F0089EBF78D7` |
| `Anim_0.003` | `0663B667C5184E8CB4E5FCF837DD4F506CFEDBD76FCF5C2CB2A9FEC5E7A2611E` |
| `Anim_0.004` | `122F1FEA491444F20F9DDF0753C29D8FDFB8C49AF222E8EA24C8483679E7B382` |
| `Anim_0.005` | `044B390285866F4935735883534BFEC0BC2A21BDE30C219851F50F4654FA313D` |

La sémantique des Actions reste `UNASSIGNED`. Le déplacement de `mixamorig:Hips` reste `ROOT_MOTION_UNCLASSIFIED`.

## GLB personnage

Source canonique : `07_sandbox_export/achilles_rig_v1_candidate.glb`.

- Taille : 16 136 348 octets.
- SHA-256 binaire : `CA162138B9BE6693210619C06BBDABF0FD486E3DC75460A2566CBE140B4A774F`.
- SHA-256 sémantique : `DB269A095A711A79F716BE1F8427DF01E5BC732C7061AB61059007F69D559112`.
- Structure : un skin, 52 joints, un mesh, quatre animations, une image, un matériau.
- Caméras : 0. Lumières : 0. Nœuds/meshes d'arme : 0.

Les manifestes `character_glb_export_manifest.json` et `character_glb_inspection.json` sont des copies bit-exactes des preuves canoniques `export_manifest.json` et `glb_pass1_inspection.json`.

## Stockage Git

- `*.blend` et `*.glb` sous les chemins Achilles personnage sont ciblés par Git LFS (`filter=lfs diff=lfs merge=lfs -text`).
- JSON et Markdown restent des fichiers Git texte normaux (`text=auto eol=lf`).
- Les fichiers `.import` Godot ne font pas partie de la lignée canonique ; ils sont régénérés dans le worktree.

## Exclusions

- La source divergente `1FA92BD6A5C5CDC7E524F03B3FA41D7E26895E1FCB9425F394B1B2FFD1A79A57` n'est pas consommée.
- La source d'arme `9F96D64E8CB95AA4B29638D049DFE458AB3833B3CB8C5A84F5B8F1F8277F662D` n'est ni copiée ni chargée.
- Aucun candidat de fitting, transform, proxy, profil ou texture d'arme de la Gate A historique n'entre dans cette lignée.

## Statut

`CANONICAL_CHARACTER_INPUTS_REVALIDATED`
`CHARACTER_COPIES_BIT_EXACT`
`WEAPON_RUNTIME_INTEGRATION_DEFERRED_TO_DEDICATED_LAB`
`WORKTREE_CANDIDATE`
`NOT_CURRENT`
`NOT_PRODUCTION`

La preuve détaillée se trouve dans l'artifact ignoré `02_character_inputs/canonical_input_manifest.json` et `02_character_inputs/copy_hashes.json`.
