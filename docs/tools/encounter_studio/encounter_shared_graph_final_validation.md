# Rencontre — graphe partagé et baseline intégrée

2026-08-28 — **WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION**.

## Périmètre et préservation

**PROUVÉ** — Travail séquentiel, sans sous-agent, sur le worktree de `main`,
base `b642e90`. Aucun commit, aucune refonte graphique, aucune modification de
donnée de production. Les six fichiers déjà modifiés hors de ce chantier sont
identiques octet pour octet à leur état initial. Les 383 fichiers de `data/`
contrôlés ont conservé leur SHA-256.

**PROUVÉ** — Dans Rencontre, les fonctions préexistantes de comptage local du
brouillon, confirmation, duplication, navigation documentaire, sauvegarde du
brouillon et génération d'aperçu sont conservées. Le branchement du graphe
ajoute son nettoyage à `PREDELETE`, sans réintroduire de nettoyage au détachement.
Preuves : `artifacts/encounter_shared_graph/preservation.json`,
`data_preservation.json`, `protected_ui_functions.json` et
`changed_existing_ui_functions.json`.

## Fichiers, dans l'ordre de première modification

**PROUVÉ** — Les retouches suivantes ont également été faites un fichier à la fois.

1. `addons/dungeon_draft_arena_studio/encounter/services/encounter_reference_graph_service.gd`
2. `addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd`
3. `addons/dungeon_draft_arena_studio/services/studio_reference_graph_service.gd`
4. `test/unit/test_encounter_shared_reference_graph.gd` — nouveau.
5. `test/unit/test_encounter_studio_v1.gd`
6. `addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_baseline.gd` — nouveau.
7. `addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_baseline.tscn` — nouveau.
8. Le présent rapport — nouveau.

Les fichiers `.gd.uid` associés aux deux nouveaux scripts sont des métadonnées Godot.
Les journaux, sauvegardes de référence et captures sont sous
`artifacts/encounter_shared_graph/`, ignoré par Git ; aucune règle d'ignorance
n'a été modifiée.

## Autorité des usages

**PROUVÉ** — `EncounterStudioMain.shared_reference_graph` est exactement
l'instance reçue dans `setup()`. Le champ concurrent `project_graph` est supprimé.
Aucun appel à `build_project_graph()` ne subsiste dans ce panneau : ouvrir une
partie ou un brouillon, sélectionner une vague, rafraîchir la vue, recevoir
`filesystem_changed` ou changer d'onglet ne lance aucun scan des parties.

**PROUVÉ** — `EncounterReferenceGraphService.published_summary()` est un
adaptateur sans chargement de fichier. Il remonte les relations
`encounter_definition`, `waves` et `ROOM_AT` du service partagé. Les occurrences
par index sont conservées ; le lien historique de salle n'est pas un combat
supplémentaire lorsque des vagues existent, même si leur tableau contient une
entrée nulle. Un chemin de sous-ressource `::` n'est plus présenté comme un
fichier externe. L'ancienne API `build_project_graph()` reste disponible pour
compatibilité, mais n'est pas utilisée par le parcours intégré.

**PROUVÉ** — Rencontre écoute début, progression, fin, annulation et invalidation
du scan partagé. Un lot d'invalidations programme un seul appel différé à
`scan(false)` ; si un autre consommateur a déjà actualisé le service, son cache
est réutilisé. La notification de fin rafraîchit les résumés, la chronologie et
la page avancée, sans relancer l'aperçu ni reconstruire le champ en cours de saisie.

**PROUVÉ** — Le service partagé expose un état `ready`, protège le scan contre
la réentrance et publie la progression aussi pour une partie sans héros.
L'annulation à la dernière progression ne valide pas une nouvelle génération.
Le parcours déduplique les Resources par clé canonique, y compris après des
relectures profondes depuis plusieurs racines.

**PROUVÉ** — Une publication peut laisser des objets anciens dans le cache du
catalogue. Les chemins invalidés sont remontés jusqu'aux parties concernées ;
ces seules racines sont relues avec `CACHE_MODE_IGNORE_DEEP` lors des scans.
Le service conserve leurs clés, sans retenir de seconde collection de Resources,
pour qu'un scan ultérieur ne reprenne pas une ancienne version du catalogue.
Un appel servi depuis le cache ne relit aucun fichier. Le scan initial normal
ne force pas la relecture profonde de toutes les parties.

## Publié, copie de travail et brouillon

**PROUVÉ** — Le résumé contient deux objets distincts : `published` et `local`.
L'interface affiche séparément :

| Périmètre | Présentation |
|---|---|
| Projet publié, graphe prêt | Nombre d'affrontements et d'occurrences de salle issus du graphe partagé. |
| Graphe absent, en cours ou annulé | Analyse en cours ou annulée ; jamais un zéro interprété comme une rencontre unique. Une édition canonique nécessitant ce diagnostic est bloquée jusqu'au résultat. |
| Copie canonique ouverte | Nombre d'usages dans la copie de travail, sans les additionner aux usages publiés. |
| Brouillon de salle | Nombre de références locales dans ce brouillon ; badge de partage limité au brouillon. |
| Rencontre nouvellement dupliquée | Zéro usage publié lorsque le graphe est prêt, avec ses usages locaux séparés. |

**PROUVÉ** — Le comptage local du brouillon préserve son comportement antérieur :
il compte aussi son lien historique `room.encounter_definition`. La capture
brouillon présente donc **11 références locales** pour dix vagues et ce lien,
contre **12 affrontements publiés dans 3 occurrences de salle**. Ces nombres
ne sont ni additionnés ni décrits comme le même périmètre.

**PROUVÉ** — Modifier le partagé, dupliquer pour l'affrontement courant et annuler
conservent leurs effets. La duplication applique ensuite l'action à la nouvelle
rencontre ; le second affrontement reste sur l'ancienne copie. Un brouillon
Terrain ne modifie jamais les rencontres canoniques des autres salles.

**PROUVÉ** — Les deux chemins de publication de Rencontre invalident uniquement
les `saved_paths` retournés après réussite. Un échec, un brouillon confirmé,
une sélection, une édition non publiée ou une prévisualisation n'invalide pas
le graphe canonique.

## Scans et invalidations mesurés

**PROUVÉ** — `test_metrics.json` instrumente le vrai parcours du service ; seule
la découverte des racines est remplacée pour les fixtures sous `user://`.
Les assertions portent sur les résultats, les signaux et les générations.

| Scénario | Scans commencés | Génération finale | Invalidations reçues |
|---|---:|---:|---:|
| Ouvertures répétées, sélection, onglets, aperçu et filesystem | 1 | 1 | 0 |
| Externes, embarquées, liens historiques et plusieurs racines | 3 | 3 | 2 |
| Annulation puis reprise | 2 | 1 | 0 |
| Salle + partie invalidées ensemble, puis unité sans changement d'usage | 3 | 3 | 3 |
| Brouillon et duplication | 1 | 1 | 0 |
| Choix d'édition canonique partagée | 1 | 1 | 0 |
| Publication, puis brouillon et publication refusée | 2 | 2 | 2 |
| Reconnexion du service reçu par setup | 1 | 1 | 1 |

**PROUVÉ** — Dans le test de reconnexion, une invalidation supplémentaire sur
l'ancien service détaché ne lance aucun scan. Dans le test d'invalidation, le
résumé passe de 2 à 3 usages après relecture du fichier ; l'invalidation suivante
de l'unité laisse le résultat à 3. Les deux chemins publiés de la fixture sont
la salle et sa partie, regroupés en un seul scan différé.

## Suites et anciens échecs

**PROUVÉ** — Godot 4.7 stable, GUT 9.7.1. Suites ciblées uniquement, en headless ;
aucune exécution de la totalité des tests du projet.

| Suite / filtre | Résultat | Assertions | Journal dans le dossier d'artefacts |
|---|---:|---:|---|
| `test_encounter_studio_v1.gd` | 17/17 | 200 | `v1_release.log` |
| `test_encounter_shared_reference_graph.gd` | 8/8 | 141 | `graph_release.log` |
| `test_encounter_document_safety.gd` | 20/20 | 711 | `document_safety_release.log` |
| `test_room_draft_encounters.gd`, filtre `shared` | 3/3 | 41 | `shared_draft_release.log` |
| `test_dungeon_draft_studio_v121.gd`, filtre `twenty_detach` | 1/1, 20 cycles | 329 | `detach_release.log` |

**PROUVÉ** — Total : **49/49 tests, 1 422 assertions**. Le mode headless de la
suite documentaire saute ses captures selon sa condition existante ; ses
711 assertions ne sont donc pas le même décompte que les 721 de son ancienne
passe graphique. Les captures de ce chantier sont assurées par le runner intégré.

**PROUVÉ** — Import/compilation globale exécuté avec
`--headless --path . --editor --import --quit` : **code de sortie 0**, scan des
fichiers, enregistrement des classes et chargement de l'éditeur terminés.
Aucune erreur de script, de parsing ou de compilation dans `import_release.log`.
La fermeture signale toutefois 862 instances ObjectDB et 23 Resources encore
utilisées, ainsi que des RID : ce résultat n'est pas un journal sans diagnostic.
`git diff --check` ne signale aucune erreur de whitespace.

**PROUVÉ** — Les huit journaux finaux ont été contrôlés dans `log_audit.json` :
aucun `[Failed]`, `SCRIPT ERROR`, `Parse Error`, `Compile Error`,
`placeholder instance` ni diagnostic de handlers incomplets. Les messages de
fuites restent présents. Les processus Godot lancés pour cette validation sont
terminés ; le processus qui existait avant le chantier n'a pas été arrêté.

### Reproduction des contrôles

**PROUVÉ** — Exécutable utilisé :
`C:\Users\jerem\OneDrive\Bureau\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`.
`APPDATA` est isolé sous `artifacts/encounter_shared_graph/appdata` pour GUT,
et sous `capture_appdata` pour les captures et l'import final.

```text
--headless --path . --script addons/gut/gut_cmdln.gd -gconfig=
  -gtest=res://test/unit/<suite>.gd -gexit

Filtres des deux suites partielles :
  -gunit_test_name=shared
  -gunit_test_name=twenty_detach

--path . --rendering-method gl_compatibility
  res://addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_baseline.tscn
  -- --width=1280 --height=720

Puis le même runner avec --width=1920 --height=1080.
```

**RAPPORTÉ** — Les trois anciens échecs sont identifiés dans
`artifacts/room_draft_v1/baseline_worktree.log`.
**PROUVÉ** — Ils ont tous été reproduits dans `v1_before.log`, avec un quatrième
échec lié au contrat de contexte du panneau autonome : première passe **13/17**.

| Test | Cause vérifiée et correction | Statut |
|---|---|---|
| Sauvegarde enfants/parents/récupération | La fixture copiait une carte de production devenue incompatible avec ses exclusions de cases. Fixture dédiée avec grille valide, exclusion réelle et unité externe ; validation intégrale avant usage. Les destinations sont uniques pour ne pas heurter un résultat de passe précédente. La récupération est désormais explicitement confirmée avant de tester le refus d'un chemin dangereux. | Passe. |
| Pont de test direct | La même incohérence de données provoquait `validation_failed` avant d'atteindre l'API de lancement. Utilise la fixture dédiée valide ; conserve toutes les assertions sur la copie temporaire et l'absence de mutation de sa source. | Passe. |
| Relecture finale des changements externes | La transaction n'atteignait pas sa relecture, car la fixture échouait auparavant à la validation. La fixture valide permet de vérifier réellement le préchargement du cache puis la nouvelle valeur sur disque et dans la session. | Passe. |
| Undo/Redo et formations — quatrième échec actuel | Le panneau était créé sans `StudioProjectContext`, alors que les transitions documentaires l'exigent. Le test fournit le contexte et le service partagé via `setup()`. | Passe. |

**PROUVÉ** — Aucun validateur n'a été modifié ; aucun échec n'a été transformé
en avertissement. Le défaut des données de production reste visible dans le
smoke : rendre les fixtures de transaction cohérentes ne rend pas ces données valides.

## Smoke et captures intégrées

**PROUVÉ** — Le runner utilise le vrai `StudioWorkspace`, son contexte et son
graphe partagés, `EmbeddedStudioHost` et `NativeStudioWindowHost`. Il ouvre
`first_run.tres`, puis `fixed_trio_prototype_run.tres`, passe par Terrain pour
ouvrir le brouillon, sélectionne les affrontements, parcourt
Terrain → Rencontre → Objets → Rencontre, détache et réintègre le même workspace.
Il crée enfin un premier affrontement sur la variante vide du brouillon.

**PROUVÉ** — Chaque résolution valide **247 contrôles**, avec **1 scan,
génération 1 et 0 invalidation** sur tout le smoke. Les scènes avec rencontre
affichent quatre placements numérotés ; la scène vide conserve le terrain.
Les usages restent stables après navigation et changement d'hôte. Aucun dialogue
résiduel, aucune transition invisible en attente, aucun `placeholder instance`
ni « Domaine modifiable sans handlers complets » dans les passes retenues.

**PROUVÉ** — Durée du scan initial dans les dernières passes : **191,067 ms**
en 1280 × 720 et **188,743 ms** en 1920 × 1080. Les rapports complets sont
`smoke_1280x720.json` et `smoke_1920x1080.json` ; les journaux de rendu sont
`capture_1280_release.log` et `capture_1920_release.log`.

**PROUVÉ** — Captures réelles OpenGL Compatibility / RTX 4060 Laptop, dimensions
du framebuffer contrôlées, toutes inspectées visuellement :

| Vue | 1280 × 720 | 1920 × 1080 |
|---|---|---|
| Canonique, partie principale | [Image](../../../artifacts/encounter_shared_graph/canonical_1280x720.png) | [Image](../../../artifacts/encounter_shared_graph/canonical_1920x1080.png) |
| Rencontre partagée, partie à vagues | [Image](../../../artifacts/encounter_shared_graph/shared_1280x720.png) | [Image](../../../artifacts/encounter_shared_graph/shared_1920x1080.png) |
| Brouillon de salle avec terrain | [Image](../../../artifacts/encounter_shared_graph/room_draft_1280x720.png) | [Image](../../../artifacts/encounter_shared_graph/room_draft_1920x1080.png) |
| Sans premier affrontement | [Image](../../../artifacts/encounter_shared_graph/no_first_encounter_1280x720.png) | [Image](../../../artifacts/encounter_shared_graph/no_first_encounter_1920x1080.png) |

**PROUVÉ** — Les essais en 1920 × 1055, limités par la zone de travail Windows,
ne font pas partie de cette baseline. Le runner applique la taille demandée
après initialisation et vérifie l'image obtenue. Son premier essai avec
`--script` initialisait les dépendances avant les autoloads : seule la scène
`.tscn`, avec autoloads initialisés normalement, est retenue comme preuve.

### Défauts visuels constatés, sans refonte

**PROUVÉ** :

- **1280 × 720** : la colonne Composition déborde à droite ; des flèches de
  champs numériques et les derniers onglets sont coupés. Le bouton « Créer le
  premier affrontement » a un bord droit à **x = 1290**, soit 10 pixels hors
  image ; son texte et sa zone centrale restent accessibles. La création passe
  dans le smoke. Les noms de salles et d'ennemis sont tronqués.
- **1280 × 720, brouillon** : la bannière réduit la hauteur utile ; la zone
  de validation ne montre pratiquement plus que son en-tête, et son bilan est
  sous le bord inférieur. Les actions principales du shell restent visibles.
- **Deux tailles** : les cartes de chronologie sont longues et leur dernière
  carte visible est coupée par le viewport de défilement. Les boutons suivants
  sont hors de ce viewport mais accessibles par défilement horizontal ; les
  coordonnées brutes `outside_buttons` ne signifient donc pas qu'ils sont tous
  définitivement inaccessibles. Le catalogue tronque également les noms longs
  en 1920 × 1080.
- **1920 × 1080, brouillon** : le nom du document dans la barre commune reste
  tronqué (« Brouillon de salle — c… »). La colonne Composition nécessite un
  défilement vertical, mais ses contrôles tiennent dans la largeur disponible.
- **Ambiguïtés conservées** : « Rencontre unique historique » décrit le mode
  de salle alors que la Resource peut être partagée ; le nombre local du
  brouillon inclut son lien historique en plus des vagues. Les périmètres sont
  maintenant affichés, mais ces conventions restent à expliquer dans une future
  amélioration de l'interface.
- **Assombrissement et superpositions** : pas de voile modal global inexpliqué.
  Le rectangle sombre de la légende et le bandeau de l'état vide recouvrent
  volontairement une partie du terrain. Aucun dialogue invisible ne subsiste.

**PROUVÉ** — Diagnostics métier visibles en grand format : partie principale
0 erreur / 6 avertissements ; partie de test 60 erreurs / 40 avertissements ;
brouillon dérivé 60 erreurs / 20 avertissements ; état sans premier affrontement
2 erreurs / 0 avertissement. Les exclusions hors grille de la partie de test
restent inchangées. L'état vide n'est pas publiable tant qu'il manque sa rencontre.

## Limites et statut

**PROUVÉ** — Les suites et les fermetures de rendu signalent encore des
orphelins et des Resources/RID non libérés. Les suites GUT comptent respectivement
14, 98, 14, 42 et 14 orphelins dans l'ordre du tableau. Ces diagnostics ne sont
pas effacés et empêchent toute revendication de fermeture sans fuite.
**À CONFIRMER** — Attribution complète de ces fuites ; elle n'a pas été menée
dans ce chantier.

**PROUVÉ** — Le scan du service reste synchrone et reconstruit son index après
invalidation ; ce chantier ne le transforme pas en indexeur incrémental. Seule
la relecture profonde des racines invalidées est ciblée. Aucun scan n'est ajouté
aux sélections ni aux aperçus. Les mesures initiales retenues sont sous 250 ms
sur cette machine, sans promesse de performance sur un autre catalogue.

**PROUVÉ** — Pas de recette humaine dans l'éditeur avec `EditorUndoRedoManager`,
pas de combat complet lancé, pas de publication d'une salle de production, pas
de suite globale de tests. La validation intégrée concerne le vrai workspace
dans son runner et les deux hôtes existants, pas une maquette ni le panneau seul.
L'accessibilité visuelle complète à 1280 × 720 n'est pas revendiquée.

**PROUVÉ** — Aucun statut CURRENT, aucune disponibilité en production et aucune
absence générale de régression ne sont revendiqués.
