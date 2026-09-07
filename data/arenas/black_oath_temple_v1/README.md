# Le Temple du Serment Noir

Salle V Catabase : une nef centrale, deux ailes, deux fosses symétriques et huit bases de colonnes basses. Le renderer partagé reste `RegisteredTerrainBattle.tscn`.

- Canevas : 1920 × 1200 ; grille : 18 × 18 ; origine : (960, 125).
- Axes : (51.6, 25.8) et (-51.6, 25.8).
- 152 FLOOR, 172 VOID dont huit cellules en deux fosses, huit obstacles, 144 cellules marchables connectées.
- Allée centrale u=6..11, v=2..15 entièrement libre. Camps opposés : u=7..10 avec héros v=14 et ennemis v=3 ; trajet de contrôle de douze cellules.
- Présentation : caméra 1.0, décalage souhaité (160, 0) borné à la peinture via camera_keep_painting_in_view, échelle globale des unités 1.08 ; profils partagés inchangés.

## Intérieur et proportions

`land_polygon` couvre tout le canevas : la réserve ne découpe jamais les murs et voûtes peints. `allowed_floor_polygon` est le rectangle indépendant x=320..1600, y=200..950. Aucun décor cosmétique séparé, détail procédural, bord de rive ou eau visible. Water est un fond uni sans texture ni shader, masqué par Land.

Dalles : x=392.4..1527.6, y=279.8..847.4. Bandeau de largeur 0.42 : x=349.056..1570.944, y=258.128..869.072. Marge minimale des dalles à la réserve : 72.4 px natifs. Les mesures de rives sont non applicables.

Le cadrage et la taille des personnages doivent être mesurés sur les vues réellement rendues avec le HUD. Tout ajustement reste local au temple et conserve la même transformation pour le paysage et la grille.

## Régénération

Depuis la racine du projet, avec Python 3 et sa bibliothèque standard :

```powershell
python tools/registered_terrain_authoring/generate_black_oath_temple.py --validate-only
python tools/registered_terrain_authoring/generate_black_oath_temple.py
```

Le [générateur dédié](../../../tools/registered_terrain_authoring/generate_black_oath_temple.py) produit les ressources canoniques, le manifeste, le [rapport](authoring_validation.json) et les guides PNG/SVG. Les paramètres artistiques existants du plan restent conservés. `--terrain-only` limite les écritures au plan géométrique, aux rapports et aux guides. La copie de campagne doit être préparée séparément via `ArenaRuntimeBridge`. Le générateur ne modifie ni la run, ni les rencontres, ni les autres cartes.

Les contrôles de données ne remplacent pas la validation GPU, les actions de combat ni la revue des proportions.
