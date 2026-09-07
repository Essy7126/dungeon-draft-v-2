# Variantes peintes v2 — capacités d’Achille

Date de livraison : 6 septembre 2026. Mode : outil image_gen intégré, une génération par capacité. Aucun asset DOFUS utilisé comme entrée, aucune retouche des anciennes icônes, aucun changement du mapping ni du code.

## Livraison

Dossier cible : `C:/Users/paolo/Documents/dungeon-draft-v-2/asset/ui/recraft_hud_v1/icons/achilles_painted_v2/`

Les quatre fichiers sont de nouvelles variantes non branchées automatiquement. Chaque PNG mesure 1254 × 1254 px ; les originaux générés sont conservés.

| Capacité | Fichier | SHA256 |
|---|---|---|
| advance | ability_achilles_advance.png | 8193961DD1D7A975BFE7F4A6AD0928184A92C0CBBFBE531C87B2E15B85D1A7D3 |
| guard | ability_achilles_guard.png | F1107135BF60C66D8FF23666E43DC967906883FB19FFFCD0FDB305C26C1DBF25 |
| spear_thrust | ability_achilles_spear_thrust.png | 5B8131FD4C2E6DE27670D720DF09E794FE7A214173BA74C920F88BBE5063951A |
| sweep | ability_achilles_sweep.png | 3381218C95DE365EC1C3501DA39C34AF5BBBB5C30E6E2BE7297DB90A890AE763 |

## Contrôle artistique

Les quatre sorties ont été inspectées visuellement à leur résolution affichée. Elles privilégient un sujet unique, de larges plages ivoire/bronze et des gestes différents : diagonale droite + impact rouge pour l’estoc ; croissant doré sur indigo pour le balayage ; jambière/avance cyan pour l’élan ; disque de bronze frontal et halo bleu pour la garde. Aucun texte, chiffre, badge, cadre d’interface ou panneau multiple n’est incorporé.

Les fonds restent sombres mais les sujets sont nettement lumineux. C’est une intention de lisibilité adaptée aux petits slots ; cette inspection seule ne prouve pas encore un gain dans le rendu réel à 64 px. La comparaison dans Godot doit se faire après correction du shader d’icône diagnostiquée par l’agent HUD, à taille et état identiques.

Réserve : le padding obtenu est irrégulier malgré la consigne de 10 %. La pointe de l’estoc approche du bord supérieur droit (~6 %) ; les orteils de l’avance approchent du bord droit (~4 %). Les formes principales restent visibles, mais un masque de slot très arrondi doit être vérifié. Les manches se prolongent volontairement au bord de la toile. La jambière comporte une frise géométrique fine ajoutée par la génération : décor secondaire, non nécessaire à l’identification.

Ces v2 sont plus emblématiques que des scènes de personnages miniatures. Elles conviennent si l’objectif prioritaire est d’identifier instantanément le type d’action. Ne pas remplacer v1 automatiquement si la comparaison réelle n’apporte pas de gain.

## Originaux conservés

- spear_thrust : C:\Users\paolo\.codex\generated_images\01a073ea-9e9b-7ff2-b6c2-4905ecf22531\exec-d9e0bfb5-05c6-4d7f-81a3-6530a018d71b.png
- sweep : C:\Users\paolo\.codex\generated_images\01a073ea-9e9b-7ff2-b6c2-4905ecf22531\exec-d5508879-49dd-4066-bfd5-8e783caee800.png
- advance : C:\Users\paolo\.codex\generated_images\01a073ea-9e9b-7ff2-b6c2-4905ecf22531\exec-f175ae2e-3c30-4a79-b43b-8575d26ae456.png
- guard : C:\Users\paolo\.codex\generated_images\01a073ea-9e9b-7ff2-b6c2-4905ecf22531\exec-0d067621-533c-45d9-b46d-7c912dd665da.png

## Prompts exacts

### spear_thrust

```text
Use case: stylized-concept
Asset type: a SINGLE square raster ability icon for a polished tactical fantasy game HUD, displayed at 64 pixels.
Style/medium: premium hand-painted stylized game art; confident brush-shaped planes, clean crisp silhouette, tactile bronze metal and ivory highlights, not photorealistic. Original art.
Composition/framing: square full-bleed painted background, exactly ONE central subject and its action effect. Main silhouette occupies 75–80% of the square. 10% breathing room on every side; keep important extremities within the safe area. Strong simple read at thumbnail scale. The brightly lit subject must remain visibly lighter than the dark colored backdrop. Medium values and large ivory highlights, never an all-black or muddy icon.
Constraints: NO frame, NO decorative border, NO slot shape, NO bevel around canvas, NO text, NO letters, NO numbers, NO badges, NO watermark, NO UI mockup, NO multiple panels or sprite sheet. No environment scenery, no character face, no tiny ornamentation.
Primary request: a powerful piercing spear-thrust ability icon. A large ivory-bright leaf-shaped bronze spearhead lunges diagonally from lower left toward upper right through one compact bright amber impact burst. Short visible dark-wood shaft with a clear bronze collar; spearhead is the dominant shape. Motion is straight and decisive, not curved.
Scene/backdrop: rich dark oxblood burgundy shading into warm burnt orange immediately behind the impact, restrained painterly texture.
Lighting/mood: strong warm ivory edge light on broad spearhead facets, bright golden impact, rich midtones. Spearhead and burst visually separate from each other.
```

### sweep

```text
Use case: stylized-concept
Asset type: a SINGLE square raster ability icon for a polished tactical fantasy game HUD, displayed at 64 pixels.
Style/medium: premium hand-painted stylized game art; confident brush-shaped planes, clean crisp silhouette, tactile bronze metal and ivory highlights, not photorealistic. Original art.
Composition/framing: square full-bleed painted background, exactly ONE central subject and its action effect. Main silhouette occupies 75–80% of the square. 10% breathing room on every side; keep important extremities within the safe area. Strong simple read at thumbnail scale. The brightly lit subject must remain visibly lighter than the dark colored backdrop. Medium values and large ivory highlights, never an all-black or muddy icon.
Constraints: NO frame, NO decorative border, NO slot shape, NO bevel around canvas, NO text, NO letters, NO numbers, NO badges, NO watermark, NO UI mockup, NO multiple panels or sprite sheet. No environment scenery, no character face, no tiny ornamentation.
Primary request: a wide spear-sweep ability icon. ONE large curved crescent-shaped golden sweeping slash describes a broad horizontal spear sweep. A clearly readable bronze-and-ivory spearhead and short shaft travel along the open end of this arc. The crescent is the dominant visual gesture, visually distinct from a straight stab. Clear broad forms with two or three restrained motion strokes.
Scene/backdrop: deep indigo blue with a luminous muted cobalt center behind the crescent.
Lighting/mood: warm pale gold and ivory slash against blue, bright polished bronze spearhead, strong complementary contrast. The arc is richly painted, not a thin neon line.
```

### advance

```text
Use case: stylized-concept
Asset type: a SINGLE square raster ability icon for a polished tactical fantasy game HUD, displayed at 64 pixels.
Style/medium: premium hand-painted stylized game art; confident brush-shaped planes, clean crisp silhouette, tactile bronze metal and ivory highlights, not photorealistic. Original art.
Composition/framing: square full-bleed painted background, exactly ONE central subject and its action effect. Main silhouette occupies 75–80% of the square. 10% breathing room on every side; keep important extremities within the safe area. Strong simple read at thumbnail scale. The brightly lit subject must remain visibly lighter than the dark colored backdrop. Medium values and large ivory highlights, never an all-black or muddy icon.
Constraints: NO frame, NO decorative border, NO slot shape, NO bevel around canvas, NO text, NO letters, NO numbers, NO badges, NO watermark, NO UI mockup, NO multiple panels or sprite sheet. No environment scenery, no character face, no tiny ornamentation.
Primary request: a decisive forward-advance ability icon. A single bronze-and-ivory armored Greek greave and sandaled foot, viewed from the side, planted in an energetic forward stride pointing toward the right. Clear large foot and shin silhouette; no whole person. Three broad cyan and pale turquoise motion streaks trail behind toward the left, communicating a dash forward. The armored foot and leg, not the streaks, are dominant.
Scene/backdrop: deep teal blue, brighter blue-green halo around the foot, no landscape or ground scene.
Lighting/mood: bright ivory facets on the greave and bronze rim, pale turquoise speed trails. Leg stays warm and readable against the cool backdrop; no black silhouetted leg.
```

### guard

```text
Use case: stylized-concept
Asset type: a SINGLE square raster ability icon for a polished tactical fantasy game HUD, displayed at 64 pixels.
Style/medium: premium hand-painted stylized game art; confident brush-shaped planes, clean crisp silhouette, tactile bronze metal and ivory highlights, not photorealistic. Original art.
Composition/framing: square full-bleed painted background, exactly ONE central subject and its action effect. Main silhouette occupies 75–80% of the square. 10% breathing room on every side; keep important extremities within the safe area. Strong simple read at thumbnail scale. The brightly lit subject must remain visibly lighter than the dark colored backdrop. Medium values and large ivory highlights, never an all-black or muddy icon.
Constraints: NO frame, NO decorative border, NO slot shape, NO bevel around canvas, NO text, NO letters, NO numbers, NO badges, NO watermark, NO UI mockup, NO multiple panels or sprite sheet. No environment scenery, no character face, no tiny ornamentation.
Primary request: a solid defensive guard ability icon. ONE round ancient Greek hoplite shield seen almost exactly from the front; convex warm bronze body, bold broad ivory crescent reflection, sturdy central boss and simple broad radial metal planes. No crest, lettering, face, heraldic drawing, or detailed ornament. Shield is a weighty defensive object, not a UI frame. A restrained pale blue protective glow behind its circular silhouette.
Scene/backdrop: deep navy blue shifting to a medium cool blue immediately behind the shield, painterly soft texture.
Lighting/mood: brightly lit warm bronze face with substantial pale ivory and gold highlights; blue rim light; the main disk is mid-value golden bronze rather than dark brown.
```



## Intégration finale

Les quatre variantes ont ensuite été retenues et branchées par le parent dans data/ui/achilles_hud_theme_refined.tres. Les réserves ci-dessus décrivent l'étape de création ; le rendu en slots est contrôlé par la galerie HUD v2. Les SVG utility_inventory.svg (sacoche) et utility_skills.svg (grimoire) sont des dessins vectoriels originaux réalisés pour les fonctions existantes, sans génération raster. Le nouveau cadre frames/achilles_v2 conserve le contour v1 mais retire le voile central ; alpha central vérifié à 0/255 contre 92/255 auparavant.

