# Achilles 3D — intégration personnage seul V1

## But et frontière

Ce pipeline fournit le personnage 3D canonique Achilles à l'intégration Odyssey sans équipement. Il sépare strictement trois sujets :

1. provenance et import du personnage canonique ;
2. présentation 3D passive et fallback 2D ;
3. futur laboratoire d'arme, hors de cette mission.

Le personnage visuel ne possède aucune autorité sur les AP, MP, HP, cellules, dégâts, ciblage ou collisions gameplay. `equipment_enabled = false` et `weapon_profile = null` sont des états valides et sans avertissement.

## Entrées autorisées

Le package canonique en lecture seule est `ACHILLES_CANONICAL_SOURCE_V1_20260819_212027`.

| Entrée copiée | SHA-256 | Stockage |
|---|---|---|
| Master personnage | `F64F1F78269E3520F1383490D9428E56CC6454E1492B581253B4840E85095D78` | Git LFS |
| GLB personnage | `CA162138B9BE6693210619C06BBDABF0FD486E3DC75460A2566CBE140B4A774F` | Git LFS |
| Manifeste du master | `3E03A418B3815CAF6FF73F40E842968EA9ED39B6CCEE6F0BD9DAF5905A48DCC7` | Git texte normal |
| Manifeste d'export GLB | `863822B22E7A185ABBD793C546FCB0E8F3CD1288E36D9E5653A06FCDB2E463BF` | Git texte normal |
| Inspection GLB pass 1 | `0BC2207D0CDAAD82BF65A4CC95A4E435B78463151E30CE3C7B94F094F167A62B` | Git texte normal |

Le snapshot `96ADBB3ECE86600EAA142561CF241DADD30E9838CC35BF6412540D80B4AE214B` est rehashé comme ancre de provenance, mais n'est pas copié. Chaque copie sélectionnée est bit-exacte ; le détail source/destination est enregistré dans `02_character_inputs/copy_hashes.json`.

## Contrat d'import

- Un `Skeleton3D`, 52 os, un mesh et quatre animations.
- Aucun nœud ou mesh d'arme, aucune caméra et aucune lumière importée.
- Le matériau et l'image du personnage sont présents dans le GLB.
- Les métadonnées `.import` sont générées par la version Godot du nouveau worktree ; elles ne sont pas reprises de la Gate A.
- Les quatre noms source restent des identifiants d'inventaire. Aucun nom ne reçoit une sémantique gameplay par intuition.
- Le root motion reste non classifié ; un contrôleur visuel doit neutraliser son influence sur le parent gameplay.

## Portage depuis la Gate A

Le diff historique de 44 fichiers a été classé intégralement. Seuls le master personnage, son manifeste et le GLB ont été portés bit pour bit. Les outils génériques d'inspection sont réutilisables conceptuellement, sans copier les workflows mixtes. Les fichiers mixtes ont été reconstruits sous une forme personnage seul. Les fichiers d'arme et de fitting ne sont pas portés.

La branche historique `integration/achilles-3d-sword-odyssey-v1` ne doit jamais être utilisée comme dépendance runtime, chemin d'import ou source de scène. Son checkpoint reste une preuve externe en lecture seule.

## Exclusions obligatoires

- aucune sélection A/B/C de fitting ;
- aucun GLB, texture, profil, proxy, scène ou contrôleur d'arme ;
- aucun bouclier ou arc runtime ;
- aucune modification des règles de jeu, ressources de production, progression, économie, ennemis ou IA ;
- aucune promotion `CURRENT` ou `PRODUCTION` avant validation humaine et intégration complète.

## Vérification de provenance

Les preuves machine-readable sont :

- `01_gate_a_handoff/gate_a_manifest.json` ;
- `01_gate_a_handoff/gate_a_diff_classification.json` ;
- `02_character_inputs/canonical_input_manifest.json` ;
- `02_character_inputs/copy_hashes.json`.

Statut de ce document : contrat de pipeline candidat. Il ne prouve pas à lui seul que le rendu salle II, les performances ou le fallback ont réussi.
