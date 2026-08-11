# Audit courant — alignement des dalles permanentes et palette Terrain

Audit réalisé avant correction le 11 août 2026 dans
`C:/Users/paolo/Documents/dungeon-draft-v-2`, branche `main`, HEAD
`29bf19719be6988898bdbef4c16f5d5b44d7b2d6`, identique à `origin/main`
(avance/retard 0/0). Godot 4.7.1, GUT 9.7.1.

La sauvegarde de prévol autoritative est :

`C:/Users/paolo/.codex/visualizations/2026/08/06/019fd6a4-3e24-7aa2-91c6-ccf0929a0938/arena_tile_alignment_preflight_20260811_215920`

- 76 fichiers suivis modifiés ;
- 165 fichiers non suivis ;
- 241 entrées dans le manifeste SHA-256 ;
- patch binaire SHA-256
  `520f4671788a6547a713b7ba1a9fe6602970135c48f8f2adfd0fd4c948758955` ;
- archive des non-suivis SHA-256
  `2e93ee62c1a16a4694eff7a57d30c81e349877336db808115ee34251645296b7` ;
- aucun fichier staged et aucun conflit.

Les patches protégés appartiennent aux chantiers déjà attribués : parité du test
direct et topologie, surfaces dynamiques, bundles/intégration transactionnelle,
catalogue étendu, ainsi que les slices Odyssey/Achilles/VFX. Le dossier gelé
`res://data/arenas/produced/room_01_forest/` est inventorié séparément et reste
hors de cette correction.

## Réponses causales

### 1. Déclaration de `neutral`

OBSERVÉ — `neutral` est déclaré dans
`res://addons/dungeon_draft_arena_studio/catalog/terrains/neutral.tres`, chargé
explicitement par `ArenaCatalogService.TERRAIN_PATHS`. Il est marqué
`dynamic_catalog=true`, `CellType.NORMAL`, praticable, coût 1.

### 2. Asset utilisé

OBSERVÉ — le catalogue référence directement
`res://tools/labs/dynamic_arena/assets/raw/neutre.png`.

### 3. Dimensions comparées

OBSERVÉ — `neutre.png` brut fait 1024×1024. Le `stone` réellement utilisé par
le catalogue n'est pas le brut 1024×1024 : il s'agit de
`res://tools/labs/dynamic_arena/assets/normalized/stone.png`, 256×128. Les
terrains permanents `water`, `ice` et `lava` utilisent eux aussi des fichiers
normalisés 256×128.

### 4. Marges transparentes

OBSERVÉ — pour `neutre.png`, le moindre alpha non nul occupe le canvas complet
`[0,0 → 1024,1024]` à cause de pixels de frange. À alpha > 2/255, le contenu
utile est `[29,185 → 996,870]`. À alpha > 64/255, il est
`[30,188 → 994,869]`.

Le brut `stone.png` a une géométrie utile pratiquement identique : à alpha
> 2/255, `[29,187 → 995,870]`, et à alpha > 64/255,
`[30,188 → 994,869]`. Sa version normalisée 256×128 reçoit ensuite le masque
losange commun du normaliseur : bounds alpha `[0,0 → 256,128]` à tous les seuils
0–254/255.

### 5. Renderer exact

OBSERVÉ — les textures permanentes passent toutes par
`ArenaTerrainRenderPlanService`, puis par le même pipeline :

- canvas Studio : `ArenaStudioCanvas._draw_cells()` + `draw_polygon()` ;
- preview/runtime : `ArenaTerrainVisualRenderer` ;
- transformation commune : `ArenaTileProjectionService`.

Il n'existe aucune branche `neutral`, aucun offset spécifique et aucun pivot
spécifique à un stable_id.

### 6. Pivot, offset et ancrage

OBSERVÉ — le canvas associe les quatre sommets du polygone logique aux UV
normalisées `(0.5,0)`, `(1,0.5)`, `(0.5,1)`, `(0,0.5)`.

Le renderer Node2D place la racine au centre du même polygone, utilise un
`Sprite2D.centered=false`, puis applique la transformation affine de
`ArenaTileProjectionService.sprite_transform()`. Le losange source est défini
par le canvas complet de la texture.

DIVERGENCE — cette convention est exacte pour un fichier normalisé 256×128 dont
le masque remplit le losange. Elle projette en revanche le canvas brut 1024×1024
de `neutral`, alors que son contenu utile n'en occupe qu'une partie. Le contenu
est donc visuellement réduit et décalé à l'intérieur de la cellule.

### 7. Polygone de projection

OBSERVÉ — le polygone cible vient toujours de
`GridTransformService.cell_polygon()` ou de `grid_view.get_cell_polygon()`. Il
est identique pour `stone`, `neutral`, `water`, `ice` et `lava` sur une même
cellule. Les overlays, sélections, highlights et la grille utilisent ce même
polygone logique.

### 8. Écriture du brush `neutral`

OBSERVÉ — `ArenaDynamicEditingService.paint_terrain()` écrit bien
`terrain_id=&"neutral"` via `ArenaTerrainRegistry.configure_cell()`, puis
synchronise la projection runtime. Les tests du catalogue étendu confirment la
mutation, le reload temporaire et l'identité des fingerprints.

### 9. Cause des autres options non peignables

OBSERVÉ — deux dropdowns concurrents sont construits en dur dans
`ArenaStudioMain` :

- le dropdown historique `terrain_option` liste `normal`, `neutral`, `wall`,
  `hole`, `lava`, `ice`, `shadow`, `rune` ;
- le dropdown dynamique liste `void`, `stone`, `neutral`, `water`, `ice`,
  `lava`.

Le premier propose comme options actives `wall`, `hole`, `shadow` et `rune`,
alors que leurs Resources ont `dynamic_catalog=false` et aucune
`base_texture`. Le brush accepte néanmoins toute Resource existante. La working
copy mute donc, puis le plan permanent retourne `texture_missing` et aucune
dalle ne peut apparaître : l'option semble ne rien faire.

Le second dropdown contient les bons identifiants, mais il duplique lui aussi
les règles au lieu de demander au catalogue, au thème et au document courant.
Il ne peut ni expliquer un refus ni se désactiver lorsque le mode PAINTED ou la
politique HYBRID masque la dalle.

DIVERGENCE — le thème `forest` ne déclare pas encore `neutral`, alors que le
catalogue et le profil modulaire par défaut le déclarent. Les champs
`ArenaThemeDefinition.terrain_ids` et `ArenaModularVisualProfile.terrain_ids`
ne pilotent pas actuellement le dropdown ni la validation du brush.

Conclusion causale : les « options fantômes » ne viennent pas d'une incapacité
de `ArenaDynamicEditingService` à écrire `stone/water/ice/lava`. Elles viennent
de listes UI codées en dur, d'une validation trop permissive et de l'absence
d'autorité commune reliant catalogue, thème, profil, mode visuel et renderer.

### 10. Source de vérité actuelle

OBSERVÉ — aucune source unique n'existe avant correction :

- le catalogue définit les terrains ;
- le thème et le profil contiennent des listes de capacités ;
- les dropdowns recopient leurs propres listes ;
- le brush vérifie seulement que l'identifiant existe ;
- le plan de rendu vérifie la texture et la politique du mode après mutation.

DÉCISION VALIDÉE — la correction doit centraliser ces décisions dans un contrat
`get_paintable_permanent_terrains(arena)` consommé par les deux dropdowns et par
le brush. Une option active devra posséder une texture permanente normalisée,
être autorisée par le thème/profil et être réellement visible dans le mode du
document. Les entrées informatives non compatibles seront désactivées avec une
raison explicite.

## Conclusion de l'audit

Cause exacte du décalage : `neutral.tres` contourne le normaliseur existant et
référence le PNG brut 1024×1024, tandis que tous les autres sols permanents du
périmètre utilisent le contrat normalisé 256×128.

Cause exacte de la palette mensongère : les UI historiques et dynamiques
possèdent des tableaux indépendants du catalogue et le brush ne valide pas la
capacité de rendu permanente. Des Resources sans texture deviennent donc des
options actives qui mutent la logique mais disparaissent visuellement.
