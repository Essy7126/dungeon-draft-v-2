# Pipeline Dynamic Arena Lab

## Document

Le Lab autonome et le mode **Construction dynamique** du Studio éditent une `ArenaDefinition` v2. Une nouvelle carte est MODULAR, dimensionnable de 1 × 1 à 64 × 64 et initialisée avec pierre, profil visuel et spawns de secours. `DynamicCellState`, `GridData`, les murs et le chemin affiché sont reconstruits depuis le document.

Les commandes conservent pierre, eau, glace, lave, VOID, murs normal/feu/glace avec leur `WallConfig`, orientation, spawns, objectifs, ancres de décor et mode visuel. Un geste crée une action dans `StudioHistoryController`; le mode intégré utilise exactement le contrôleur de la session Arena et n’instancie aucun `DynamicArenaLab`.

## Sauvegarde et migration

**Sauver** écrit une ArenaDefinition canonique. Un schéma ancien n’est jamais réécrit silencieusement : l’ouverture propose migration de la working copy, lecture seule ou annulation. La migration v2 est annulable.

## Envoyer au Studio

**Envoyer au Studio** crée sous `user://dungeon_draft_studio/lab_transfers/` un dossier finalisé par renommage contenant `arena.tres`, `manifest.json` et `validation.json`. Le manifeste contient une empreinte SHA-256 sémantique et seulement des chemins portables.

Le Studio sonde les transferts terminés. La barre d’état annonce le plus récent ; le bouton **Lab** le recharge avec `CACHE_MODE_IGNORE`, vérifie son empreinte et l’ouvre comme nouvelle working copy. Le manifeste est ensuite marqué importé, sans supprimer le transfert.
