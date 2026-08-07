# Contrat vérifié — intégration d’une salle dans une run

Date de l’audit : 7 août 2026  
Baseline : `main` — `29f307b5ff61822f266bbd2d14636ca8dcea2d95`  
Godot : `4.7.1.stable.official.a13da4feb` — GUT : `9.7.1`

## 1. Comportement actuel de Produire

`ArenaProductionService` valide la working copy, vérifie l’assemblage visuel,
crée un bundle sous `res://data/arenas/produced`, recharge `arena.tres`, exporte
les previews et le kit artistique, puis écrit un manifeste avec fingerprints.
Les fichiers déjà possédés par un manifeste compatible reçoivent un point de
récupération avant modification. Un fichier manuel non possédé bloque la
production.

La production ne choisit pas à elle seule la place de la salle dans une run.
Cette opération est déléguée ensuite au service d’attachement.

## 2. Comportement actuel du service d’attachement

`ArenaProductionAttachmentService` expose `NONE`, `APPEND`, `INSERT_BEFORE`,
`INSERT_AFTER`, `REPLACE` et `UPDATE`. Il recharge l’arène produite et la
RunData avec `CACHE_MODE_IGNORE_DEEP`, ouvre une `ArenaRunAuthoringService`,
modifie `RunData.rooms`, sauvegarde une copie de récupération de la run, écrit
la run, la recharge et vérifie l’index exact.

### Divergence confirmée

Avant cette mission, `REPLACE` et `UPDATE` appellent la même opération :
`replace_room(index, produced)`. Les deux noms recouvrent donc le remplacement
de la référence complète. `ArenaRunAuthoringService.update_room()` délègue lui
aussi à `replace_room()`.

## 3. Rôle exact de « Réintégrer »

Les signaux `detach_requested` et `reintegrate_requested` déplacent l’unique
instance de `StudioWorkspace` entre `EmbeddedStudioHost` et
`NativeStudioWindowHost`. Ils ne sauvegardent aucune Resource et ne modifient
aucune run. Le terme concerne exclusivement la fenêtre du Studio.

Le contrat final réserve donc les libellés « Détacher la fenêtre » et
« Réintégrer la fenêtre » à ce déplacement. L’intégration de contenu utilise
une action distincte : « Intégrer à la run ».

## 4. Données sauvegardées avant correction

La phase Produire écrit notamment :

- `arena.tres` et, le cas échéant, `modular_visual_profile.tres` ;
- previews Logique, Art et Jeu ;
- kit artistique et masques ;
- rapport de validation, configuration de test et manifeste.

La phase d’attachement écrit uniquement la `RunData` cible après avoir modifié
sa séquence `rooms`. Elle ne supprime jamais l’ancien fichier de salle.

## 5. Transaction globale

Avant correction, il n’existe pas de transaction globale couvrant le bundle de
production et la référence de run. Chaque phase possède sa vérification et ses
recovery, mais une production réussie reste sur disque si l’attachement échoue.
La RunData demeure alors inchangée.

Le workflow retenu traite le bundle produit et vérifié comme une phase de
préparation immuable. La transaction canonique commence ensuite : sauvegarde
des fichiers qui seront réellement intégrés, écriture, rechargement, contrôle
des invariants, rollback sur échec et journal de résultat. Un bundle préparé
peut rester disponible sans être référencé ; il ne corrompt pas une run.

## 6. Distinction UPDATE / REPLACE retenue

### UPDATE — recommandé

- conserve l’index et l’identité de la salle ;
- conserve `EncounterDefinition`, vagues, ennemis, récompenses, multiplicateurs
  et contraintes gameplay ;
- copie uniquement les champs possédés par l’arène ;
- conserve normalement le chemin canonique de la salle ;
- ne réécrit pas `RunData.rooms` lorsque la salle est unique à cette run ;
- applique automatiquement une copie spécifique à la run si la salle est
  partagée, afin de ne pas modifier les autres runs.

### REPLACE — avancé

- remplace explicitement la référence `RoomData` à l’index ;
- fait pointer la RunData vers la nouvelle `ArenaDefinition` ;
- laisse l’ancien fichier sur disque ;
- montre les données gameplay abandonnées et bloque si la run finale devient
  invalide.

### INSERT / APPEND

Ajoutent une nouvelle référence à l’index calculé ou à la fin. L’ordre exact et
la validité finale de la run sont vérifiés après rechargement.

## 7. Risques de perte de données de rencontre

`ArenaDefinition.to_snapshot()` sérialise l’arène et le chemin de
`encounter_definition`, mais pas `waves`, les récompenses de salle, les plages
de vagues ni `enemies`. Construire une arène produite depuis ce snapshot puis
remplacer une salle complète peut donc perdre ces données, particulièrement
dans la run de test `WAVE_CHAIN`.

La politique finale classe explicitement chaque propriété stockée. UPDATE
reprend les champs gameplay depuis la salle cible canonique, jamais depuis la
working copy Arena.

## 8. Ressources partagées

`StudioReferenceGraphService` indexe les usages et sait déterminer si une salle
est atteinte depuis plusieurs runs. Avant correction, cette information est
affichée mais n’influence pas l’attachement.

Le contrat final interdit la modification en place d’une salle partagée pour
une destination « spécifique à la run ». UPDATE crée alors une ressource
intégrée propre à la run, remplace uniquement la référence de cette run et
conserve le fichier partagé intact.

## 9. Workflow cible retenu

1. Choisir la run, l’action et la salle dans le panneau permanent
   **Destination de la salle**.
2. Construire l’arène et son art sans modifier les fichiers canoniques.
3. Valider et tester la même working copy.
4. Lire le plan : chemins, partage, index avant/après et fichiers affectés.
5. Cliquer **Intégrer à la run** ou **Produire sans intégrer**.
6. Produire et recharger le bundle vérifié.
7. Appliquer la transaction d’intégration selon la politique de champs.
8. Recharger la RunData, vérifier l’index et les invariants gameplay.
9. Sélectionner immédiatement la salle intégrée dans le contexte Studio.

La run principale conserve `SINGLE_ENCOUNTER` et l’absence de vagues. La run de
test conserve `WAVE_CHAIN` et ses vagues. Aucun test n’écrit dans les Resources
de production officielles.
