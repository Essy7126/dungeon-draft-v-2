# Monstres de Catabase — animation v2, 8 septembre 2026

Les **63 tests GUT passent strictement, avec 15 369 assertions**, et **8 tests Python passent** (5 pour les atlas, 3 pour l'articulation et les chevilles). Les 768 poses finales sont importées et vérifiées, avec leurs huit techniques, le runtime visuel et la progression des salles. Les probes graphiques réussissent **385 contrôles à chacune des deux résolutions**, avec 56 captures au total. Leur lanceur conserve toutefois un verdict **FAIL** à cause de la rétention terrain déjà observée en v1 à la fermeture ; elle n'est pas masquée.

## Contrat d'animation et de texture

Chaque personnage dispose de quatre vues sources indépendantes, sans miroir, et de **48 poses par direction**, soit 768 poses pour les quatre familles. Les mouvements sont des articulations locales en 2D à partir de ces peintures. Il ne s'agit pas de 768 nouvelles poses peintes individuellement.

| Action | Indices dans la direction | Poses | Comportement |
| --- | --- | ---: | --- |
| Repos | 0–7 | 8 | Boucle réelle ; phase conservée au changement de direction |
| Marche | 8–19 | 12 | Phase liée à la distance parcourue sur la grille |
| Attaque | 20–27 | 8 | Impact à la pose locale 4, index 24 |
| Sort | 28–35 | 8 | Libération à la pose locale 4, index 32 |
| Coup reçu | 36–39 | 4 | Réaction visuelle dédiée |
| Mort | 40–47 | 8 | Poses complètes avant disparition |

Les marqueurs d'attaque et de sort interviennent à 50 % de la durée avec les poids uniformes exportés. Le runtime prend aussi en charge des durées de frames non uniformes et situe alors le marqueur à la somme exacte des poids précédents. Pause, temps nul, annulation, destruction et appels réentrants conservent les garanties de signal unique. La Fournaise attend toujours la libération puis ses 0,2 seconde de trajet avant les dégâts.

Les cycles de repos sont propres à chaque espèce : Sentinelle 2,4 s, Rejeton 1,25 s, Molosse 1,1 s, Lamie 2,8 s. L'export SpriteFrames et l'aperçu lisent les mêmes profils que le runtime. Les légendes d'aperçu indiquent le rôle et les PM ; les PV dépendent de la salle.

Les régions sont recadrées sans rotation et séparées par une gouttière de deux pixels. Chaque `AtlasTexture.margin` restitue le canevas logique **512 × 384** et l'ancre **(256, 320)**. Les régions conservent tous les canaux RGBA, y compris les pixels transparents contenant une couleur. La pose 0 est identique à la vue source ; le portrait est un PNG compact extrait de la pose E0. Les sémantiques utilisées sont documentées par [Godot AtlasTexture](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html) et vérifiées dans le moteur réel.

## Preuves exécutées

Environnement : Windows, Godot **4.7.1.stable.official.a13da4feb**, GUT **9.7.1**. Les processus utilisent des répertoires `APPDATA` et `LOCALAPPDATA` isolés dans les artefacts ignorés. L'import en mode récupération évite les effets des plugins éditeur. Les suites ciblées ne représentent pas une exécution exhaustive des tests du dépôt.

| Vérification | Résultat | Preuve |
| --- | --- | --- |
| Runtime visuel 21, IA 2, présentation différée 10, conséquences atomiques 7, récupération visuelle 6 | **46/46, 947 assertions, PASS strict**, zéro erreur moteur ou de parsing | [Rapport](../../artifacts/catabase_monsters/checks/runtime48_species_verified/gut-strict-report.json) |
| Progression, placement, statistiques et conservation des sources | **8/8, 1 877 assertions, PASS strict** | [Rapport](../../artifacts/catabase_monsters/checks/progression_v2_final/gut-strict-report.json) |
| Données, combat, IA, routes et pixels des atlas finaux | **9/9, 12 545 assertions, PASS strict**, zéro erreur moteur ou de parsing | [Rapport](../../artifacts/catabase_monsters/checks/monster48_integration_verified/gut-strict-report.json) |
| Assembleur Python : 48 frames, restauration RGBA exacte, source 0, portrait, régions/marges, corruption rejetée, déterminisme et gouttières | **5/5 PASS** | `tools/catabase_monster_sprite_pipeline/test_packing.py`, commande ci-dessous |
| Ensemble Python final, incluant articulation et chevilles | **8/8 PASS**, 6,572 s | `test_*.py`, commande ci-dessous |
| Rendu OpenGL d'un atlas synthétique recadré dans un AnimatedSprite2D | **PASS**, image GPU exactement égale à l'image attendue, processus 0 | [Rapport](../../artifacts/catabase_monsters/atlas_margin_gpu/report.json), [image](../../artifacts/catabase_monsters/atlas_margin_gpu/rendered.png) |
| Atlas artistiques finaux : hashes, source 0, cadences, restauration | **768/768 poses**, 16 directions, erreur RGBA 0 | [Audit](../../artifacts/catabase_monsters/atlas48_audit.json) |
| Contrôles JavaScript de l'aperçu HTML, chemins PNG et géométrie | **96 combinaisons**, 16 PNG, lecture/pause/curseur/direction vérifiés | [Smoke Node VM](../../artifacts/catabase_monsters/html_smoke.json) ; aucun rendu navigateur revendiqué |

Le probe OpenGL place une région opaque 10 × 12 à (219, 286) sur le canevas logique 512 × 384. Les 786 432 octets RGBA exportés correspondent exactement à l'image attendue. Le test natif GUT vérifie séparément que `get_image()` retourne seulement la région recadrée et que la taille logique du sprite reste celle du canevas.

Un premier passage a détecté un résidu flottant à la jonction d'une boucle de repos pondérée. La remise à zéro utilise maintenant la même tolérance que l'échantillonneur ; les 46 tests ont été rejoués après cette correction et après les durées propres à chaque espèce.

## Commandes exécutées

Depuis la racine du dépôt :

```powershell
$monsterGodot = 'C:/Users/p.montebello/AppData/Local/Temp/dungeon-draft-godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe'
./tools/catabase_monster_validation/run_checks.ps1 -GodotPath $monsterGodot -TestPath @('res://test/unit/test_catabase_monster_sprite_runtime.gd','res://test/unit/test_catabase_monster_ai_cooldowns.gd','res://test/unit/test_pending_spell_presentation.gd','res://test/unit/test_combat_atomic_outcomes.gd','res://test/unit/test_spell_visual_recovery.gd') -ExpectedTestCount 46 -SuiteId runtime48_species_verified -ImportEvidenceDirectory artifacts/catabase_monsters/checks/progression_v2_verified

./tools/catabase_monster_validation/run_checks.ps1 -GodotPath $monsterGodot -TestPath @('res://test/unit/test_catabase_monster_progression.gd') -ExpectedTestCount 8 -SuiteId progression_v2_final -ImportEvidenceDirectory artifacts/catabase_monsters/checks/progression_v2_verified

./tools/catabase_monster_validation/run_checks.ps1 -GodotPath $monsterGodot -TestPath @('res://test/unit/test_catabase_monsters_integration.gd') -ExpectedTestCount 9 -SuiteId monster48_integration_verified -ImportEvidenceDirectory artifacts/catabase_monsters/checks/monster48_integration_checked

./tools/catabase_monster_validation/run_checks.ps1 -GodotPath $monsterGodot -Runtime -SuiteId runtime48_1280x720 -Resolution 1280x720
./tools/catabase_monster_validation/run_checks.ps1 -GodotPath $monsterGodot -Runtime -SuiteId runtime48_1920x1080 -Resolution 1920x1080

$env:PYTHONPATH = (Join-Path (Get-Location) 'output/monster-meshy-deps')
& 'C:/Users/p.montebello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -m unittest discover -s tools/catabase_monster_sprite_pipeline -p test_packing.py -v
& 'C:/Users/p.montebello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -m unittest discover -s tools/catabase_monster_sprite_pipeline -p 'test_*.py' -v
& 'C:/Users/p.montebello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/catabase_monster_sprite_pipeline/animate.py --slug all
& 'C:/Users/p.montebello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/catabase_monster_sprite_pipeline/preview.py

$marginOutput = Join-Path (Get-Location) 'artifacts/catabase_monsters/atlas_margin_gpu'
$env:APPDATA = Join-Path $marginOutput 'appdata'
$env:LOCALAPPDATA = $env:APPDATA
& $monsterGodot --path . --rendering-method gl_compatibility --audio-driver Dummy --position '-3000,-3000' --resolution '512x384' --log-file (Join-Path $marginOutput 'engine.log') --script res://tools/catabase_monster_validation/atlas_margin_probe.gd
```

Les suites synthétiques réutilisent les preuves d'un import réel propre. Les atlas finaux ont fait l'objet d'un nouvel import propre dans `monster48_integration_checked` ; la dernière suite réutilise ce même import après la seule correction de sa méthode de comparaison des pixels.

## Export et revue artistique finale

La commande Python `tools/catabase_monster_sprite_pipeline/animate.py --slug all` a terminé avec le code 0. L'audit indépendant restaure les 768 poses avec une erreur RGBA nulle et retrouve exactement les 16 vues sources à l'index 0. Les atlas occupent **200 331 560 octets RGBA**, contre **603 979 776 octets** pour des canevas complets : **66,83 % de réduction** hors copies moteur et autres ressources.

Les planches de contrôle échantillonnent les indices 0, 2, 6, 8, 11, 14, 17, 22, 24, 30, 32, 37, 42, 44 et 46 dans chaque direction, complétées par des vues agrandies d'attaque, de sort et de mort. La revue a vérifié les corrections des fragments de doigts, lance et bâton, les chevilles articulées et leurs appuis, la liaison de l'épaulière et l'effondrement des pattes du Molosse. Une couture de bassin reste perceptible dans les poses de mort extrêmes de la Lamie N/W ; aucune pièce absente ni trou n'a été observé. Cette révision n'utilise aucun nouvel appel de génération distante.

L'[aperçu interactif local](../../output/catabase_monsters_v2/review/animation_review.html) lit directement les atlas finaux, avec les géométries intégrées à la page. Le [GIF](../../output/catabase_monsters/review/monstres_animations.gif) conserve les cadences de chaque espèce. L'aperçu PNG 1024 × 800 a été inspecté pour les cadrages et légendes. Les contrôles du lecteur ont été exercés dans un smoke JavaScript avec DOM et canvas simulés ; aucun navigateur n'était disponible via l'outil de contrôle, donc une vérification de rendu navigateur n'est pas revendiquée.

## Import et comparaison des pixels

Le premier import a détecté un script d'audit déjà présent dans `artifacts/project_audit/2026-09-08/expedition_screen_publication.gd`, déclarant la même classe globale `ExpeditionScreen` que l'UI de production. Un `.gdignore` local dans `artifacts/project_audit/` exclut ces artefacts. L'import suivant est propre ; le script de l'UI de production n'a pas été modifié pour résoudre ce doublon.

Le test raster lit les références avec `Image.load_png_from_buffer(FileAccess.get_file_as_bytes(...))`. La comparaison initiale a également révélé le traitement des franges à l'import : sur Lamie W, alpha inchangé, 7 578 pixels RGBA différents, dont 890 après composition, et un écart RGB composé maximal de 9/8/6. Le défaut Godot `fix_alpha_border` recolore les pixels d'alpha inférieur à 20/255 à partir d'un voisin dans un rayon de quatre pixels ([code moteur](https://raw.githubusercontent.com/godotengine/godot/master/core/io/image.cpp)). Le test applique maintenant exactement `Image.fix_alpha_edges()` à la référence, après recadrage pour les portraits, puis exige l'égalité composée stricte. Aucune tolérance numérique ne remplace la preuve ; l'audit Python confirme séparément la conservation complète des PNG.

## Combat graphique final

Le probe utilise quatre fixtures issues de la route de seed 2401 et la vraie scène `RegisteredTerrainBattle.tscn`, avec déploiement du héros et décisions du vrai `EnemyTurnRunner`. Il vérifie les 24 clips de chaque espèce, observe huit indices de repos au cours de la boucle et capture rencontre, repos, marche, attaque, sort, mort et combat résolu. Les techniques passent par les règles de ciblage, les coûts et les effets de combat réels ; les placements supplémentaires du héros sont explicitement des fixtures légales. La mort utilise `achilles_peleid_strike` après abaissement explicite de la cible à 1 PV.

| Résolution | Contrôles et captures | Résultat processus | Verdict du lanceur |
| --- | --- | --- | --- |
| 1280 × 720 | **385/385**, 4 rencontres, 28 PNG, 8 frames de repos par famille | Godot 0, zéro erreur du probe, aucun `SCRIPT ERROR` | **FAIL** : fermeture terrain 489 instances / 5 ressources |
| 1920 × 1080 | **385/385**, 4 rencontres, 28 PNG, 8 frames de repos par famille | Godot 0, zéro erreur du probe, aucun `SCRIPT ERROR` | **FAIL** : même fermeture terrain |

Rapports : [1280 × 720](../../artifacts/catabase_monsters/1280x720/report.json), [1920 × 1080](../../artifacts/catabase_monsters/1920x1080/report.json). Les journaux et codes de sortie sont conservés dans `artifacts/catabase_monsters/checks/runtime48_1280x720/` et `runtime48_1920x1080/`.

Les statistiques réellement instanciées confirment la progression par salle :

| Rencontre observée | Ennemis et PV | PM |
| --- | --- | --- |
| Le portique des lances | Sentinelle 35 ; Rejeton 19 | 2 ; 3 |
| Les éclaireurs du portique | Molosse 23 ; Rejeton 19 | 5 ; 3 |
| Le gué des serments | Lamie 37 ; Sentinelle 53 | 3 ; 2 |

Captures v2 inspectées : Sentinelle attaque et mort, Rejeton sort, Molosse mort et Lamie sort en 1280 × 720 ; Sentinelle repos, Molosse attaque et Lamie mort en 1920 × 1080. Silhouettes, équipement, portraits, cadrage et ancrage au sol sont présents et cohérents. Les captures d'attaque et de sort visent la pose locale 4 de libération, celles de mort une pose à partir de l'index local 5.

| Vue | 1280 × 720 | 1920 × 1080 |
| --- | --- | --- |
| Sentinelle au repos dans la salle | [Capture](../../artifacts/catabase_monsters/1280x720/sentinelle_airain_idle.png) | [Capture](../../artifacts/catabase_monsters/1920x1080/sentinelle_airain_idle.png) |
| Rejeton pendant sa technique | [Capture](../../artifacts/catabase_monsters/1280x720/rejeton_braise_cast.png) | [Capture](../../artifacts/catabase_monsters/1920x1080/rejeton_braise_cast.png) |
| Molosse en attaque | [Capture](../../artifacts/catabase_monsters/1280x720/molosse_styx_attack.png) | [Capture](../../artifacts/catabase_monsters/1920x1080/molosse_styx_attack.png) |
| Lamie en fin de combat | [Capture](../../artifacts/catabase_monsters/1280x720/lamie_lethe_death.png) | [Capture](../../artifacts/catabase_monsters/1920x1080/lamie_lethe_death.png) |

Ces contrôles ne simulent ni une descente complète gagnée ni l'équilibrage de nombreuses parties. La génération synchrone de PNG pendant les actions ne constitue pas une mesure de fluidité ou de performances. Aucun benchmark multi-machine, Vulkan ou mobile n'a été effectué.

## Limite de fermeture déjà observée

Les deux probes graphiques v2 retrouvent les cinq scripts terrain et 489 instances ObjectDB déjà signalés en v1. Les scripts retenus sont `GridData`, `CellSurfaceState`, `ElectricalTerrainRegionResolver`, `TerrainSurfaceRuntimeService` et `TerrainEffects`. Aucun script de visuel de monstre ni aucune texture n'apparaît dans ces cinq ressources. Les douze références faibles des grilles, façades et services des fixtures sont libérées après les coroutines. Le lanceur strict conserve correctement l'échec global malgré les contrôles de combat réussis. Le diagnostic préalable est décrit dans le [rapport v1](catabase_monsters_validation_v1.md) ; aucune refonte de la gestion du terrain en production n'est incluse.

Les journaux, captures, rapports JSON, scripts de diagnostic et sauvegardes de test restent dans les artefacts ignorés. Aucun commit ni publication n'a été effectué par cette validation.
