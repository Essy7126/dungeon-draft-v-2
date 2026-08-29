# G1 — Un seul Studio Rencontre

28 août 2026 — **WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION**.

## Résultat et périmètre

**PROUVÉ** — Rencontre n'a plus de propriété `guided`, de méthode `set_guided()`
ni de condition métier dépendant de cet état. Le shell masque son interrupteur
dans Rencontre et continue de transmettre ses changements à Terrain et Objets.
Leur implémentation et leurs préférences persistantes sont conservées.

**PROUVÉ** — La disposition générale, le catalogue, le rendu de carte, les
couleurs et les animations ne sont pas refondus. Le diagnostic local est un
simple `AcceptDialog` de consultation ; aucun nouveau tiroir de diagnostics ni
éditeur concurrent n'est créé. Les noms du catalogue sont seulement traduits
pour ne plus présenter les identifiants de faction et de rôle.

## Fichiers, dans l'ordre de première modification

**PROUVÉ** — Travail séquentiel, un fichier à la fois, sans sous-agent.

1. `addons/dungeon_draft_arena_studio/encounter/ui/encounter_presentation.gd` — nouveau : libellés et présentation des résultats, sans calcul métier.
2. `addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd` — suppression des modes, diagnostic à la demande et branchement de la présentation.
3. `addons/dungeon_draft_arena_studio/ui/dungeon_draft_studio_main.gd` — visibilité de l'interrupteur et retrait de sa transmission à Rencontre.
4. `test/unit/test_encounter_document_safety.gd` — remplacement du seul appel à `set_guided(false)` par l'ouverture de l'onglet technique dans le test des préférences.
5. `test/unit/test_encounter_g1.gd` — nouvelle suite ciblée.
6. `addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g1.gd` — extension du runner intégré.
7. `addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g1.tscn` — scène héritée de `encounter_workspace_baseline.tscn`.
8. Le présent rapport.

**PROUVÉ** — Godot a généré les trois `.gd.uid` des nouveaux scripts. Les
sauvegardes de référence, journaux, rapports de contrôle et images G1 sont sous
`artifacts/encounter_g1/`. Un `.gdignore` exclut ce dossier du scan des scripts.
La scène et le script de baseline antérieurs ne sont pas modifiés.

## Anciennes différences et destination dans l'écran unique

**PROUVÉ** — Comparaison avec la copie du fichier présent au début de G1 :

| Avant G1 | Maintenant |
|---|---|
| `set_guided()` masquait les boutons multi-valeurs en mode guidé. | 10, 100, 1 000 et Annuler sont accessibles dans Analyse, sans prérequis de mode. |
| Le tooltip de validation ajoutait code et chemin en mode avancé. | Explication simple dans tous les cas ; action locale « Afficher les détails techniques » après sélection. |
| L'onglet « Avancé » regroupait déjà les diagnostics, sans fonction d'édition. | Onglet « Détails techniques », annoncé facultatif et destiné au diagnostic. |
| Progression et Analyse exposaient des dictionnaires JSON. | Lignes nommées, formations lisibles, explications des échecs ; JSON conservé dans les diagnostics. |
| Identifiants dans les formations, rôles, factions, capacités et certains statuts. | Noms français ou explications simples ; identifiants et erreurs exactes dans les diagnostics. |

**PROUVÉ** — Les fonctions de composition, placement, création, duplication,
suppression d'un affrontement, validation, correction automatique, rapport,
test, sauvegarde et publication restent dans leurs panneaux ou actions métier.
Les usages publiés et locaux restent consultables dans Composition et dans
les tooltips de chronologie. Aucune fonction métier n'est réservée au diagnostic.

**PROUVÉ** — Composition reste l'onglet initial. Une préférence sauvegardée
pointant vers l'ancien dernier onglet ne réouvre pas automatiquement les
diagnostics. Le bouton local de diagnostic est absent tant qu'aucun message
n'est sélectionné ; il ne concurrence donc pas la création du premier affrontement.

## Informations techniques et validation

**PROUVÉ** — Le panneau technique contient les chemins de partie, salle et
rencontre, les groupes d'apparition, les identifiants des unités de la
composition, leurs factions et rôles, les formations, les capacités désactivées,
la génération du graphe partagé, les usages publiés et locaux exacts, ainsi que
les résultats bruts de progression, analyse, placement, validation et de la
dernière opération signalée.

**PROUVÉ** — La consultation d'un message présente son code stable, le chemin
concerné, les indices de salle et d'affrontement, la cellule et toutes les
métadonnées conservées par `StudioValidationMessage`, dont l'identifiant de
correction et l'explication originale. Pour une copie sans chemin, la source
est recherchée sans navigation documentaire ; un document sans fichier est
explicitement décrit comme une copie en mémoire.

**PROUVÉ** — La sélection et la consultation ne déclenchent pas
`_on_validation_activated()`. Ce gestionnaire garde ses corrections et sa
confirmation de partage. Les tests vérifient une consultation sans changement
de fingerprint, dirty ou historique, puis une vraie correction ajoutant une
action Annuler après confirmation.

**PROUVÉ** — L'avertissement sur les groupes non consommés reste présent dans
la validation : « Ce réglage est conservé dans le fichier, mais il n'est pas
encore utilisé pendant les combats. » Les tooltips de formation décrivent des
préférences de disposition, sans promettre un placement strict.

**PROUVÉ** — Les plans explicites de sauvegarde/publication conservent leurs
listes de fichiers pour permettre une décision éclairée. Ce ne sont pas des
explications techniques ajoutées au parcours principal.

## Préservation

**PROUVÉ** — Le contrôle SHA-256 final porte sur **1 387 fichiers protégés** :
**383 fichiers de `data/` et 1 004 artefacts du chantier précédent**, tous
inchangés. Sur les 16 fichiers déjà modifiés ou non suivis au début, seul
`EncounterStudioMain` reçoit des changements G1. Les quinze autres sont
identiques octet pour octet. Preuve :
[preservation_final.json](../../../artifacts/encounter_g1/preservation_final.json).

**PROUVÉ** — Dans `EncounterStudioMain`, 107 fonctions existantes sont conservées
textuellement. Les changements des autres fonctions portent sur la présentation,
la consultation technique et le retrait des modes. Les fonctions de nettoyage
du cycle de vie, de comptage, de confirmation partagée, de duplication, de
navigation transactionnelle et d'historique restent conservées. Les services
de calcul, de placement, de validation, de sauvegarde et de graphe ne sont pas
modifiés par G1. Relevé :
[function_preservation.json](../../../artifacts/encounter_g1/function_preservation.json).

**PROUVÉ** — Le smoke conserve l'instance unique de `StudioWorkspace`, son
contexte, son graphe et sa session lors de Terrain → Rencontre → Objets →
Rencontre, du détachement et de la réintégration. Les usages publiés viennent
toujours de `StudioReferenceGraphService` ; les références du brouillon sont
comptées séparément. Dans la capture partagée : **12 affrontements publiés dans
3 salles**, contre **10 références dans la copie de travail** ; dans le
brouillon Terrain : **11 références locales**, sans addition au total publié.

**PROUVÉ** — Les trois actions de partage (modifier, dupliquer pour cet
affrontement, annuler) sont vérifiées pour le canonique et le brouillon. Les
quatre décisions documentaires `SAVE`, `DRAFT`, `DISCARD`, `CANCEL` sont également
couvertes. Aucun équilibrage, ennemi, formation, récompense ou donnée de partie
n'est modifié sur disque.

## Tests et compilation

**PROUVÉ** — Résultats des passes retenues :

| Contrôle | Résultat exact | Journal |
|---|---|---|
| Nouvelle suite `test_encounter_g1.gd` | **7/7 tests, 362 assertions**, sortie 0 | [GUT G1](../../../artifacts/encounter_g1/gut_g1_final.log) |
| Test existant `content_fingerprint_undo_redo_and_preferences` | **1/1 test, 22 assertions**, sortie 0 | [Préférences](../../../artifacts/encounter_g1/gut_document_preferences.log) |
| Smoke intégré 1280 × 720 | **602/602 contrôles**, sortie 0 | [Smoke](../../../artifacts/encounter_g1/smoke_1280x720.json), [journal](../../../artifacts/encounter_g1/capture_1280_final.log) |
| Smoke intégré 1920 × 1080 | **602/602 contrôles**, sortie 0 | [Smoke](../../../artifacts/encounter_g1/smoke_1920x1080.json), [journal](../../../artifacts/encounter_g1/capture_1920_final.log) |
| Import/compilation globale | **Sortie 0**, aucune erreur de parsing, compilation ou script | [Import](../../../artifacts/encounter_g1/import_final.log) |
| `git diff --check` | Aucune erreur de whitespace | Commande exécutée après les changements. |

**PROUVÉ** — Chaque smoke réalise **1 scan, génération 1, 0 invalidation**.
Les boutons d'analyse et le nouveau bouton/dialogue de diagnostic sont vérifiés
entièrement dans le framebuffer lorsqu'ils sont ouverts. Les 49 tests du
chantier du graphe partagé ne sont pas relancés ; la suite documentaire est
filtrée sur son unique test modifié.

**PROUVÉ** — Les premiers essais ont révélé une erreur de typage du nouveau
test, une fixture Terrain insuffisante et des dialogues laissés ouverts par
le test ; ces points ont été corrigés avant les passes retenues. Le premier
import était limité par le cache système ; un autre a scanné les sauvegardes
G1 avant ajout du `.gdignore`. Les journaux intermédiaires restent dans le
dossier G1 et ne sont pas présentés comme des validations réussies.

**PROUVÉ** — Les journaux finaux contiennent encore des diagnostics de fuite :
GUT G1 compte 210 orphelins et signale 1 947 instances ObjectDB / 79 Resources à
la fermeture ; le test documentaire signale 11 / 7 ; chaque smoke graphique
712 / 68 ; l'import 862 / 23, avec des RID/textures selon le mode de rendu.
**À CONFIRMER** — Leur attribution complète ; G1 ne mène pas un chantier de
fermeture sans fuite et ne revendique pas l'absence générale de régression.

### Reproduction

**PROUVÉ** — Exécutable utilisé :
`C:\Users\jerem\OneDrive\Bureau\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`.
`APPDATA` et `LOCALAPPDATA` sont isolés sous le dossier d'artefacts G1.

```text
--headless --path . --script addons/gut/gut_cmdln.gd -gconfig=
  -gtest=res://test/unit/test_encounter_g1.gd -gexit

--headless --path . --script addons/gut/gut_cmdln.gd -gconfig=
  -gtest=res://test/unit/test_encounter_document_safety.gd
  -gunit_test_name=content_fingerprint_undo_redo_and_preferences -gexit

--path . --rendering-method gl_compatibility
  res://addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g1.tscn
  -- --width=1280 --height=720

Même scène héritée avec --width=1920 --height=1080.
--headless --path . --editor --import --quit
```

## Captures produites et inspectées

**PROUVÉ** — **22 captures finales**, véritables images du workspace en OpenGL
Compatibility, dimensions contrôlées. Les douze vues demandées :

| Vue | 1280 × 720 | 1920 × 1080 |
|---|---|---|
| Rencontre canonique | [Image](../../../artifacts/encounter_g1/canonical_1280x720.png) | [Image](../../../artifacts/encounter_g1/canonical_1920x1080.png) |
| Rencontre partagée | [Image](../../../artifacts/encounter_g1/shared_1280x720.png) | [Image](../../../artifacts/encounter_g1/shared_1920x1080.png) |
| Brouillon Terrain | [Image](../../../artifacts/encounter_g1/room_draft_1280x720.png) | [Image](../../../artifacts/encounter_g1/room_draft_1920x1080.png) |
| Aucun premier affrontement | [Image](../../../artifacts/encounter_g1/no_first_encounter_1280x720.png) | [Image](../../../artifacts/encounter_g1/no_first_encounter_1920x1080.png) |
| Détails techniques ouverts | [Image](../../../artifacts/encounter_g1/technical_details_1280x720.png) | [Image](../../../artifacts/encounter_g1/technical_details_1920x1080.png) |
| Diagnostic d'un message | [Image](../../../artifacts/encounter_g1/validation_details_1280x720.png) | [Image](../../../artifacts/encounter_g1/validation_details_1920x1080.png) |

**PROUVÉ** — Dix vues complémentaires inspectées :

| Vue | 1280 × 720 | 1920 × 1080 |
|---|---|---|
| Analyse | [Image](../../../artifacts/encounter_g1/analysis_1280x720.png) | [Image](../../../artifacts/encounter_g1/analysis_1920x1080.png) |
| Progression | [Image](../../../artifacts/encounter_g1/progression_1280x720.png) | [Image](../../../artifacts/encounter_g1/progression_1920x1080.png) |
| Placement | [Image](../../../artifacts/encounter_g1/placement_1280x720.png) | [Image](../../../artifacts/encounter_g1/placement_1920x1080.png) |
| Retour dans Terrain | [Image](../../../artifacts/encounter_g1/terrain_toggle_1280x720.png) | [Image](../../../artifacts/encounter_g1/terrain_toggle_1920x1080.png) |
| Retour dans Objets | [Image](../../../artifacts/encounter_g1/items_toggle_1280x720.png) | [Image](../../../artifacts/encounter_g1/items_toggle_1920x1080.png) |

**PROUVÉ** — Inspection : interrupteur absent dans Rencontre et présent dans les
deux autres domaines ; analyses accessibles ; aucun JSON ou chemin dans les
panneaux ordinaires montrés ; diagnostic local entièrement à l'écran ; terrain
conservé et création principale dans l'état vide. Le premier placement du
nouveau bouton de diagnostic, trop à droite, a été corrigé avant les captures
finales. Aucun nouveau voile modal ou chevauchement inexpliqué n'est observé.

## Défauts réservés à G2 et limites

**PROUVÉ** — Les captures confirment les limites de disposition déjà présentes
dans la baseline, sans les corriger dans G1 :

- À 1280 × 720, la colonne Composition déborde encore ; certains contrôles
  numériques sont coupés à droite. Le bouton du premier affrontement conserve
  son bord droit légèrement hors image, mais son texte et son centre restent
  accessibles.
- En brouillon à 1280 × 720, la validation se réduit pratiquement à son en-tête
  en bas de fenêtre ; sa liste et le bilan demandent une meilleure allocation
  de hauteur en G2.
- Les onglets de propriétés utilisent leur défilement horizontal existant ;
  tous ne tiennent pas simultanément. Les diagnostics et Analyse sont atteints
  avec ce mécanisme, sans mode caché.
- Les noms longs restent tronqués dans l'arbre, le catalogue et la barre
  documentaire. La dernière carte de chronologie visible est coupée par son
  viewport, avec défilement horizontal disponible.
- À 1920 × 1080, Composition et Progression peuvent nécessiter un défilement
  vertical. La nouvelle présentation n'est pas une refonte responsive.

**PROUVÉ** — Les erreurs métier des données restent visibles : canonique
0 erreur / 6 avertissements ; partagée 60 / 40 ; brouillon 60 / 20 ; sans
premier affrontement 2 / 0. Aucun calcul ou diagnostic n'est abaissé pour
faire passer la présentation.

**PROUVÉ** — Pas de publication de données de production, de combat complet,
de suite globale de tests, de commit ni de promotion CURRENT. Les transactions
de partage et les quatre décisions sont exercées sur fixtures personnelles ;
la recette humaine dans l'éditeur et la validation de production restent hors
de cette remise. L'accessibilité complète à 1280 × 720 n'est pas revendiquée
tant que les défauts de disposition réservés à G2 subsistent.
