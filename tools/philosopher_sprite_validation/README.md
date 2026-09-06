# Mage philosophe : validation en combat

Le runner charge la Cour des Sources par `RegisteredTerrainBattle`, avec les vrais visuels, sorts, règles de ciblage et IA. La copie mémoire de la salle change uniquement les placements initiaux et la direction du mage ; elle n'est jamais enregistrée. Pour les deux scénarios avec allié, une `EncounterDefinition` mémoire utilise le planificateur canonique avec distances de rôles (mage à quatre cases, spectre à deux) et cases initiales restreintes : le mélange aléatoire des cases de la salle ne peut pas échanger le soigneur et son patient. Ces contraintes ne bloquent aucun déplacement pendant le combat. Le probe déploie Achilles par le chemin normal, clique les cases de terrain et passe son tour par les callbacks de l'interface.

Toutes les décisions du mage appartiennent à `EnemyAI`. Aucun sort ennemi n'est forcé. Les scénarios de soin préparent légalement Achilles au niveau 2 avant le combat : 22 de Prouesse donnent 11 + 12 dégâts, ce qui dépasse le seuil de soin du mage sans retoucher les PV. Les soins sont précédés d'une véritable blessure : Achilles tire, marche vers la cible puis utilise Frappe du Péléide, avec ses PA et PM normaux. Il ne modifie jamais les PV, PA, PM, statuts, occupations ou horloges d'animation en cours de combat. Le scénario `defeat` prépare légalement un Achilles de niveau 10 avant le lancement, sans maîtrise, pour obtenir un coup réel puis une frappe mortelle ; ce n'est pas une validation de parcours de campagne.

## Scénarios

| Scénario | Situation initiale | Preuve attendue |
| --- | --- | --- |
| `attack` | Adversaire à cinq cases | Axiome choisi par l'IA et dégâts après le release |
| `control` | Adversaire à quatre cases | Aporie, puis PM effectivement réduits à l'activation d'Achilles |
| `shield` | Spectre allié à proximité d'Achilles | Égide réellement accordée à l'allié menacé |
| `heal_self` | Mage blessé par Tir et Frappe | PV réellement rendus au mage, animation de coup reçu |
| `heal_ally` | Spectre blessé par Tir et Frappe | PV réellement rendus à l'allié |
| `approach` | Mage à sept cases | Marche réelle avec dépense de PM, puis Axiome |
| `repel` | Achilles adjacent | Réfutation et déplacement réel d'Achilles |
| `defeat` | Duel avec Achilles niveau 10 | Coups réels, une mort, une fin d'animation et suppression de la vue |

Chaque scénario accepte les quatre orientations `N`, `E`, `S`, `W`. Le contrôle vérifie l'animation de repos demandée, le pivot des pieds, la position après déplacement, les événements de release/résolution/fin exactement une fois et la dépense de PA/PM. Les captures sont séparées des runs de timing parce que le readback GPU peut perturber la cadence.

```powershell
./tools/philosopher_sprite_validation/run_matrix.ps1 -Batch matrix_validated
./tools/philosopher_sprite_validation/run_matrix.ps1 -Batch heal_visual -Scenarios heal_ally -Directions E -Capture
```

Le runner lance un seul Godot à la fois, masque sa fenêtre, conserve stdout/stderr et exige un rapport `ok`, un exit code 0 et aucune erreur runtime. Les diagnostics déjà connus de ressources/RID à la fermeture sont conservés dans les logs et distingués des erreurs de script. Un timeout tue exclusivement le processus enfant du scénario en cours.

Le long scénario de défaite conserve au maximum les 240 dernières captures, avec le nombre de captures antérieures omises déclaré dans le manifest. Les autres scénarios conservent la séquence complète. Les PNG viennent de la vraie fenêtre de combat et sont compressés après l'action. `clip/clip_manifest.json` conserve chaque timestamp. L'encodeur dérivé du validateur Achilles peut les assembler et vérifier l'ordre des images et les durées sans inventer d'intervalles :

```powershell
node tools/philosopher_sprite_validation/assemble_clip.cjs artifacts/philosopher_sprite_validation_v1/heal_visual/heal_ally_E/clip/clip_manifest.json docs/design/philosopher_mage/media/heal_ally.gif
```

Les rapports sous `artifacts/` sont locaux. Un rapport final compact et les médias retenus peuvent être conservés sous `docs/design/philosopher_mage/` après exécution réelle ; cette documentation n'affirme aucun résultat avant ces runs.

## Dalles et nouveau parcours de production

Le harness indépendant `TerrainCombatValidation.tscn` complète les 32 cas d'animation par 24 combats sur la Cour des Sources, la Porte des Cendres, le Parvis du Jugement, le Gué du Léthé et le Temple du Serment Noir. Le [contrat détaillé](TERRAIN_VALIDATION.md) décrit les fixtures de sol précombat, les règles exactes et les preuves observées. `run_terrain_matrix.ps1 -Batch terrain_final -IncludeCourtyardExtras` exécute cette matrice ; `run_matrix.ps1 -Batch matrix_post_terrain` relance ensuite les 32 cas après l'extension d'IA.

`trial_entry_probe.tscn` suit séparément la sélection de L'Épreuve du Dialecticien, Incarner Achille, Continuer et le déploiement normal. Il exige le héros niveau 1, la RunData publiée, la salle autonome du Léthé, ses huit dalles enregistrées, la paire de vortex, les trois unités en sprites et le profil de taille du mage. Il demande ensuite un vrai Fin du tour et observe la première activation : marche volontaire, sortie réelle du portail, dépenses de PA/PM et sort visible après fermeture du bandeau. Il ne modifie aucune ressource et n'utilise aucune option de lancement de test direct. La régénération de cette salle est décrite dans [le builder Léthé](../philosopher_sprite_pipeline/README_trial_terrain.md).

Le rapport final `summarize_validation.cjs` attend `matrix_post_terrain`, `terrain_final`, `gut_final`, les journaux Node réels et `trial_entry_terrain_final`. Les captures choisies sont contrôlées contre leurs manifests et rapports d'encodage avant référencement. Le bandeau de tour est attendu réellement par le runner ennemi ; son affichage ne doit pas masquer le début d'un sort. Les données d'une ancienne exécution ne peuvent pas remplacer silencieusement une preuve finale manquante.