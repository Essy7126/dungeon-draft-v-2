# Catabase — dix arènes supplémentaires

Statut : prototype jouable validé en chargement combat. Les rencontres utilisent les acteurs existants ; la composition et les statistiques finales restent à équilibrer dans la run longue.

Les cinq ressources historiques restent intactes. `ExpeditionMapCatalog` expose quinze salles par `all_rooms()` et `get_room(index)` ; `ROOM_COUNT` vaut 15. L'index du catalogue ne représente ni un numéro de combat obligatoire ni une difficulté. Les dix ajouts sont de véritables `ArenaDefinition` persistées, directement consommées par le renderer Catabase `RegisteredTerrainBattle` et ouvrables dans Arena Studio.

## Intentions tactiques

| Index catalogue | Arène | Cases libres | Obstacles | Ennemis | Distance initiale minimale | Décision principale |
|---|---|---:|---:|---:|---:|---|
| 5 | La Porte des Porteurs | 115 | 13 | 3 | 10 | Choisir un des deux couloirs autour d'une épine de colonnes. |
| 6 | La Citerne des Échos | 122 | 8 | 3 | 10 | Tenir un accès court ou tourner autour du vide pour conserver sa distance. |
| 7 | La Galerie des Braises | 93 | 6 | 3 | 6 | Couper par les braises ou garder un trajet sûr dans les lacets. |
| 8 | Le Péristyle Brisé | 145 | 16 | 3 | 11 | Exploiter l'alternance entre colonnes hautes et socles laissant passer les tirs. |
| 9 | La Digue du Léthé | 142 | 6 | 3 | 12 | Traverser par un des trois ponts ; le centre est gelé. |
| 10 | La Cour des Mesures | 121 | 10 | 3 | 11 | Contrôler l'étranglement avant l'ouverture des deux ailes. |
| 11 | La Nécropole des Vœux | 127 | 6 | 3 | 10 | Attirer les ennemis de quatre chambres vers la place centrale. |
| 12 | Le Carrefour des Offrandes | 84 | 4 | 3 | 10 | Désigner une branche prioritaire face à trois directions de menace. |
| 13 | Les Degrés de Cendre | 86 | 6 | 4 | 8 | Recomposer son front sur des terrasses décalées. |
| 14 | L'Atrium des Moires | 132 | 16 | 4 | 10 | Choisir sa distance autour du noyau, conserver une retraite. |

La distance mesure le plus court chemin cardinal entre les zones de départ, sans unité. Les 4 cases de déploiement d'Achille sont toutes sûres. Chaque case jouable appartient à la même composante accessible ; les trous n'isolent aucun ennemi. Toutes les nouvelles formes sont distinctes. Les trois premières salles historiques partagent déjà leur topologie : leur distinction repose sur leur peinture et leur rencontre ; ce lot ne réécrit pas ces cartes.

## Contrat de création

La source éditoriale est `data/rooms/catabase_expansion/blueprints.json`. Chaque plan est écrit à la main sous forme de lignes ; aucun bruit, duplication de grille historique ou génération au lancement n'intervient.

| Symbole | Sens |
|---|---|
| espace | Case absente, sans dalle et non praticable |
| `.` | Pierre praticable |
| `H` | Case de déploiement d'Achille |
| `E` | Case de déploiement ennemi |
| `o` | Socle bas : déplacement bloqué, vue et projectiles conservés |
| `#` | Colonne haute : déplacement, vue et projectiles bloqués |
| `L` | Lave réellement active via le terrain existant |
| `I` | Glace réellement active via le terrain existant |

`tools/catabase_map_authoring/BuildCatabaseExpansion.tscn` exporte les dix ressources, les projections `RoomGridLayout` et `PaintedMapVisualData`, les manifestes géométriques, les plans de terrain et les guides PNG de calibration. Le guide PNG est destiné à Arena Studio et à une future commande artistique. En combat, il est masqué et remplacé par les véritables dalles, le vide, les shaders et les props existants.

Les palettes pierre, Léthé, cendre, jugement et serment changent l'ambiance sans altérer les règles. Les décors d'obstacle utilisent `StonePlinth` et `BrokenColumn`. Les nouvelles cartes possèdent une direction visuelle cohérente et une géométrie finalisée ; elles n'ont pas encore les grandes peintures d'environnement uniques des cinq salles historiques.

Le planificateur de formation partagé considère `enemy_spawn_zone` comme une préférence. Les nouvelles rencontres interdisent explicitement les autres cases pour le placement initial, afin de conserver les fronts prévus. Elles définissent aussi un minimum de cinq pas pour chacun de leurs rôles. Le déplacement devient libre dès le combat commencé. Les 24 seeds testées par salle ne peuvent pas placer un archer à côté d'Achille en contournant le plan auteur.

## Pipeline pour la suite

1. Écrire la question tactique de la salle et les builds qu'elle met en tension : mêlée, distance, projection, défense, mobilité ou terrain.
2. Dessiner un plan court dans `blueprints.json`, placer quatre départs sûrs et un front ennemi ; garder un trajet praticable qui n'impose pas une technique facultative.
3. Exporter les ressources avec le lanceur d'auteur, puis importer les nouvelles textures dans Godot.
4. Exécuter `CatabaseMapsTest.tscn` : connexité, états des cases, spawns, formations, sérialisation et rendu doivent rester cohérents.
5. Exécuter `CatabaseMapsRuntimeProbe.tscn` : scène réelle, acteurs, déploiement et projection graphique.
6. Faire un playtest de la rencontre dans sa vraie position de run : temps avant première décision offensive, usage des outils du build, dégâts inévitables, chemins inutilisés et tours morts.
7. Pour la peinture finale, utiliser le guide de calibration, conserver exactement le canvas 1920×1200 et les axes du manifeste, puis importer le décor par la chaîne Arena Studio existante. La peinture ne redéfinit aucune collision.

Ne pas régénérer après une modification directe des `.tres` dans Arena Studio sans reporter d'abord cette décision dans la source auteur : l'export reconstruit volontairement les dix ressources à partir des blueprints.

## Vérifications exécutées

Binaire utilisé : `C:\Users\p.montebello\AppData\Local\Temp\dungeon-draft-expedition-godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe` (Godot 4.7.1).

Depuis la racine du dépôt, avec ce binaire à la place de `godot` :

```powershell
godot --headless --path . --log-file artifacts/catabase-map-authoring-final.log res://tools/catabase_map_authoring/BuildCatabaseExpansion.tscn
godot --headless --path . --log-file artifacts/catabase-maps-test-final.log res://tests/expedition/CatabaseMapsTest.tscn
godot --headless --path . --log-file artifacts/catabase-maps-runtime.log res://tests/expedition/CatabaseMapsRuntimeProbe.tscn
godot --path . --resolution 1280x720 --log-file artifacts/catabase-maps-visual-final.log res://tests/expedition/CatabaseMapsRuntimeProbe.tscn -- capture=true
```

- Export auteur : 10 maps, aucune erreur.
- Données finales et 24 formations par nouvelle map : 4 439 contrôles, 0 échec.
- Rendu GPU à 1280×720 : 206 contrôles, 0 échec, 10 captures de scènes réelles après disparition du bandeau de tour ; placements ennemis auteurs et quatre sorts canoniques vérifiés.
- Le smoke runtime vérifie le chargement de chacune des dix salles, le déploiement manuel et le rendu réel. Il ne simule aucune victoire et ne prétend pas valider l'équilibrage.
- Rapports et captures : `artifacts/catabase_maps/` (ignorés par Git).

L'import des textures s'est terminé ; l'ouverture de l'éditeur pendant le développement concurrent a aussi signalé des scripts momentanément incomplets et le smoke automatique du plugin Studio n'a pas pu écrire dans `user://`. Ces messages ne constituent pas une validation du gate complet Studio. Les tests dédiés des maps lancés après stabilisation passent. Le harness de scènes relève des ressources/RID encore vivants à la fermeture Godot, comme les autres probes du projet ; aucun échec de topologie ou de chargement combat n'est masqué par ce constat.
