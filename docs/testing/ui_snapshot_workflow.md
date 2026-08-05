# Workflow de snapshots UI

## Périmètre

Le runner est une scène outil indépendante : `res://tools/ui_snapshots/UISnapshotRunner.tscn`. Il ne remplace pas la scène principale et n'écrit aucune sauvegarde joueur. Le registre inventorie les écrans, leur fixture, leur driver et, lorsque l'automatisation est impossible, le blocage exact.

## Commandes

Depuis la racine du dépôt, avec Godot 4.7.1 :

```powershell
& 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' --path . --rendering-method gl_compatibility res://tools/ui_snapshots/UISnapshotRunner.tscn -- --phase=current
& 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' --path . --rendering-method gl_compatibility res://tools/ui_snapshots/UISnapshotRunner.tscn -- --phase=after
```

Une vraie fenêtre de rendu est requise : le driver headless/dummy produit volontairement des échecs « capture vide ou sans contraste ». `current` remet le manifeste à zéro ; `after` le complète et ne capture que les états impactés (`battle` et galerie).

## Sorties

La racine est `artifacts/ui_snapshots/<HEAD court>/` :

- `current/<résolution>/*.png` ;
- `after/<résolution>/*.png` ;
- `manifest.json` ;
- `layout_metrics.json` ;
- `inventory.md` ;
- `capture_failures.md` ;
- `contact_sheet.png` ;
- `gallery.html`.

Chaque PNG suit `<screen_id>__<state_id>__<width>x<height>.png`. Le manifeste garde le chemin de scène, la fixture, la locale, le seed 1337, la branche, le commit, la version Godot, la date UTC, le checksum et le résultat.

## Déterminisme

- Résolutions fixes : 1280×720, 1920×1080 et 2560×1440.
- Run de production : `res://data/runs/first_run.tres`, salle 1, seed documenté 1337.
- Le runner appelle `GameManager.cleanup_run_state()` avant/après une bataille et prépare un run en mémoire uniquement.
- Les scènes sont stabilisées pendant six frames ; le combat est désactivé avant capture.
- Le titre est positionné à la fin de l'intro, la cinématique à 42,5 s et la galerie est figée.
- Le curseur et l'interaction humaine ne participent pas aux fixtures.
- Les scénarios documentés ne produisent pas de faux PNG : ils produisent une entrée d'échec avec leur raison.

## Ajouter un scénario

1. Ajouter un `UISnapshotScenario` dans `ui_snapshot_registry.gd` avec IDs stables, scène et fixture.
2. N'utiliser qu'une scène réellement accessible. Indiquer `production_status` et un blocage si l'état dépend d'une API privée.
3. Ajouter un driver minimal dans `_instantiate_scenario()` ; ne pas muter de sauvegarde.
4. Exposer `get_layout_metrics()` si une mesure spécialisée est plus fiable que la collecte générique.
5. Ajouter un test de registre et régénérer Current aux trois résolutions.

## Vérification

Ouvrir `gallery.html`, contrôler le contact sheet puis les PNG en taille native, surtout 720p. Vérifier que le nombre de fichiers et leurs SHA-256 correspondent aux entrées `success`. Comparer les IDs d'une seconde exécution ; les dates peuvent changer, pas le jeu de scénarios ni les fixtures.

Les fuites RID/ObjectDB signalées à la fermeture de la passe groupée proviennent du chargement/déchargement successif des scènes 3D de production dans un même processus. Elles sont consignées et empêchent de qualifier la passe globale comme entièrement propre, même si les PNG et checksums sont valides.
