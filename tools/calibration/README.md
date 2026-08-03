# Outils de calibration des maps peintes

`probe_painted_grid.py` estime les deux familles de lignes répétées d'une grille
isométrique. Le script ne contient aucun chemin de projet, aucune map prédéfinie
et aucune source aléatoire : à image et arguments identiques, le JSON produit est
identique.

Entrées obligatoires :

- `--image PATH` : image à analyser.

Entrées optionnelles :

- `--roi X,Y X,Y ...` : polygone de trois sommets ou plus, en pixels image ;
- `--slope-min`, `--slope-max`, `--slope-samples` : recherche des pentes ;
- `--spacing-min`, `--spacing-max` : plage de répétition en pixels ;
- `--output-json PATH` : copie du résultat JSON, en plus de stdout.

Exemple volcan :

```powershell
python tools/calibration/probe_painted_grid.py `
  --image artifacts/maps/pool_map/map_lave_v2.jpg `
  --roi 315,155 688,135 1062,326 1056,420 688,592 315,420 `
  --output-json artifacts/maps/unit_presence_audit/volcano_grid_probe.json
```

Sortie : dimensions d'image, ROI, paramètres effectifs puis, pour les familles
positive et négative, pente, espacement détecté et liste des interceptions.
