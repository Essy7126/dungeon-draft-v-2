# Arbre de compétences — contrat d’assets

Ce document décrit le skin de consultation utilisé par l’arbre passif de l’Elfe. Il ne modifie ni les règles de progression, ni les choix, ni l’XP. La règle fonctionnelle reste : un lancement de sort réussi rapporte exactement `1 XP` à sa discipline ; aucun système d’énergie n’est impliqué.

## Source de vérité visuelle

Le skin est centralisé dans :

- `res://ui/progression/skin/dungeon_draft_skill_tree_skin.tres` pour les textures ;
- `res://ui/progression/theme/skill_tree_graybox_theme.tres` pour les couleurs, styles, focus et connexions ;
- `res://ui/progression/skin/elf_archer_visual_map.tres` pour l’association data-driven entre les 19 nœuds affichés et leurs glyphes.

Les composants ne chargent pas directement les PNG. Ils reçoivent le skin et demandent une texture par rôle. Les zones utiles des grandes planches sont extraites avec `AtlasTexture` ; les fichiers source restent intacts.

## Audit du dossier fourni

Tous les PNG ci-dessous possèdent un fichier `.import` Godot et sont importés comme `CompressedTexture2D`.

| Fichier source | Dimensions | Usage réel | Décision |
|---|---:|---|---|
| `skill_tree_panel_main.png.png` | 2688×1536 | cadre de l’écran complet | utilisé, recadré |
| `skill_details_panel.png.png` | 1536×2688 | panneau de détail droit | utilisé, recadré et étiré en 9-patch |
| `skill_node_standard.png.png` | 2048×2048 | cadre octogonal standard | utilisé, recadré |
| `skill_node_frame_base.png` | 2048×2048 | cadre octogonal générique | utilisé pour la racine et les capstones |
| `skill_character_tab_base.png` | 2560×1664 | bouton HUD de progression | utilisé, recadré |
| `skill_discipline_tab_base.png.png` | 3072×1536 | onglets Archer/Assassin/Mage/Soigneur | utilisé, recadré |
| `skill_xp_bar_frame.png.png` | 3072×1536 | cadre de jauge XP | utilisé, recadré |
| `skill_state_lock.svg.png` | 2048×2048 | verrou XP | utilisé, recadré |
| `skill_state_purchased.svg.png` | 2048×2048 | nœud sélectionné | utilisé, recadré |
| `skill_state_excluded.svg.png` | 2048×2048 | branche exclue | utilisé, recadré |
| `glyph_damage.png` | 2048×2048 | dégâts | utilisé, recadré |
| `glyph_area..png` | 2048×2048 | zone/perforation | utilisé, recadré |
| `skill_node_root.png.png` | 1024×1024 | annoncé comme racine | non utilisé : damier aplati, aucune transparence exploitable |
| `er skill_node_frame_capstone.png` | 1024×1024 | annoncé comme capstone | non utilisé : damier aplati, aucune transparence exploitable |
| `skill_node_capstone.png.png` | 2560×1664 | annoncé comme capstone | non utilisé comme nœud : c’est une plaque horizontale |
| `skill_rank_badge_base.svg.png` | 2560×1664 | annoncé comme badge de rang | non utilisé : doublon binaire exact de `skill_node_capstone.png.png` |
| `386f619c-df3c-406e-8eda-e54a29efc0de.png` | 1536×1024 | image de référence | référence uniquement, jamais chargée en jeu |

`preview.html` est également présent dans le dossier d’assets. Il n’est pas un asset runtime conforme et n’est référencé par aucune scène, ressource ou script.

Les doubles extensions et noms irréguliers (`.png.png`, `glyph_area..png`, préfixe `er `) sont conservés pour ne pas casser les imports existants. Les nouvelles livraisons doivent employer les noms canoniques indiqués plus bas.

## Recadrages centralisés

Les régions d’atlas courantes sont exprimées en pixels source :

| Rôle | Région |
|---|---|
| cadre principal | `(570, 374, 1548, 788)` |
| détail | `(425, 244, 690, 2200)` |
| nœud standard | `(400, 395, 1248, 1250)` |
| racine/capstone de secours | `(400, 395, 1248, 1255)` |
| onglet personnage | `(260, 525, 2010, 690)` |
| onglet discipline | `(300, 500, 2470, 560)` |
| jauge XP | `(30, 560, 3010, 420)` |
| verrou | `(650, 460, 750, 1050)` |
| sélectionné | `(790, 790, 470, 470)` |
| exclu | `(500, 520, 1050, 1000)` |
| dégâts | `(560, 555, 930, 950)` |
| zone/perforation | `(200, 815, 1650, 580)` |

Toute modification de ces régions doit rester dans la ressource de skin, pas dans les composants.

## Fallbacks actuellement actifs

Les remplacements programmatiques sont dessinés par `SkillTreeEffectGlyph`. Ils sont déterministes, redimensionnables et ne masquent jamais l’état fonctionnel.

| Élément manquant ou inutilisable | Fallback |
|---|---|
| racine transparente | cadre octogonal générique + teinte verte |
| capstone transparent | cadre octogonal générique + halo doré distinct |
| badge de rang | capsule sombre bordée d’or avec texte `R1`…`R5` |
| état disponible/en attente | point d’exclamation doré |
| état futur | losange gris |
| Archer | flèche dans un cercle |
| Assassin | lame diagonale |
| Mage | losange/rune |
| Soigneur | croix cerclée |
| portée | flèche graduée |
| repoussement | chevron et flèche |
| mobilité/ralentissement | trajectoire en zigzag |
| saignement | goutte |
| vulnérabilité | bouclier brisé |
| collision | deux chevrons opposés |
| durée | sablier |

Les glyphes réels `damage` et `area_or_pierce` remplacent automatiquement leur fallback lorsque le skin les fournit. Les autres identifiants restent data-driven dans la visual map.

## Assets encore nécessaires

Livrer des PNG RGBA avec fond réellement transparent, sans damier aplati, sans ombre coupée et avec au moins 24 px de marge transparente autour du motif.

| Nom canonique attendu | Dimensions recommandées | Zone utile / ratio | Usage |
|---|---:|---|---|
| `skill_node_root.png` | 512×512 | octogone centré, ratio 1:1 | racine rang 1 |
| `skill_node_capstone.png` | 512×512 | octogone centré, ratio 1:1 | rang 5 |
| `skill_rank_badge_base.png` | 256×128 | capsule 2:1, centre libre pour le texte | badges R1–R5 |
| `skill_state_pending.png` | 256×256 | symbole centré 1:1 | choix disponible/en attente |
| `discipline_archer.png` | 256×256 | symbole centré 1:1 | discipline Archer |
| `discipline_assassin.png` | 256×256 | symbole centré 1:1 | discipline Assassin |
| `discipline_mage.png` | 256×256 | symbole centré 1:1 | discipline Mage |
| `discipline_healer.png` | 256×256 | symbole centré 1:1 | discipline Soigneur |
| `glyph_range.png` | 256×256 | symbole centré 1:1 | portée |
| `glyph_push.png` | 256×256 | symbole centré 1:1 | repoussement |
| `glyph_movement.png` | 256×256 | symbole centré 1:1 | déplacement/ralentissement |
| `glyph_bleed.png` | 256×256 | symbole centré 1:1 | saignement |
| `glyph_vulnerability.png` | 256×256 | symbole centré 1:1 | vulnérabilité |
| `glyph_collision.png` | 256×256 | symbole centré 1:1 | collision/obstacle |
| `glyph_duration.png` | 256×256 | symbole centré 1:1 | durée |

Palette recommandée : ivoire `#DDE3DC` pour le trait principal, or `#D0A653` pour l’accent, charbon `#171C20` pour les ombres internes. Le trait doit rester lisible à 18 px et 42 px à l’écran.

## Contrat de remplacement

1. Ajouter le fichier canonique au dossier d’assets et laisser Godot générer son `.import`.
2. Assigner sa texture dans `dungeon_draft_skill_tree_skin.tres`.
3. Pour un nouveau type d’effet, ajouter une entrée à `effect_glyphs` avec l’identifiant déjà utilisé par `elf_archer_visual_map.tres`.
4. Ne pas coder de chemin PNG dans un composant.
5. Exécuter `test_skill_tree_skin_ui.gd`, puis vérifier le laboratoire à 1920×1080, 1600×900 et 1280×720.

La texture ne détermine jamais si un nœud est accessible. L’autorité reste la progression et `SkillTreeResolver`; l’UI ne fait que traduire leur présentation.
