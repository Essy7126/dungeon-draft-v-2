# Atlas des maîtrises : assets originaux

Générations originales du 6 septembre 2026 avec l’outil intégré `image_gen`, depuis descriptions textuelles. Aucun asset tiers de jeu n’est copié. Les illustrations ont été inspectées puis copiées sans retouche dans le projet.

| Livrable | Source de génération | Rôle |
| --- | --- | --- |
| `asset/ui/progression/mastery_atlas/canvas_v1.png` | `exec-8b1a37fd-c585-4b4b-82f7-abe3e3321fe1.png` | Fond sombre peint de l’arbre |
| `asset/ui/progression/mastery_atlas/doctrines_v1.png` | `exec-d664b580-2c5c-4f35-87b4-40ea911de5b6.png` | Trois emblèmes de doctrine, atlas 2172 × 724 |

Les sources sont conservées dans `C:/Users/paolo/.codex/generated_images/01a071ac-57af-72e0-948e-eabbebdda416/`. Les ressources `wrath_v1.tres`, `chiron_v1.tres` et `aeacus_v1.tres` sélectionnent respectivement les trois cellules de 724 × 724 via `AtlasTexture`, sans rééchantillonnage du fichier source.

Le fond ne représente aucun prérequis : tous les nœuds, connexions et états viennent du graphe runtime. Les boutons réutilisent la [matière cendrée de sélection](../character_selection/ashen_material_v1_prompt.md) et son shader ; les textes restent rendus par des fontes locales. Les icônes des techniques conservent le raccord au thème HUD courant.

## Prompt exact du fond

Use case: stylized-concept. Asset type: original background painting for an interactive Greek-mythology mastery skill tree in a premium dark fantasy RPG. A horizontal panoramic expanse of blackened parchment and smoky ash-brown slate, with an almost invisible ancient bronze astrolabe engraving, fragmentary laurel relief and faint ember dust concentrated near the OUTER EDGES. Very dark warm charcoal and burnt umber, desaturated antique bronze, a restrained soft warm central haze. Museum-quality painted material, exquisitely detailed but extremely low contrast. The central 80 percent must remain broad calm dark negative space for interactive nodes and readable labels. No readable letters, no words, no UI buttons, no pre-made skill nodes, no network of glowing connecting lines, no character, no weapon, no bright fire, no logo, no watermark. Flat front-facing textured art plate. Wide landscape 16:9 composition. Entire image should feel an ancient heroic codex, not a space-science screen.

## Prompt exact des emblèmes

Use case: stylized-concept. Asset type: game-ready original triptych atlas of three Greek mythic doctrine emblems for a dark fantasy RPG mastery UI. One wide horizontal image split into THREE EXACTLY EQUAL SQUARE CELLS, no gutters. Each cell contains a single exquisitely painted symbolic artifact, centered with 15 percent breathing room, on the SAME very dark warm ash-brown matte background, no outer frames. LEFT emblem: golden spearhead crossed with a short bronze blade, restrained crimson cloth and a small ember glow, evokes wrath and decisive assault. CENTER emblem: elegant carved bow and a silver arrow, a small ivory laurel sprig, restrained soft sage/teal glint, evokes Chiron's teaching and precision. RIGHT emblem: a round ancient Greek bronze shield with a central raised boss and delicate hammered concentric ornament, subtle muted blue protective aura, evokes Aeacus's guard. Precious hand-painted fantasy inventory icon quality, legible chunky silhouettes at small sizes, controlled highlights, consistent light from upper left, polished metal but no photographic busy noise. NO text, letters, numbers, characters, logos, watermarks, labels, card borders, UI, or background scenes. All three objects equally prominent and confined to their own square. Landscape 3:1 exactly; three equal squares.
