# Ancres de métamorphose de Paris

Source inspectée : `art/source/characters/paris/sprites_v1/source_transform_ALL.png`, RGBA natif 1536 × 1024. Revue sur fond gris, à la définition native. Aucun dessin ni asset de jeu n'a été modifié pour cette mesure ; aucun build ou Godot n'a été lancé.

Le fichier `alignment_transform.json` utilise une échelle **commune de 0,59** pour les huit dessins, avec pivot cible `(256,320)` sur canevas `(512,384)`. Les positions source sont globales. L'arc et le fouet ne participent jamais au calcul du centre de gravité.

| Pose | Vue | Ancre source | Repère |
|---:|---|---|---|
| 0 | E | (236,450) | Projection du bassin sur le plan d'appui ; extrémité de brume y449 |
| 1 | E | (619,447) | Même projection ; le bout du fouet à y456 n'est pas le sol |
| 2 | E | (959,466) | Milieu des deux appuis de griffes ; semelles centrales autour de y460 |
| 3 | E | (1309,468) | Milieu des deux appuis de griffes, pose plus large |
| 4 | N | (205,925) | Projection du bassin ; extrémité de brume y925 |
| 5 | N | (579,921) | Projection du bassin ; brume y920 |
| 6 | N | (942,937) | Milieu des pieds, contacts principaux y933 |
| 7 | N | (1300,940) | Milieu des pieds, contact du pied droit y940 |

Les contacts ont été recoupés avec les pixels d'alpha >32 du module de segmentation : E2 à y456, pieds `[856,919]` et `[996,1066]` ; E3 à y456, pieds `[1194,1262]` et `[1350,1431]` ; N6 à y923, pieds `[833,903]` et `[975,1055]` ; N7 à y928, pieds `[1184,1256]` et `[1341,1420]`.

La transformation change effectivement la morphologie : queue flottante, jambes puis pieds. Son échelle reste fixe et le fantôme n'est pas remonté pour faire artificiellement coïncider son contour avec celui du démon. Les mèches de feu et les cornes dépassent la hauteur du crâne. Avec une définition stricte du crâne excluant flammes et cornes, les quatre poses finales font environ 220–230 px du crâne aux pieds à 0,59 ; annoncer exactement 245 px pour ce repère serait incorrect. Les silhouettes fantômes complètes font environ 235 px en E et 243 px en N jusqu'à leur extrémité de brume. La validation d'intégration doit donc comparer la transition aux sprites de repos finaux, pas ajuster l'échelle image par image.

La troisième étape garde encore le carquois de l'archer ; la quatrième le retire. Ce détail est cohérent avec une transformation progressive et ne doit pas être interprété comme un équipement à conserver dans la forme infernale finale.
