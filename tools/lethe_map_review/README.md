# Les traces du Léthé — étape II

Adaptation du décor de la salle existante, par la pipeline
`docs/maps/registered_terrain_pipeline.md`. Le chemin de salle demeure
`res://data/rooms/catabase_routes/route_f51a86b714b9/room.tres` : le résolveur de
run et l'explorateur utilisent donc le nouveau plan de terrain automatiquement.

## Production

1. `prepare.py` conserve une référence dans `artifacts/dev/lethe-traces/before`,
   lit le manifeste canonique et exporte le guide de calibration.
2. La peinture est produite par image_gen intégré avec ce guide, l'Autel des
   serments et l'Étal du passeur. Source, guide et prompt exact restent dans
   `assets/catabase/combat/lethe_traces_v1/`.
3. `apply.py` applique la texture, ses UV, la réserve de sol, les berges et les
   palettes. Le canevas reste 1920×1200 ; le PNG 1586×992 est compensé par son
   échelle UV. Les 112 dalles et 13 obstacles viennent du moteur ; aucun obstacle
   ou dallage tactique n'est peint dans le fond.
4. `PrepareRoom.tscn` synchronise les projections par ArenaRuntimeBridge,
   sauvegarde le profil de cadrage local et contrôle l'empreinte de gameplay
   avant/après sauvegarde et rechargement avec ArenaSnapshotService.
5. `verify.ps1` lance la vraie scène de combat et les oracles partagés aux
   résolutions 1920×1080 et 1200×896, avant/après déplacement et garde, puis
   compare les proportions des unités entre résolutions. Inspecter les captures.

Les vides conservent leurs règles et leurs parois. Leur ancien fond opaque est
transparent pour laisser voir la peinture ; l'absence de dalles délimite le
terrain interactif. La caméra locale garde la barque en vue. Aucun changement
de statistiques, rencontre ou topologie.

## Jouer / vérifier

```powershell
./tools/lethe_map_review/open.ps1
./tools/lethe_map_review/verify.ps1
./dev.ps1 test test/unit/test_catabase_route_layouts.gd
```

L'aperçu emploie des données utilisateur isolées et la rencontre de test réelle
de la ressource. Il ne modifie pas la sauvegarde personnelle. L'explorateur de
run permet aussi de tester cette destination dans sa position d'expédition.

## Limites

Seule la map II est adaptée. La suite exclusive de cinq escales et les départs
interactifs en barque depuis les combats suivants restent à construire. Les
contrôles de mouvement/garde ne constituent pas un playtest d'équilibrage ni une
bataille complète gagnée. Les propositions v1/v2 sous `docs/maps/concepts/`
restent des archives artistiques, pas la peinture intégrée.

## Eau et lumières
Le shader local living.gdshader anime le courant et les reflets turquoise, avec une réserve conservatrice pour la zone de combat et la coque. La torche et la lanterne reçoivent une lueur chaude modulée lentement, sans déformation UV. Living.tscn pilote une horloge qui respecte la réduction des animations. verify.ps1 mesure huit images GPU : eau, torche et lanterne mobiles, sol témoin stable, gel de l'horloge vérifié.

