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
