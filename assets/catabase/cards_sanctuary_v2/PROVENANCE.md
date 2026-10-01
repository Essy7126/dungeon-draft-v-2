# Préparation Cartes — matière de la référence

Assets peints générés avec l'outil ImageGen le 1 octobre 2026 à partir de la
référence fournie par Jérémy (`codex-clipboard-7dd0a01d-d58d-4e1f-a8f3-3ee237d7706e.png`).
Ils servent exclusivement à la sélection Cartes. Les textes et interactions
restent des contrôles Godot. Les régions visibles sont définies par des
AtlasTexture dans `ui/selection/cards_sanctuary_skin.gd` ; les fichiers PNG
originaux générés ont été copiés sans retouche.

| Asset | Sortie ImageGen |
| --- | --- |
| `class_seal.png` | `e3314ae3-50a3-4a58-80df-004a67019b6b` |
| `deck_socle.png` | `00e00262-b888-4ee1-a136-5ad6fc39cd98` |
| `elements_socle.png` | `c19369a7-1512-4f9b-89ff-392024621ceb` |
| `difficulty_socle.png` | `ff11337a-8572-4664-87ae-19a572bd425e` |
| `hero_dais.png` | `b7e01baf-3cd4-4668-84e2-4634871d50bf` |
| `action_plate.png` | `b2b6c76d-11c2-4232-85a2-a42f320d47d4` |

L'atlas d'illustrations de cartes proposé n'est pas intégré, à la demande de
Jérémy. La grille utilise toujours `Catalog.make_spell(id).icon` et le cadre
existant `assets/catabase/cards_drawn_v1/card_frame.png`.

## Référence finale — sanctuaire v3

`sanctuary_reference_v3.png` a été généré avec l'outil intégré ImageGen le
1 octobre 2026, sortie `exec-e7768ba4-6599-4d24-8461-d4cc1c8cbfaf.png`.
La référence finale fournie par Jérémy est
`codex-clipboard-f62cdb67-f68a-44ce-b735-4717ed33fdf2.png`.
Le PNG généré est copié sans retouche. Il ne contient que le décor et la
végétation des coins : aucune interface, aucun personnage ni bouton.
Les quatre illustrations précédentes et leurs socles restent inchangés.
`quiet_panel.svg` est un tracé natif : surface noire translucide, bordure bronze,
angles biseautés. Les textes, objets et interactions sont des couches Godot.

Prompt de génération (outil intégré, image fournie comme référence) :

> Use case: stylized-concept. Produce a production game BACKGROUND ONLY, landscape 16:9 ideally 2048x1152. The attached image is a visual reference for style and architecture ONLY. Reconstruct its painted ancient Greek sanctuary environment extremely closely: blue grey weathered stone columns at far left and far right, crimson hanging banners with subtle gold Greek decoration, amber fire braziers to the sides, ivy over ancient masonry, vast luminous turquoise misty depth with tall cliffside temples, tiered aqueduct arches receding into the distance, slender dark cypress trees and distant antique stone statue on the right. Preserve the reference camera, painterly crisp brushwork and cinematic teal/amber illumination. In the bottom 30% show a relatively quiet flat stone terrace, perspective paving and low parapet at 68% height, ample clear floor for game character and existing clickable props. Central area x35%-56%, y20%-75% must remain open so a character can be composited there. Right x74%-96%, y14%-84% will receive a UI panel: paint environment behind it normally. Small DARK shadowed leafy plants frame only the far bottom corners (x0%-15%,x89%-100%,y77%-100%) for depth, never intruding on the clear central bottom floor. CRITICAL: remove ALL user interface, ALL text, titles, letters, labels, buttons, borders, panels and portraits. NO living character, no hooded hero, no sword, no helmets, coins, deck cards, elemental tokens, tabletop props, no hero dais and no four small UI pedestals. No watermark. This is a standalone painted game environment, NOT the complete screenshot. Preserve the open space from the removed character and UI.
