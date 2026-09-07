# La Cour des Sources — laboratoire d’arène

Cette scène indépendante utilise le combat de production, Achille et deux ennemis Odyssey existants. Les campagnes et le code partagé ne sont pas modifiés.

```powershell
& .\tools\labs\greek_drawn_arena\run_greek_courtyard.ps1
```

Le lanceur cherche Godot 4.7.1 dans `C:\Godot\4.7.1`. Utiliser `-GodotPath 'C:\chemin\Godot.exe'` si nécessaire. On peut aussi exécuter `GreekDrawnCourtyard.tscn` depuis Godot. Placer Achille sur une case de déploiement pour commencer avec ses quatre disciplines actuelles.

```powershell
& .\tools\labs\greek_drawn_arena\run_greek_courtyard.ps1 -Capture
& .\tools\labs\greek_drawn_arena\run_greek_courtyard.ps1 -Verify
```

`-Capture -KeepOpen` conserve la session inspectée. Les rapports et captures vont dans `artifacts/arena_dofus_greece_2026-09-05/runtime/`. Les actions de validation consomment des PM/PA uniquement avec `-Capture` ou `-Verify` ; un lancement interactif normal commence avec toutes ses ressources.

## Géométrie canonique

Le runtime consomme `data/arenas/greek_drawn_courtyard_v1/arena.tres`. Le manifeste voisin est une source d’auteur régénérée par :

```powershell
& .\tools\labs\greek_drawn_arena\sync_geometry.ps1 -ValidateOnly
& .\tools\labs\greek_drawn_arena\sync_geometry.ps1
```

Le générateur accepte un `floor_cells` explicite et exact, ou un `floor_contour_grid` en coefficients de grille dont il teste les centres de cellules puis retire `pits` et `corner_cuts`. Sans ces deux champs, le rectangle `grid_size` reste une option compatible. Une cellule de `floor_cells` ne peut pas être simultanément déclarée vide. La taille de grille est explicite et ne suppose aucune dimension fixe.

Origine, axes, taille logique, taille native de l’image, décalage/échelle de l’image, caméra et ancres sont synchronisés ensemble dans la ressource. Les quatre sommets et `tile_footprint` dérivent des axes. `obstacles.scene_path` puis `prop_scene` priment sur les scènes de secours. Chaque blocker et spawn est vérifié ainsi que la connexité du sol marchable. Les guides SVG/PNG utilisent les dimensions natives du manifeste. Le PNG du guide peut servir de texture de calibration masquée lorsque le terrain composé est actif.

## Terrain composé

`GreekDrawnBattle.tscn` active explicitement `terrain_plan.json` par `registered_terrain_plan_path`. `greek_terrain_composition.gd` transforme tout le plan natif via le même GridView que les dalles. Le terrain est défini par `land_polygon`, des couches `soil_patches`, une surface d’eau et des `shorelines` ; les textures remplissent ces formes. Elles ne décident pas de la frontière terre/eau. `allowed_floor_polygon`, `excluded_floor_polygons` et les marges servent à la validation du sol tactique.

Le plan prend `canvas_size` sans dimensions figées. Les styles de surface acceptent `color` de secours, `texture_path`, `texture_scale` (natifs par pixel texture, scalaire ou paire) un `tint` facultatif et `texture_repeat:false` pour une peinture composée sans répétition. Un patch de sol utilise la clé `polygon` ; une berge utilise `points`, `width`, `color`. Les exclusions acceptent `{id, polygon}`.

`world_decor` accepte soit une texture et `region_px:[x,y,w,h]`, soit une `scene_path`. `anchor:[x,y]` est natif ; `anchor_grid:[i,j]` est converti par les axes de grille. `pivot` est normalisé dans la région de l’image et vaut `[0.5,1]` par défaut. `scale` accepte un scalaire ou une paire. Les couches sont `back`, `y_sorted` ou `foreground`. Les scènes de banc extérieur restent des décors sans cellules ni blocages de gameplay supplémentaires. Les `contact_profiles` sont des listes de polylignes UV normalisées dans la région ; `contact_disabled:true` les désactive. Les contacts suivent pivot, échelle, rotation et ancre du sprite. Le chroma key est facultatif et ignoré lorsqu’une région possède un alpha natif.

Les vrais sprites stone sont conservés. Le shader local atténue le biseau et raccorde la mousse à la prairie dans le repère natif, en gardant l’alpha et les sommets d’origine. Le sol périphérique affleure le terrain : aucune tranche de plateforme n’est ajoutée. Les fosses sont annotées par `manifest.pits`, chaque cellule étant vérifiée contre les vrais VOID de `ArenaDefinition.cells`. Une fosse peut être ouverte sur le contour ; les murs restent limités aux arêtes de leur union. Les props sont des dessins de référence entièrement transformés dans le polygone réel de leur dalle, y compris hauteur, ombre, gravures et traits. Les empreintes au sol des unités sont recalibrées après l’échelle des personnages peints.

## Preuves runtime

Les comptes viennent des cellules et décorations canoniques. La sonde mesure les quatre sommets des vrais Sprite2D en pixels de viewport, les compare à une affine indépendante et aux polygones GridView, puis vérifie les arêtes voisines, neuf points de ciblage par dalle, les empreintes d’unités, les ancrages et les fosses. Tolérance : 0,05 pixel de viewport. La section `terrain_materials` vérifie l'identité effective de texture avec Land, les UV, la teinte et la répétition sur chacun des matériaux de dalle. Le contrôle de support transforme les sprites vers le plan natif et mesure leur intersection avec la terre, les exclusions et les berges.

Les points issus des vrais sprites sont transmis aux véritables endpoints `GridView.update_hover/click_at`, dont les signaux alimentent Battle/TurnState. Un déplacement réel et Garde vérifient occupation, PM, PA, bouclier et usages. L’injection d’événements OS/fenêtre n’est pas certifiée : Godot Window continue à interroger le pointeur système malgré `push_input`. La sonde ne déplace jamais ce pointeur et nomme exactement l’API testée.

Les captures comprennent le combat initial avant dépenses, le terrain sans décors, les contours GridView, la zone de déplacement et l’état après déplacement/Garde.

Les détails de berge sont dessinés par `greek_ground_details.gd`, sans modifier le sol tactique. Le contrôle de support mesure aussi les polygones Land et les lignes de berge réellement rendus. L'arrondi indépendant au pixel entier est désactivé localement pendant cette scène pour conserver la projection fractionnaire, puis restauré à la sortie.


La passe V4 utilise `land_composed_v4.png` pour le paysage arrière et la prairie, puis les deux régions inférieures de `environment_clusters_v4.png` pour les premiers plans. Les textures et contacts sont décoratifs ; la géométrie acceptée reste inchangée. Les prompts exacts et la normalisation de l'illustration figurent dans le manifeste des assets.

## Bandeau de terre autour du combat

`combat_ground_band` dans le plan active le bandeau : `enabled:true`, `width_cells:0.42`, `minimum_shore_clearance_native_px:20`, `shader_path`. Le contour provient des vrais FLOOR et des fosses annotées et vérifiées. L'offset est calculé en espace de grille puis projeté, découpé contre la terre intérieure et les exclusions. La couche sous dalles et fosses est purement décorative.

Le shader fait apparaître uniquement la frange du contour, avec un fondu vers l'herbe. `combat_ground_surface.gdshaderinc` partage la terre avec les bords extérieurs des dalles. La sonde ajoute `combat_ground_band` au rapport : largeur, support, marge de rive, transforms, ordre Z, absence de nouvelles cellules/collisions et accord des 217 matériaux. Si `enabled:false`, le contrôle indique explicitement `skipped`.
