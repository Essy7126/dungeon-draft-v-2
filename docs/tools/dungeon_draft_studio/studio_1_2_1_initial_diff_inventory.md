# Inventaire initial Studio 1.2.1

Snapshot pris avant toute modification source le 5 août 2026.

- Dépôt : `C:\Users\paolo\Documents\dungeon-draft-v-2`
- Branche : `main`
- HEAD : `1ba5ea5f91c8600bc8a139853859788aa7557334`
- HEAD distant : `origin/main` au même commit
- État Git initial : propre
- Fichiers suivis modifiés : 0
- Fichiers non suivis : 0
- Fichiers staged : 0
- Conflits : 0
- Version déclarée : Godot 4.7, Forward Plus
- Binaire : Godot 4.7.1.stable.official.a13da4feb

Le merge `1ba5ea5` contient Studio 1.2 ainsi que les changements de combat et de
feedback auparavant concurrents. La mission 1.2.1 ne modifie pas ces derniers :

- `battle/floating_text.gd`
- `battle/floating_text_spawner.gd`
- `battle/reporting/combat_report_tracker.gd`
- `core/event_bus.gd`
- `core/damage_resolver.gd`
- `battle/combat_feedback/`
- le flux post-combat

## Baseline vérifiée

| Suite | Résultat |
|---|---:|
| Arena Studio 1.0 | 15/15, 1287 assertions |
| Arena Studio 1.1 | 16/16, 1378 assertions |
| Dungeon Draft Studio 1.2 | 8/8, 108 assertions |
| Encounter Studio | 15/15, 166 assertions |
| Dynamic Arena | 21/22, 366/368 assertions |
| Globale | 666/676, 49026/49079 assertions |

L'échec Dynamic Arena est l'asset historique absent
`artifacts/labs/dynamic_arena/walls_final/wall_assets_normalized.png`.
Les dix échecs globaux sont consignés dans
`artifacts/studio_1_2_1/baseline/logs/global.log`.

Le scan éditeur initial termine avec un code 0 mais rencontre aussi le script
du projet imbriqué `output/validation-feedback-candidate`, qui masque une classe
globale `ItemDefinition`. Ce projet de sortie est hors périmètre Studio.

Les quinze captures de référence sont sous
`artifacts/studio_1_2_1/screenshots/before/`.
