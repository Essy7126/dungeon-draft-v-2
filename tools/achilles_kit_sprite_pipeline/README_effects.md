# Extraction mécanique des effets Achille V2

`build_effects.cjs` découpe les vrais pixels RGBA d’une planche ImageGen. Il ne dessine aucun effet, ne détoure aucune couleur et n’utilise aucune composante connectée. Les étincelles détachées appartiennent à leur fenêtre et sont conservées. Une correction explicitement validée peut seulement retirer du bruit très peu opaque sur son unique pixel de bord ; son bilan exact apparaît dans le manifeste.

## Source

Déposer la planche dans `art/source/vfx/achilles_kit_v2/source_effects.png` : PNG RGBA 8 bits, avec une véritable transparence. La grille contient **4 colonnes × 6 rangées de cellules carrées**, sans titre, légende ni trait de séparation. Une image de 1024 × 1536 pixels convient directement ; une image plus grande respectant exactement cette grille convient également. Pour une source irrégulière mesurée, le fichier source_layout.json décrit explicitement ses fenêtres et centres, comme expliqué plus bas.

| Rangée, du haut vers le bas | Animation | Dessins, de gauche à droite |
| --- | --- | --- |
| 1 | `arrow` | Quatre phases d’une flèche horizontale pointant vers la droite. |
| 2 | `impact` | Quatre phases d’un éclat ivoire et or. |
| 3 | `sweep` | Quatre phases d’un croissant de bronze. |
| 4 | `guard` | Quatre phases d’un arc défensif argent et bronze. |
| 5 | `dust` | Quatre phases d’un souffle de poussière grise. |
| 6 | `barrier` | Quatre phases d’un pavois spectral bleu et bronze. |

Le centre de chaque cellule source est l’ancre commune. La pointe et l’orientation de la flèche doivent être correctes dans le dessin source : le pipeline ne retourne et ne pivote jamais les images. Examiner les aperçus produits pour valider cette orientation artistique.

## Normalisation et conservation des pixels

Chaque cellule est d’abord extraite par ses coordonnées exactes dans la grille. Les bornes de **tous** les pixels d’alpha supérieur à zéro des quatre dessins d’une rangée déterminent un carré de recadrage commun, centré sur le centre original de la cellule. Ce même carré et cette même échelle sont appliqués aux quatre dessins. Les déplacements, développements et dissipations déjà dessinés sont préservés ; aucun recentrage, ajustement d’échelle ou suivi du centre de masse n’est effectué image par image.

Le carré commun devient une zone de 232 × 232 pixels centrée sur une toile transparente de 256 × 256 pixels, avec 12 pixels de marge. Après l’éventuelle correction de bord autorisée, la somme alpha avant et après recadrage doit être identique : cela détecte la perte d’une étincelle, même isolée. Le rééchantillonnage Lanczos3 interpole nécessairement le RGBA ; aucune suppression par seuil à l’intérieur des fenêtres ni recoloration n’est appliquée. Hors de la correction de bord explicite, les seuils alpha 0 et 32 servent uniquement aux mesures. Le remplissage transparent et l’assemblage de l’atlas se font par copie d’octets, sans recomposer plusieurs fois les pixels semi-transparents.

Le build refuse une cellule vide, une source RGB, une fausse grille, moins de 5 % de pixels réellement transparents par cellule, tout pixel non transparent touchant un bord de cellule ou un cœur visible à moins de quatre pixels d’un bord source. Chaque image finale possède au moins 12 pixels de marge alpha. Ces contraintes décrivent le mode de grille stricte. Les fenêtres irrégulières validées emploient le contrôle de bord détaillé ci-dessous. Un trait fort coupé reste toujours bloquant.

## Commandes

Depuis la racine du projet, avec Node.js et `sharp` :

```powershell
node tools/achilles_kit_sprite_pipeline/build_effects.cjs --inspect
node tools/achilles_kit_sprite_pipeline/build_effects.cjs
node --test tools/achilles_kit_sprite_pipeline/build_effects.test.cjs
```

`--inspect` réalise les mêmes contrôles et le même assemblage en mémoire sans écrire de fichier. Pour comparer une autre source ou produire un essai isolé :

```powershell
node tools/achilles_kit_sprite_pipeline/build_effects.cjs --source art/source/vfx/achilles_kit_v2/source_effects.png --output artifacts/achilles_effects_review
```

Le dossier de sortie doit rester dans le projet et hors de ses métadonnées. Les arguments inconnus sont refusés. Le script cherche `sharp` localement, puis à `SHARP_PATH` si défini, puis au chemin du runtime Codex déjà employé par les autres extracteurs. Il ne lance pas Godot.

## Sorties

Le dossier de production est `assets/vfx/achilles_kit_v2/` :

- `effects.png` : atlas RGBA de **1024 × 1536 pixels**, dans le même ordre 4 × 6.
- `effects.tres` : `SpriteFrames` avec les six animations de quatre images de 256 × 256, toutes sans boucle.
- `manifest.json` : empreintes SHA-256 source/atlas/images, géométrie commune par rangée, histogrammes alpha, bornes, marges et contrôles de conservation.
- `preview_effects_light.jpg` et `preview_effects_dark.jpg` : aperçus sur fonds clair et sombre, jamais utilisés en combat.

Toutes les vérifications d’entrée, de recadrage et de copie de l’atlas passent avant la première écriture de production. Les temps de la ressource sont 0,20 s pour `arrow`, 0,22 s pour `impact`, 0,24 s pour les autres. Le runtime de combat reste propriétaire du temps réel : le projectile attend son impact confirmé et `barrier` tient sur une image fixe jusqu’à expiration du vrai Rempart.

Les dix tests Node utilisent uniquement des pixels de fixture synthétiques. Ils vérifient la conservation des éléments détachés, la transformation commune, les empreintes de chaque région, le déterminisme, les rejets alpha/grille, les références Godot, l’inspection sans écriture et la préservation d’un atlas existant si une nouvelle source échoue, puis les fenêtres irrégulières, les centres déclarés, les bilans alpha et le rejet d’un bord supérieur à 32.


## Fenêtres irrégulières explicitement mesurées

Le fichier tools/achilles_kit_sprite_pipeline/source_layout.json est automatiquement chargé pour la source de production. Pour une autre source, passer --layout chemin/source_layout.json. Le SHA-256 de la source et ses dimensions doivent correspondre exactement : une nouvelle génération ne peut pas réutiliser silencieusement les anciennes mesures.

Le format contient six bands [[y0,y1], ...] contiguës couvrant la hauteur entière, six listes columns [[x0,x1,x2,x3,x4], ...] couvrant chacune la largeur, et six listes centers de quatre couples (x,y) en coordonnées globales source. Les fenêtres ne se chevauchent pas ; aucun intervalle de pixels n’est omis. Les centres sont déclarés par la revue, jamais déduits du halo ou d’une boîte variable image par image. Une même taille carrée et une même échelle sont appliquées aux quatre phases d’une rangée autour de ces centres. Le carré peut ajouter du transparent au-delà de la fenêtre, mais ne prélève jamais des pixels dans le dessin voisin.

La règle boundary_cleaning avec width=1 et maximum_alpha=32 autorise uniquement le nettoyage du pixel le plus extérieur de chaque côté d’une fenêtre. **Tout alpha supérieur à 32 sur ce bord provoque un refus ; tout pixel intérieur reste identique, quelle que soit son opacité.** Les glows faibles et les étincelles à l’intérieur sont donc préservés. Le manifeste compte les pixels retirés, leur somme alpha et leur alpha maximum pour chaque image et au total. Il vérifie l’identité des histogrammes alpha 33–255 avant et après ce nettoyage, puis l’absence de toute perte supplémentaire au recadrage.

La source actuellement sélectionnée possède des rangées irrégulières. Les bandes mesurées sont [0,238], [238,478], [478,735], [735,988], [988,1212], [1212,1536]. Les colonnes du croissant, de la garde et de la poussière suivent également leurs séparations réelles. La coupe centrale de Garde à x521 rencontre uniquement un résidu de halo à alpha19 sur une face et alpha31 sur l’autre. Les grands traits visibles ne sont pas touchés.

Revue de ce build : 3 098 pixels de bord retirés, somme alpha 3 550 sur 68 835 492, soit **0,00516 % de la masse alpha**. Maximum retiré : 31 ; zéro pixel d’alpha >32 retiré et zéro pixel intérieur modifié. Les vingt-quatre régions vérifiées octet pour octet disposent d’une marge finale minimale de 13 pixels. Les aperçus clair et sombre ont été examinés : flèches orientées à droite, phases séparées, halos et particules présents. Les mesures initiales et les aperçus de contrôle sont dans artifacts/achilles_effects_alpha_review/.
