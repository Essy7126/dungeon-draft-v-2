# Garde d’airain — sprites mécaniquement préparés

La source retenue est `art/source/vfx/achilles_guard_bronze_v1/guard_source_v2.png`, produite avec ImageGen. Les prompts exacts sont conservés à côté. Le script ne dessine aucun effet : il recadre, réduit et range les pixels RGBA de cette source.

Depuis la racine du projet :

```powershell
node tools/guard_sprite_pipeline/build.cjs
```

Le script utilise `sharp` installé localement, ou `SHARP_PATH`, puis le runtime Codex de cette machine en dernier recours. Il ne dépend ni du réseau ni de Godot.

Les 16 cases sont découpées dans la grille 4 × 4. Leur échelle nominale commune est 0,78 ; l’arrondi raster ne dépasse pas un demi-pixel au niveau de l’ancre. L’ellipse au sol utilise une hauteur mesurée commune à chaque rangée, jamais un recalage par pose. L’ancre de toutes les images est `(128, 210)` dans une toile transparente de `256 × 256` pixels. Cette ancre est le centre de l’anneau, pas le bas du cadre.

| Atlas | Grille | Cases sources | Lecture |
|---|---|---|---|
| `activation.png` | 4 × 2 | 0–7 | 16 images/s, 0,50 s |
| `hold.png` | 1 × 1 | 7 | Image fixe |
| `hit.png` | 4 × 1 | 8–11 | 16 images/s, 0,25 s |
| `end.png` | 4 × 1 | 12–15 | 13,333 images/s, 0,30 s ; fondu final de 0,05 s dans Godot |

Sortie : `vfx/assets/flipbooks/achilles_guard_bronze_v1/`. Les ressources Godot qui consomment ces atlas sont maintenues séparément ; le script ne les réécrit pas.

L’alpha partiel d’origine et les franges très faibles restent présents. Aucun fond n’est détouré, aucun pixel n’est effacé suivant un seuil. La réduction Lanczos3 interpole nécessairement les couleurs et l’alpha ; la source non modifiée est conservée pour toute future exportation. Les seuils 0/8/32/128 servent uniquement aux mesures. Une assertion arrête la construction si le cœur visible dépasse une case ou perd sa marge.

`manifest.json` consigne les empreintes SHA-256, les découpes, les ancres et leur erreur d’arrondi, les histogrammes alpha et les marges de chaque image. `preview_light.jpg` et `preview_dark.jpg` permettent de contrôler les franges ; `preview_contact.jpg` ajoute une croix de contrôle à l’ancre, absente des fichiers de jeu. Les GIF montrent activation, maintien, impact et dissolution à la cadence cible, avec durées totales de 0,50 / 0,25 / 0,30 s. La quantification temporelle GIF au centième de seconde alterne des images de 60/70 ou 70/80 ms ; Godot lit les PNG à 16 images/s pour activation/impact et ajuste la dissolution à 0,30 s avec un fondu des 0,05 dernières secondes. Le GIF ne simule pas ce fondu du moteur.
