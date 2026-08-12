# Rapport de régression Arena Authoring / décor / statuts / vortex

Date : 12 août 2026. Statut : **WORKTREE_CANDIDATE**. Baseline Git :
`8bd9d455bced1c68acf98843e6f6d4844d4174e8`.

## Résultats ciblés

- performance authoring : 14/14, 29 assertions ;
- workflow décor : 16/16, 49 assertions ;
- timing terrains : 17/17, 57 assertions ;
- réseaux vortex : 22/22, 81 assertions ;
- total nouveau : 69/69, 216 assertions ;
- catalogue complet : 64/64, 317 assertions ;
- Dynamic Terrain Tile Replacement : 11/11, 245 assertions ;
- Permanent Tile Alignment/Brush : 27/27, 183 assertions ;
- Removed Cell Topology : 15/15, 204 assertions ;
- Direct Test Runtime Parity : 5/5, 699 assertions.

Le benchmark passe les seuils : 50 cellules 2,451 ms de mutation maximum, 100
cellules 1,516 ms de finalisation, une synchronisation runtime, et 200
cellules/32x32 6,634 ms de finalisation.

Le runner visuel produit 88/88 PNG, zéro échec, en 1280x720, 1920x1080,
2560x1440 et 1200x896. Palette, Grèce, comparaison forêt/Grèce et réseau de
quatre ont été inspectés. Rapport :
`artifacts/arena_authoring_speed/capture_report.json`.

Les suites qui chargent le catalogue complet remontent les UID invalides déjà
présents dans le bundle gelé `produced/room_01_forest` et les profils de test.
GUT les compte comme erreurs inattendues dans certains shards. Le bundle n'est ni
réécrit ni normalisé. Le scan/import termine code 0 ; les diagnostics de
fermeture RID/ObjectDB et la copie `output/validation-feedback-candidate` restent
historiques.

## Validation finale

- suite globale finale de consolidation : 1136/1156, 56 593/56 659
  assertions ; les 20 tests en échec sont exactement les mêmes échecs
  historiques que sur la baseline précédente 1130/1150 ;
- Run Content Isolation : 14/14, 1 504 assertions ;
- Skill Tree protégé : 50/50, 521 assertions ;
- run/trio/GameManager/hub : 116/117, 4 575/4 576 assertions, avec l'unique
  échec historique d'ordre des salles ;
- Dynamic Arena Lab : 21/22, 366/368 assertions, avec l'unique capture
  historique absente ;
- painted runtime, modular runtime et lifecycle plugin : PASS ;
- test direct réel : fingerprints working/temporaire/runtime identiques,
  configuration consommée, caméra `STUDIO_MATCH`, un renderer de sol, aucune
  dalle dupliquée, aucun mauvais parent Y-sort, bundle `produced` non chargé ;
- 41 Resources officielles et les quatre fichiers du bundle produit gelé :
  SHA-256 et tailles identiques au prévol ;
- `git diff --check` : propre.

## Consolidation du gizmo de grille

Le drag de calibration possede desormais une transaction ephemere
`GridTransformPreviewSession`. La Resource canonique, la projection runtime,
l'historique et le plan Destination restent inchanges pendant le geste. Les
evenements Windows sont coalesces a une preview maximum par frame et le canvas
affiche uniquement le background, les contours de grille, le gizmo et les
reperes utiles tant que la precision est active.

Mesure avant correctif (`grid_transform_baseline.json`, 100 evenements) :

- 134 070,025 ms de drag total ;
- 4 709,358 ms pour le pire evenement ;
- 1 056 synchronisations runtime pendant le drag ;
- 9 synchronisations au relachement ;
- ArenaDefinition mutee avant le relachement.

Mesure apres correctif (`grid_transform_after.json`, 500 evenements puis 100
vrais gestes) :

- 1,445 ms pour mettre en file 500 mouvements ;
- 0,073 ms pour le pire evenement ;
- 499 mouvements intermediaires elimines, derniere position conservee ;
- zero mutation et zero synchronisation pendant le drag ;
- une synchronisation au relachement ;
- erreur finale : 0,000 px ;
- relachement complet : 12,042 ms, dont 0,083 ms de projection runtime et
  11,953 ms d'historique/rafraichissement ;
- apres 100 commits : 1 701 noeuds, 2 367 Resources, 8 connexions de signaux et
  1 SubViewport, valeurs strictement identiques avant/apres.

Tests ajoutes : Grid Transform Preview 4/4, 141 assertions. Le workflow Decor
est etendu a 18/18 avec promotion transactionnelle des trois chemins visuels
`background`, `foreground` et `occlusion`; aucun chemin de staging `user://`
n'est conserve dans une production canonique.

### Soak reel de 30 minutes

Le runner `grid_transform_30_minute_soak_runner.tscn` a execute 100 gestes
reels repartis sur 1 800,15 secondes. Verdict : **PASS**.

- premier/dernier evenement : 0,074 / 0,073 ms ; maximum : 0,402 ms ;
- premier/dernier relachement : 3,801 / 3,707 ms ; maximum : 29,594 ms ;
- historique final : 100 actions ;
- noeuds : 53 -> 53 ;
- Resources : 550 -> 550 ;
- connexions de signaux : 4 -> 4 ;
- SubViewports : 0 -> 0 ;
- memoire statique : 244 454 962 -> 286 132 210 octets, soit +41 677 248
  octets ; la valeur finale est aussi le maximum mesure. Cette metrique est
  rapportee mais n'entre pas dans le critere structurel de fuite.

Le dernier geste reste equivalent au premier et le pire relachement reste sous
le budget de 33 ms. Mesures brutes :
`artifacts/arena_authoring_speed/grid_transform_30_minute_soak.json`.
