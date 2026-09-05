# La Cour des Sources — carte grecque composée, 5 septembre 2026

> Modèle de production du 5 septembre 2026 : cette carte est désormais utilisée dans la salle I de Catabase. La scène partagée [RegisteredTerrainBattle](../../battle/painted/registered_terrain/RegisteredTerrainBattle.tscn) et la [recette de création](registered_terrain_pipeline.md) portent le modèle réutilisable. La [Porte des Cendres](ashen_hell_courtyard_v1.md) en est la déclinaison infernale pour la salle II. Les chemins du laboratoire cités plus bas sont des enveloppes de compatibilité de ce runtime commun ; les preuves historiques restent datées.


La version actuelle remplace le prototype à 149 dalles posé sur une illustration indépendante. Le sol tactique, la terre, l'eau, les berges et les décors sont maintenant construits dans un même repère natif. La passe artistique V4 complète le paysage autour de cette géométrie acceptée : bosquet et ruines à gauche, falaise continue à droite, prairie peinte et premiers plans cohérents. Les précédentes conclusions de validation visuelle sont remplacées par cette revue.

## Ce que montre Dofus

La [capture du combat avec les zones vertes](../../artifacts/arena_dofus_greece_2026-09-05/reference/dofus_geometry_review.png), prise avec PrintWindow en 2560 × 1600, sert de référence. Aucune entrée n'a été envoyée à Dofus et aucune donnée interne de carte n'a été extraite.

Le [relevé annoté](../../artifacts/arena_dofus_greece_2026-09-05/reference_geometry_measurement/source_geometry_plan_overlay.jpg), le [plan source](../../artifacts/arena_dofus_greece_2026-09-05/reference_geometry_measurement/source_geometry_plan.json) et le [rapport de mesure](../../artifacts/arena_dofus_greece_2026-09-05/reference_geometry_measurement/REPORT.md) distinguent les parties visibles des parties cachées.

| Élément | Observation et conséquence |
| --- | --- |
| Projection | Axes mesurés (68,7989 ; 34,4042) et (-68,8178 ; 34,4232), ratio 1,99945. L'angle 2:1 du projet était correct. |
| Emprise | Environ 233 cellules avant fosses dans la reconstruction candidate ; le rectangle initial de 13 × 13 était trop petit et ses encoches inexactes. |
| Coin près de l'eau | Environ 101 ± 15 px horizontaux entre le rebord peint et l'eau en pixels source. Cette mesure est distincte de la distance euclidienne depuis un sommet logique. |
| Fosses | Cinq formes différentes, totalisant 16 cellules sombres visibles. Le pilier reste sur une case solide bloquée. |
| Terrain et muret | La terre continue autour du dallage ; le muret suit la falaise hors du sol jouable. |
| Cadrage | Référence 16:10 ; passage uniforme à 1920 × 1200. Une conversion indépendante en 1920 × 1080 déformerait la pente des axes. |

Le problème principal était l'absence de raccord entre une géométrie arbitraire et une terre déjà peinte. Le double relief des dalles et de la plateforme accentuait l'effet d'objet posé. Les premiers tests de coordonnées ne mesuraient pas cette relation au paysage.

## Construction actuelle

Le [manifeste géométrique](../../data/arenas/greek_drawn_courtyard_v1/geometry_manifest.json) produit l'[arène](../../data/arenas/greek_drawn_courtyard_v1/arena.tres) et ses guides. Le [plan terrain](../../data/arenas/greek_drawn_courtyard_v1/terrain_plan.json) reprend terre, berges et ancrages dans le même repère.

- Canevas 1920 × 1200 ; grille logique 19 × 18.
- Origine (830,676793205 ; 46,528936910), axes (51,6 ; 25,8) et (-51,6 ; 25,8).
- 217 sprites stone existants, de 103,2 × 51,6 px natifs.
- 12 cellules bloquées, 205 cellules accessibles connectées.
- 16 cellules de fosse dans cinq groupes ; 109 autres cellules hors dallage.
- 12 sections de blocs et sept sections de muret extérieur, sans ajout de cellules jouables.

Le [renderer de terrain](../../tools/labs/greek_drawn_arena/greek_terrain_composition.gd) dessine la terre comme un polygone texturé ; l'eau et les lignes de berge sont distinctes. Le paysage arrière et la prairie partagent une peinture composée à l'échelle de la carte ; les deux premiers plans restent des sprites transparents ancrés séparément. Le guide PNG utilisé par l'adaptateur peint est masqué en jeu. Les anciennes illustrations monolithiques sont conservées comme sources historiques et ne sont plus affichées.

Le [shader calcaire](../../tools/labs/greek_drawn_arena/limestone_palette.gdshader) conserve la texture stone, son alpha et ses sommets, atténue le biseau et raccorde les joints intérieurs à la prairie et les arêtes extérieures au bandeau de terre dans les coordonnées natives. Aucun relief périphérique supplémentaire n'est dessiné. Les [fosses](../../tools/labs/greek_drawn_arena/greek_platform.gd) utilisent des annotations sémantiques vérifiées contre les vrais VOID ; une fosse ouverte sur le contour conserve ainsi son intérieur sombre. Les murs ne divisent jamais deux cellules d'une même fosse.

Les [détails de berge](../../tools/labs/greek_drawn_arena/greek_ground_details.gd) ajoutent terre, herbes, petites pierres et contacts sous les décors à partir des lignes existantes. Ils ne créent ni cases ni collisions. L'eau reçoit un shader local animé.

Le réglage global d'arrondi indépendant des objets au pixel entier est désactivé uniquement pendant cette scène, puis restauré. Il aurait arrondi les positions fractionnaires malgré une géométrie CPU correcte. Ce comportement et l'API runtime sont décrits dans la [documentation Godot](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-rendering-2d-snap-snap-2d-transforms-to-pixel). Le projet partagé n'est pas modifié.

## Composition artistique V4

La [peinture de terrain](../../asset/map/painted/greece/greek_drawn_courtyard_v1/land_composed_v4.png) réunit le bosquet d'oliviers, l'arche grecque, les colonnes, les falaises calcaires, les chemins de terre et la végétation basse. Elle remplace la prairie répétée et les deux grands décors arrière isolés. Aucun dallage ni eau n'est peint dans cette texture : le polygone de terre et les vraies cases restent les autorités de placement.

L'[atlas de premiers plans](../../asset/map/painted/greece/greek_drawn_courtyard_v1/environment_clusters_v4.png) apporte un olivier et un massif rocheux bas assortis à ce paysage. Les régions transparentes sont mesurées pour ne pas couper les silhouettes ; les échelles sont uniformes et les deux ancres natives sont conservées. Les petits profils de contact suivent désormais ces régions, avec exclusion de toutes les dalles.

Les deux images sont des créations originales avec image_gen. Le [prompt du paysage](../../asset/map/painted/greece/greek_drawn_courtyard_v1/land_composed_v4_prompt.txt), le [prompt de l'atlas](../../asset/map/painted/greece/greek_drawn_courtyard_v1/environment_clusters_v4_prompt.txt) et le [manifeste des assets, révision 6](../../asset/map/painted/greece/greek_drawn_courtyard_v1/asset_manifest.json) conservent la méthode et les empreintes SHA-256. La peinture générée en 1503 × 1047 a été rééchantillonnée sur le canevas natif 1920 × 1200. Cette normalisation concerne uniquement l'illustration ; aucune coordonnée tactique, rive ou collision ne provient de ses pixels.

Le shader des 217 dalles conserve la même instance de texture que Land, avec la même échelle UV, teinte et répétition désactivée, pour la mousse des joints. Le bandeau décrit ci-dessous fournit désormais la matière des raccords extérieurs. Les anciens atlas et le matériau de prairie restent archivés mais ne sont plus utilisés par cette scène. La comparaison avec le plan précédemment accepté confirme des polygones de terre, berges, exclusions rocheuses, ancres et cellules inchangés.

## Bandeau de sol autour du combat

Le [bandeau de terre calcaire](../../tools/labs/greek_drawn_arena/greek_combat_ground_band.gd) délimite maintenant le dallage. Il part de l'union des 217 cellules de sol et des 16 cellules de fosse annotées : 74 arêtes forment un unique contour extérieur, simplifié en 26 sommets. Les fosses et les blocs ne reçoivent aucun anneau intérieur.

L'extension est de 0,42 cellule en espace logique, puis projetée avec les mêmes axes que les dalles. Cela représente environ 19,4 px natifs perpendiculairement aux arêtes. La géométrie est découpée contre la terre reculée de 20 px et les exclusions rocheuses. Le bandeau reste au niveau du sol, sous les vrais sprites de combat et le rendu des fosses ; il n'ajoute aucune case ni collision.

Le [shader du bandeau](../../tools/labs/greek_drawn_arena/combat_ground_band.gdshader) utilise une terre ocre mate, une variation légère et un fondu extérieur. Sa [fonction de matière commune](../../tools/labs/greek_drawn_arena/combat_ground_surface.gdshaderinc) est également utilisée sur les bords extérieurs des dalles. La mousse de prairie reste sur les joints intérieurs, pour éviter une frange verte entre pierre et terre.

Le [contrôle indépendant](../../tools/labs/greek_drawn_arena/greek_combat_band_checks.gd) vérifie les polygones réellement rendus, leur ordre d'affichage, le support terrestre, les exclusions, la largeur, les 217 matériaux et les 125 VOID. Les deux résolutions passent : marge minimale du bandeau jusqu'aux rives d'environ 26,434 px ; erreur de transformation inférieure à 0,001 px. Les résidus numériques de découpe restent sous les tolérances du rapport.

Les réglages sont dans `terrain_plan.json#combat_ground_band` : `enabled`, `width_cells`, `minimum_shore_clearance_native_px` et `shader_path`. Aucun nouveau bitmap n'a été nécessaire pour cette passe.

## Vérification du combat

Les rapports actuels en [1920 × 1080](../../artifacts/arena_dofus_greece_2026-09-05/runtime/runtime_validation_1920x1080.json) et [1200 × 896](../../artifacts/arena_dofus_greece_2026-09-05/runtime/runtime_validation_1200x896.json) donnent ok=true et aucune erreur de validation.

Le [contrôle de support](../../tools/labs/greek_drawn_arena/greek_terrain_support_checks.gd) transforme les quatre sommets des sprites réellement rendus vers le repère terrain. Il mesure également les sommets du Polygon2D Land et des Line2D de berge réellement présents dans la scène.

- Raccord Land/dalles : 217 identités de texture, échelles UV, teintes et états de répétition concordants ; écarts nuls.
- 217 polygones de dalle intégralement sur terre ; aire hors terre nulle et aucune intersection avec l'emprise rocheuse exclue.
- Décalage du Land et des berges par rapport au plan : inférieur à 0,001 px aux deux résolutions (arrondi numérique des transformations).
- Coin critiqué, sommet gauche de la dalle (5,14) : environ 70,238 px jusqu'à la rive, soit 0,681 dalle, au-dessus du minimum prévu de 0,6.
- 868 sommets de sprites, 378 arêtes communes et 1953 points de ciblage contrôlés ; erreurs géométriques inférieures à la tolérance de 0,05 px.
- Cinq fosses, 16 VOID, 42 arêtes d'union, 19 murs arrière et aucune cloison interne.
- Déplacement réel d'Achille de (7,12) à (7,10), PM 3 → 1, occupation mise à jour ; Garde d'airain, PA 6 → 4, bouclier 0 → 10.

Les interactions passent par les vrais endpoints GridView.update_hover/click_at et leurs signaux vers Battle/TurnState, depuis les positions mesurées sur les sprites. L'injection OS/fenêtre n'est pas certifiée et le pointeur système n'a pas été déplacé. Le test ne joue pas une partie entière jusqu'à la victoire.

Les captures de [combat complet](../../artifacts/arena_dofus_greece_2026-09-05/runtime/combat_1920x1080.png), de [résolution habituelle](../../artifacts/arena_dofus_greece_2026-09-05/runtime/combat_1200x896.png), de [grille](../../artifacts/arena_dofus_greece_2026-09-05/runtime/diagnostic_grid_1920x1080.png) et de [déplacement](../../artifacts/arena_dofus_greece_2026-09-05/runtime/diagnostic_move_range_1920x1080.png) ont été produites par le combat. Les deux compositions complètes ont été inspectées visuellement ; le plateau reste dans l'écran et au-dessus de la barre d'actions.

Les journaux band_final_1920 et band_final_1200 dans artifacts/arena_dofus_greece_2026-09-05/ground_band ne présentent pas d'erreur de compilation de script ou de shader. Des messages RID/ObjectDB/ressources non libérées subsistent à la fermeture, famille déjà documentée dans CURRENT_STATE ; ils ne sont pas déclarés résolus ici.

## Utilisation et limites

Exécuter [GreekDrawnCourtyard.tscn](../../tools/labs/greek_drawn_arena/GreekDrawnCourtyard.tscn) avec F6, ou le [lanceur PowerShell](../../tools/labs/greek_drawn_arena/run_greek_courtyard.ps1), puis placer Achille sur une case de déploiement. Le lancement normal commence sans les dépenses des tests.

La silhouette observable et ses proportions guident cette reconstruction ; les contours masqués par arbres, HUD et falaise restent des hypothèses explicites. Les décors sont des dessins grecs originaux, avec des proportions et une densité de végétation différentes de Dofus. La technologie interne de Dofus n'a pas été identifiée : cette carte utilise les systèmes Godot du projet et les nouveaux composants locaux décrits ici. Elle ne constitue pas une copie certifiée de ses données ou de son pipeline propriétaire.
