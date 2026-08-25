# Studio Terrain — contrat spatial

Statut : **WORKTREE_CANDIDATE**

Date : 2026-08-25

Godot vérifié : `4.7.stable.official.5b4e0cb0f`

Ce contrat remplace le parcours nominal en sept étapes par un éditeur spatial
direct. Les services historiques de workflow restent disponibles pour calculer
l'état du document et assurer la compatibilité, mais ils ne pilotent plus la
navigation ni la visibilité des outils.

## 1. Interface nominale

```text
en-tête Terrain : Accueil · Nouveau · Ouvrir · Mode guidé/avancé · aperçu
                  état de validation · Tester · Intégrer
rail gauche     : tous les outils, toujours accessibles
                  checklist repliable, informative et non bloquante
centre          : canvas éditable + bibliothèque visuelle filtrable
droite          : propriétés de la sélection spatiale
bas             : validation détaillée, historique, rapport et console
```

- Le rail d'étapes, le guidage précédent/continuer et les palettes dépendantes
  d'une étape ne font plus partie de l'interface nominale.
- Choisir un outil ne change aucune étape. `set_current_step()` reste un
  adaptateur de compatibilité sans effet sur le contexte spatial.
- La checklist résume cinq états : forme valide, sols définis, départs
  présents, décor prêt et absence de problème bloquant. Elle ne verrouille
  jamais le canvas.
- L'état de validation est recalculé pendant l'édition et reste visible dans
  l'en-tête. Le détail s'ouvre dans le tiroir de validation.

## 2. Bibliothèque data-driven

`TerrainPlaceableCatalogService` est l'autorité de la bibliothèque. Il fusionne
les catalogues existants de sols et de murs avec
`catalog/placeables/terrain_library.tres`. Chaque entrée fournit un identifiant
stable, une famille, un type de placement, un résultat en jeu, des badges, une
vignette et un payload métier.

Les familles visibles sont : **Sols**, **Obstacles**, **Départs**,
**Interactifs** et **Décor**. Les filtres **Tous**, **Récents** et **Favoris**
complètent la recherche textuelle. L'interface ne contient pas de table cachée
qui traduise un identifiant de carte vers un identifiant de gameplay.

Un clic sélectionne une entrée et active l'outil correspondant. `Alt` + clic
sur le canvas prélève l'élément spatial sous le pointeur et resélectionne son
entrée. Le clic droit efface pendant tout le geste continu.

## 3. Placement et sélection directs

- Sol, mur, départ et marqueur de décor se placent directement depuis la
  bibliothèque.
- Un clic sur un élément existant ouvre ses propriétés : nom, cases, activation
  et équipes autorisées quand ces propriétés existent.
- Un vortex peut être renommé, désactivé, limité à des équipes, réédité ou
  supprimé depuis l'inspecteur.
- Les gestes composites de vortex conservent un instantané initial. Une case
  d'impulsion se termine après un clic, un portail à deux cases après deux
  clics, et un portail multiple avec l'action explicite **Terminer le
  placement**. Toute la séquence produit une seule action d'historique ;
  `Échap` restaure exactement l'instantané initial.

## 4. Sols peints et mode hybride

La palette des sols est découverte depuis `ArenaCatalogService`, sans liste
figée. Sur un terrain peint, poser un sol spécial ou à effet active
automatiquement le mode hybride avec la politique `NON_BASE` au sein du même
geste. Restaurer le sol de base au clic droit n'exige aucun changement de mode.

Peindre un autre sol ordinaire sur un terrain peint demande une activation
explicite de tous les sols définis. Cette opération passe en hybride avec la
politique `ALL_DEFINED` et forme une action d'historique séparée et annulable.

## 5. Création et responsive

L'assistant propose deux intentions :

1. **Depuis une illustration** : choisir l'image, puis créer une grille 3 × 3
   centrée et l'ajuster directement ;
2. **Avec des tuiles** : créer immédiatement un terrain 10 × 8 prêt à peindre.

Sous 1 400 px de large, l'inspecteur droit se replie dans un tiroir superposé
au canvas. Sous 760 px de haut, la bibliothèque réduit sa hauteur. Le mode
Focus mémorise puis restaure sa visibilité avec celle des autres panneaux.

## 6. Contrats conservés

Les contrats `Enregistrer le brouillon`, `Tester` et `Intégrer à la partie`,
la sauvegarde transactionnelle, la working copy, la projection runtime non
mutante, la validation métier, l'historique Annuler/Rétablir, le routeur
d'entrées unique et l'intégration `UPDATE` restent inchangés.

Le mode guidé continue de masquer les réglages avancés. La visite historique
reste une aide facultative ; elle n'est pas une navigation de production.

## 7. Composants principaux

| Fichier | Rôle |
|---|---|
| `domain/terrain_placeable_definition.gd` | schéma d'un élément plaçable |
| `domain/terrain_placeable_catalog.gd` | catalogue Resource |
| `services/terrain_placeable_catalog_service.gd` | fusion et découverte des entrées |
| `services/terrain_placement_session.gd` | geste composite annulable |
| `ui/terrain/terrain_tool_palette.gd` | rail permanent |
| `ui/terrain/terrain_checklist_panel.gd` | checklist informative |
| `ui/terrain/terrain_library_panel.gd` | recherche, filtres et cartes |
| `ui/terrain/terrain_inspector_panel.gd` | propriétés de la sélection |
| `ui/arena_studio_canvas.gd` | hit-test, prélèvement et aperçu fantôme |
| `ui/arena_studio_main.gd` | orchestration de l'unique workspace |

Aucune règle de gameplay, valeur d'équilibrage, rencontre, récompense, vague,
IA ou donnée de production officielle n'est modifiée par ce chantier.
