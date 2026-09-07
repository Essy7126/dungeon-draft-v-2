# Le Dialecticien — sources des sprites

Ces huit planches proviennent du générateur d'images intégré. Chaque planche contient seize poses sur une grille 4 × 4 et un véritable canal alpha. Les fichiers d'origine sont conservés sans retouche. Le pipeline effectue uniquement la séparation mécanique des poses, une mise à l'échelle fixe par planche et leur placement dans les atlas RGBA.

Le modèle conserve le crâne dégarni, les cheveux blancs aux tempes, la barbe blanche, le chiton ivoire, le manteau bleu pétrole à bordure grecque dorée, les sandales brunes, le rouleau à la ceinture et le bâton à orbe turquoise cerclé de bronze. Les directions sont dessinées séparément : E avant vers la droite, S avant vers la gauche, N arrière vers la droite, W arrière vers la gauche. Aucun miroir logiciel n'est utilisé.

| Planche | Ligne 1 | Ligne 2 | Ligne 3 | Ligne 4 |
| --- | --- | --- | --- | --- |
| `source_base_*.png` | Repos, marche 1–3 | Marche 4–7 | Axiome, 4 poses | Soin, 4 poses |
| `source_extra_*.png` | Contrôle, 4 poses | Égide, 4 poses | Coup reçu, 4 poses | Mort, 4 poses |

Les 128 dessins sont conservés dans les atlas. Les 32 animations utilisent 124 dessins distincts : quatre poses présentant une incohérence de main ou de bâton sont remplacées par une pose déjà dessinée du même geste. L'animation conserve sa durée et sa pose de release pendant le maintien, les effets de sort indiquant son activation.

| Dessin écarté du playback | Motif observé | Dessin conservé |
| --- | --- | --- |
| `base_N_14` | Bâton détaché et relation main/bras incohérente | `base_N_13` |
| `extra_S_2` | La paume change de bras et le bâton perd sa prise | `extra_S_1` |
| `extra_N_2` | La main qui tenait le bâton devient une paume libre sans transmission cohérente | `extra_N_1` |
| `extra_W_2` | Le bâton reste debout sans prise visible lors de l'extension du bras | `extra_W_1` |

Les positions et motifs sont explicites dans `tools/philosopher_sprite_pipeline/alignment.json`. Les coordonnées sont les pixels globaux des sources 1254 × 1254, avec une incertitude manuelle estimée de 3 pixels pour les appuis et de 6 à 8 pixels pour la projection d'un pied levé ou du bassin couché.

La hauteur de référence est le corps humain debout, du sommet du crâne à la sandale, environ 225 pixels dans l'atlas ; la hauteur du bâton ne détermine pas l'échelle. Les poses accroupies ou couchées gardent cette échelle. Les racines de marche et de coup reçu suivent la projection des appuis au sol. Les racines de mort suivent ensuite le bassin agenouillé puis couché : elles ne recentrent pas le corps à partir du bâton tombé ou de la boîte englobante complète.

Une revue sur fond gris des huit sources, puis des huit atlas générés, a vérifié les pieds, l'échelle humaine, les pointes du bâton, les silhouettes accroupies et les appuis des chutes. Le pipeline a vérifié les 128 régions d'atlas après leur écriture. Les captures de combat et les checks de cadence du moteur restent une validation distincte dans `tools/philosopher_sprite_validation/`.

Ce dossier comporte `.gdignore` : Godot importe les atlas de production, pas les planches de travail.
