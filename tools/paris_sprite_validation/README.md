# Paris : validation par de vrais combats

`ParisCombatValidation.tscn` lance le terrain enregistré du Jugement silencieux comme champ de test isolé avec le même `UnitData`, les mêmes sorts, la même IA et le même catalogue de classifications que Catabase. Le runner copie l’arène en mémoire, déclare les placements et l’orientation avant le combat, puis utilise le déploiement normal, les clics du `GridView` et la confirmation de Fin du tour. Il ne modifie jamais les PV, PA, PM, statuts, cooldowns, positions ou horloges d’animation pendant le combat. Aucun sort ennemi n’est imposé.

Le héros reçoit avant le lancement les points d’expérience d’un niveau 3 pour les volées, ou d’un niveau 6 pour les deux scénarios de métamorphose. Au niveau 6, ses vrais Tir du Pélion et Frappe du Péléide infligent respectivement 24 et 26 dégâts sans achat de maîtrise ni allocation de points. Le probe cesse de blesser Paris dès son passage démoniaque et attend une décision offensive réelle de son nouveau kit. Le scénario de défaite reprend ensuite les attaques ordinaires jusqu’au décès. Ce montage vérifie le combat ; il ne prétend pas avoir joué les salles précédentes de campagne.

| Scénario | Situation de départ | Preuve attendue |
| --- | --- | --- |
| `spectral` | Distance 7, hors portée élémentaire | Flèche spectrale et vrai impact après le release |
| `ice` | Distance 4 | Flèche de glace, statut Gelé et surface de glace réelle |
| `fire` | Distance 4 | Flèche de feu, Brûlure et réaction réelle : la glace précédente fond en eau |
| `vortex` | Distance 4, lave sur la case d’attraction | Choix du vortex et déplacement réel d’Achille sur le danger |
| `teleport` | Distance 2 | Pas du vortex décidé par l’IA, vrai changement de case et vue à destination |
| `approach` | Distance 9 | Déplacement volontaire, PM payés et flèche après l’approche |
| `transform` | Paris indemne, Achille niveau 6 | Blessures réelles, seuil strictement inférieur à 20 %, animation une fois, atlas démoniaque et fouet effectif |
| `defeat` | Même duel complet | Métamorphose, action démoniaque, coups réels, décès et nettoyage de la vue une fois |

Chaque scénario accepte `N`, `E`, `S`, `W`. Les fixtures de lane sont validées sur la topologie de production ; seule la lave nécessaire au cas `vortex` est ajoutée par le service d’édition canonique avant le combat. Les cadres, racines, pieds, événements de release/résolution/fin, budgets de PA/PM, surfaces et déplacements sont observés directement.

```powershell
./tools/paris_sprite_validation/run_matrix.ps1 -Batch matrix_final
./tools/paris_sprite_validation/run_matrix.ps1 -Batch transform_capture -Scenarios transform -Directions E -Capture
```

Le script lance un seul Godot à la fois, avec fenêtre masquée, conserve stdout/stderr et demande un code de sortie 0, un rapport `ok` et aucune erreur runtime. Il distingue les diagnostics de ressources déjà connus lors de la fermeture du moteur, conservés dans les logs. Un timeout arrête uniquement le processus enfant du cas concerné.

Les mesures de cadence et les captures sont séparées : le readback GPU peut modifier la cadence. Les PNG du viewport conservent leurs timestamps. Les longs duels conservent les 360 dernières captures, avec le nombre d’images antérieures omises déclaré. Le cadrage reste fixe. L’encodeur contrôle ordre et durée sans inventer d’images intermédiaires :

```powershell
node tools/paris_sprite_validation/assemble_clip.cjs artifacts/paris_sprite_validation_v1/transform_capture/transform_E/clip/clip_manifest.json docs/design/paris/media/paris_transform_v1.gif
```

Paris est accessible dans le jeu normal via **Catabase → salle V, Le Temple du Serment Noir**, comme boss final accompagné de deux spectres. Il ne figure plus dans les salles précédentes. Le test `test_paris_production_access.gd` vérifie ce raccord depuis le catalogue du menu, les références canoniques de la salle et de l’arène, le portrait et l’absence de mutation des données source par les fixtures. Les rapports sous `artifacts/` sont des preuves locales ; aucun résultat n’est affirmé dans cette documentation avant exécution.

La fiche d’inspection de Paris annonce le seuil et le kit démoniaque dès la forme spectrale. Une fiche verrouillée est rafraîchie à son véritable événement de changement de forme. Le catalogue de Catabase réunit les entrées canoniques de Paris et du mage ; les flèches conservent ainsi les blocages propres aux projectiles et Achille garde ses classifications.

Le personnage utilise 72 dessins issus de cinq feuilles : deux angles maîtres E/N par forme et huit poses de métamorphose. S et W utilisent le miroir horizontal du moteur à partir des textures E et N. La matrice de combat vérifie bien les quatre orientations jouées ; elle ne prétend pas utiliser quatre angles dessinés indépendants. Les 52 clips et leur provenance sont décrits dans le pipeline de production.

## Vérification séparée de la salle finale réelle

Le runner FinalBossProductionValidation.tscn charge la ressource canonique de la salle 5, son terrain Black Oath Temple, ses obstacles, ses zones de déploiement, son planificateur et son roster Paris + deux spectres. Ces données ne sont pas copiées puis modifiées. Une run mémoire démarre directement sur cette dernière salle et prépare légalement Achille au niveau 6 avant le combat. Le probe déploie le héros, avance par un vrai clic de déplacement, passe le tour et exige une activation offensive réelle de Paris avec ses sprites et effets. Il ne retouche aucun PV, PA, PM, cooldown, statut ou placement pendant le combat. Il ne simule ni ne prétend avoir joué les quatre premières salles.

```powershell
./tools/paris_sprite_validation/run_final_boss.ps1 -Batch final_boss_production
./tools/paris_sprite_validation/run_final_boss.ps1 -Batch final_boss_capture -Capture
node tools/paris_sprite_validation/summarize_validation.cjs matrix_final final_boss_production
```

Le résumé exige la matrice complète de 32 combats **et** la preuve distincte de la salle finale, toutes deux sans capture pour les mesures de cadence. Il refuse une preuve absente, partielle, limitée aux captures ou comportant une erreur. Les images proviennent du second lancement consacré aux captures.

La matrice de 32 scénarios reste sur le champ de test isolé, dont les couloirs permettent quatre orientations reproductibles. Elle complète la preuve d’intégration de la véritable salle finale, sans la remplacer.

Avant chaque mesure de repos, le harnais observe la stabilisation réelle de la caméra et du canvas pendant au moins 300 ms, avec une limite de cinq secondes. Cette attente ne déplace pas la caméra et ne règle aucune horloge. Les poses et les transforms locales et monde du personnage restent surveillées pendant l’attente. La mesure de repos héritée conserve ensuite ses 650 ms d’observation et sa tolérance de 0,01 pixel ; son rapport inclut les transitions de canvas précédentes. Une caméra qui ne se stabilise pas ou un personnage qui dérive fait échouer le cas.

Une matrice interrompue doit être relancée entièrement dans son batch après correction du code ou des ressources. Les anciens rapports ne contiennent pas d’empreinte complète des fichiers effectivement exécutés ; le runner ne les transforme donc pas en résultats certifiés d’une nouvelle version par une reprise implicite.