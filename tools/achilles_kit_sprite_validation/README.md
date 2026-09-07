# Validation du kit sprite actuel d'Achille

Outil distinct des anciennes validations Achille, Garde et Spectre. Il utilise RegisteredTerrainBattle, le terrain de production, le vrai Achille, trois spectres canoniques, le déploiement natif et le routage GridView. Il ne remplace jamais le personnage ou les VFX par des illustrations de démonstration.

## Lancement

Scène : `res://tools/achilles_kit_sprite_validation/KitSpriteValidation.tscn`.

```powershell
& $godot --path . res://tools/achilles_kit_sprite_validation/KitSpriteValidation.tscn -- --kit=base --direction=E --no-screenshots --artifact-dir=res://artifacts/achilles_kit_sprite_validation_v2/base_E_timing
```

Le chemin par défaut est `res://data/arenas/greek_drawn_courtyard_v1/arena.tres` (Cour des Sources). Ajouter `--room-path=res://data/rooms/odyssey/room_02.tres` pour vérifier Catabase II. La scène enregistrée par la salle est conservée.

Chaque combinaison exige un nouveau processus. Les options sont :

| Option | Valeurs |
| --- | --- |
| `--kit` | `base`, `wrath`, `chiron`, `volley`, `aeacus`, `counter` |
| `--scenario` | `combo`, `shot`, `bastion`, `counter`, `hit_death` ; défaut selon le kit |
| `--direction` | `N`, `E`, `S`, `W` ; défaut E |
| `--artifact-dir` | Dossier dédié à cette combinaison et à cette passe |
| `--no-screenshots` | Mesures sans lecture GPU ni capture |
| `--capture-clip` | Captures du viewport réel à 20 Hz maximum ; ignoré avec `--no-screenshots` |

Rapport : `runtime_validation.json`. Le code de sortie vaut 0 seulement lorsque `errors` est vide. Les mesures de timing et les captures sont deux passes distinctes. Une capture graphique peut ralentir le moteur : elle ne prouve pas la cadence non perturbée.

## Six configurations et sept scénarios minimaux

| Kit | Niveau | Scénario par défaut | Couverture |
| --- | --- | --- | --- |
| base | 1 | combo | Garde 2 PA, Percée 3 cases 1 PA, Frappe 3 PA |
| base | 1 | `--scenario=shot` | Tir normal sur une cible |
| wrath | 10 | combo | Garde, Percée, Fléau de Troie en ligne sur 2 cibles |
| chiron | 10 | shot | Ligne de mort perçante sur 3 cibles |
| volley | 13 | shot | Volée du centaure en éventail sur 3 cibles |
| aeacus | 13 | bastion | Garde orientée, Rempart de 3 cases, Percée et Bastion sur 2 ennemis adjacents |
| counter | 10 | counter | Garde orientée puis vrai tour ennemi, une Frappe de riposte automatique |

Exécuter ces sept cas dans chaque direction pour une matrice complète de 28 combats. Chaque cas commence par une vraie marche d'une case : elle donne l'orientation souhaitée sans assigner `facing_dir`, puis vérifie la stabilité du repos. Percée garde un trajet réel de trois cases. Les adversaires sont identiques afin que le mélange normal des cases de spawn ne modifie pas la géométrie attendue.

## Préparation annoncée dans le rapport

Le harness crée une copie de l'ArenaDefinition en mémoire. Il y définit une empreinte de départ et trois emplacements ennemis légaux, sans changer le terrain. Ces spawns remplacent seulement la rencontre de cette copie ; ce test ne prétend pas rejouer son équilibrage de production. Toutes les scènes, ressources d'unités, règles, statistiques, animations, objets visuels et contrôleurs restent canoniques. Aucun fichier de production n'est enregistré.

Le lanceur appelle ArenaRuntimeBridge, RunHeroResolver et GameManager.start_direct_encounter_test. Avant le démarrage différé du combat, il prépare l'XP via CharacterRunState.award_encounter_xp et les seuils du ChampionProgressionProfile, puis achète chaque maîtrise par GameManager.purchase_champion_mastery. Chaque décision légale figure dans `progression_fixture`. Aucun niveau, point, tableau de maîtrises, modificateur, PV, PA ou PM n'est assigné directement. Cet apport d'XP est une fixture de progression et ne prétend pas provenir d'une campagne jouée.

Chemins d'achat :

- Colère : focused_fury → murderous_momentum → execution → break_formation → scourge_of_troy, préfixe `achilles_wrath_`.
- Chiron : centaur_eye → pelion_reach → stopping_arrow → piercing_arrow → death_line ou centaur_volley, préfixe `achilles_chiron_`.
- Éaque : active_guard → directional_guard → arrow_wall → mobile_bastion → myrmidon_rampart ou counter, préfixe `achilles_aeacus_`.

## Contrôles et limites

Le rapport conserve les familles de clips, poses, marqueurs, terminaisons, PA et usages, PV des cibles et événements de dégâts. Il vérifie une seule émission de release et une seule fin par action normale. Percée autorise l'annulation normale du budget visuel à l'arrivée : pas de fin artificiellement exigée, aucune seconde release. Son UnitView doit réellement se déplacer, rejoindre la cellule logique et garder le clip de charge pendant le trajet. Le repos avant/après vérifie frame 0, absence d'autoplay, ancre et transform immobiles.

Les dégâts doivent survenir au frame moteur du release ou après. Le callback interne Battle peut résoudre les dégâts avant le callback du probe dans la même pile de signal ; ce cas est correctement distingué d'un impact prématuré. Les counts de cibles vérifient Frappe, Fléau, Tir, Ligne, Volée et Bastion. Les informations de profil proviennent du résolveur partagé, jamais du nom affiché du sort.

Garde est recherchée sur le vrai UnitView. Ses phases et son erreur de suivi d'ancre sont enregistrées. Rempart exige trois cellules de barrière. Bastion doit consommer la Garde et toucher deux cibles après le signal synchrone `unit_visual_movement_finished`, avec une erreur de position inférieure à 0,01 pixel. Le rapport conserve `movement_arrival_usec`, chaque événement de PV et les instants de résolution : un dommage antérieur au contact échoue même s’il suit déjà le release. Le contre provient de l'IA après la confirmation normale de fin de tour, sans appel à take_damage ou cast_automatic par le probe ; son fait `spell_visual_resolved` doit être automatique, sans dépense de PA ni usage manuel de Frappe. Les choix de suivi facultatifs sont refusés par leur callback UI normal.

Les effets sont obligatoires. `effect_validation` exige le burst de Garde, deux poussières distinctes de départ/réception, le choc et les deux impacts de Bastion après contact, la flèche en vol avant la perte de PV puis son impact confirmé, l’arc et les deux impacts de Fléau, et un seul impact automatique du Contre. Toute phase vide, absence de vrais Sprite2D texturés ou ressource différente de l’atlas canonique fait échouer le scénario. `effects` conserve l’identité de chaque effet, ses changements de texture, ses cibles, ses positions écran et sa phase. Le rapport du Contre inclut la classification/position/secteur des coups et la télémétrie du déclencheur. Les captures `effect_*` montrent ces sprites dans le vrai viewport et conservent leur état exact ; la compression reste différée. Les dessins et leur lisibilité font ensuite l’objet d’une inspection de ces images, complémentaire aux assertions mécaniques.

Les tests déterministes complémentaires sont `test/unit/test_achilles_kit_sprite_runtime_v2.gd` (six tests) et le test actualisé `test/unit/test_achilles_sprite_advance_timing.gd`. Ils contrôlent les ressources v2, les marqueurs de toutes les familles dans quatre directions, une grosse frame avec annulation réentrante, la charge jusqu'à l'arrivée, le changement d'orientation et les réactions/mort. Les textures canoniques sont requises ; aucune image simulée ne les remplace. `test/unit/test_achilles_kit_reaction_arrival.gd` ajoute sept tests sur la file réelle de Bastion : résolution immédiate hors Battle, réservation sans paiement de Garde avant réception, arrivée du UnitView canonique, coûts uniques, annulations avant/après release, fermeture et mort du lanceur. Les commandes restent réservées pendant le trajet et sont vidées avant la notification de fin d’action et le déverrouillage. Le signal de contact précède le réveil synchrone du UnitView. Une présentation annulée après résolution logique est recalée sur sa case, acquitte cette arrivée sans jouer de réception artificielle, puis règle une seule fois son effet déjà engagé ; fermer le combat détruit sa file sans faux acquittement.

## Captures

Pour la passe visuelle, retirer `--no-screenshots` et ajouter `--capture-clip`. La caméra de production est conservée. Le clip est une région fixe du viewport, calculée avant les actions pour inclure les vrais acteurs. La lecture GPU se fait après frame_post_draw ; l'écriture PNG et la compression sont différées après les actions. Aucun sprite ni frame intermédiaire n'est reconstruit.

```powershell
& 'C:/Program Files/nodejs/node.exe' tools/achilles_kit_sprite_validation/assemble_clip.cjs artifacts/achilles_kit_sprite_validation_v2/base_E_visual/clip/clip_manifest.json
```

L'encodeur écrit `achilles_kit_gameplay.gif`, `poster.png` et `encode_report.json`. Il utilise les timestamps enregistrés, arrondis aux centisecondes du GIF, et refuse un clip tronqué par sa limite de frames. Le GIF peut fusionner plusieurs captures consécutives identiques pendant un repos ou une pose maintenue : leur durée est additionnée, sans prolonger le clip. Le nombre de pages GIF peut donc être inférieur au nombre de captures.

Après encodage, le contrôle décode le GIF, vérifie ses dimensions et exige une durée totale exactement égale à celle de la chronologie source arrondie au centième de seconde. Chaque changement d'image doit tomber sur un timestamp source. Pour chacun des intervalles capturés, l'image GIF doit correspondre à la capture attendue dans l'ordre : une comparaison RGB réduite à 96 pixels de largeur cherche la capture la plus proche parmi toutes les images source, afin de tolérer la palette GIF sans confondre les poses. Les images source identiques peuvent être ex æquo. Le rapport conserve le nombre de captures, le nombre de pages encodées, les états visuels distincts, les correspondances temporelles et l'erreur de palette mesurée. La différence avec la durée source non arrondie reste celle du centième de seconde, et aucun ralenti artificiel n'est ajouté. Les anciens outils restent inchangés.

## Réactions et mort par combat réel

Ajouter `--kit=base --scenario=hit_death --direction=E` pour le cas complémentaire. Sa copie de rencontre place trois spectres canoniques adjacents au point de marche initial. Achille se déploie, marche normalement, lance Garde une fois, puis confirme la fin de ses tours jusqu'à sa défaite. Aucun appel direct à take_damage, aucun dégât injecté et aucune modification de PV/PA/PM n'intervient.

Le rapport `real_hit_and_death` exige au moins une réaction hit non létale terminée au repos, des pertes de PV correspondant aux événements d'attaques ennemies, un seul événement de mort, le clip death, une seule fin visuelle après fondu, l'absence de faux markers d'attaque et une ancre fixe. La fin du scénario conserve la dernière observation avant destruction normale du UnitView ; aucun retour idle n'est exigé après la mort. Les captures `real_hit_*` et `real_death_*` montrent les réactions au sein de la vraie carte. La direction finale peut être celle de l'agresseur, choisie normalement par le combat.

Ce scénario est réservé au kit de base niveau 1 pour rester court et reproductible. Il complète la matrice des sept scénarios de sorts ; la comparaison de cadence exige toujours une passe `--no-screenshots` indépendante de la capture visuelle.

## Matrice automatique et erreurs de moteur

`run_matrix.ps1` lance les sept scénarios dans N/E/S/W, un processus Godot à la fois. Exemple :

```powershell
./tools/achilles_kit_sprite_validation/run_matrix.ps1 -Directions @('E','N','S','W') -Batch 'matrix_validated'
```

`-Capture` ajoute les captures du viewport ; `-IncludeDefeat` ajoute le scénario de réaction/mort dans chaque direction demandée. `-Godot` permet de choisir le binaire. Chaque processus possède son dossier et un délai limite de 120 secondes. Le lanceur arrête au premier échec et écrit un `summary.json` progressif.

La réussite exige un code de sortie nul, un rapport runtime valide et aucune erreur de script/moteur dans stdout ou stderr. Seules les lignes déjà identifiées de ressources/RID encore alloués à la fermeture sont distinguées des erreurs d'exécution ; elles restent conservées intégralement dans les journaux. Une assertion de dégâts réussie ne masque donc plus un effet dont le script a échoué au démarrage.