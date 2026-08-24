# Studio Terrain — contrat de la refonte

Statut : **WORKTREE_CANDIDATE**
Date : 2026-08-24
Base : `main`, HEAD `d566b4480e928c16ce6d5dd924d3e4031fca4bb2`
Audit d'origine : `docs/audits/terrain_studio_complete_audit_2026-08-24.md`
Godot vérifié : `4.7.stable.official.5b4e0cb0f`

Ce document remplace, pour le domaine Terrain, les parties du guide débutant et
du guide d'authoring rapide qui décrivaient l'ancienne barre interne, le
sélecteur `Création / Vérification / Avancé` et la visite de 22 pages comme
parcours nominal.

## 1. Identité et vocabulaire

- **PROUVÉ** — l'onglet visible s'appelle `TERRAINS` et porte le sous-titre
  `Construire la zone tactique d'une salle`. Les noms internes
  `ArenaDefinition`, `ArenaStudioMain`, `ArenaEditSession` sont inchangés.
- `TerrainVocabulary` est l'autorité unique du glossaire. Le parcours nominal
  emploie : **Point de départ** (spawn), **Premier plan** (foreground),
  **Zones masquées** (occlusion), **Résultat en jeu** (runtime),
  **Dossier de production** (bundle), **Depuis une illustration** / **Avec des
  tuiles** / **Illustration avec tuiles spéciales** (PAINTED / MODULAR /
  HYBRID).
- **PROUVÉ** — `test_24_guided_vocabulary_avoids_technical_terms` interdit ces
  termes techniques dans les libellés d'étapes, d'objectifs, de consignes et de
  cartes de création.

## 2. Écran d'accueil

`TerrainHomePanel` est le point d'entrée du domaine. Il expose :

1. `Modifier le terrain de la salle active` — désactivé, avec une explication,
   quand aucune salle n'est sélectionnée ;
2. `Créer un nouveau terrain` ;
3. `Ouvrir un terrain existant` ;
4. `Faire l'exercice d'entraînement` ;
5. `Que veulent dire ces mots ?` — glossaire ;
6. la liste des terrains récemment ouverts, ou son état vide explicite.

L'ouverture automatique de la salle active reste effectuée par
`ensure_initial_arena_loaded()`, mais elle n'empêche plus l'accueil : `_ready()`
appelle `show_home()` après le chargement.

## 3. Deux niveaux seulement

- Un unique interrupteur `Mode guidé` / `Mode avancé`, actif en guidé par
  défaut, porté par `ArenaStudioMain.guided` et persisté hors Resources.
- Un unique sélecteur d'aperçu : `Structure`, `Décor`, `Résultat en jeu`. Le
  sélecteur `Logique / Art / Jeu` du shell est masqué quand l'onglet Terrain est
  actif.
- Les presets de disposition (`Construction`, `Calibration`, `Gameplay`,
  `Aperçu final`), le laboratoire autonome et les transferts sont des
  préférences avancées : ils disparaissent du shell en mode guidé.
- `_on_mode_selected()` subsiste comme adaptateur de compatibilité : `2`
  bascule en avancé, `1` ouvre l'étape Vérifier, `0` revient au guidé.

**PROUVÉ** — `advanced_only_controls()` énumère les contrôles qui ne doivent
jamais être visibles en mode guidé ; le test 04 les vérifie un par un.

## 4. Parcours en sept étapes

`TerrainWorkflowService` est le modèle métier du parcours. Il ne connaît aucun
nœud d'interface.

| # | Étape | Terminée quand |
|---|---|---|
| 1 | Départ | un terrain est ouvert |
| 2 | Forme | au moins une case jouable et une bordure |
| 3 | Sols | chaque case jouable porte un sol |
| 4 | Obstacles et départs | au moins un départ héros et un départ ennemi |
| 5 | Décor | illustration présente et alignée, ou terrain en tuiles |
| 6 | Vérifier | rapport de validation sans erreur |
| 7 | Tester et intégrer | intégré à une salle et document propre |

Chaque étape expose : objectif en une phrase, état (`à faire`, `en cours`,
`terminé`, `erreur`) avec **glyphe et mot** — jamais la couleur seule —,
éléments manquants, action principale et prochaine action recommandée.

Le parcours reste libre : `set_current_step()` ouvre n'importe quelle étape, et
choisir un outil repositionne l'étape correspondante.

`readiness()` distingue `Terrain incomplet`, `Prêt à tester` et
`Prêt à intégrer`.

## 5. Disposition

```
barre globale du shell : Annuler · Rétablir · Enregistrer le brouillon ·
                         Vérifier · Tester · Intégrer à la partie
en-tête Terrain        : TERRAINS · sous-titre · Accueil · + Nouveau terrain ·
                         Ouvrir… · Mode guidé · aperçu · état du document
rail gauche            : les 7 étapes + objectif + manquants + action
zone centrale          : guidage contextuel, palette contextuelle, canvas
inspecteur droit       : uniquement l'étape, l'outil ou la sélection en cours
tiroir bas             : Validation · Historique · Rapport · Console · Analyse
```

- **PROUVÉ** — l'en-tête Terrain n'appartient pas à `top_bar` : `StudioWorkspace`
  masque la barre historique, l'en-tête reste visible.
- Le rail, la palette et l'inspecteur défilent : leur hauteur minimale ne peut
  plus repousser le canvas ni le tiroir hors de la fenêtre.
- **PROUVÉ** — à 1280 × 720, les six vues capturées tiennent dans la fenêtre
  (marqueur `TERRAIN_STUDIO_LAYOUT` du runner de captures).

### Responsive

- Sous 1 180 px de large, l'inspecteur se replie et un bouton permanent
  `Ouvrir l'inspecteur ▸` l'ouvre en tiroir par-dessus le canvas.
- Sous 760 px de haut, la palette défile dans moins de place, la barre
  historique disparaît (son contenu est dupliqué ailleurs) et l'ouverture du
  tiroir efface temporairement le guidage sans modifier la préférence.
- Le mode Focus (`Tab`) conserve puis restaure exactement la visibilité
  précédente des panneaux.

## 6. Assistant de création

`TerrainCreationWizard` remplace le formulaire technique :

1. trois cartes d'intention ;
2. puis uniquement nom visible, dimensions, orientation du camp et
   illustration si le choix en demande une ;
3. bouton final adapté : `Créer et peindre` ou `Créer et aligner l'illustration`.

Identifiant stable et calibration de référence n'apparaissent que dans
`RÉGLAGES AVANCÉS`.

## 7. Outils par intention et palette des sols

`TerrainToolPalette` regroupe les outils par étape. `TerrainFloorPalette`
présente chaque sol avec sa texture, son nom français, un pictogramme `⚠` quand
le sol applique un effet, et son comportement en infobulle. Deux familles sont
séparées visuellement : **sols permanents** enregistrés dans le terrain, et
**surfaces temporaires** créées pendant le combat par un sort — ces dernières ne
sont pas peignables et leurs simulations techniques sont passées en mode avancé.

`ArenaStudioMain.TOOL_SHORTCUT_KEYS` est l'autorité unique du raccourci affiché
et du raccourci réellement traité : `1` à `0` puis `A`. Les deux ne peuvent plus
diverger, un test le vérifie touche par touche.

## 8. Validation actionnable

`TerrainValidationPanel` remplace la liste plate par des cartes :
ce qui ne va pas, pourquoi c'est important, l'emplacement, puis `Me montrer`,
`Sélectionner la case` et — seulement pour une correction déterministe, sûre et
annulable — `Corriger automatiquement`.

`ArenaValidationFixService` n'accepte que trois corrections :
`create_border`, `make_border_non_playable`, `move_spawn_to_nearest_valid`. Le
déplacement de départ utilise un parcours en largeur à ordre de voisins fixe :
deux exécutions donnent toujours la même case. Les suggestions de navigation
(`select_isolated_cells`, `select_chokepoints`, `restart_calibration`) ne
proposent aucune correction. Toute correction passe par l'historique et reste
annulable.

## 9. Brouillon, test et intégration

| Action | Effet | Écrit où |
|---|---|---|
| `Enregistrer le brouillon` | garde le travail personnel | `user://dungeon_draft_studio/arena_studio/drafts/` |
| `Tester` | vrai combat sur la version en cours | copie temporaire sous `user://` |
| `Intégrer à la partie` | publie dans une salle, après résumé | transaction de production |

`TerrainWorkflowService.document_state_text()` produit l'état permanent :
`Brouillon modifié — non intégré`, `Intégré dans Principale · Salle 2`,
`Modifications locales non publiées — dernière intégration : …`.

L'étape `Tester et intégrer` est le seul endroit où destination, chemins et
fichiers de production apparaissent. `UPDATE` reste l'action recommandée et
`REPLACE` reste explicitement avancée.

### Sauvegarde canonique transactionnelle

`ArenaCanonicalSaveTransactionService` applique au bouton le plus simple le même
contrat que la production :

1. validation ; 2. détection de conflit externe ; 3. plan des fichiers créés et
modifiés ; 4. récupération et copies de secours ; 5. écritures ; 6. relecture
sans cache ; 7. vérification d'empreinte ; 8. rollback complet en cas d'échec ;
9. réouverture d'une working copy propre par l'appelant.

`ArenaSerializer.materialize_staged_visual_assets()` ne laisse plus de fichier
partiel : en cas d'échec en cours de copie, les fichiers déjà créés sont
supprimés. La transaction matérialise les images sur une **copie de
publication** ; les nouveaux chemins ne sont reportés sur le document édité
qu'après la vérification finale.

## 10. Projection runtime non mutante

- `ArenaDefinition.authoring_document` marque la working copy. Le champ n'est ni
  exporté, ni sérialisé, ni recopié par `restore_snapshot()`.
- `ArenaRuntimeBridge.sync_runtime_resources()` est strictement non mutante sur
  un document d'auteur : elle n'écrit plus `grid_layout`,
  `painted_map_visual_data`, les zones de départ, les ennemis, `room_name`,
  `arena_visual_profile` ni `battle_scene` dans la working copy.
- `ArenaEditSession.runtime_projection()` construit et met en cache une
  projection synchronisée, invalidée à chaque `commit()` et `apply_snapshot()`.
- `ArenaRuntimeBridge.build_runtime_projection()` est la voie supportée pour
  obtenir ces champs à partir d'un document d'auteur.

`RoomIntegrationFieldPolicy` classe `arena_visual_profile`, `battle_scene` et
les ennemis calculés comme `DERIVED_RUNTIME` lorsqu'ils appartiennent à une
`ArenaDefinition` marquée comme document d'auteur. Les mêmes champs d'une
`RoomData` historique ou d'une `ArenaDefinition` déjà produite conservent leur
autorité précédente : la fusion `UPDATE` continue donc de préserver les
données de gameplay de la salle cible.

## 11. État d'interface persistant

`TerrainStudioUiStateService` écrit `user://dungeon_draft_studio/ui_state/terrain_studio.json` :
mode guidé, étape courante, guidage visible, tiroirs, aperçu et terrains
récents. Aucune Resource métier n'y est sérialisée.

## 12. Composants extraits

| Fichier | Rôle |
|---|---|
| `services/terrain_vocabulary.gd` | glossaire et libellés utilisateur |
| `services/terrain_workflow_service.gd` | modèle des sept étapes |
| `services/terrain_studio_ui_state_service.gd` | état d'interface persistant |
| `services/arena_validation_fix_service.gd` | corrections déterministes |
| `services/arena_draft_save_service.gd` | brouillon local |
| `services/arena_canonical_save_transaction_service.gd` | sauvegarde transactionnelle |
| `ui/terrain/terrain_home_panel.gd` | accueil |
| `ui/terrain/terrain_header_bar.gd` | identité et actions permanentes du domaine |
| `ui/terrain/terrain_creation_wizard.gd` | assistant de création |
| `ui/terrain/terrain_workflow_rail.gd` | rail des étapes |
| `ui/terrain/terrain_tool_palette.gd` | palettes contextuelles |
| `ui/terrain/terrain_floor_palette.gd` | palette visuelle des sols |
| `ui/terrain/terrain_guidance_panel.gd` | guidage contextuel |
| `ui/terrain/terrain_validation_panel.gd` | cartes de validation |
| `ui/terrain/terrain_inspector_panel.gd` | inspecteur contextuel |
| `ui/terrain/terrain_finalize_panel.gd` | étape Tester et intégrer |

`ArenaStudioMain` orchestre ; aucun second éditeur, second workspace, seconde
session ni second routeur d'entrées n'est créé.

## 13. Invariants conservés

Un seul `StudioWorkspace`, un seul `StudioProjectContext`,
`StudioReferenceGraphService`, `ArenaEditSession` et sa working copy,
l'historique Annuler/Rétablir, `ArenaInputRouter` et son consommateur unique, le
canvas avec son zoom, sa sélection et son état de session, les registres
data-driven, la validation métier, le test depuis la working copy dans la vraie
scène, les récupérations et points de restauration, le mode Focus, la production
et l'intégration transactionnelles, et la distinction entre terrains permanents
et surfaces temporaires de sorts.

Aucune règle de gameplay, valeur d'équilibrage, rencontre, récompense, vague, IA
ou donnée de production officielle n'est modifiée par ce chantier.
