# Le Parvis du Jugement — troisième carte de Catabase

La salle III, **Catabase III — Le Jugement de Paris**, utilise maintenant cette cour funéraire dessinée, construite avec le [modèle partagé de terrain peint](registered_terrain_pipeline.md). Le sol gris perle reste calme ; les ruines, cyprès et niches de calcaire se concentrent sur le pourtour. L'eau sombre donne une limite nette à la terre.

## Centre de combat dégagé

- Les **217 vraies dalles** utilisent la projection commune ; aucune grille n'est peinte dans l'image.
- `world_decor` est vide : aucun sprite de premier plan ni segment de banc cosmétique susceptible de dépasser sur une case. Les détails procéduraux de sol et leurs contacts sont désactivés.
- Les **12 cases d'obstacles tactiques** et les **16 cellules de fosse, en cinq groupes**, restent intégrées aux règles de déplacement et de visibilité. Les 205 cases praticables sont connectées.
- La peinture de paysage reste sous les dalles et les personnages. Aucun brouillard, branche ou grande ombre séparée ne passe devant le combat.
- Le bandeau de terre suit le contour réel sur **0,42 cellule**, sans ajouter de case. Sa palette claire (`#b0aa9c`, `#bbb5a8`, `#a7a192`) adoucit le raccord sans créer un rebord sombre.
- L'animation très lente de l'eau est limitée au polygone d'eau, sous le terrain.

Une ancre de décor hors du plateau ne suffit pas : la silhouette entière et son ombre doivent rester dégagées. C'est pourquoi cette variante retire les bancs cosmétiques périphériques. Les obstacles de gameplay restent visibles.

## Projection et joints

Le [manifeste géométrique](../../data/arenas/silent_judgment_courtyard_v1/geometry_manifest.json) reprend le canevas natif 1920 × 1200, la grille logique 19 × 18, l'origine `(830.676793205, 46.528936910)` et les axes `(51.6, 25.8)`, `(-51.6, 25.8)`. Le paysage, le terrain, les dalles, les silhouettes tactiques et le picking partagent ce repère. La peinture ne redéfinit aucune collision.

Le [plan](../../data/arenas/silent_judgment_courtyard_v1/terrain_plan.json) déclare `floor_palette.shader_parameters.interior_joint_land_weight: 0.0`. Cette option utilise la terre compacte du bandeau dans la couleur des joints intérieurs. Le défaut du shader reste `1.0` pour les salles I et II.

Les matériaux gardent leur texture Land, son échelle, sa teinte et son mode de répétition. Cette option ne change ni les sommets, ni l'alpha, ni la texture de pierre, ni les règles tactiques. Elle évite de reprendre les motifs du paysage dans les joints de III ; la composition de la peinture reste contrôlée visuellement.

## Assets créés

Les deux peintures originales ont été produites avec **l'outil intégré image_gen**, puis installées dans le projet. Aucune API ou CLI de génération externe n'a été utilisée.

| Asset | Production et fichier final | Prompt exact |
|---|---|---|
| Paysage funéraire | [land_composed.png](../../asset/map/painted/underworld/silent_judgment_courtyard_v1/land_composed.png), opaque, 1920 × 1200. Variante artistique de la composition grecque validée ; sortie 1683 × 935 normalisée globalement par interpolation bicubique. | [land_composed_prompt.txt](../../asset/map/painted/underworld/silent_judgment_courtyard_v1/land_composed_prompt.txt) |
| Eau calme | [still_water.png](../../asset/map/painted/underworld/silent_judgment_courtyard_v1/still_water.png), opaque, 1254 × 1254, sortie générée conservée. | [still_water_prompt.txt](../../asset/map/painted/underworld/silent_judgment_courtyard_v1/still_water_prompt.txt) |
| Animation d'eau | [still_water.gdshader](../../asset/map/painted/underworld/silent_judgment_courtyard_v1/still_water.gdshader), glissement discret des UV et variation légère de couleur. | Code local, appliqué uniquement à l'eau. |

Les sources, empreintes SHA-256 et paramètres de livraison figurent dans le [manifeste des assets](../../asset/map/painted/underworld/silent_judgment_courtyard_v1/asset_manifest.json). Le recadrage du terrain et la position des cases sont pilotés par les données géométriques, pas par les pixels générés.

## Intégration persistante

La [salle III](../../data/rooms/odyssey/room_03.tres) est une `ArenaDefinition` qui sélectionne ce plan et la scène partagée [RegisteredTerrainBattle](../../battle/painted/registered_terrain/README.md). Sa rencontre finale canonique reste [odyssey_room_03_encounter.tres](../../data/encounters/odyssey_room_03_encounter.tres), avec le champion et l'Ombre de Paris. Les récompenses, l'économie et le profil de Paris sont conservés.

Après import, la préparation reproductible est :

```powershell
Godot --headless --path . res://test/support/PrepareCatabaseJudgmentRoom.tscn
```

Cette scène attend les autoloads, synchronise les données dérivées et sauvegarde uniquement III après comparaison du snapshot de gameplay. Le lancement direct du script comme `SceneTree` compile ses dépendances trop tôt ; employer cette scène.

## Validation du 5 septembre 2026

La préparation par scène termine avec `ok: true`. La [suite GUT ciblée](../../artifacts/catabase_third_map_2026-09-05/gut_maps.log) passe **13 tests / 5 565 assertions**, couvrant les trois packages, leurs ressources persistées, les formations, la connectivité et le contenu Catabase courant.

La [passe GPU 1920 × 1080](../../artifacts/catabase_third_map_2026-09-05/1920x1080/registered_terrain_report.json) passe les trois salles, les déplacements et gardes, les deux transitions et six captures. Pour III : zéro décor cosmétique, zéro remplissage de contact, 217 matériaux à joints neutres, 217 dalles au-dessus du paysage et 12 cases d'obstacles avec représentation tactique. Le bandeau conserve **26,434 px natifs** de marge minimale aux rives.


La [passe complémentaire en 1200 × 896](../../artifacts/catabase_third_map_2026-09-05/1200x896_exact/registered_terrain_report.json) passe également : trois salles, trois déplacements et gardes, deux transitions et **six captures aux dimensions exactes**. La [capture de III en petite fenêtre](../../artifacts/catabase_third_map_2026-09-05/1200x896_exact/room_03_combat_1200x896.png) a été inspectée ; le plateau et les unités restent lisibles. Une première passe compacte avait changé de taille native en III ; le runner rétablit désormais le mode fenêtré après chaque chargement et refuse les captures de taille différente. Cette reprise exacte constitue la preuve compacte.

La capture ci-dessous est une image réelle du combat en salle III, avec le bandeau clair final ; son inspection confirme la séparation des personnages, l'absence de masse décorative dans le centre et le raccord adouci du dallage.

![Le Parvis du Jugement en combat, 1920 × 1080](../../artifacts/catabase_third_map_2026-09-05/1920x1080/room_03_combat_1920x1080.png)

Les victoires des salles I et II sont forcées seulement pour la QA, après les déplacements et gardes réels. Les récompenses et transitions utilisent ensuite les API de production. III est encore en combat après ses actions, avant fermeture du processus. Ces contrôles ne certifient ni une victoire jouée intégralement, ni l'équilibrage, ni les événements de souris Windows. Des signalements de ressources non libérées subsistent à la fermeture de Godot ; ce résultat n'est pas une certification globale du projet.
