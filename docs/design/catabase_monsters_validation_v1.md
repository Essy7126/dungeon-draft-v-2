# Monstres de Catabase — validation du 8 septembre 2026

Les **50 tests distincts passent, avec 5 996 assertions**. Les tests couvrent les quatre ressources de personnage, les 320 poses importées, les huit techniques, les effets réels sur les unités, l'IA et les compositions de la descente. L'import Godot final réussit. Les probes graphiques distinguent les contrôles fonctionnels réussis de leur verdict global de fermeture : les références de l'infrastructure terrain encore retenues ne sont pas masquées.

Contrats : [gameplay et statistiques](catabase_monsters_gameplay_v1.md). Production artistique : [README du pipeline](../../tools/catabase_monster_sprite_pipeline/README.md) et [rapport de génération Meshy](../../art/source/characters/catabase_monsters/generation_report.json). Les personnages utilisent des peintures indépendantes par direction, articulées localement en 2D ; aucun modèle 3D ni nouvelle pose peinte à chaque frame n'est revendiqué.

## Environnement et méthode

- Windows, Godot **4.7.1.stable.official.a13da4feb**, GUT **9.7.1**.
- Captures par le viewport Godot avec le moteur `gl_compatibility`, OpenGL 3.3, Intel Graphics. Audio de test `Dummy`.
- Processus enfants avec `APPDATA` et `LOCALAPPDATA` isolés sous `artifacts/catabase_monsters/checks/<suite>/appdata`. Aucune sauvegarde de joueur n'est remplacée.
- Import `--headless --editor --recovery-mode --import` pour éviter les effets des plugins éditeur. Le lanceur GUT normal rencontrait un répertoire protégé d'anciennes dépendances Meshy ; le helper fournit les vrais résultats de processus, journaux et JUnit au mode `Analyze` du vérificateur strict existant, sans en modifier les règles.
- Les suites sont ciblées. Une vérification exhaustive de tous les tests et scripts du dépôt n'a pas été effectuée.

## Résultats GUT

| Exécution | Résultat | Assertions | Rapport |
| --- | --- | ---: | --- |
| Runtime visuel 16, IA 2, présentation différée 10, régressions atomiques 7, récupération visuelle 6 | **41/41 PASS strict** | 883 | [runtime_lifecycle_verified](../../artifacts/catabase_monsters/checks/runtime_lifecycle_verified/gut-strict-report.json) |
| Données, combat, routes et textures réelles finales | **9/9 PASS strict** | 5 113 | [monster_integration_final](../../artifacts/catabase_monsters/checks/monster_integration_final/gut-strict-report.json) |
| Répétition du test raster après le dernier recadrage des quatre portraits, avec nouvel import | **1/1 PASS strict** | 4 428 | [portrait_raster_final](../../artifacts/catabase_monsters/checks/portrait_raster_final/gut-strict-report.json) |

Les trois rapports contiennent zéro test manquant, ignoré, risqué ou en attente, zéro erreur de parsing et zéro erreur moteur. Le dernier test est une répétition parmi les neuf : il n'augmente pas le nombre de tests distincts.

Les 320 régions de texture sont réellement chargées et découpées : dimensions, pixels non vides, alpha des coins, absence de découpe de silhouette aux bords et variations de pixels pour marche/attaque/sort/mort. Les quatre portraits chargés doivent fournir une animation disponible. Les tests échouent en cas d'import ou ressource manquante.

Les tests de logique vérifient les coûts PA, une seule résolution par contexte, dégâts, poussée, ticks de brûlure/saignement, réduction de PM, cooldowns et choix d'IA quand une spéciale est indisponible. La Fournaise est également vérifiée avec cible hors portée, ligne de vue rompue, cible morte et impact létal sans statut résiduel. Trois routes complètes de seeds `2401`, `42` et `777` utilisent la vraie factory et le vrai planificateur de placement ; les ressources sources restent inchangées.

## Commandes exécutées

Depuis la racine du dépôt, avec le binaire installé à ce chemin :

```powershell
./tools/catabase_monster_validation/run_checks.ps1 -GodotPath 'C:/Users/p.montebello/AppData/Local/Temp/dungeon-draft-godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe' -SuiteId runtime_lifecycle_verified -ImportEvidenceDirectory artifacts/catabase_monsters/checks/runtime_synthetic_and_lifecycle_fixed -TestPath @('res://test/unit/test_catabase_monster_sprite_runtime.gd', 'res://test/unit/test_catabase_monster_ai_cooldowns.gd', 'res://test/unit/test_pending_spell_presentation.gd', 'res://test/unit/test_combat_atomic_outcomes.gd', 'res://test/unit/test_spell_visual_recovery.gd') -ExpectedTestCount 41

./tools/catabase_monster_validation/run_checks.ps1 -GodotPath 'C:/Users/p.montebello/AppData/Local/Temp/dungeon-draft-godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe' -SuiteId monster_integration_final -ExpectedTestCount 9

./tools/catabase_monster_validation/run_checks.ps1 -GodotPath 'C:/Users/p.montebello/AppData/Local/Temp/dungeon-draft-godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe' -SuiteId portrait_raster_final -TestNameFilter test_imported_art_has_all_explicit_directions_and_real_atlas_regions -ExpectedTestCount 1

./tools/catabase_monster_validation/run_checks.ps1 -GodotPath 'C:/Users/p.montebello/AppData/Local/Temp/dungeon-draft-godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe' -Runtime -SuiteId runtime_1280x720_verified -Resolution 1280x720

./tools/catabase_monster_validation/run_checks.ps1 -GodotPath 'C:/Users/p.montebello/AppData/Local/Temp/dungeon-draft-godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe' -Runtime -SuiteId runtime_1920x1080_verified -Resolution 1920x1080
```

La première commande réutilise des preuves d'import réelles pour des modifications limitées aux tests. Les deux commandes suivantes exécutent chacune un nouvel import : la deuxième après stabilisation des atlas, la troisième après le recadrage final des portraits. Les imports terminent avec le code 0.

## Combat graphique et captures

Le probe `tools/catabase_monster_validation/combat_probe.tscn` choisit dans la route de seed `2401` les premiers nœuds contenant chaque famille. Il ouvre la scène de combat réelle, déploie Achille, vérifie les cellules des ennemis contre le vrai plan de formation, puis exécute une décision de l'IA via `EnemyTurnRunner`.

Pour exercer les deux techniques sans dépendre du choix d'IA, la fixture avance les activations et place le héros existant sur une cellule que `SpellCaster.can_cast()` juge légale. Les sorts passent ensuite par le runner réel, avec coûts et dégâts réels. Pour la mort, la fixture abaisse explicitement l'ennemi à 1 PV puis lance légalement **Frappe du Péléide**, du kit CATABASE actuel, pour 3 PA. Les animations sont échantillonnées sur les véritables `AnimatedSprite2D` de la salle ; aucune animation factice n'est substituée.

| Résolution | Contrôles de combat et capture | Captures | Verdict global |
| --- | --- | ---: | --- |
| 1280 × 720 | **253/253 réussis** ; 10/12 références de terrain libérées au point de contrôle, les 2 restantes appartiennent au dernier appel de fixture | 24 | **FAIL** : fermeture terrain encore signalée ; aucun `SCRIPT ERROR` après correction de l'échantillonneur |
| 1920 × 1080 | **253/253 réussis** ; 12/12 références de terrain libérées après quatre frames, soit **265/265 contrôles réussis** | 24 | **FAIL du lanceur** : mêmes références terrain signalées à la fermeture ; processus Godot 0, aucun `SCRIPT ERROR` |

Rapports : [1280 × 720](../../artifacts/catabase_monsters/1280x720/report.json), [1920 × 1080](../../artifacts/catabase_monsters/1920x1080/report.json). Les journaux et codes de sortie sont conservés dans `artifacts/catabase_monsters/checks/runtime_1280x720_verified/` et `runtime_1920x1080_verified/`.

Chaque résolution produit, pour chaque famille, les fichiers `<famille>_authored_encounter.png`, `_walk.png`, `_attack.png`, `_cast.png`, `_resolved_combat.png` et `_death.png`. Leurs dimensions sont vérifiées sur les pixels exportés, pas déduites des paramètres de fenêtre.

Vues de référence inspectées aux deux résolutions :

| Vue | 1280 × 720 | 1920 × 1080 |
| --- | --- | --- |
| Sentinelle et Rejeton — Le portique des lances | [Capture](../../artifacts/catabase_monsters/1280x720/sentinelle_airain_authored_encounter.png) | [Capture](../../artifacts/catabase_monsters/1920x1080/sentinelle_airain_authored_encounter.png) |
| Rejeton pendant son sort | [Capture](../../artifacts/catabase_monsters/1280x720/rejeton_braise_cast.png) | [Capture](../../artifacts/catabase_monsters/1920x1080/rejeton_braise_cast.png) |
| Molosse — Les éclaireurs du portique | [Capture](../../artifacts/catabase_monsters/1280x720/molosse_styx_authored_encounter.png) | [Capture](../../artifacts/catabase_monsters/1920x1080/molosse_styx_authored_encounter.png) |
| Lamie et Sentinelle — Le gué des serments | [Capture](../../artifacts/catabase_monsters/1280x720/lamie_lethe_authored_encounter.png) | [Capture](../../artifacts/catabase_monsters/1920x1080/lamie_lethe_authored_encounter.png) |

Les vues ont été inspectées visuellement : silhouettes présentes et distinctes, portraits lisibles dans l'initiative, pivots cohérents avec les cellules et salle cadrée sans découpe des personnages. Les captures de rencontre attendent la disparition naturelle de la bannière de début de tour.

## Limites et anomalies conservées

Le probe ne représente ni une partie complète gagnée, ni une mesure d'équilibrage. Il ne teste pas les performances sur plusieurs machines, Vulkan ou les exports mobiles. Les captures de mort peuvent coïncider avec une nouvelle bannière de tour générée par le combat.

Aux deux résolutions, le processus final signale `489 ObjectDB instances were leaked at exit` et `5 resources still in use at exit`. Les cinq ressources sont les scripts existants de `GridData`, `CellSurfaceState`, `ElectricalTerrainRegionResolver`, `TerrainSurfaceRuntimeService` et `TerrainEffects`. Aucune classe de visuel de monstre, sprite ou texture n'apparaît dans ces ressources retenues. Le lanceur renvoie donc correctement un échec, même lorsque les contrôles de combat passent. Le dernier passage 1920 × 1080 confirme également la libération des douze références faibles des objets terrain des quatre fixtures après le retour des coroutines.

Un diagnostic de fermeture d'une seule salle, sans déploiement ni attaque, retrouve les mêmes cinq classes alors que les références faibles du grid, de la façade et du service effectivement ouverts sont toutes nulles après quatre frames. Les fichiers `artifacts/catabase_monsters/checks/cleanup_diagnostic.stdout.log` et `.stderr.log` conservent ce constat. Le nettoyage explicite ajouté reste dans le probe et les fixtures de test ; aucune refonte de la gestion de terrain en production n'est incluse.

Des passages préliminaires ont également échoué sur un ancien identifiant de lance et un accès de l'échantillonneur à un sprite détruit. Ces erreurs du probe ont été corrigées. Les résultats préliminaires ne sont pas présentés comme des validations propres.

Les journaux, JUnit, captures et sauvegardes de test restent dans les artefacts ignorés. Aucun commit ni publication n'a été effectué par cette validation.
