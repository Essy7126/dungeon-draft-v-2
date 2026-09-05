# Sources du kit sprite d’Achille v2

Les huit feuilles `source_base_{N,E,S,W}.png` et `source_extra_{N,E,S,W}.png` sont les dessins RGBA produits avec l’outil ImageGen intégré. Les fichiers `prompts/*.txt` conservent les prompts exacts des générations retenues. Les références `reference_*.png` sont des extractions mécaniques des poses idle V1 approuvées ; elles servent à la comparaison d’identité, de volume et d’appuis.

Le modèle conserve son casque ouvert, son visage blond découvert, sa crête rouge courte, son plastron ivoire, sa jupe bleu pétrole, ses sandales et son bouclier à chevron. Lance dans la main droite, bouclier au bras gauche ; pour l’arc, lance et bouclier sont rangés au dos.

| Feuille | Rangées | Prompt retenu |
| --- | --- | --- |
| base E | charge, arc, garde | `prompts/base_E_native_v2.txt` |
| base S | charge, arc, garde | `prompts/base_S.txt` |
| base N | charge, arc, garde | `prompts/base_N_v2.txt` |
| base W | charge, arc, garde | `prompts/base_W.txt` |
| extra E | frappe étendue, volée, réaction, chute | `prompts/extra_E_v3.txt` |
| extra S | frappe étendue, volée, réaction, chute | `prompts/extra_S.txt` |
| extra N | frappe étendue, volée, réaction, chute | `prompts/extra_N.txt` |
| extra W | frappe étendue, volée, réaction, chute | `prompts/extra_W.txt` |

Chaque rangée contient quatre poses. Les huit feuilles représentent 112 dessins. Les images précédées/suivies de l’idle dans les clips utilisent exactement l’idle historique. La pose de relâchement `extra_N[6]` perdait le bouclier : elle est exclue du clip par `clip_overrides`, qui réutilise `base_N[6]`, le même relâchement de l’arc avec l’équipement complet. Cette substitution de référence ne retouche aucun dessin. Ainsi, 111 nouveaux dessins distincts sont effectivement utilisés par les clips, avec réemploi de la pose d’arc.

Les fichiers de revue ne sont jamais consommés par le build : `source_base_N_review.png` présentait un bouclier dupliqué, et `source_extra_E_overlap_review.png` une pointe de lance superposée au pied de la pose voisine. Ils sont conservés pour expliquer les rejets. Les premières propositions à fond quadrillé opaque ou à lance à deux pointes ont également été rejetées.

L’assemblage est mécanique : segmentation des silhouettes et de leurs armes, une échelle fixe par feuille, racines au sol mesurées à la main, rééchantillonnage unique et copie RGBA exacte dans les atlas. Les racines des poses aériennes se rapportent au sol sous le bassin ; celles des poses couchées suivent le bassin au sol, jamais le bas de la lance. Aucun personnage n’est redessiné par script.

Pipeline et repères : `tools/achilles_kit_sprite_pipeline/`. Les six fichiers `alignment_review_*.json` consignent les mesures avant leur réunion dans `alignment.json`. Le manifeste livré dans `assets/characters/Achilles/sprites_kit_v2/manifest.json` conserve les SHA des sources, des alignements et des régions d’atlas.

Le dossier source est exclu de l’import Godot. Le jeu utilise uniquement les atlas et la ressource `SpriteFrames` de `assets/characters/Achilles/sprites_kit_v2/`.
