# Combat du mage sur les cinq cartes et les dalles canoniques

`TerrainCombatValidation.tscn` est un harness distinct de la matrice d'animations. Il charge les `ArenaDefinition` de la Cour des Sources, de la Porte des Cendres, du Parvis du Jugement, du Gué du Léthé et du Temple du Serment Noir, avec `RegisteredTerrainBattle`, leur topologie, leurs décors et leur caméra. Les fichiers des maps ne sont pas modifiés.

Les placements et dalles sont des **fixtures déclarées avant le combat**, sur une copie mémoire. Ils ne prétendent pas reproduire des dalles déjà présentes dans la campagne. `ArenaDynamicEditingService` pose les sols permanents ; les services canoniques créent les paires/réseaux de vortex. Achilles reste au niveau 1. Aucun PV, PA, PM, sort, statut, occupation ou terrain n'est imposé après le début du combat. Le probe utilise seulement le déploiement et Fin du tour ; l'IA choisit tous les sorts et déplacements du mage.

| Cas | Preuve réelle |
| --- | --- |
| `push_lava` | Réfutation pousse Achilles sur la lave ; dégâts environnementaux et Brûlure |
| `push_water` | Réfutation pousse dans l'eau ; Mouillé et un PM de moins au prochain tour jouable |
| `push_ice` | Réfutation pousse sur la glace ; Gelé et un PM de moins au prochain tour jouable |
| `portal_pair` | Marche volontaire vers l'entrée, relocalisation réelle vers l'autre portail, sort depuis cette sortie avec portée et ligne de vue valides |
| `avoid_fire` | Une dalle de lave coupe le trajet direct ; détour choisi sans dégât de terrain, marche puis sort |
| `escape_fire` | Départ sur une lave réellement dangereuse ; le mage quitte la dalle avant son premier sort |
| `push_electric` | Réfutation vers l'eau électrifiée ; dégâts, Mouillé, Choc et vraie activation sautée |
| `portal_network` | Entrée volontaire d'un réseau à deux sorties sûres ; sortie tirée par le moteur et sort vérifié depuis la sortie réellement obtenue |

Les quatre premiers cas sont exécutés sur chacune des cinq cartes ; les quatre derniers complètent la Cour des Sources. La glace applique actuellement Gelé, sans glissade physique automatique. Les sorts sacrés du mage restent inchangés : ces scénarios ne prétendent pas déclencher conduction électrique, fonte ou vapeur.

```powershell
./tools/philosopher_sprite_validation/run_terrain_matrix.ps1 -Batch terrain_final -IncludeCourtyardExtras
./tools/philosopher_sprite_validation/run_terrain_matrix.ps1 -Batch terrain_visual_lethe -Maps lethe_crossing_v1 -Scenarios portal_pair -Capture
```

Chaque rapport contient les événements réels de `GridData.occupancy_changed`, les dégâts et statuts, les activations et budgets après traitement, les sorts/PA, les chemins préparés et réellement résolus, le rendu des textures canoniques et les pivots d'animation. L'observateur ne consomme aucun résultat du moteur de terrain. Les événements imbriqués des portails sont conservés tels quels, avec position réelle et timestamp.

L'exécution refuse toute erreur de script, timeout, résultat manquant ou assertion échouée. Les runs de capture ne servent pas de preuve de cadence. Les tableaux de résultats ne sont publiés qu'après exécution effective.
