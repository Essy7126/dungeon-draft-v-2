# Rapport de non-régression — terrains permanents

Date : 2026-08-11. Godot : 4.7.1 stable official `a13da4feb`. GUT : 9.7.1.

## Résultat principal

DÉCISION VALIDÉE — la correction satisfait le contrat fonctionnel et visuel
pour `stone`, `neutral`, `water` et `ice`. `lava` et `void` sont informatifs et
inactifs avec un motif explicite. Aucun changement gameplay n’a été effectué.

### Tests dédiés et associés

| Suite | Résultat | Assertions |
|---|---:|---:|
| permanent tile alignment and brush | 27/27 | 160/160 |
| extended tile catalog | 10/10 | inclus dans le lot |
| data-driven catalogs v2 | 5/5 | inclus dans le lot |
| dynamic terrain tile replacement | 11/11 | inclus dans le lot |
| removed-cell topology parity | 15/15 | inclus dans le lot |
| runtime preview/direct test v2 | 2/4 | 2 diagnostics UID historiques |
| Encounter Studio v1 | 15/15 | inclus dans le lot associé |

OBSERVÉ — le lot principal totalise 70/72 tests et 937/939 assertions. Les deux
échecs proviennent exclusivement de l’UID invalide déjà présent dans le bundle
gelé `room_01_forest`; GUT intercepte ce warning comme erreur inattendue. Les
assertions de la nouvelle suite sont toutes vertes.

HISTORIQUE — les suites de production/intégration qui ouvrent le bundle gelé
restent sensibles à sa divergence locale : certains tests attendent encore un
bundle incomplet de 2 fichiers, tandis que le prévol en a gelé 4. Un autre smoke
historique attend une surface temporaire sur la cellule occupée par un obstacle.
Ces comportements n’ont pas été modifiés par cette mission.

## Captures réelles

Le runner graphique OpenGL 3.3 a produit 30 PNG, sans échec : 10 cas à
1280×720, 1920×1080 et 2560×1440. Le rapport est
`res://artifacts/arena_permanent_tile_alignment/capture_report.json`.

Cas couverts : stone, neutral, damier stone/neutral, water, ice, lave désactivée,
dropdown, preview, test direct et vraie bataille modulaire.

OBSERVÉ — inspection réelle : losanges, bords et hauteurs identiques ; aucune
translation propre à `neutral`; aucun trou, chevauchement ou renderer de sol
multiple ; preview, test direct et bataille montrent le même motif.

## Recette instrumentée exécutée

1. création d’une ArenaDefinition de test et peinture de cellules contiguës en
   `neutral`, `stone`, `water` et `ice` : PASS ;
2. tentative `lava` : refus explicite, option désactivée : PASS ;
3. Undo puis Redo du stroke permanent : PASS ;
4. refresh incrémental du canvas : PASS ;
5. projection preview : PASS ;
6. sérialisation/reload de la working copy : PASS ;
7. copie temporaire `user://` et test direct : PASS ;
8. chargement de la scène runtime modulaire réelle : PASS ;
9. égalité des cartes terrain/texture et absence de doublons : PASS ;
10. expiration d’une surface temporaire et restauration du sol `neutral` : PASS.

## Scan et limites

OBSERVÉ — le scan/import termine avec le code 0 et aucune erreur de parse dans
les fichiers de mission. Restent les diagnostics historiques : UID invalide du
bundle gelé et collision de classe `ItemDefinition` sous `res://output/`.

OBSERVÉ — les sorties normalisées stone/water/ice/lava ont été régénérées à
l’identique. Seule `normalized/neutral.png` est nouvelle.

LIMITATION — la lave permanente ne sera activée qu’après certification de sa
projection runtime WALL, sans conversion en HOLE. Cette mission ne modifie ni
les surfaces temporaires, ni les sorts, ni les runs, ni les rencontres.

## Bundle gelé

Le runner direct n’a chargé aucun chemin sous
`res://data/arenas/produced/room_01_forest/`. Les quatre SHA-256 postvol doivent
rester égaux au prévol avant remise du patch.
