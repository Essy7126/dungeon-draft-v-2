# Audit des assets legacy — SkillTreeScreen REFINED V2

Date de référence : 2026-07-31  
Branche : `main`  
HEAD : `dd7cbafd5dea14d5e337e792af81516a43d6e32d`

## État de travail préexistant

L’audit a été effectué avant toute modification runtime de la passe V2. Le dépôt contenait déjà la refonte fonctionnelle REFINED précédente. Les 32 textures historiques du dossier `asset/ui/dungeon_draft/arbre_compétences/` et leurs sidecars étaient déjà marqués supprimés dans Git. Le fichier `cadenas.jpg` et son sidecar venaient d’être ajoutés sans être suivis.

Ces suppressions sont considérées comme des modifications préexistantes de l’utilisateur. Elles ne seront ni restaurées ni étendues automatiquement.

## Chaîne de références actuelle

Les scènes suivantes chargent `res://ui/progression/skin/dungeon_draft_skill_tree_skin.tres` :

- `ui/progression/screens/skill_tree_screen.tscn` ;
- `ui/progression/components/skill_tree_graph_view.tscn` ;
- `ui/progression/components/skill_tree_node_detail_panel.tscn` ;
- `ui/progression/components/skill_tree_status_button.tscn` ;
- `ui/progression/components/skill_tree_tooltip_panel.tscn`.

Le skin central référence encore 26 textures supprimées : panneaux, cadres de nodes, plaques de navigation, jauge XP, quatre glyphes d’état, quatre emblèmes de disciplines Elf et neuf glyphes d’effet. Les scènes `skill_tree_discipline_tab.tscn` et `skill_tree_node_view.tscn` utilisent ensuite ces textures par leurs scripts.

`skill_tree_graybox_theme.tres` ne référence aucune image legacy : il définit des `StyleBoxFlat` et des couleurs. Il constitue donc la base sûre du remplacement.

## Catégories et décisions

| Catégorie | Assets historiques | Référence avant V2 | Décision | Remplacement V2 |
|---|---|---|---|---|
| Panneaux métal/pierre | `skill_tree_panel_main.png.png`, `skill_details_panel.png.png` | skin central → écran et détail | remplacer | surfaces charbon et bordures fines par `StyleBoxFlat` |
| Plaques anciennes | `skill_character_tab_base.png`, `skill_discipline_tab_base.png.png` | skin central → statut/branche | remplacer | cartes REFINED plates et rail d’accent |
| Jauge décorée | `skill_xp_bar_frame.png.png` | skin central → branche/statut | remplacer | `ProgressBar` sobre sans texture |
| Cadres de nodes | `skill_node_standard.png.png`, `skill_node_frame_base.png`, `skill_node_root_v2.png.png` | skin central → nodes | remplacer | quatre variations ROOT/STANDARD/SPECIALIZATION/CAPSTONE en `StyleBoxFlat` |
| États | `skill_state_lock.svg.png`, `skill_state_purchased.svg.png`, `skill_state_excluded.svg.png`, `skill_state_pending.svg.png` | skin central → nodes/statut | remplacer | cadenas fourni nettoyé + SVG REFINED check/exclusion/pending |
| Emblèmes Elf | `icon_discipline_elf_archer.png.png`, `icon_discipline_elf_assassin.png.png`, `icon_discipline_elf_mage.png.png`, `icon_discipline_elf_healer.png.png` | skin central → branches/racines | remplacer | icônes de sorts déjà utilisées par le HUD REFINED via catalogue |
| Glyphes d’effets | `glyph_damage.png`, `glyph_area..png`, `glyph_range.svg.png`, `glyph_push.svg.png`, `glyph_movement.svg.png`, `glyph_bleed.svg.png`, `glyph_vulnerability.svg.png`, `glyph_collision.svg.png`, `glyph_duration.svg.png` | skin central → nodes/détail | remplacer | SVG sémantiques originaux, 64×64, transparents |
| Variantes jamais référencées | `386f619c-df3c-406e-8eda-e54a29efc0de.png`, `er skill_node_frame_capstone.png`, `skill_node_capstone.png.png`, `skill_node_capstone_v2.png.png`, `skill_node_root.png.png`, `skill_rank_badge_base.svg.png` | aucune référence texte/runtime trouvée | inutilisé, candidat à suppression ultérieure | aucun |
| Badge de rang historique utilisé | `skill_rank_badge_base_v2.png.png` | skin central → nodes | remplacer | petite plaque de rang en `StyleBoxFlat` |

## Assets partagés ou conservés ailleurs

- Aucun des 32 fichiers supprimés n’est référencé hors du skin de l’arbre et de ses tests historiques.
- `asset/ui/dungeon_draft/arbre_compétences/preview.html` est une preview hors runtime. Il est conservé et n’est pas une source visuelle du nouvel arbre.
- Les portraits, badges de personnages, icônes de sorts et utilitaires sous `asset/ui/character_hud/` sont partagés avec le HUD REFINED et seront conservés/réutilisés.
- Le nouveau `cadenas.jpg` reste intact. Sa source est un JPEG 600×500 sans alpha, avec fond blanc intégré. Une dérivée transparente reproductible sera créée sous `generated/`.

## Risques observés avant remplacement

- Le skin central ne peut plus charger correctement car toutes ses textures sources sont absentes du filesystem.
- Les tests historiques attendent encore les atlas fantasy et doivent être remplacés par des contrats V2 portant sur l’absence de références legacy.
- Les fallbacks dessinés par `SkillTreeEffectGlyph` sont sobres, mais la présence d’une texture legacy dans le skin les court-circuite systématiquement.
- La visual map Archer ne constitue qu’un mapping sémantique. Elle peut être conservée comme donnée de migration, mais la résolution finale doit passer par un catalogue V2 indépendant des cadres historiques.

## Décision de migration

Le runtime V2 conservera le nom de ressource `dungeon_draft_skill_tree_skin.tres` pour ne pas créer de second arbre, mais cette ressource ne référencera plus aucun asset fantasy. Les panneaux et cadres seront dessinés par thème, les icônes seront résolues par un catalogue data-driven et la révélation des rangs sera configurée dans une ressource unique.

Le manifeste machine lisible associé est `artifacts/skill_tree_refined_v2/legacy_assets_manifest.json`.
