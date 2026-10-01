# Recentrage — S32

Carte `cc2_n08` : doigts de la main droite à la tempe, ouverture de la paume gauche, retour vers le buste et repos. Concept SE approuvé le 30 septembre 2026 par demande d'intégration. Un geste complet, huit directions dessinées, sans miroir. Aucun autre geste produit dans cette étape.

12 poses par vue, 800 ms. Résolution à 360 ms, pose 6. Échelle fixe par vue, stature de référence 214 pixels × profil natif, pied recalé sur le même appui. Palette calibrée par groupe de matières sur le repos natif. Fondu bref aux raccords, locomotion native conservée.

Les glyphes sont des sprites séparés liés à la paume. Ils apparaissent seulement après la confirmation de la pioche : 0–3 selon le nombre réellement ajouté à la main, y compris pioche vide ou main pleine. La consommation de Recentrage libère une place avant la pioche. Les effets n'inventent ni cartes, ni soin, ni protection. Dans les trois vues arrière, le corps peut masquer les glyphes en fin de trajectoire.

## Sources retenues

| Vue | Source originale | Poses |
| --- | --- | --- |
| SE | SE_v01.png | 0–11 |
| E | E_W_v01.png | 0–11 |
| W | W_v02.png | 0–11 |
| NE | NE_v03.png | 0–11 |
| NW | NW_v03.png | 0–11, maintien de la pose 6 au créneau 7 |
| S | S_N_v01.png | 0–9 puis repos 0 aux créneaux 10–11 |
| N | N_v02.png | 0–11 |
| SW | SW_v01.png | 0–11 |

Sources et prompts conservés sous `sources/`, PNG utilisés copiés sans transformation dans `assets/characters/PasseRive/sprites_s32`. `tools/class_card_vfx/passe_rive_s32/build_metadata.py` mesure les régions, appuis, sockets et palettes ; il ne retouche aucun pixel. Le glyphe original est conservé séparément.

Reprises pendant l'audit : W initial rapetissait en fin de geste ; N initial raccourcissait les jambes ; NE/NW initiaux avaient des incohérences d'occlusion et de bras. La revue Godot a aussi révélé un buste NW trop massif : remplacé par NW_v03, recalé sur le repos natif. La pose 6 est maintenue au créneau 7 pour éviter une réouverture prématurée de la paume. Ces versions restent dans les sources pour traçabilité, seules les parties listées ci-dessus sont utilisées. Variation de hauteur de silhouette <2 % dans les huit vues ; pas de redimensionnement compensatoire image par image.

## Lecteurs

Depuis la racine du jeu, PowerShell 7 :

`tools/class_card_vfx/passe_rive_s32/play.ps1` — scène de combat avec carte réelle, choix de direction et cas de pioche.

`tools/class_card_vfx/passe_rive_s32/play.ps1 -Capture` — 40 lancers réels et refus sans PA, rapport et captures.

`tools/class_card_vfx/passe_rive_s32/capture_poses.ps1` — grille des huit vues, base puis amélioration.

Le banc utilise les scripts publics et une session isolée ; aucune sauvegarde de partie de l'utilisateur n'est écrite. Les résultats vérifiés sont consignés dans `VALIDATION.md`.
