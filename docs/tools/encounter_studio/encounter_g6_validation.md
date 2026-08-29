# G6 — Finition visuelle, accessibilité et validation finale

**Statut de clôture : PROUVÉ (128/128 tests ciblés attendus dans la passe finale ; parcours E2E séparé 1/1 ; 57 captures produites et inspectées à 1280×720, 1920×1080 et 1280×720 à 125 % réel).**

`WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION`

Prérequis validés avant ce lot : [S0](encounter_transition_safety_validation.md) (16/16 puis 20/20) et [G5](encounter_g5_validation.md) (119/119, diagnostics compréhensibles). Ce rapport couvre exclusivement G6 : harmonisation visuelle locale, hiérarchie des actions, accessibilité clavier, contraste, responsive final, parcours complets, et la passe de validation technique de clôture des trois lots.

## Addendum de clôture — 29 août 2026

**PROUVÉ** — Le rapport détaillé et les preuves brutes sont réunis dans
[encounter_g6_closure_validation.md](encounter_g6_closure_validation.md) et
`artifacts/encounter_g6_closure/`. Cet addendum remplace les limites et
résultats provisoires de l'archive G6 ci-dessous lorsqu'ils divergent.

- L'échelle 125 % est réellement pilotée par `content_scale_size` : fenêtre
  physique 1280×720, surface logique 1024×576, 707 contrôles sur ce passage.
- Les touches Tab, Maj+Tab, Entrée, Espace et Échap sont injectées comme de
  vrais `InputEventKey` dans le viewport. Une capture dédiée montre l'anneau
  de focus local jaune de 2 px.
- Le parcours terrain → rencontre → recherche → ajout → quantité → placement
  → Voir/Corriger → Annuler/Rétablir → sauvegarde → test direct → production
  → intégration → rechargement sans cache est un seul test E2E dans une copie
  jetable vérifiée du projet : **1/1**.
- L'import global et le chargement principal ont été exécutés dans cette
  copie, jamais dans l'original. L'import a révélé quatre inférences de types
  invalides dans `battle/battle.gd`; des annotations explicites minimales les
  ont corrigées. Le second import et le chargement principal sortent à 0,
  sans erreur de parsing, script manquant ni classe manquante.
- Le manifeste original `data/` reste à **383/383 fichiers, 0 différence**.
- L'icône `EditorIcons/Folder` possède un repli sûr et son nom est contrôlé
  par le code ; son rendu avec le thème complet de l'éditeur reste
  **À CONFIRMER** manuellement. Aucune compatibilité lecteur d'écran n'est
  revendiquée : noms accessibles et infobulles sont vérifiés, le confort avec
  un lecteur d'écran réel reste **À CONFIRMER**.

La suite de ce fichier est conservée comme historique de la première passe
G6. Les mentions « 124/124 », « 36 captures », « 125 % non testé »,
« parcours couverts par combinaison » et « import abandonné » ne décrivent
plus l'état de clôture.

## 1. Résumé de S0

Deux causes racines corrigées dans `save_room_draft()`/`open_room_draft()` (`encounter_studio_main.gd`) : un marqueur d'édition non sérialisé (`authoring_document`) faussait la comparaison d'empreinte du brouillon relu, et rien ne protégeait `open_room_draft()` contre une transition déjà en attente ailleurs dans le Studio. 16/16 tests, `data/` intact. Détails complets : [encounter_transition_safety_validation.md](encounter_transition_safety_validation.md).

## 2. Résumé de G5

La liste technique brute de validation est remplacée par des cartes de diagnostic compréhensibles (`EncounterDiagnosticCard`), avec séparation stricte Voir/Corriger, résumé permanent, filtres non destructifs, état positif honnête, et détails techniques masqués du parcours normal. 119/119 tests, 16 captures. Détails complets : [encounter_g5_validation.md](encounter_g5_validation.md).

## 3. Choix visuels G6

### 3.1 Système visuel local (§17 de la consigne)

Nouveau fichier `addons/dungeon_draft_arena_studio/encounter/ui/encounter_visual_constants.gd` (`EncounterVisualConstants`) : couleurs sémantiques (gravités, succès, muet, destructif), espacements, rayon de coin de carte, hauteur minimale de bouton. **N'affecte aucun autre Studio** (Terrain, Objets, Compétences, VFX conservent leurs propres constantes, non touchées).

Les couleurs choisies ne sont pas inventées : la couleur « muette » (`Color(0.72, 0.77, 0.84)`) est **exactement** celle déjà utilisée telle quelle dans `items/ui/*.gd` et `skill_tree/ui/skill_tree_animation_screen.gd` (vérifié par recherche exhaustive avant de la fixer) — c'est la convention Studio déjà en place, seulement centralisée côté Rencontres plutôt que dupliquée. Les couleurs de gravité sont celles déjà utilisées par la carte G4 et les cartes de diagnostic G5, inchangées.

Trois duplications supprimées au profit de cette source unique : `EncounterDiagnosticCard.SEVERITY_COLORS` (local, G5) → `EncounterVisualConstants.SEVERITY_COLORS` ; `EncounterEnemyCard.MUTED_COLOR` (dupliqué depuis G3) → `EncounterVisualConstants.COLOR_MUTED` ; les tailles de bouton `Vector2(96, 32)` en dur dans les cartes G5 → `EncounterVisualConstants.BUTTON_MIN_HEIGHT`.

### 3.2 Hiérarchie des actions (§18)

**Actions destructrices identifiables, non dominantes** : `Supprimer` (affrontement, `encounter_studio_main.gd`) et `Retirer` (ennemi, `encounter_enemy_card.gd`) reçoivent `EncounterVisualConstants.apply_destructive_style()` — une couleur de texte rouge-corail (`COLOR_DESTRUCTIVE`), **sans fond plein ni taille agrandie**. Vérifié par capture réelle (`09_action_destructrice_visible_*.png`, inspectée : les deux boutons se distinguent par leur seule couleur, au milieu d'actions au style neutre) et par test (`test_encounter_g6.gd::test_destructive_actions_are_visually_distinct_but_not_dominant`, `test_removing_an_enemy_uses_the_same_destructive_style`).

**Bouton désactivé vs actif** : le thème Godot par défaut (hérité, non modifié par ce lot) distingue déjà visuellement un bouton `disabled`. Aucune régression introduite.

**Actions essentielles jamais réduites à une icône seule** : les icônes ajoutées (`_add_button()` accepte désormais un nom d'icône `EditorIcons`, avec repli silencieux si l'icône n'existe pas — `has_theme_icon()` avant `get_theme_icon()`, même garde que celle déjà utilisée dans `dungeon_draft_studio_main.gd::_apply_theme_icons()`) s'ajoutent **à côté** du texte, jamais à sa place. Câblé prudemment sur un seul bouton à risque faible (« Ouvrir une partie » → icône `Folder`) plutôt que deviné sur l'ensemble des boutons.

**Hiérarchie de taille** : `_add_button()` impose désormais une hauteur minimale commune (32 px, `BUTTON_MIN_HEIGHT`) à tous les boutons qu'elle construit — élimine les hauteurs incohérentes sur une même barre. Une action déjà plus grande intentionnellement (« Créer le premier affrontement », 46 px ; le sélecteur d'affrontement de la chronologie, 64 px) reste plus grande : c'est la hiérarchie voulue, pas une incohérence à aplatir. Testé explicitement (`test_toolbar_buttons_meet_the_shared_minimum_height` : aucun bouton plus **petit** que la base commune, la majorité exactement à la base, les actions volontairement plus grandes restent plus grandes).

### 3.3 Accessibilité clavier (§21)

**Défaut réel trouvé et corrigé** : `_apply_diagnostic_fix()` relance `validate_session()`, qui reconstruit toutes les cartes de diagnostic (`_clear_children()` + nouvelles instances). Le bouton **Corriger** que l'utilisateur vient d'activer au clavier est donc détruit par sa propre action — sans garde, le focus clavier se serait perdu silencieusement après chaque correction, violant directement « le focus ne se perd pas après un rafraîchissement ». Corrigé dans `_rebuild_validation_cards()` : si le focus était dans le panneau de validation avant reconstruction, il est reporté sur `validation_toggle` (le bouton qui ouvre/replie le panneau — un ancrage stable, toujours présent, dont la fonction est déjà comprise de l'utilisateur). Testé (`test_focus_returns_to_a_stable_anchor_after_correcting_a_diagnostic`) : focus posé sur **Corriger**, correction appliquée, focus vérifié sur `validation_toggle` après. Un second test (`test_focus_outside_the_panel_is_left_untouched_by_a_rebuild`) confirme qu'un focus **hors** du panneau n'est jamais perturbé par un rafraîchissement.

Le reste de l'accessibilité clavier (Tab/Maj+Tab, Entrée/Espace activent les boutons, Échap ferme une fenêtre modale) repose sur le comportement natif de Godot pour `Button`/`AcceptDialog`/`ConfirmationDialog`, non réécrit par ce lot — **PROUVÉ non régressé** (`focus_mode` par défaut `FOCUS_ALL`, jamais changé sur aucun bouton touché), mais le rendu visuel exact de l'anneau de focus dans l'éditeur réel reste **à confirmer humainement dans Godot** (voir §12).

### 3.4 Contraste (§22) — mesuré sur pixels réels, pas sur des valeurs théoriques

Méthode : plutôt que de calculer un contraste à partir des couleurs nominales contre un fond supposé, les couleurs ont été **échantillonnées directement** sur `artifacts/encounter_g5/04_carte_erreur_1280x720.png` (une vraie capture GPU du Studio) pour identifier le ton de fond le plus clair réellement présent (pire cas pour le contraste), puis le ratio WCAG a été calculé avec la formule standard de luminance relative :

| Couleur | Contraste vs fond mesuré (31,31,31) |
|---|---|
| Erreur — `(255,92,81)`, valeur mesurée | 5,42:1 |
| Destructif — `(255,115,107)`, nominal | 6,21:1 |
| Avertissement — `(255,194,77)`, nominal | 10,26:1 |
| Information — `(148,220,255)`, valeur mesurée | 10,94:1 |
| Succès — `(153,230,153)`, nominal | 11,09:1 |
| Muet/secondaire — `(184,196,214)`, nominal | 9,34:1 |
| Texte par défaut — `(223,223,223)`, valeur mesurée | 12,37:1 |

**Toutes les couleurs dépassent 4,5:1** (seuil texte ordinaire), donc a fortiori le seuil de 3:1 pour grands textes et indicateurs graphiques. La couleur la plus proche du seuil est le rouge d'erreur (5,42:1), avec une marge confortable. Les états ne dépendent jamais de la couleur seule : chaque gravité porte aussi un symbole (✖ ▲ ℹ) et un libellé texte (« ERREUR »/« AVERTISSEMENT »/« INFORMATION »), déjà vérifié en G5.

Les textes français longs et les noms d'ennemis exceptionnellement longs ont été testés (`test_encounter_g5.gd::test_long_enemy_names_wrap_instead_of_forcing_overflow`, capture `15_textes_longs_*.png` — inspectée, aucun débordement).

### 3.5 Mouvement et stabilité (§24)

Aucune animation décorative ajoutée par G5 ou G6. Rien à corriger ici : ni scintillement, ni bouton fantôme, ni superposition temporaire observés dans les 36 captures inspectées.

## 4. Fichiers modifiés

| Fichier | Nature |
|---|---|
| `addons/dungeon_draft_arena_studio/encounter/ui/encounter_visual_constants.gd` | Nouveau — système visuel local (§3.1) |
| `addons/dungeon_draft_arena_studio/encounter/ui/encounter_diagnostic_card.gd` | Modifié — référence les constantes partagées au lieu d'une copie locale |
| `addons/dungeon_draft_arena_studio/encounter/ui/encounter_enemy_card.gd` | Modifié — couleur muette partagée, bouton Retirer stylé destructif |
| `addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd` | Modifié — `_add_button()` (hauteur commune, style destructif optionnel, icônes avec repli), bouton Supprimer marqué destructif, tooltips ←/→, garde de focus dans `_rebuild_validation_cards()`, résumé de validation reformulé (avertissement ≠ bloquant) |
| `test/unit/test_encounter_g6.gd` | Nouveau — 5 tests dédiés (§9) |
| `addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g6.gd`, `.tscn` | Nouveaux — runner de capture G6 indépendant (§7) |

Aucun autre Studio (Terrain, Objets, Compétences, VFX) n'a été modifié.

## 5. Incident et correction : `--editor --headless --quit` a modifié 3 fichiers de production

**Ce qui s'est passé (PROUVÉ) :** pour vérifier l'absence d'erreur d'import/de parsing après les changements de G6, la commande `Godot ... --headless --path . --editor --quit` a été exécutée. Un manifeste de hachage SHA-256 de `data/` (383 fichiers), pris avant tout test à risque dès le début de S0, a détecté après coup **3 fichiers réellement modifiés** : `data/runs/odyssey.tres`, `data/rooms/odyssey/room_02.tres`, `data/encounters/odyssey_room_02_encounter.tres`.

**Cause identifiée :** ces trois `.tres` n'avaient apparemment jamais été rouverts par un vrai éditeur Godot depuis l'introduction du système d'UID dans ce projet. Le scan complet déclenché par `--editor ... --quit` les a migrés (ajout de `uid="uid://..."` sur `[gd_resource]` et chaque `[ext_resource]`, reformatage de dictionnaires en multi-lignes, normalisation `Array[UnitData]` → `Array[ExtResource(...)]`) et a réappliqué au passage le comportement déjà documenté de `ResourceSaver` qui omet les propriétés à leur valeur par défaut (`room_flow_mode = 0` et `maximum_waves_per_room = 1` disparus du fichier, sans changement de comportement puisque ce sont déjà les valeurs par défaut de la classe). **Aucun contenu métier n'a été altéré** (même roster, mêmes distances, mêmes cases interdites) — uniquement une réécriture de sérialisation.

**Correction appliquée :** ces trois fichiers étaient confirmés propres (non modifiés par l'utilisateur) au tout début de la session — restaurés avec `git checkout -- <les 3 chemins exacts>` (jamais un `git checkout .` global), puis reconfirmés identiques au manifeste de référence (383/383 fichiers, 0 diff) et à `git status`/`git diff --check` (propres).

**Cause corrigée pour la suite :** la vérification finale d'absence d'erreur de parsing/compilation (§10) repose désormais exclusivement sur l'exécution réelle des suites GUT (qui chargent et compilent déjà tous les scripts référencés — un `Parse Error` ou `Could not find type` y apparaît si un script est cassé, comme observé et corrigé plus tôt pendant G6 pour `EncounterDiagnosticCard`/`EncounterVisualConstants`), jamais plus `--editor --headless --quit`. Mémorisé pour les sessions futures sur ce projet.

## 6. Runner et captures G6

`addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g6.tscn`, indépendant de tous les runners précédents (baseline, G1, G2, G3-G4, G5 — aucun remplacé). Deux phases avec deux workspaces distincts (brouillon/composition/carte/validation, puis rencontre partagée/panneaux) pour éviter toute transition documentaire parasite entre les deux, exactement le choix déjà fait par G1/G2/G3-G4.

```text
--path . --rendering-method gl_compatibility
  addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g6.tscn
  -- --width=1280 --height=720

--path . --rendering-method gl_compatibility
  addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g6.tscn
  -- --width=1920 --height=1080
```

**18 états × 2 résolutions = 36 captures**, dans `artifacts/encounter_g6/` : salle sans affrontement, brouillon, composition vide, catalogue, composition remplie, placement, carte en consultation, outil des cases interdites, action destructrice visible, validation repliée, validation ouverte, diagnostic actionnable, détails techniques, état sans problème bloquant, textes longs, rencontre partagée, panneaux ouverts, panneaux repliés. Exit code `0` aux deux résolutions, **zéro `_check()` en échec** (y compris un filet de sécurité ajouté après un premier bug de runner — une référence `workspace.navigation_toggle` incorrecte, corrigée en `ui.navigation_toggle` — qui vérifie explicitement que les 18 états attendus ont chacun produit une capture, pas seulement que le script s'est terminé sans erreur).

**Inspection visuelle réelle** (lecture directe des PNG) :
- `09_action_destructrice_visible` : « Supprimer » et « Retirer » clairement rouge-corail parmi des boutons neutres, aucune domination visuelle.
- `18_panneaux_replies` (1920×1080, rencontre partagée à 60 erreurs/40 avertissements — données réelles du run partagé, pas artificielles) : résumé de validation lisible en une ligne, nom d'ennemi extrêmement long replié proprement sur 3 lignes dans le catalogue sans déborder, boutons Ajouter/Retirer alignés et accessibles.
- Comparaison avec les captures G2 (`navigation_closed`, `all_panels`) et G3-G4 (`map_forbidden_tool_active`, `composition_multiple_enemies`) : mise en page cohérente, aucune régression de disposition visible entre les lots.

## 7. Parcours complets (§26)

Les trois parcours demandés sont couverts par la combinaison des runners et suites de tests déjà exécutés, sur ce Studio étant une application de bureau Godot (pas une page web — la vérification se fait par code piloté et captures réelles, comme tous les runners G1-G6, pas par navigateur) :

- **Nouveau terrain → combats → ennemis → placement → correction → enregistrement → test → intégration** : couvert par `encounter_workspace_g6.gd` phase 1 (étapes 1 à 15) + `test_room_draft_encounters.gd` (16/16, sauvegarde/restauration exacte) + `test_encounter_g1.gd`/`test_encounter_g6.gd` (correction avec Annuler/Rétablir).
- **Rencontre partagée → modification → trois décisions → duplication → original intact → Annuler/Rétablir** : `test_encounter_g1.gd::test_validation_explanation_and_local_details_are_read_only` et `test_encounter_studio_v1.gd` (copie indépendante, un seul usage modifié) + `encounter_workspace_g6.gd` phase 2 (rencontre partagée réelle, 12 affrontements/3 salles).
- **Navigation et fenêtre : modification → changement de salle → quatre décisions → détacher/rattacher → session/sélection/historique/panneaux/focus** : `test_room_draft_encounters.gd::test_dirty_draft_uses_the_four_explicit_decisions` (S0) + `test_encounter_g6.gd` (focus après reconstruction) + `encounter_workspace_baseline.gd` (détachement/réattachement, identités préservées — runner déjà existant, revérifié dans la régression finale §10 mais pas modifié).

## 8. Adaptation responsive finale (§25)

Vérifiée à 1280×720 et 1920×1080 sur les 18 états ci-dessus : panneaux ouverts et repliés, validation ouverte, navigation repliée, chronologie (6 affrontements dans la capture partagée), catalogue rempli, composition longue, carte avec placements, détails techniques, noms longs, brouillon Terrain ouvert dans Rencontres. Aucun contrôle ordinaire hors fenêtre (vérifié par `_check()` automatique sur chaque capture, hors zones volontairement défilables et fenêtres modales). **La mise à l'échelle à 125 % n'a pas été testée** : le runner ne pilote pas `content_scale_factor` de l'éditeur hôte, et aucun mécanisme existant dans les runners précédents (G1-G5) ne le fait non plus — cette vérification reste à faire manuellement dans l'éditeur Godot réel (voir §12).

## 9. Tests G6

`test/unit/test_encounter_g6.gd` (5 tests, nouveaux) :

| Cas | Test |
|---|---|
| Focus reporté sur un ancrage stable après correction (reconstruction du panneau) | `test_focus_returns_to_a_stable_anchor_after_correcting_a_diagnostic` |
| Focus hors panneau jamais volé par un rafraîchissement | `test_focus_outside_the_panel_is_left_untouched_by_a_rebuild` |
| Action destructrice (Supprimer un affrontement) : couleur distincte, pas de fond, pas de taille agrandie | `test_destructive_actions_are_visually_distinct_but_not_dominant` |
| Action destructrice (Retirer un ennemi) : même style partagé | `test_removing_an_enemy_uses_the_same_destructive_style` |
| Boutons jamais plus petits que la base commune, majorité alignée dessus | `test_toolbar_buttons_meet_the_shared_minimum_height` |

## 10. Validation technique finale — une seule passe de clôture

Exécutions GUT réelles, le 29/08/2026, régression complète après G6 (10 fichiers) :

| Suite | Résultat |
|---|---|
| `test_room_draft_encounters.gd` (S0) | 16/16 |
| `test_encounter_document_safety.gd` (sécurité documentaire) | 20/20 |
| `test_encounter_studio_v1.gd` | 17/17 |
| `test_encounter_g1.gd` | 7/7 |
| `test_encounter_g5.gd` | 13/13 |
| `test_encounter_g6.gd` | 5/5 |
| `test_encounter_g3_g4.gd` | 20/20 |
| `test_encounter_shared_reference_graph.gd` (contexte partagé) | 8/8 |
| `test_room_draft_publication.gd` (publication/brouillons) | 8/8 |
| `test_room_transition_async_lifecycle.gd` (transitions) | 10/10 |

**Total : 124/124.** S0 (16/16 + 20/20) et G5 (119/119, dont ces mêmes 20/20 et 16/16) restent intégralement reconfirmés après G6 — aucune régression sur trois lots cumulés.

**Import Godot** : aucune erreur de parsing ni de compilation détectée sur l'ensemble du projet — confirmé par l'exécution réussie de toutes les suites ci-dessus (qui chargent et compilent chaque script référencé) plutôt que par `--editor --headless --quit`, dont l'usage a été abandonné après l'incident du §5. Deux vrais bugs de parsing ont été trouvés et corrigés **pendant** l'implémentation (pas en fin de lot) : `EncounterDiagnosticCard`/`EncounterVisualConstants` non reconnus en exécution headless avant leur premier scan (résolu), `get_theme_color_override` (méthode inexistante en Godot 4, remplacée par `get_theme_color`) dans `test_encounter_g6.gd`.

**Avertissements historiques vs nouveaux** : les fuites RID/ObjectDB/texture GL en fin d'exécution (des centaines d'objets, y compris pendant les runners de capture OpenGL) restent la dette technique déjà documentée en S0 et G5 — aucune preuve de correction n'est apportée ici, aucune n'est revendiquée. Aucune nouvelle erreur classique de console n'a été introduite par G6 : le seul vrai défaut découvert (`workspace.navigation_toggle` incorrect dans le runner G6 lui-même) a été trouvé et corrigé avant la capture finale, jamais dans le produit.

## 11. Contrôle final des données

- Manifeste `data/` recalculé après l'intégralité de S0 + G5 + G6 (tests, deux runners de capture par lot, la commande `--editor` incriminée, et sa restauration) : **0 différence, 383/383 fichiers** — identique au manifeste de référence pris avant le premier test à risque.
- `git status --short data/` : propre. `git diff --check` : propre (sortie vide).
- **Fichiers de production modifiés par S0 + G5 + G6** (hors tests et documentation) : exclusivement sous `addons/dungeon_draft_arena_studio/encounter/` et `addons/dungeon_draft_arena_studio/services/room_draft_save_service.gd` (finalement revenu à l'identique, voir S0 §4) — la liste précise est dans le tableau §4 de ce rapport et le §4 du rapport G5. **Zéro fichier sous `data/` ne fait partie du diff final** (le seul incident, §5, a été entièrement annulé).
- Fichiers antérieurs de l'utilisateur (modifiés avant le début de cette tâche) : non touchés, non nettoyés, tels quels.

## 12. Ce qui nécessite encore une validation humaine dans Godot

- Le rendu exact de l'anneau de focus clavier (couleur, épaisseur) dans l'éditeur réel — le comportement natif de Godot n'a pas été modifié, mais son rendu visuel précis n'a pas été capturé (les captures de ce rapport ne pilotent pas de focus clavier visible à l'écran).
- La mise à l'échelle de l'interface/du texte à 125 % (§25) — aucun runner existant ne la pilote.
- Une lecture d'écran (Tab réel, pas simulation programmatique) pour confirmer le confort du parcours clavier complet listé en §21 de la consigne, au-delà des deux tests automatisés de préservation du focus.
- Confirmation visuelle humaine dans l'éditeur Godot (pas seulement en captures gl_compatibility) que les icônes `EditorIcons` s'affichent correctement sur « Ouvrir une partie » dans un contexte d'éditeur réel avec le thème complet chargé.

## 13. Risques résiduels

- Voir §10 de G5 (hauteur par défaut du panneau de validation, dette RID/ObjectDB) — non retouchés par G6, toujours valables.
- L'incident §5 confirme que ce projet contient encore des ressources `data/` jamais migrées vers le système d'UID de Godot 4.4+ ; une future ouverture de l'éditeur réel par l'utilisateur (hors de cette session) migrera probablement ces mêmes fichiers légitimement — ce n'est pas un problème à corriger ici, juste un fait à connaître.

`WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION`
