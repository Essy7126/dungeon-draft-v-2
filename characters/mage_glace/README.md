# Mage de glace — inventaire et traitement

Prototype visuel 2D construit à partir de dix PNG Meshy AI de 1024 × 1024,
tous encodés en RGB 24 bits sans canal alpha. Les originaux restent intacts.
Le traitement reproductible est assuré par
`tools/process_mage_glace_sprites.gd`, Godot 4.7.1 étant disponible sur la
machine alors que Python/Pillow ne l'est pas.

## Inventaire des sources

| Fichier (préfixe `Meshy_AI_`) | Fond | Découpage observé | Contenu probable | Appréciation et usage |
|---|---|---:|---|---|
| `093910d6…e1d.png` | blanc | 3 × 2 | garde/émotion au bâton | Six poses propres, mais variations de visage et de volume ; variante non retenue. |
| `1c30e91d…380.png` | blanc | 4 × 2 | incantation | Meilleure planche de cast. La frame source 1, quasi doublon de 0, est écartée. |
| `1ec72e1a…312.png` | blanc, séparateurs noirs | 4 × 2 | garde/idle | Huit poses proches ; retenue pour l'idle après exclusion des séparateurs par inset. |
| `b9c550cb…10b.png` | gris | 4 × 2 | rotation avant/arrière/profil | Étude directionnelle statique cohérente, non retenue car elle ne fournit pas de marche et tranche avec les autres planches. |
| `dd394792…61b.png` | blanc | 4 × 2 | marche | Huit poses lisibles ; retenue pour walk et réutilisée plus vite pour run. |
| `e6603f83…dae.png` | blanc | 3 × 2 | réaction/maniement du bâton | Six poses ; les trois premières fournissent la réaction hit, avec retour symétrique. |
| `ed15dc9c…ce8.png` | blanc | collage 4 + 3 | mort/chute | Sept poses exploitables, découpées par rectangles manuels pour préserver la chute. |
| `f2f81e94…c5d.png` | blanc, séparateurs noirs | 4 × 2 | emotes/attaque | Poses très différentes ; conservée comme variante non retenue. |
| `f2f81e94…c5d (1).png` | blanc, séparateurs noirs | 4 × 2 | emotes/attaque | Doublon binaire exact de la ligne précédente ; non retenu. |
| `fd3dd0c1…180d.png` | blanc | image unique | pose héroïque | Meilleure illustration détaillée ; retenue pour le portrait recadré. |

## Séquences finales

- `idle` : les huit frames de `1ec72e1a…312`, ordre source 0→7, 6 FPS.
- `walk` : les huit frames de `dd394792…61b`, ordre source 0→7, 10 FPS.
- `run` : les mêmes huit poses que walk, 13 FPS.
- `cast` : `1c30e91d…380`, ordre source 0, 3, 4, 5,
  10 FPS. Les sources 1, 2, 6 et 7 sont écartées car leurs silhouettes sont
  soudées à leurs voisines. La libération est la frame finale index 3
  (frame source 5), main
  libre et bâton au maximum d'extension.
- `hit` : `e6603f83…dae`, ordre source 0, 1, 2, 1, 0, 12 FPS. La courte
  réaction est renforcée en jeu par un recul et un flash discrets.
- `death` : les sept poses de `ed15dc9c…ce8` dans leur ordre visuel,
  8 FPS. Les trois poses au sol emploient des rectangles manuels et une
  échelle de séquence commune plutôt qu'une normalisation individuelle.

## Détourage et alignement

Le fond est échantillonné dans les quatre coins de chaque découpe. Un
flood-fill limité aux pixels proches de cette couleur part des bords : il
supprime uniquement le fond connecté, ce qui préserve les blancs enfermés
dans la barbe et la robe. Une rampe alpha sur la distance colorimétrique
retire les franges extérieures sans durcir le contour.

Chaque silhouette debout est normalisée en hauteur puis placée sur un canevas
RGBA commun de 384 × 384. L'ancre horizontale est calculée sur la masse de la
moitié basse du corps ; le pied est recherché dans une bande centrale pour
ignorer la pointe basse du bâton. Toutes les frames convergent vers l'ancre
sol `(192, 350)`. La mort conserve l'échelle de la première pose et applique
une descente progressive manuelle aux poses suivantes.

## Limitation directionnelle

Les animations retenues offrent une vue trois-quarts unique. `RIGHT` utilise
la vue source, `LEFT` son miroir horizontal ; `UP` et `DOWN` conservent la
dernière orientation horizontale connue. La planche statique avant/arrière
n'est pas mélangée aux séquences animées afin d'éviter un changement brutal
de style et de proportions.
