# G5 — Diagnostics compréhensibles et actionnables

**Statut : PROUVÉ (119/119 tests, vérifié directement par exécution GUT le 29/08/2026 ; captures produites et inspectées aux deux résolutions).**
**WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION.**

Prérequis : [S0](encounter_transition_safety_validation.md) validé (16/16 puis 20/20). Ce rapport couvre exclusivement G5. G6 (finition visuelle, accessibilité, validation finale) suit dans un rapport séparé.

## 1. Ce qui a changé

La liste technique brute (`ItemList` + tooltip + double-clic qui appliquait une correction) est remplacée par des **cartes de diagnostic** compréhensibles, construites dans `EncounterDiagnosticCard`
(`addons/dungeon_draft_arena_studio/encounter/ui/encounter_diagnostic_card.gd`, nouveau fichier) et assemblées par `EncounterStudioMain._rebuild_validation_cards()`. Les données restent exclusivement celles produites par `EncounterValidationService`/`StudioValidationMessage` (§ RAPPORTÉ dans le rapport S0) — aucune erreur ni correction n'est inventée par la vue.

Chaque carte affiche, en français simple :
- la gravité en toutes lettres (« ERREUR » / « AVERTISSEMENT » / « INFORMATION ») **et** un symbole (✖ / ▲ / ℹ) **et** une couleur — jamais la couleur seule ;
- un titre compréhensible (`EncounterPresentation.validation_title`) ;
- une explication (« qu'est-ce qui ne va pas ») ;
- une conséquence (« Effet : … », nouvelle fonction `EncounterPresentation.validation_consequence`, « qu'est-ce que cela empêche ») ;
- l'endroit concerné, si disponible (salle / affrontement / case) ;
- une action attendue (« À faire : … », nouvelle fonction `EncounterPresentation.validation_action`, « que dois-je faire maintenant ») ;
- un bouton **Voir** si une localisation existe, un bouton **Corriger** seulement si un `fix_id` reconnu existe, et un accès **Détails techniques** toujours disponible.

Code interne, `fix_id`, chemin de ressource et JSON restent **masqués du parcours normal** — ils n'apparaissent que dans le dialogue « Détails techniques » (`_show_validation_details_for`), inchangé dans son contenu mais désormais déclenché par carte plutôt que par une sélection globale.

## 2. Voir / Corriger : séparation stricte

Avant ce lot, `_on_validation_activated()` était appelée par un double-clic (`item_activated`) sur la liste et **combinait** navigation et correction en une seule action — exactement le risque que G5 devait éliminer. Cette fonction est supprimée. À la place :

- `_view_diagnostic(message)` — sélectionne la salle/l'affrontement concernés (`_request_room`) et, si un message porte une case, la met en évidence sur la carte (`map_preview.selected_cell`). **Ne modifie jamais rien.**
- `_apply_diagnostic_fix(message)` — le seul chemin qui applique une correction, à partir des trois `fix_id` reconnus (`fit_living_cap`, `use_actual_room_index`, `deduplicate_forbidden`) exactement comme avant, en passant par `_ensure_editable()` (protection des rencontres partagées, inchangée) et `_edit_encounter_property()` (une action Annuler/Rétablir, inchangée), puis relance `_refresh_all()` → `validate_session()`.

Les deux sont désormais des boutons distincts sur la carte (`view_requested` / `fix_requested`), jamais une sélection ou un double-clic. Testé explicitement (`test_encounter_g1.gd::test_validation_explanation_and_local_details_are_read_only`) : cliquer **Voir** sur un message qui porte un `fix_id` reconnu ne modifie ni le contenu, ni l'état modifié, ni l'historique, et ne déclenche jamais la confirmation de partage ; seul **Corriger** le fait.

## 3. Résumé permanent et état sans problème

`validation_summary_label` (nouveau, dans le pied de page, à côté du bouton qui replie/déplie le panneau) reste visible même panneau replié. Ordre de priorité respecté :

1. une ou plusieurs erreurs → « ✖ N erreur(s) [• M avertissement(s)] », en rouge ;
2. sinon des avertissements → « Aucun problème bloquant (M avertissement(s)) », en orange — un avertissement n'empêche jamais de tester (`allowed_spawn_groups_unused` est un avertissement systématique et non bloquant : c'est explicitement testé, `test_encounter_g5.gd::test_one_warning_alone_still_counts_as_no_blocking_problem`) ;
3. sinon → « Aucun problème bloquant », en vert.

À l'intérieur du panneau, l'état positif (§11 de la consigne) s'affiche dès qu'**aucune erreur** n'est présente : « Aucun problème bloquant détecté. Vous pouvez tester l'affrontement. » — sans jamais promettre un équilibrage (testé explicitement). Les avertissements/informations restent listés séparément en dessous, jamais masqués par ce message.

**Limite honnête** : `EncounterValidationService` ajoute toujours au moins une information (`run_flow_mode`) et un avertissement (`allowed_spawn_groups_unused`) pour tout affrontement valide. Un état à zéro diagnostic n'est donc jamais atteignable avec des données réelles ; le construire artificiellement violerait la règle « ne pas inventer ». Le critère G5 réellement démontré est « zéro erreur » → état positif, ce qui est le cas utile en pratique.

## 4. Filtres

Trois cases à cocher (Erreurs / Avertissements / Informations), toutes actives par défaut, filtrent l'affichage des cartes sans jamais toucher au document : `test_encounter_g5.gd::test_filters_hide_severities_without_dirtying_or_touching_history` vérifie l'empreinte, l'état modifié et l'historique identiques avant/après filtrage, et que le filtre **survit** à un rafraîchissement de validation (`validate_session()` reconstruit les cartes mais ne réinitialise pas `_validation_severity_filters`).

## 5. Adaptation à 1280×720 et 1920×1080

Le panneau utilise désormais un `ScrollContainer` vertical (`horizontal_scroll_mode = SCROLL_MODE_DISABLED`) : aucune carte n'impose de défilement horizontal, toutes les étiquettes de texte utilisent `AUTOWRAP_WORD_SMART`. Vérifié :
- par test (`test_encounter_g5.gd::test_long_enemy_names_wrap_instead_of_forcing_overflow`) : un texte de plus de 40 caractères ne reste jamais en `AUTOWRAP_OFF` ;
- par capture réelle aux deux résolutions (`08_texte_long_*.png`, inspectées, aucun débordement horizontal visible).

Le runner de capture (§7) vérifie qu'aucun bouton n'est hors écran, **en excluant les contrôles volontairement défilés hors de la fenêtre visible d'un `ScrollContainer`** (un bouton scrollé n'est pas un débordement — c'est le rôle du défilement ; voir `_inside_scroll_container()` dans le runner). Avec cette distinction correcte, les 8 états capturés aux deux résolutions ne signalent aucun bouton réellement hors écran.

## 6. Fichiers modifiés ou créés

| Fichier | Nature |
|---|---|
| `addons/dungeon_draft_arena_studio/encounter/ui/encounter_diagnostic_card.gd` | Nouveau — composant carte réutilisable |
| `addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd` | Modifié — panneau de validation reconstruit (résumé, filtres, cartes, `_view_diagnostic`/`_apply_diagnostic_fix`/`_show_validation_details_for`), `_on_validation_activated` et `ItemList` supprimés |
| `addons/dungeon_draft_arena_studio/encounter/ui/encounter_presentation.gd` | Modifié — `validation_consequence()` et `validation_action()` ajoutées |
| `test/unit/test_encounter_g1.gd` | Modifié — le test qui dépendait de l'ancienne API (`validation_list`, activation combinée) est réécrit pour la séparation Voir/Corriger |
| `test/unit/test_encounter_g5.gd` | Nouveau — 13 tests dédiés (§8) |
| `addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g1.gd`, `encounter_workspace_g2.gd`, `encounter/test/encounter_studio_capture_runner.gd` | Modifiés — 4 références à l'ancienne API (`validation_list`, `validation_details_button`) mises à jour pour rester compilables ; ce sont des runners d'exploration G1/G2 déjà existants, aucun artefact antérieur n'a été supprimé |
| `addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g5.gd`, `encounter_workspace_g5.tscn` | Nouveaux — runner de capture G5 indépendant (§7) |

`addons/dungeon_draft_arena_studio/ui/arena_studio_main.gd` et `addons/dungeon_draft_arena_studio/test/arena_studio_capture_runner.gd` contiennent un `validation_list` **différent** (Terrain, pas Rencontres) : vérifié et confirmé hors périmètre, non modifié.

## 7. Runner de capture G5

`addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g5.tscn`, indépendant des runners G1/G2/G3-G4/S0 (aucun n'a été remplacé). Commandes réellement exécutées :

```text
--path . --rendering-method gl_compatibility
  addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g5.tscn
  -- --width=1280 --height=720

--path . --rendering-method gl_compatibility
  addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g5.tscn
  -- --width=1920 --height=1080
```

**8 captures × 2 résolutions = 16 images**, dans `artifacts/encounter_g5/` : `01_aucun_probleme_bloquant`, `02_validation_repliee_avec_erreurs`, `03_validation_ouverte_plusieurs_gravites`, `04_carte_erreur`, `05_carte_avec_corriger`, `06_diagnostic_sur_une_case`, `07_details_techniques`, `08_texte_long`. Exit code `0` aux deux résolutions ; tous les contrôles internes du runner passent (voir `g5_1280x720.json` / `g5_1920x1080.json`).

**Inspection visuelle réelle** (via lecture directe des PNG, pas seulement leur génération) :
- `01_aucun_probleme_bloquant` : bannière positive verte visible en pied de panneau, résumé « Aucun problème bloquant (6 avertissement(s)) ».
- `03_validation_ouverte_plusieurs_gravites` : carte d'information lisible, filtres Erreurs/Avertissements/Informations visibles et cochés, résumé « ✖ 1 erreur(s) • 6 avertissement(s) ».
- `04_carte_erreur` : carte `living_cap_too_low` avec la ligne « À faire : … » et trois boutons distincts **Voir**, **Corriger**, **Détails techniques**.
- `07_details_techniques` : dialogue technique avec code stable, chemin, métadonnées JSON — absent du parcours normal, disponible ici uniquement.
- `08_texte_long` (1920×1080) : aucun débordement horizontal, carte peinte et panneau de composition intacts avec un nom d'ennemi très long tronqué proprement dans la liste des salles.

Une correction a été nécessaire dans le runner lui-même (pas dans le produit) : une référence à une carte de diagnostic était réutilisée après un `validate_session()` intermédiaire qui reconstruit toutes les cartes (`_clear_children` + `queue_free`) — la carte devait être retrouvée à nouveau après reconstruction plutôt que réutilisée par référence, exactement comme un vrai clic le ferait. Corrigé en récupérant la carte par son code juste avant utilisation.

## 8. Tests G5

`test/unit/test_encounter_g5.gd` (13 tests, nouveaux) + 1 test réécrit dans `test/unit/test_encounter_g1.gd` couvrent, avec le code source dans la colonne « couverture » :

| Cas de la consigne | Test |
|---|---|
| Aucune erreur | `test_no_blocking_diagnostics_shows_the_positive_state` |
| Une erreur | `test_one_error_hides_the_positive_state_and_shows_a_card` |
| Un avertissement (non bloquant) | `test_one_warning_alone_still_counts_as_no_blocking_problem` |
| Une information | `test_information_message_is_shown_without_blocking_anything` |
| Plusieurs gravités simultanées | `test_multiple_severities_are_all_present_at_once` |
| Filtres sans dirty, survivent au rafraîchissement | `test_filters_hide_severities_without_dirtying_or_touching_history` |
| Voir une case | `test_seeing_a_cell_diagnostic_highlights_it_on_the_map` |
| Voir un onglet/une salle | `test_seeing_a_room_diagnostic_selects_the_right_room_and_wave` |
| Corriger un plafond vivant + partage + Annuler/Rétablir + détails techniques | `test_encounter_g1.gd::test_validation_explanation_and_local_details_are_read_only` (réécrit) |
| Corriger un index de salle + Annuler/Rétablir | `test_fixing_room_index_mismatch_updates_only_that_property` |
| Dédupliquer les cases interdites | `test_fixing_duplicate_forbidden_cells_deduplicates_only` |
| Absence de correction automatique au clic/double-clic | Structurel (plus d'`ItemList`/`item_activated`) + `test_validation_explanation_and_local_details_are_read_only` (Voir ne corrige jamais) |
| Détails techniques accessibles, codes/chemins absents du parcours normal | `test_technical_identifiers_are_absent_from_cards_but_present_in_details` |
| Textes très longs | `test_long_enemy_names_wrap_instead_of_forcing_overflow` |
| Aucune mutation par simple rafraîchissement | `test_rebuilding_cards_never_mutates_or_dirties_the_document` |

## 9. Résultats exacts

Exécutions GUT réelles, le 29/08/2026, régression complète après G5 (9 fichiers, 119 tests) :

| Suite | Résultat |
|---|---|
| `test_room_draft_encounters.gd` | 16/16 |
| `test_encounter_document_safety.gd` | 20/20 |
| `test_encounter_studio_v1.gd` | 17/17 |
| `test_encounter_g1.gd` | 7/7 |
| `test_encounter_g5.gd` | 13/13 |
| `test_encounter_g3_g4.gd` | 20/20 |
| `test_encounter_shared_reference_graph.gd` | 8/8 |
| `test_room_draft_publication.gd` | 8/8 |
| `test_room_transition_async_lifecycle.gd` | 10/10 |

**Total : 119/119.** Les 16/16 et 20/20 de S0 sont donc reconfirmés inchangés après G5 (aucune régression sur la sécurisation des transitions).

**Empreintes `data/`** : recalculées après l'intégralité de G5 (tests + deux runs du runner de capture, GL compatibility inclus) — **0 différence, 383 fichiers**, identique à l'état après S0.

## 10. Risques résiduels et hors périmètre G5

- La hauteur par défaut du panneau de validation (`_validation_height = 145.0`, préexistante) montre peu de cartes à la fois à 1280×720 avant de faire défiler ; ergonomie/hiérarchie visuelle globale = périmètre G6, pas retouchée ici.
- Les couleurs sémantiques (rouge/orange/bleu) sont pour l'instant définies localement dans `EncounterDiagnosticCard.SEVERITY_COLORS`, dupliquant les constantes déjà utilisées ailleurs dans `encounter_studio_main.gd` (carte G4) — centralisation en système visuel partagé = périmètre G6 (§17 de la consigne), non traitée ici pour ne pas déborder du lot.
- Le raccourci clavier/focus complet (Tab, Entrée/Espace, Échap) sur les nouveaux boutons Voir/Corriger/Détails n'a pas été vérifié spécifiquement dans ce lot ; ce sont des `Button` Godot standards (focus et activation clavier natifs), mais la vérification explicite du parcours clavier complet est un critère G6 (§21) traité dans le rapport suivant.
- Les fuites RID/ObjectDB/texture GL en fin d'exécution (runner de capture OpenGL inclus) restent la dette technique préexistante déjà documentée en S0 — aucune amélioration ni dégradation constatée ici.

## 11. Critères G5 — statut final

- [x] Cartes compréhensibles sans vocabulaire technique (gravité, symbole, titre, explication, effet, action, tout en français simple).
- [x] Aucune correction ne peut être déclenchée accidentellement (Voir/Corriger séparés, testé explicitement).
- [x] La destination de « Voir » est correcte (salle, affrontement, case).
- [x] Le panneau reste responsive à 1280×720 et 1920×1080 (captures inspectées, aucun débordement horizontal, aucun bouton réellement hors écran).
- [x] Les 13 tests G5 + le test réécrit passent (119/119 en régression complète).
- [x] Les tests de sécurité S0 passent toujours (16/16 + 20/20 reconfirmés).
- [x] Les ressources de production restent inchangées (0 diff / 383 fichiers `data/`).

**G5 est validé. G6 peut commencer.**

`WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION`
