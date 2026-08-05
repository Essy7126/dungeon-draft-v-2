# Rapport de régression Studio 1.2

Environnement : Godot 4.7.1 stable, GUT 9.7.1, Windows, chemins `user://` redirigés vers `artifacts/studio_1_2/sandbox_appdata` pour les exécutions automatisées.

## Suites ciblées

| Suite | Résultat 1.2 | Baseline | Évolution |
|---|---:|---:|---|
| Arena Studio 1.0 | 15/15, 1287 assertions | 15/15 | stable |
| Arena Studio 1.1 | 16/16, 1378 assertions | 16/16 | stable |
| Encounter Studio | 15/15, 166 assertions | 15/15 | stable |
| Dynamic Arena | 21/22, 366/368 assertions | 21/22 | échec historique identique |
| Dungeon Draft Studio 1.2 | 8/8, 108 assertions | nouvelle | passe |

L’unique échec Dynamic Arena est l’asset historique absent `artifacts/labs/dynamic_arena/walls_final/wall_assets_normalized.png`. Il est reproduit avant et après la mission et n’est pas causé par le Studio.

## Validation visuelle

60 PNG couvrent les 20 cas demandés à 1280 × 720, 1920 × 1080 et 2560 × 1440 sous `artifacts/studio_1_2/screenshots/`. `capture_metrics.json` contient taille/ratio réel du canvas et état des panneaux. Les captures inspectées incluent 1280 responsive, Focus, Lab, vue Jeu, assistant, Salle prête, fixture modulaire et fixture hybride.

## Suite globale

La recette finale exécute 70 scripts et 674 tests : **661 passent, 13 échouent, 49003/49059 assertions passent**. Les 8 tests Studio 1.2 passent dans ce run. Dix échecs correspondent au baseline initial ; deux échecs supplémentaires portent uniquement sur des jeux de captures forêt absents du HEAD et non touchés par cette mission. Le dernier (`test_combat_report_tracks_real_events_casts_movement_and_idle_hero`, 17 au lieu de 20) se reproduit isolément et appartient aux changements concurrents du tracker de combat, explicitement laissés hors périmètre.

Les avertissements restants sont le certificat racine inaccessible du sandbox, les UID historiques de GLB et les compteurs de fuite de tests déjà observés. Les smoke tests runtime peint et modulaire sont consignés dans le rapport final de mission.
