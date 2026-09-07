# Paris — sources des sprites

Les images de production ont été créées avec l’outil imagegen intégré. Le modèle conserve les cheveux bouclés, le laurier de bronze, la broche en spirale, la cuirasse et le drapé indigo. La forme spectrale porte un arc et se termine par une volute ; la forme infernale garde cette identité avec des cornes, une peau parcourue de braises et un fouet de feu.

| Source native | Dessins | Usage |
| --- | ---: | --- |
| `source_spectral_E.png` | 16 | Archer vu de face vers la droite |
| `source_spectral_N.png` | 16 | Archer vu de dos vers la droite |
| `source_infernal_E.png` | 16 | Démon vu de face vers la droite |
| `source_infernal_N.png` | 16 | Démon vu de dos vers la droite |
| `source_transform_ALL.png` | 8 | Quatre étapes de transformation, face puis dos |

Les 72 dessins sont conservés dans les atlas. Les directions S et W utilisent les textures E et N avec un miroir dans le moteur : les pièces d’équipement gardent leur dessin, mais les asymétries de main et de broche sont visuellement inversées. Il ne s’agit pas de quatre angles dessinés séparément. Les variantes qui changeaient l’équipement ou conservaient un faux damier ont été écartées.

Le pipeline `tools/paris_sprite_pipeline/build.cjs` effectue uniquement la séparation des poses, une échelle fixe par source et le placement sur un canvas 512 × 384, pivot (256, 320). Les deux feuilles spectrales et la transformation utilisent une segmentation mécanique lorsque leurs boîtes se chevauchent. Chaque pixel RGBA non transparent est affecté une seule fois ; les bords de faible alpha ne sont pas effacés. Les feuilles infernales utilisent des fenêtres explicites. Les fichiers d’alignement séparés conservent les ancrages révisés et les motifs des substitutions de poses présentant une prise d’arc incohérente.

Les prompts `master_prompt.txt` et `prompt_*.txt` conservent la chaîne de génération et de détourage. Les fichiers `source_*.png` sont les sorties natives retenues, sans retouche de peinture ni miroir hors moteur. Le modèle initial est `model_reference.png`. Le dossier comporte `.gdignore` : Godot charge les atlas finaux, pas les images de travail.
