# Revue des deux vues infernales natives

Configuration fusionnable : `alignment_infernal.json`. Le fichier fournit les
clés `infernal_E`, `infernal_N` et les trois entrées `clip_overrides` propres à E.
Le contrôle a appelé `inspect()` puis `prepare()` en mémoire. Il n’a modifié ni
les sources, ni `build.cjs`, ni les assets runtime.

| Vue | Source | Échelle fixe | Pixels d’alpha non nul | Omis / dupliqués | Poses préparées |
| --- | --- | ---: | ---: | --- | ---: |
| E | 1254×1254 | 0,94 | 577 229 | 0 / 0 | 16 |
| N | 1367×1151 | 0,98 | 574 509 | 0 / 0 | 16 |

Les fenêtres partitionnent la source entière. Leurs frontières passent dans
les intervalles sans silhouette, avec zéro pixel d’alpha supérieur à 24 sur les
bords des 32 cellules. Les pixels d’alpha faible restent intégralement affectés
à une cellule et conservés ; aucune suppression, recoloration ou recomposition
du personnage n’a été pratiquée.

La grille nominale aurait notamment coupé la pose d’attaque E7 par sa limite
gauche et les fouets au sol E14/E15. Les limites horizontales varient donc par
rangée. Les séparations verticales suivent également les intervalles réels :
E `0/320/635/940/1254`, N `0/302/590/860/1151`.

Les racines horizontales utilisent le milieu des pieds, sans inclure l’arme.
Les deux poses de marche E1/E2 prennent en compte le pied arrière relevé et le
pied avant en appui ; la hauteur de référence reste celle de l’appui au sol.
Les dernières poses utilisent les genoux et les appuis corporels de réception,
sans déplacer la racine vers l’extrémité du fouet. Les flammes, cornes, doigts
étendus et boucles de l’arme n’influencent ni l’échelle ni le centrage.

Sur le repos, l’estimation visuelle du haut du crâne hors flamme à la ligne
d’appui est d’environ 245 pixels après mise à l’échelle pour les deux angles.
Les poses penchées et accroupies conservent cette même échelle de source.

La revue des planches alignées confirme la stabilité des appuis debout,
l’absence de fouet coupé et la réception progressive au sol. Les images
suivantes sont des contrôles mécaniques d’atelier sur fond gris ; elles ne
constituent pas une validation d’animation en combat.

![Vue infernale E alignée](../../artifacts/paris_sprite_production/alignment_infernal_E_review.jpg)

![Vue infernale N alignée](../../artifacts/paris_sprite_production/alignment_infernal_N_review.jpg)

Les substitutions de lecture E sont : attaque `5/6/7/10`, incantation `8/9/10`,
réaction `11/12`. La pose E13 reste préservée dans la source et l’atlas préparé,
mais n’entre pas dans ces clips. La vue N conserve le mapping standard.

`alignment_infernal_report.json` consigne les SHA des sources, chaque placement,
les marges de silhouette et les marges du rectangle RGBA préservé. Le canevas
reste 512×384 avec le pivot `(256, 320)` ; aucun atlas runtime n’a été écrit.
