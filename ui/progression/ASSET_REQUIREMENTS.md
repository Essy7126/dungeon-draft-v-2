# Arbre de compétences — contrat d’assets (archive du pipeline fantasy)

> Ce document décrit l’ancien pipeline d’import et de recadrage. Depuis REFINED V2,
> aucune texture listée ci-dessous n’est chargée par le runtime de l’arbre. La source
> à jour se trouve dans `data/ui/skill_tree_refined_config.tres`,
> `data/ui/skill_tree_icon_catalog_refined.tres` et le thème REFINED.

Ce document décrit le skin de consultation de l’arbre passif de l’Elfe. Il ne
modifie ni les règles de progression, ni les choix, ni l’XP. Un lancement de
sort réussi rapporte toujours exactement `1 XP` à sa discipline et aucun
système d’énergie n’est impliqué.

## Source de vérité visuelle

- `res://ui/progression/skin/dungeon_draft_skill_tree_skin.tres` centralise les
  textures et tous les recadrages `AtlasTexture`.
- `res://ui/progression/theme/skill_tree_graybox_theme.tres` porte les couleurs,
  styles, focus, halos et connexions.
- `res://ui/progression/skin/elf_archer_visual_map.tres` associe les 19 nœuds
  Archer à des identifiants stables de discipline et d’effet.

Les composants ne chargent aucun PNG directement. Ils demandent une texture au
skin par rôle ou par identifiant, puis `SkillTreeEffectGlyph` conserve le ratio
de la texture dans son conteneur. Les fichiers Recraft restent intacts.

## Audit de la livraison Recraft v2

Les quinze fichiers détectés sont des PNG RGBA 8 bits, même lorsque leur nom
contient `.svg.png` ou `.png.png`. Chacun possède un `.import` Godot valide,
avec `importer="texture"` et `type="CompressedTexture2D"`. Aucun damier aplati
n’a été détecté.

Les pourcentages de transparence ci-dessous correspondent aux pixels dont
l’alpha vaut exactement zéro dans le fichier source. Les régions indiquées sont
les seuls recadrages effectués ; elles ne rééchantillonnent pas les pixels.

| Fichier exact | Source / ratio | Alpha nul | Région runtime / ratio | Rôle et décision |
|---|---:|---:|---:|---|
| `skill_node_root_v2.png.png` | 1024×1024 / 1,000 | 72,503 % | `(64, 64, 896, 896)` / 1,000 | `node_root_texture`, valide et utilisé : extérieur et centre réellement transparents, cadre carré complet |
| `skill_node_capstone_v2.png.png` | 2560×1664 / 1,538 | 89,775 % | — | invalide, non utilisé : plaque horizontale à centre opaque, incompatible avec un cadre de nœud carré transparent |
| `skill_rank_badge_base_v2.png.png` | 2560×1664 / 1,538 | 72,009 % | `(287, 367, 1981, 973)` / 2,036 | `rank_badge_texture`, valide et utilisé : plaque horizontale sans texte, espace central réservé à `R1`…`R5` |
| `skill_state_pending.svg.png` | 2048×2048 / 1,000 | 1,475 % | `(800, 800, 448, 448)` / 1,000 | `state_pending_texture`, valide et utilisé : point d’exclamation centré, sans fond carré opaque |
| `icon_discipline_elf_archer.png.png` | 2048×2048 / 1,000 | 89,529 % | `(380, 445, 1290, 1160)` / 1,112 | `elf_archer`, valide et utilisé |
| `icon_discipline_elf_assassin.png.png` | 2048×2048 / 1,000 | 87,560 % | `(545, 245, 970, 1560)` / 0,622 | `elf_assassin`, valide et utilisé |
| `icon_discipline_elf_mage.png.png` | 2048×2048 / 1,000 | 85,402 % | `(495, 420, 1060, 1200)` / 0,883 | `elf_mage`, valide et utilisé |
| `icon_discipline_elf_healer.png.png` | 2048×2048 / 1,000 | 86,369 % | `(545, 395, 960, 1265)` / 0,759 | `elf_healer`, valide et utilisé |
| `glyph_range.svg.png` | 2048×2048 / 1,000 | 95,406 % | `(300, 785, 1450, 470)` / 3,085 | `range`, valide et utilisé |
| `glyph_push.svg.png` | 2048×2048 / 1,000 | 90,924 % | `(195, 575, 1615, 860)` / 1,878 | `push`, valide et utilisé |
| `glyph_movement.svg.png` | 2048×2048 / 1,000 | 93,590 % | `(555, 605, 950, 840)` / 1,131 | `movement`, valide et utilisé |
| `glyph_bleed.svg.png` | 2048×2048 / 1,000 | 97,312 % | `(890, 575, 275, 910)` / 0,302 | `bleed`, valide et utilisé |
| `glyph_vulnerability.svg.png` | 2048×2048 / 1,000 | 87,361 % | `(570, 585, 905, 1000)` / 0,905 | `vulnerability`, valide et utilisé |
| `glyph_collision.svg.png` | 2048×2048 / 1,000 | 93,070 % | `(125, 740, 1800, 585)` / 3,077 | `collision`, valide et utilisé |
| `glyph_duration.svg.png` | 2048×2048 / 1,000 | 86,327 % | `(600, 465, 1100, 1100)` / 1,000 | `duration`, valide et utilisé |

Les quatre icônes n’intègrent ni texte ni cadre. Leur région runtime est serrée
autour de la silhouette afin de conserver une échelle perceptuelle cohérente
entre 42 et 96 pixels. Les sept glyphes n’intègrent aucun cadre ; leur région
est adaptée à leur silhouette naturelle et reste lisible entre 20 et 36 pixels
sans étirement.

Le fichier pending contient un résidu diffus à très faible alpha hors de son
motif. Le recadrage runtime élimine l’immense marge source ; il ne produit ni
fond opaque ni rectangle visible aux tailles 18–28 pixels.

## Mapping runtime

| Identifiant du skin | Fichier réellement utilisé |
|---|---|
| `node_root_texture` | `skill_node_root_v2.png.png` |
| `node_capstone_texture` | `skill_node_frame_base.png` — fallback conservé |
| `rank_badge_texture` | `skill_rank_badge_base_v2.png.png` |
| `state_pending_texture` | `skill_state_pending.svg.png` |
| `elf_archer` | `icon_discipline_elf_archer.png.png` |
| `elf_assassin` | `icon_discipline_elf_assassin.png.png` |
| `elf_mage` | `icon_discipline_elf_mage.png.png` |
| `elf_healer` | `icon_discipline_elf_healer.png.png` |
| `range` | `glyph_range.svg.png` |
| `push` | `glyph_push.svg.png` |
| `movement` | `glyph_movement.svg.png` |
| `bleed` | `glyph_bleed.svg.png` |
| `vulnerability` | `glyph_vulnerability.svg.png` |
| `collision` | `glyph_collision.svg.png` |
| `duration` | `glyph_duration.svg.png` |
| `damage` | `glyph_damage.png` — intégration existante conservée |
| `area_or_pierce` | `glyph_area..png` — intégration existante conservée |

Le même identifiant alimente les onglets, le bouton HUD Archer, son tooltip,
les nœuds et le panneau de détails. Assassin, Mage et Soigneur utilisent chacun
leur texture dédiée ; aucune icône Archer n’est substituée. Les quatre
identifiants `elf_*` sont aussi exposés comme glyphes afin qu’un visual map
puisse demander la même icône dans la zone principale d’un nœud, comme le fait
la racine Archer.

## Fallbacks conservés

Le capstone v2 est volontairement ignoré. Les quatre capstones Archer continuent
d’utiliser le cadre octogonal `skill_node_frame_base.png`, avec leur halo et
leurs états actuels. Le cadre reste distinct de la nouvelle racine.

Tous les dessins programmatiques de `SkillTreeEffectGlyph` restent présents.
Ils sont utilisés lorsqu’un skin est absent, lorsqu’un identifiant futur n’a pas
de texture, ou si une livraison ultérieure est refusée. Le fallback du badge,
du pending et des identifiants désormais mappés n’est donc pas supprimé ; il est
simplement inactif avec le skin Dungeon Draft courant.

## Assets historiques

Les assets déjà intégrés restent inchangés : cadre principal, panneau de détail,
nœud standard, onglets, jauge XP, verrou, sélection, exclusion, dégâts et
zone/perforation. Les anciens `skill_node_root.png.png` et
`er skill_node_frame_capstone.png` restent invalides à cause de leur damier
aplati. `skill_node_capstone.png.png` et `skill_rank_badge_base.svg.png` sont un
ancien doublon de plaque horizontale et ne sont pas utilisés pour les nœuds.
`preview.html` et `386f619c-df3c-406e-8eda-e54a29efc0de.png` restent des
références, jamais chargées au runtime.

## Procédure de remplacement future

1. Déposer le fichier dans
   `res://asset/ui/dungeon_draft/arbre_compétences/` et laisser Godot produire
   son `.import`.
2. Vérifier les dimensions, le ratio, le canal alpha et le contenu visuel. Un
   damier aplati ou un cadre à centre opaque est refusé.
3. Vérifier la silhouette à sa taille runtime minimale. Pour un grand canevas
   transparent, définir un `AtlasTexture` dans le skin avec une petite marge
   autour du motif.
4. Affecter la texture au rôle exporté ou au dictionnaire
   `discipline_icons`/`effect_glyphs`. Ne jamais ajouter un chemin PNG dans un
   composant.
5. Conserver le fallback programmatique et l’identifiant stable.
6. Exécuter `test_skill_tree_skin_ui.gd`, puis contrôler le laboratoire à
   1920×1080, 1600×900 et 1280×720.

Une texture ne décide jamais si un nœud est accessible. L’autorité reste la
progression et `SkillTreeResolver` ; l’UI ne traduit que leur présentation.
