# Ramener au front — huit directions

Geste S25 approuvé conservé en SE, complété par sept vues dessinées. Carte g04, base et amélioration ; aucun changement de ses règles, coûts ou portée.

## Sources et fabrication

- Images produites avec l'outil intégré imagegen, à partir des repos natifs de chaque caméra. Prompts exacts et PNG conservés dans `sources/`.
- Retenus : E_W_v02, NE_NW_v01, S_N_v01, SW_v02. E_W_v01 porte un fermoir sur l'épaule cachée ; SW_v01 change de bras au retour. Ces essais ne sont pas utilisés.
- Corps séparés par leurs silhouettes opaques, marge de trois pixels ; aucun repeint, découpage destructif ou redimensionnement des fichiers source.
- Métadonnées runtime : `assets/characters/PasseRive/sprites_s31_pull/pull.json`. Dimensions anatomiques fixes par vue, appui et main enregistrés par pose, palette appliquée par le shader existant.
- Séquence temporelle S25 conservée : 11 positions parmi les 12 dessins, 890 ms, poing ramené à 400 ms. La cellule 2 n'est pas utilisée, pour rester sur la même partition que SE.
- Raccords courts au repos natif en entrée/sortie. Aucun miroir, aucune orientation remplacée par l'idle.

## Outils reproductibles

`tools/class_card_vfx/passe_rive_pull_directions/build_metadata.py` lit les pixels source et écrit uniquement la calibration JSON/copie les PNG.
`capture_poses.ps1` filme les huit vues du backend public. Le losange orange est un repère de main limité à ce banc.
`play.ps1 -Capture` exerce la vraie carte, la consommation, les PA, la résolution et le déplacement de la cible.
`build_review.py <poses> <combat>` assemble les captures Godot en GIF, sans toucher aux sprites.

Le lien existant suit la main projetée et uniquement un déplacement confirmé. Les diagonales conservent la sélection d'axe de déplacement des règles de combat. Les VFX ne déplacent jamais une unité logiquement.
