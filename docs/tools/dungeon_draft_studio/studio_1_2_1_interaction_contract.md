# Dungeon Draft Studio 1.2.1 — contrat d’interaction

## Audit de l’ancien montage et cause exacte

`ArenaStudioMain._build_canvas_panel()` instancie auparavant
`DynamicArenaLab.tscn` dans un `SubViewport` lui-même contenu dans un
`SubViewportContainer` plein cadre. `show_dynamic_construction()` masquait le
canvas Arena puis affichait ce container. La scène instanciée apportait sa
toolbar standalone complète et son propre `_unhandled_input()`.

Le blocage ne provenait donc pas d’un simple `mouse_filter` : le Studio
remplaçait son canvas par un second éditeur plein écran. Le flux concurrent
était `Studio/Canvas._gui_input` d’un côté et
`DynamicArenaLab._unhandled_input` dans un autre viewport de l’autre. Les deux
systèmes possédaient leurs contrôles, leur état d’outil et leurs commandes de
document. L’ordre des Controls, le container plein cadre et la propagation du
SubViewport détournaient naturellement la souris et le focus de la map Studio.

Les overlays du canvas mêlaient en outre contour/poignées de transformation,
ancres de calibration, segments de mesure, résidus, pivot et aides de gameplay
dans le même dessin. Les opérations disponibles étaient translation,
rotation, échelle et axes indépendants, mais sans identification visuelle
suffisante ni poignée dédiée à l’ouverture angulaire.

## Nouveau montage

Le chemin intégré ne crée plus ni scène Lab, ni SubViewport, ni container.
`WorkspaceMode.DYNAMIC_CONSTRUCTION` conserve le canvas existant et montre une
palette contextuelle. Le graphe devient :

`StudioWorkspace → ArenaStudioMain → ArenaStudioCanvas → ArenaInputRouter → outil actif`

`GridAffineGizmo` est un enfant décoratif du canvas, sans traitement d’input.
Terrain, murs et contenus spéciaux passent par
`ArenaDynamicEditingService`. Le Lab autonome conserve son host et sa toolbar,
mais délègue au même service et à une façade du même routeur.

Les données canoniques restent `ArenaEditSession.working_arena`, son
`StudioHistoryController`, puis `grid_origin`, `axis_x` et `axis_y` pour toute
transformation. Le nouveau gizmo couvre translation, axes X/Y, rotation,
échelle uniforme, pivot éditeur et angle Symétrique/Conserver X/Conserver Y.

## Invariants

1. Une arène ouverte possède une seule `ArenaEditSession`, une seule
   `ArenaDefinition` de travail et un seul `StudioHistoryController`.
2. **Lab / Construction dynamique** change le mode du workspace existant. Il
   ne crée ni `Window`, ni `Popup`, ni `SubViewportContainer`, ni
   `DynamicArenaLab` dans le Studio.
3. Le canvas `ArenaStudioCanvas` reste le même objet entre Édition,
   Construction dynamique et retour à l’édition. Sélection, zoom, session et
   historique sont conservés.
4. `ArenaInputRouter` distribue chaque instance d’`InputEvent` au plus une
   fois. Un geste possède un mode et un consommateur uniques.
5. Un geste continu produit au plus une entrée d’historique. Les previews
   intermédiaires ne sont pas des actions.
6. Échap, clic droit pendant un geste, perte de focus, changement d’outil,
   changement de document, fermeture ou réintégration restaurent exactement
   l’instantané initial, sans entrée d’historique.
7. Le pivot du gizmo est un état éditeur. Son déplacement ne modifie pas
   l’`ArenaDefinition` et ne rend pas la carte dirty.
8. La projection runtime est toujours dérivée de `grid_origin`, `axis_x` et
   `axis_y`. Aucun calque visuel ne possède une géométrie concurrente.

## Séparation des calques

- **Transformation** : grille et `GridAffineGizmo`; ancres et résidus masqués.
- **Ancres** : points/mesures/résidus; gizmo affine masqué.
- **Gameplay** : rendu de bataille; gizmo, ancres et aides éditeur masqués.
- **Construction dynamique** : même canvas, palette contextuelle et outil
  courant; aucun panneau de document du Lab autonome n’est dupliqué.

## Autorité et historique

Toutes les opérations dynamiques et affines modifient la working copy de la
session active. Le runtime est resynchronisé par `ArenaRuntimeBridge` après
chaque preview valide et après undo/redo. Une action est enregistrée seulement
si l’empreinte avant/après diffère.
