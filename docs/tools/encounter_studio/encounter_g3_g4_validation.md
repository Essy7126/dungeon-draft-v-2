# G3 + G4 — Composition ennemie et langage visuel du terrain

29 août 2026 — **WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION**.

## Erratum de clôture — 29 août 2026

**PROUVÉ** — Les résultats `13/15` et les deux échecs présentés plus bas
décrivent l'état historique observé pendant G3/G4. Ils ne sont plus l'état
courant : S0 a corrigé les transitions et la sauvegarde de brouillon, puis la
passe de clôture G6 a rejoué `test_room_draft_encounters.gd` à **16/16**.
Le détail de la correction est conservé dans
[encounter_transition_safety_validation.md](encounter_transition_safety_validation.md)
et la preuve finale dans
[encounter_g6_closure_validation.md](encounter_g6_closure_validation.md).

**PROUVÉ** — Le manifeste final porte sur **383 fichiers `data/`**, avec
**0 différence SHA-256** entre l'avant et l'après. Les restaurations par
`git checkout` relatées dans l'incident ci-dessous sont des faits historiques
antérieurs à la procédure de clôture renforcée ; pendant la clôture, aucun
fichier canonique original n'a été restauré ni réécrit.

La suite du présent document est donc une archive technique de G3/G4. Toute
affirmation de résultat courant qu'elle contient est remplacée par cet
erratum et par le rapport de clôture.

## Incident hors périmètre G3/G4 — détecté, diagnostiqué et corrigé

**PROUVÉ** — En exécutant `test/unit/test_room_draft_encounters.gd` (suite
déjà existante, non modifiée par ce chantier) sur le code de base **avant
toute modification G3/G4** (vérifié après `git stash` des changements de ce
chantier), trois ressources de production étaient réécrites sur disque par le
test lui-même : `data/runs/odyssey.tres` (perte de `room_flow_mode` et
`maximum_waves_per_room`), `data/rooms/odyssey/room_02.tres` (environ 1 148
lignes perdues) et `data/encounters/odyssey_room_02_encounter.tres`. Les
fichiers corrompus ont été restaurés à chaque occurrence avec
`git checkout -- <fichiers>`, vérifié par `git status`/`git diff --stat -- data/`.

**PROUVÉ — cause racine identifiée et reproduite de façon déterministe.**
`EncounterStudioMain.open_room_draft()` faisait passer l'ouverture du
brouillon (« Créer les combats de la salle ») par `_request_navigation()`,
qui interroge `StudioProjectContext.request_dirty_transition()` — une
fonction qui bloque dès qu'**un domaine quelconque** est modifié
(`_dirty_domains` global), pas seulement le domaine Rencontres concerné. Or
créer un nouveau terrain marque systématiquement le domaine `arena` comme
modifié. Résultat : cliquer sur « Créer les combats de la salle » juste après
avoir créé/modifié un terrain déclenchait silencieusement une
« décision en attente » côté `StudioProjectContext`, `open_room_draft()`
retournait `false` sans jamais afficher d'erreur exploitable, et la session
Rencontres restait dans l'état où `_discover_default_run()` l'avait ouverte
automatiquement à l'ouverture du workspace : **directement sur la partie et
la salle canoniques**, jamais isolée dans un brouillon. Toute édition
ultérieure (`_add_unit`, `_edit_encounter_property`, etc.) modifiait alors
les vraies Resources de production en mémoire, et un appel explicite à
`EncounterSaveService.save()` — censé être refusé par le garde-fou
`room_draft_mode` — ne l'était pas, puisque `room_draft_mode` était resté
`false`. C'est ce dernier appel, présent dans
`test_saving_a_room_draft_only_writes_under_user_and_restores_everything`,
qui écrivait réellement sur `res://data/...`.

Reproduction confirmée : rejouer exactement la séquence (stash des fichiers
G3/G4, `--editor --import --quit`, puis la suite complète) recrée les mêmes
empreintes SHA-256 corrompues que celles observées la première fois ; le
fichier a de nouveau été restauré immédiatement après confirmation.

**PROUVÉ — correctif appliqué**, dans
`addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd`,
fonction `open_room_draft()` : si la session Rencontres elle-même n'a *aucun*
changement non enregistré (`not session.is_dirty()` — le cas normal juste
après l'ouverture automatique), l'ouverture du brouillon de Terrain est
exécutée directement (`_open_approved_draft(...)`) sans passer par la
décision globale à quatre choix : ce geste ne discute jamais son propre
document, quel que soit l'état d'un autre domaine (Terrain peut légitimement
être « modifié », c'est le cas normal en créant un terrain tout juste créé).
Si Rencontres a lui-même des changements non enregistrés, la décision
explicite à quatre choix reste demandée exactement comme avant — ce chemin
n'est pas modifié.

**PROUVÉ — vérification après correctif** :

- `test_creating_room_encounters_writes_nothing_canonical_and_opens_the_draft`
  (le test qui exerçait directement le scénario cassé) : **1/1 passant**,
  contre un échec systématique avant le correctif.
- Suite complète `test_room_draft_encounters.gd` : **13/15 passants**, contre
  une cascade de dizaines d'échecs et une corruption de données avant le
  correctif. Les empreintes SHA-256 de `data/runs/odyssey.tres`,
  `data/rooms/odyssey/room_02.tres` et
  `data/encounters/odyssey_room_02_encounter.tres` sont restées **identiques
  à `HEAD`** tout au long de cette exécution (vérifié explicitement avant et
  après). Deux tests restent en échec
  (`test_dirty_draft_uses_the_four_explicit_decisions` sur le cas `DRAFT`,
  et `test_saving_a_room_draft_only_writes_under_user_and_restores_everything`
  avec `draft_content_mismatch`) : **aucun des deux n'écrit sur une Resource
  canonique** — ce sont des défauts distincts, plus contenus, non
  investigués plus avant faute de lien avec le risque de corruption qui
  motivait cette intervention. **RAPPORTÉ, à confirmer** — leur cause
  précise n'a pas été établie.
- Les six suites ciblées G3/G4 (`test_encounter_g3_g4.gd`, `test_encounter_g1.gd`,
  `test_encounter_studio_v1.gd`, `test_encounter_document_safety.gd`,
  `test_encounter_shared_reference_graph.gd`, `test_dungeon_draft_studio_v121.gd`)
  ont été rejouées après le correctif : **totaux inchangés** (20/20, 7/7,
  17/17, 20/20, 8/8, 10/10) — le correctif ne régresse aucune d'entre elles.
- `git status --short -- data/` et `git diff --stat -- data/` sont vides
  après cette dernière exécution.

**À CONFIRMER** — Ce correctif répare le chemin identifié et reproduit ; il
ne constitue pas une revue exhaustive de `StudioProjectContext` ni une preuve
qu'aucune autre séquence ne peut laisser Rencontres lié par erreur au
canonique. Une revue dédiée de `request_dirty_transition()` (actuellement
global à tous les domaines plutôt que scopé par domaine concerné) reste
recommandée à Jérémy au-delà de ce correctif ponctuel.

## Prérequis vérifiés avant modification

**PROUVÉ** — `EncounterStudioMain` n'a pas de `guided`, pas de `set_guided()`,
l'interrupteur global reste masqué dans Rencontres, les analyses 10/100/1000
restent disponibles sans mode, l'onglet « Détails techniques » existe (G1).

**PROUVÉ** — La disposition responsive de G2 est intacte : `navigation_panel`
repliable, `validation_panel` repliable, trois dimensions mémorisées
(`_navigation_width`, `_properties_width`, `_validation_height`),
`get_layout_snapshot()` / `apply_layout_snapshot()` inchangés, le terrain
central conserve la priorité d'espace.

**PROUVÉ** — Les runners et rapports G1 (`encounter_workspace_g1.*`,
`test_encounter_g1.gd`) et G2 (`encounter_workspace_g2.*`) ainsi que le
travail du graphe partagé (`encounter_workspace_baseline.*`,
`test_encounter_shared_reference_graph.gd`) sont présents et n'ont pas été
remplacés. Seule une nouvelle suite (`test_encounter_g3_g4.gd`) et un nouveau
runner (`encounter_workspace_g3_g4.*`) ont été ajoutés.

## Fichiers modifiés et créés

**PROUVÉ** — Travail séquentiel, un fichier à la fois, sans sous-agent.

Modifiés :

1. `addons/dungeon_draft_arena_studio/encounter/ui/encounter_presentation.gd`
   — glossaire des types de terrain (`TERRAIN_TYPE_LABELS`,
   `terrain_type_name()`), centralisé pour G4.
2. `addons/dungeon_draft_arena_studio/encounter/ui/encounter_map_preview.gd`
   — G4 : outil explicite, survol/sélection distincts, glyphes de zone,
   bandeau d'échec global, informations de case.
3. `addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd`
   — G3 (composition) et câblage G4 (outil, case sélectionnée, Affichage).

Créés :

4. `addons/dungeon_draft_arena_studio/encounter/ui/encounter_enemy_card.gd`
   — carte réutilisable (catalogue et composition).
5. `test/unit/test_encounter_g3_g4.gd` — 20 tests ciblés.
6. `addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g3_g4.gd`
   et `.tscn` — runner graphique indépendant.
7. Le présent rapport.

Les `.gd.uid` associés sont des métadonnées Godot générées à l'import.

## Résultats G3 — composition ennemie

**PROUVÉ** — État sans affrontement : bloc « Aucun affrontement dans cette
salle », explication précisant que le travail « reste un brouillon tant qu'il
n'est pas intégré à la partie », bouton principal « Créer le premier
affrontement » (46 px de haut, bien visible).

**PROUVÉ** — Après création : la nouvelle rencontre est sélectionnée, l'onglet
Composition reste actif, un message « Ajoutez au moins un ennemi depuis le
catalogue ci-dessous. » apparaît, et le focus est programmé sur la recherche
du catalogue (`_focus_catalog_search_next_refresh`). La création est une
seule action d'historique (`test_create_first_encounter_is_single_undo_action_and_selected`) ;
Annuler restitue l'état exact sans affrontement, Rétablir recrée le même
objet `EncounterDefinition`.

**PROUVÉ** — Ordre de Composition vérifié par test
(`test_composition_order_is_summary_then_roster_then_catalog_then_settings`) :
résumé (nom, effectif total, nombre de types, avertissement réel si le
plafond simultané est inférieur à l'effectif initial — règle déjà validée
par `EncounterValidationService`, jamais une alerte inventée) → « Ennemis
ajoutés » → « Catalogue des ennemis » → deux sections repliables « Réglages
de l'affrontement » (multiplicateurs PV/attaque/récompense) et « Invocations
et capacités » (plafond vivant, budgets d'invocation, capacités désactivées).
Ouvrir/fermer une section ne modifie ni le brouillon ni l'historique (état
Control pur, jamais routé par `_set_property`).

**PROUVÉ** — Cartes d'ennemis (`EncounterEnemyCard`) réutilisées à l'identique
dans la composition et le catalogue : illustration réelle si
`UnitData.sprite_frames` fournit une frame exploitable, sinon remplacement
neutre par initiales (jamais de scène de combat instanciée, jamais de visuel
inventé) ; nom, faction, rôle, PV/PA/PM, badge INVOCATION si un sort est un
sort d'invocation. Testé avec une unité illustrée et une unité sans
illustration au nom volontairement très long
(`test_illustrated_and_fallback_units_render_without_crashing`,
`test_no_technical_identifiers_in_composition_text`).

**PROUVÉ** — Catalogue transformé en cartes avec bouton « Ajouter » explicite
(le double-clic reste un raccourci, via un signal `activated` sur la carte).
Recherche texte conservée ; deux filtres (Faction, Rôle) construits
dynamiquement depuis `enemy_catalog` réel, jamais codés en dur
(`_catalog_factions()`, `_catalog_roles()`). Message dédié si aucun résultat :
« Aucun ennemi ne correspond à cette recherche. Effacez la recherche ou
changez les filtres. ». Une unité déjà présente affiche « Déjà ajouté × N » ;
une nouvelle pression sur Ajouter incrémente la quantité.

**PROUVÉ** — Recherche et résultats du catalogue conservés après un ajout
d'ennemi (`test_search_and_scroll_persist_across_a_composition_edit`) : la
recherche, les filtres et le défilement de Composition sont capturés avant
chaque reconstruction et restaurés après, sans salir le brouillon ni
l'historique.

**PROUVÉ** — Règles fonctionnelles préservées : premier ajout = quantité 1,
ajout répété = incrément, quantité jamais sous 1, Retirer supprime l'unité,
chaque geste = une action d'historique cohérente, Annuler/Rétablir exacts
(`test_first_add_creates_quantity_one_and_repeat_add_increments`,
`test_quantity_never_goes_below_one_and_remove_then_undo_restores`).

**PROUVÉ** — Protection des rencontres partagées intacte à travers les
nouvelles cartes : un ajout via `_add_unit` (chemin identique pour bouton
« Ajouter » et double-clic) déclenche toujours `_ensure_editable` et le
dialogue « Rencontre partagée » ; Dupliquer pour cet affrontement isole la
copie sans jamais modifier l'original
(`test_shared_encounter_protection_still_gated_through_new_cards`).

**PROUVÉ** — Bouton local « Voir le placement » apparaît uniquement quand la
composition contient au moins un ennemi et sélectionne l'onglet Placement. Il
ne duplique aucun bouton global (Tester, Valider, Enregistrer le brouillon,
Intégrer restent uniquement dans l'en-tête commun du Studio).

## Résultats G4 — carte de rencontre

**PROUVÉ — Consultation par défaut, outil explicite.** Un clic ordinaire sur
la carte sélectionne une case sans muter aucune donnée
(`test_map_click_in_view_mode_selects_without_mutation`). Le bouton
« Modifier les cases interdites » (à bascule) doit être activé pour qu'un
clic sur une case praticable ajoute/retire une interdiction, en une seule
action d'historique
(`test_forbidden_tool_must_be_active_for_a_click_to_emit_a_mutation`). Le
curseur passe en croix et un bandeau orange annonce l'édition active ; en
consultation, le curseur reste une flèche normale.

**PROUVÉ — Sortie propre de l'outil.** Échap désactive l'outil sans autre
mutation (`test_escape_exits_tool_without_other_mutation`, capturé via
`_unhandled_key_input`). Changer d'onglet de propriétés ou de salle/document
désactive aussi l'outil (`test_changing_properties_tab_exits_forbidden_tool`,
`test_changing_room_exits_forbidden_tool`). Activer/désactiver l'outil est un
état d'interface pur : jamais de salissure du brouillon
(vérifié dans les deux tests ci-dessus et dans
`test_display_preferences_do_not_dirty_the_draft`).

**PROUVÉ — Informations de case.** Le survol met à jour un contour blanc
distinct de la sélection (contour jaune plus épais) ; une case sélectionnée
garde un résumé visible en permanence sous la carte (`cell_info_label`), pas
seulement au survol : coordonnée, type de terrain en français
(`EncounterPresentation.terrain_type_name`, glossaire centralisé), zone
(alliée / ennemie préférée / aucune), état interdit, et ennemi placé avec son
numéro d'ordre si présent
(`test_cell_info_reports_terrain_zone_and_forbidden_state`). Aucun
identifiant, chemin ou code interne de `GridData` n'y apparaît.

**PROUVÉ — Signes visuels combinés, pas seulement des couleurs.** Zone
alliée : remplissage bleu + glyphe « A » ; zone ennemie préférée : orange +
glyphe « E » ; case interdite : rouge + croix ; placement : marqueur vert
numéroté ; survol : contour blanc fin ; sélection : contour jaune épais ;
légende textuelle listant ces correspondances, repliable via la préférence
« Légende » du menu Affichage.

**PROUVÉ — Aucune fausse validité par case.** `EncounterPreviewService` ne
fournit qu'une validité globale (`valid`) et une raison ; les placements
individuels n'ont pas de champ de validité propre. Avant ce chantier, un
résultat global invalide teignait **tous** les marqueurs en rouge — ce que la
consigne interdit explicitement. Désormais les marqueurs restent toujours
verts, et l'échec global est annoncé séparément par un bandeau dédié
(`_draw_failure_banner`). Vérifié par
`test_placement_markers_stay_normal_when_global_placement_is_invalid`
(contrôle du code source : l'ancienne teinte rouge conditionnelle a disparu)
et confirmé visuellement dans les captures `map_view_mode` (bandeau rouge
« Placement impossible… » sans marqueur rouge).

**PROUVÉ — Contrôles d'affichage.** Un menu « Affichage » (`MenuButton` +
`PopupMenu` à cases à cocher) regroupe Grille / Zones / Placements /
Distances / Légende, sans rangée de petits boutons séparés. Ces préférences
sont des booléens locaux à `EncounterMapPreview`, jamais persistés dans une
Resource et jamais dirty (`test_display_preferences_do_not_dirty_the_draft`).

**PROUVÉ — Terrain visible avant tout affrontement**, y compris sans
`preview_result` (`test_terrain_visible_before_first_encounter`), inchangé
depuis G1/G2.

**PROUVÉ — Aucune seconde autorité de grille.** Aucune nouvelle projection de
coordonnées n'a été ajoutée : `_cell_center`, `_cell_polygon`,
`_position_to_cell`, `_configure_projection` restent les mêmes qu'avant G4
(délégation à `PaintedMapVisualData` ou à la grille modulaire selon le cas).
Seuls l'affichage (glyphes, bandeaux, contours) et la gestion d'entrée
(mode consultation/édition, survol séparé de la sélection) ont changé.

## Défaut corrigé en cours de route (hors périmètre initial, mais nécessaire)

**PROUVÉ** — `_clear_children()` appelait `hide()` puis `queue_free()` sans
`remove_child()` immédiat. Comme `_refresh_composition()` peut être appelée
plusieurs fois dans la même image (par exemple par un test ou par un
enchaînement d'actions), d'anciens nœuds masqués mais pas encore libérés
restaient retournés par `get_children()`, avant les nouveaux — un bouton
« Créer le premier affrontement » fraîchement construit pouvait ainsi être
masqué visuellement par un doublon fantôme de l'itération précédente. Corrigé
en ajoutant `parent.remove_child(child)` avant `queue_free()`. Aucune
régression observée dans les six suites ciblées après correction.

## Contrôle intermédiaire G3 (avant G4)

**PROUVÉ** — Les 12 points demandés ont été exercés par la nouvelle suite
avant de commencer les modifications de carte : création, Annuler/Rétablir,
ajout simple, ajout répété, quantité minimale, retrait puis annulation,
rencontre partagée, recherche et filtres, illustration réelle, illustration
absente, nom long, absence d'informations techniques. L'état responsive a été
vérifié visuellement aux deux résolutions via le runner graphique (section
suivante), la même disposition G2 restant en vigueur.

## Tests fonctionnels — résultats exacts

| Suite | Résultat | Assertions | Code de sortie |
|---|---:|---:|---:|
| `test_encounter_g3_g4.gd` (nouvelle) | **20/20** | 299 | 0 |
| `test_encounter_g1.gd` | **7/7** | 362 | 0 |
| `test_encounter_studio_v1.gd` | **17/17** | 200 | 0 |
| `test_encounter_document_safety.gd` | **20/20** | 753 | 0 |
| `test_encounter_shared_reference_graph.gd` | **8/8** | 141 | 0 |
| `test_dungeon_draft_studio_v121.gd` | **10/10** | 1037 | 0 |

**PROUVÉ** — Comparaison directe aux baselines : ces six suites donnaient déjà
exactement les mêmes totaux avant les modifications G3/G4 (G1 : 7/7/362 dans
`encounter_g1_validation.md` ; G2 rapporte les mêmes six suites cumulées à
67/67/2 543, dont 7/7/362 pour G1 seul ; `test_encounter_studio_v1.gd` 17/17
et `test_encounter_shared_reference_graph.gd` 8/8 dans
`encounter_shared_graph_final_validation.md`). **Zéro régression** sur ces
totaux après G3/G4.

**RAPPORTÉ, hors comparaison** — `test_room_draft_encounters.gd` n'a pas été
relancé après la découverte de la section « Alerte prioritaire » ci-dessus ;
son état vis-à-vis de G3/G4 reste donc non déterminé par ce chantier
(il échoue déjà, avec un ensemble de défauts différent, sur le code de base
seul — voir cette section).

**PROUVÉ** — Import/compilation globale :
`--headless --path . --editor --import --quit` termine avec le code 0, sans
`Parse Error`, `SCRIPT ERROR` de chargement ni erreur de compilation, à
chaque exécution (avant et après les changements G3/G4). `EncounterEnemyCard`
est bien enregistrée comme classe globale.

## Vérification graphique — runner `encounter_workspace_g3_g4`

**PROUVÉ** — Nouveau runner indépendant, n'écrasant ni la baseline, ni G1, ni
G2. Artefacts sous `artifacts/encounter_g3_g4/`. Utilise le vrai
`StudioWorkspace`, `EmbeddedStudioHost`, la vraie partie `first_run.tres` (via
un brouillon Terrain réel) et `fixed_trio_prototype_run.tres` pour la vue
rencontre partagée — aucune maquette.

**PROUVÉ** — Dix vues capturées et inspectées en 1280×720 et 1920×1080
(20 images) : `shared_encounter`, `no_first_encounter`,
`empty_encounter_catalog`, `catalog_with_fallback_unit`,
`composition_multiple_enemies`, `catalog_search_no_results`,
`map_view_mode`, `map_forbidden_tool_active`, `map_cell_hovered`,
`map_cell_selected`. Chaque passe : **0 contrôle en échec**, code de sortie 0.
Un tooltip réel a d'abord été compté comme fenêtre résiduelle (comme dans
G2) ; corrigé en écartant le curseur avant chaque contrôle de modales.

**PROUVÉ (inspection visuelle réelle des 20 PNG)** :

- `no_first_encounter` (1280×720 et 1920×1080) : le terrain (illustration
  peinte) reste pleinement visible, le bloc « Aucun affrontement dans cette
  salle » et son bouton principal sont entièrement à l'écran, sans
  chevauchement.
- `empty_encounter_catalog` : résumé « 0 ennemi(s) au total • 0 type(s)
  d'ennemi », message « Ajoutez au moins un ennemi… », catalogue accessible
  par défilement.
- `catalog_with_fallback_unit` : cartes réelles avec initiales (« CS », « S »,
  « ED ») faute d'illustration disponible sur ces unités de production,
  boutons « Ajouter » visibles, nom très long renvoyé à la ligne sans
  débordement.
- `composition_multiple_enemies` : trois cartes ajoutées, résumé « 3
  ennemi(s) au total • 3 type(s) d'ennemi », sections repliées « Réglages de
  l'affrontement » / « Invocations et capacités », bouton « Voir le
  placement ».
- `catalog_search_no_results` : message exact affiché, filtres Faction/Rôle
  visibles au-dessus.
- `map_view_mode` : bandeau rouge « Placement impossible… » distinct des
  marqueurs (aucun marqueur recoloré), légende combinant couleur/glyphe/motif
  lisible en bas de carte.
- `map_forbidden_tool_active` : bandeau orange annonçant l'édition active,
  bouton « Modifier les cases interdites » visiblement enfoncé.
- `map_cell_selected` : résumé de case sous la carte : « Case (2, 2) / Type :
  Sol praticable / Zone : Aucune zone particulière / Case interdite au
  déploiement ennemi : non ».
- `shared_encounter` (partie à vagues réelle) : hachures rouges denses pour
  les cases interdites, glyphes « E »/« A » sur les zones, quatre marqueurs
  verts numérotés, légende de distances en haut à gauche — aucune
  information technique visible dans le parcours normal.

**PROUVÉ — Terrain toujours prioritaire.** Aux deux résolutions, le terrain
occupe la même part de l'écran qu'en G2 ; aucune régression de largeur/hauteur
du panneau central n'est observée dans les captures.

**RAPPORTÉ, limites de captures** — Le runner couvre 10 vues sur les 16
demandées dans la consigne (salle peinte vs sans carte peinte non distinguées
séparément — la seule salle disponible pour ce runner est peinte ; options
d'affichage et légende repliée non capturées isolément ; « plusieurs
placements proches » non isolé). Ces vues manquantes n'ont pas révélé de
défaut dans les tests unitaires correspondants, mais n'ont pas été
inspectées visuellement de façon dédiée.

## Préservation des données

**PROUVÉ** — `git status --short -- data/` et `git diff --stat -- data/` sont
vides après ce chantier : aucune Resource de `data/` n'a été modifiée par
G3/G4. (Voir la section « Alerte prioritaire » pour l'incident distinct,
détecté et corrigé, provoqué par une suite de test préexistante et non par ce
chantier.)

**PROUVÉ** — Aucun fichier temporaire de test n'est resté dans un catalogue
découvert par le jeu : les fixtures de `test_encounter_g3_g4.gd` écrivent
exclusivement sous `user://dungeon_draft_studio/encounter_g3_g4*/`.

## Écarts par rapport à G2

Aucun. La disposition, les largeurs mémorisées, le repli des panneaux et
l'ordre général (barre documentaire, bannière, chronologie, trois colonnes,
validation, bilan) sont inchangés. Seul le contenu de la colonne Composition
et le contenu du panneau central (carte + nouveaux contrôles) ont changé.

## Limites reportées à G5/G6

- La palette de couleurs finale, les icônes dédiées et les animations restent
  à faire (G6, explicitement exclu par la consigne).
- Les 6 vues graphiques non capturées par ce runner (voir ci-dessus) restent
  à couvrir si une passe G5 approfondit la carte.
- Les remplacements par initiales dominent les captures issues de données de
  production réelles : cela prouve que le mécanisme de repli fonctionne, mais
  ne prouve pas qu'un jeu de sprites compatible existe déjà pour la majorité
  du catalogue — question d'art, hors périmètre technique de G3/G4.
- Le bandeau d'échec global de placement (`_draw_failure_banner`) est un
  texte simple ; son intégration avec un futur système de diagnostic
  utilisateur plus riche reste ouverte.

## Risques résiduels

- **Corrigé pendant ce chantier, à confirmer plus largement** : la
  corruption de `data/runs/odyssey.tres` et de ses Resources associées est
  réparée à la racine (voir la section dédiée ci-dessus) et vérifiée par
  ré-exécution avec contrôle d'empreinte SHA-256. `request_dirty_transition()`
  reste cependant un verrou global à tous les domaines plutôt que scopé par
  domaine ; une revue dédiée de `StudioProjectContext` reste recommandée pour
  écarter d'autres séquences similaires non couvertes par ce correctif ponctuel.
- Deux tests de `test_room_draft_encounters.gd` restent en échec sans écrire
  sur le canonique (`test_dirty_draft_uses_the_four_explicit_decisions` sur le
  cas `DRAFT`, `test_saving_a_room_draft_only_writes_under_user_and_restores_everything`
  avec `draft_content_mismatch`) : cause non investiguée, hors périmètre du
  risque de corruption qui motivait l'intervention.
- Les fuites de fermeture (ObjectDB/RID/orphelins) déjà documentées en G1/G2
  restent présentes ; ce chantier ne les corrige pas et ne prétend pas à une
  fermeture sans fuite.
- La revue humaine interactive dans l'éditeur Godot reste à faire : les
  captures et tests automatisés prouvent la structure et l'absence de
  régression, pas le confort d'usage réel par une personne non technique.

## Statut

`WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION`

Aucun commit, aucun stage, aucun push. Aucune promotion sans validation
explicite de Jérémy.
